import hashlib
import http.client
import io
import json
from pathlib import Path
import stat
import tempfile
import threading
import unittest
from unittest.mock import patch
from zipfile import ZipFile, ZipInfo

from local_server import (API_PATH, UpdateError, UpdateState, create_server,
                          extract_bundle, validate_release, version_tuple)


def manifest(version='2.0.0', build='5'):
    return {'buildId': '20260910120000000000', 'version': version, 'buildNumber': build}


def bundle_bytes(extra=None):
    output = io.BytesIO()
    with ZipFile(output, 'w') as archive:
        for name, data in {
            'index.html': '<title>Updated POS</title>', 'main.dart.js': 'updated',
            'flutter_bootstrap.js': 'bootstrap', 'sqlite3.wasm': b'\0asm',
            'app-update.json': json.dumps(manifest()), **(extra or {}),
        }.items():
            archive.writestr(name, data)
    return output.getvalue()


def release(archive):
    return {'tag_name': 'v2.0.0+5', 'draft': False, 'prerelease': False, 'assets': [{
        'name': 'bazaar-pos-web.zip', 'state': 'uploaded', 'size': len(archive),
        'digest': 'sha256:' + hashlib.sha256(archive).hexdigest(),
        'browser_download_url': 'https://github.com/safin97/flutter-pos/releases/download/v2.0.0+5/bazaar-pos-web.zip',
    }]}


class Response(io.BytesIO):
    status = 200


class FakeOpener:
    def __init__(self, metadata, data):
        self.metadata = metadata
        self.data = data

    def open(self, request, timeout):
        if request.full_url.startswith('https://api.github.com/'):
            return Response(json.dumps(self.metadata).encode())
        return Response(self.data)


class LocalUpdateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.parent = Path(self.temp.name)
        self.root = self.parent / 'web'
        self.root.mkdir()
        (self.root / 'index.html').write_text('original')
        (self.root / 'app-update.json').write_text(json.dumps(manifest('1.0.3', '4')))
        self.database = self.parent / 'market.sqlite'
        self.database.write_bytes(b'preserve market data')

    def install(self, archive, metadata=None):
        state = UpdateState(self.root, 'safin97/flutter-pos')
        state.job = {'state': 'running'}
        state.opener = FakeOpener(metadata or release(archive), archive)
        state.install('v2.0.0+5')
        return state

    def test_verified_bundle_replaces_only_app_and_keeps_previous(self):
        state = self.install(bundle_bytes())
        self.assertEqual(state.job['state'], 'complete')
        self.assertIn('Updated POS', (self.root / 'index.html').read_text())
        self.assertEqual((self.parent / 'web.previous/index.html').read_text(), 'original')
        self.assertEqual(self.database.read_bytes(), b'preserve market data')

    def test_digest_or_size_mismatch_keeps_original(self):
        archive = bundle_bytes()
        for change in ({'digest': 'sha256:' + '0' * 64}, {'size': len(archive) - 1}, {'digest': None}):
            metadata = release(archive)
            metadata['assets'][0].update(change)
            state = self.install(archive, metadata)
            self.assertEqual(state.job['state'], 'failed')
            self.assertEqual((self.root / 'index.html').read_text(), 'original')

    def test_release_validation_rejects_downgrades_changed_releases_and_foreign_downloads(self):
        archive = bundle_bytes()
        for current in ('2.0.0+5', '3.0.0+1'):
            with self.assertRaises(UpdateError):
                validate_release(release(archive), 'safin97/flutter-pos', 'v2.0.0+5', current)
        metadata = release(archive)
        for change in ({'draft': True}, {'prerelease': True}, {'tag_name': 'v3.0.0'}):
            with self.assertRaises(UpdateError):
                validate_release({**metadata, **change}, 'safin97/flutter-pos', 'v2.0.0+5', '1.0.3+4')
        metadata['assets'][0]['browser_download_url'] = 'https://example.com/update.zip'
        with self.assertRaises(UpdateError):
            validate_release(metadata, 'safin97/flutter-pos', 'v2.0.0+5', '1.0.3+4')
        self.assertEqual(version_tuple('v1.0.0.3'), (1, 0, 0, 3))

    def test_archive_traversal_and_wrong_app_version_never_activate(self):
        for extra in (
            {'../market.sqlite': 'bad'}, {'/tmp/escape': 'bad'},
            {'nested\\escape': 'bad'}, {'MAIN.DART.JS': 'bad'},
            {'app-update.json': json.dumps(manifest('9.0.0'))},
        ):
            state = self.install(bundle_bytes(extra))
            self.assertEqual(state.job['state'], 'failed')
            self.assertEqual((self.root / 'index.html').read_text(), 'original')
            self.assertEqual(self.database.read_bytes(), b'preserve market data')

    def test_symlinks_and_non_zip_packages_are_rejected(self):
        output = io.BytesIO(bundle_bytes())
        with ZipFile(output, 'a') as archive:
            link = ZipInfo('link')
            link.create_system = 3
            link.external_attr = (stat.S_IFLNK | 0o777) << 16
            archive.writestr(link, '../market.sqlite')
        for data in (output.getvalue(), b'not an archive'):
            self.assertEqual(self.install(data).job['state'], 'failed')
            self.assertEqual((self.root / 'index.html').read_text(), 'original')

    def test_failed_activation_restores_old_app(self):
        stage = self.parent / 'stage'
        stage.mkdir()
        import os
        replace = os.replace
        def fail_stage(source, target):
            if source == stage:
                raise OSError('simulated failed rename')
            return replace(source, target)
        with patch('local_server.os.replace', side_effect=fail_stage):
            with self.assertRaises(OSError):
                UpdateState(self.root, 'safin97/flutter-pos').activate(stage)
        self.assertEqual((self.root / 'index.html').read_text(), 'original')

    def test_http_requires_local_host_origin_and_token(self):
        server = create_server(self.root, port=0)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        def cleanup():
            server.shutdown()
            server.server_close()
            thread.join()
        self.addCleanup(cleanup)
        host = 'localhost:' + str(server.server_port)
        def request(method, headers=None, body=None):
            connection = http.client.HTTPConnection('127.0.0.1', server.server_port, timeout=3)
            connection.request(method, API_PATH, body=body, headers={'Host': host, **(headers or {})})
            response = connection.getresponse()
            result = response.status, response.read(), response.getheader('Access-Control-Allow-Origin')
            connection.close()
            return result
        status, body, cors = request('GET')
        self.assertEqual(status, 200)
        self.assertIsNone(cors)
        token = json.loads(body)['token']
        for bad in ({'Host': 'evil.example'}, {'Origin': 'https://evil.example'}, {'Sec-Fetch-Site': 'cross-site'}):
            self.assertEqual(request('GET', bad)[0], 403)
        headers = {'Content-Type': 'application/json', 'Origin': 'http://' + host}
        body = json.dumps({'tag': 'v2.0.0+5'})
        self.assertEqual(request('POST', headers, body)[0], 403)
        headers['X-Bazaar-Update-Token'] = token
        with patch.object(server.updates, 'start', return_value='job-id') as start:
            self.assertEqual(request('POST', headers, body)[0], 202)
            start.assert_called_once_with('v2.0.0+5')


if __name__ == '__main__':
    unittest.main()
