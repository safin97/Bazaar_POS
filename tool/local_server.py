"""Loopback-only POS server with verified, staged GitHub web updates.

Only application files in build/web are replaced. Browser IndexedDB and native
market databases are never read or changed by this service.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import secrets
import shutil
import stat
import tempfile
import threading
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import urllib.parse
import urllib.request
from zipfile import ZipFile

MAX_DOWNLOAD = 256 * 1024 * 1024
MAX_EXPANDED = 512 * 1024 * 1024
MAX_FILE = 64 * 1024 * 1024
API_PATH = '/_bazaar/updater'


class UpdateError(Exception):
    pass


def version_tuple(value):
    match = re.fullmatch(r'v?(\d+)\.(\d+)\.(\d+)(?:[.+](\d+))?', value)
    if not match:
        raise UpdateError('invalidGitHubRelease')
    return tuple(int(part or 0) for part in match.groups())


def read_manifest(root):
    value = json.loads((root / 'app-update.json').read_text())
    if not re.fullmatch(r'\d{20}', value.get('buildId', '')):
        raise UpdateError('updateArchiveInvalid')
    version_tuple(value['version'] + '+' + value['buildNumber'])
    return value


def validate_release(release, repository, tag, current):
    if (release.get('tag_name') != tag or release.get('draft') is not False
            or release.get('prerelease') is not False):
        raise UpdateError('updateReleaseChanged')
    if version_tuple(tag) <= version_tuple(current):
        raise UpdateError('updateNotNewer')
    for asset in release.get('assets', []):
        if asset.get('name') != 'bazaar-pos-web.zip' or asset.get('state') != 'uploaded':
            continue
        expected = 'https://github.com/' + repository + '/releases/download/'
        expected += urllib.parse.quote(tag, safe='+.') + '/bazaar-pos-web.zip'
        if asset.get('browser_download_url') != expected:
            raise UpdateError('invalidGitHubRelease')
        digest = asset.get('digest')
        if not isinstance(digest, str) or not re.fullmatch(r'sha256:[0-9a-fA-F]{64}', digest):
            raise UpdateError('updateDigestMissing')
        size = asset.get('size')
        if type(size) is not int or not 0 < size <= MAX_DOWNLOAD:
            raise UpdateError('updateArchiveInvalid')
        return expected, digest[7:].lower(), size
    raise UpdateError('githubNoInstallerHint')


def extract_bundle(archive, destination, tag):
    with ZipFile(archive) as bundle:
        entries = bundle.infolist()
        if not entries or len(entries) > 2000 or sum(e.file_size for e in entries) > MAX_EXPANDED:
            raise UpdateError('updateArchiveInvalid')
        seen = set()
        for entry in entries:
            path = PurePosixPath(entry.filename)
            parts = entry.filename.rstrip('/').split('/')
            kind = stat.S_IFMT(entry.external_attr >> 16)
            if (path.is_absolute() or any(p in ('', '.', '..') for p in parts)
                    or '\\' in entry.filename or ':' in entry.filename
                    or kind not in (0, stat.S_IFREG, stat.S_IFDIR)
                    or entry.flag_bits & 1 or entry.file_size > MAX_FILE
                    or entry.filename.rstrip('/').casefold() in seen):
                raise UpdateError('updateArchiveInvalid')
            seen.add(entry.filename.rstrip('/').casefold())
            target = destination.joinpath(*parts)
            if entry.is_dir():
                target.mkdir(parents=True, exist_ok=True)
                continue
            target.parent.mkdir(parents=True, exist_ok=True)
            with bundle.open(entry) as source, target.open('xb') as output:
                shutil.copyfileobj(source, output, 1024 * 1024)
            if target.stat().st_size != entry.file_size:
                raise UpdateError('updateArchiveInvalid')
        for name in ('index.html', 'main.dart.js', 'flutter_bootstrap.js', 'sqlite3.wasm'):
            if not (destination / name).is_file():
                raise UpdateError('updateArchiveInvalid')
        manifest = read_manifest(destination)
        if version_tuple(manifest['version'] + '+' + manifest['buildNumber']) != version_tuple(tag):
            raise UpdateError('updateArchiveInvalid')
        return manifest


class GitHubRedirects(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        url = urllib.parse.urlsplit(newurl)
        if (url.scheme != 'https' or url.hostname not in (
                'github.com', 'release-assets.githubusercontent.com', 'objects.githubusercontent.com')
                or url.username or url.password or url.port not in (None, 443)):
            raise UpdateError('updateInstallFailed')
        return super().redirect_request(req, fp, code, msg, headers, newurl)


class UpdateState:
    def __init__(self, root, repository):
        self.root = Path(root).resolve()
        self.repository = repository
        if not re.fullmatch(r'[\w.-]+/[\w.-]+', repository):
            raise ValueError('Invalid GitHub repository')
        self.token = secrets.token_urlsafe(32)
        self.lock = threading.RLock()
        self.files_lock = threading.RLock()
        self.job = None
        self.opener = urllib.request.build_opener(GitHubRedirects())

    def snapshot(self):
        with self.lock:
            return {'protocol': 1, 'repository': self.repository, 'token': self.token,
                    'job': dict(self.job) if self.job else None}

    def start(self, tag):
        version_tuple(tag)
        with self.lock:
            if self.job and self.job['state'] == 'running':
                raise UpdateError('updateBusy')
            job_id = secrets.token_hex(16)
            self.job = {'id': job_id, 'state': 'running', 'stage': 'updateDownloading', 'progress': 0}
            threading.Thread(target=self.install, args=(tag,), daemon=True).start()
            return job_id

    def progress(self, **values):
        with self.lock:
            self.job.update(values)

    def install(self, tag):
        try:
            manifest = read_manifest(self.root)
            current = manifest['version'] + '+' + manifest['buildNumber']
            request = urllib.request.Request(
                'https://api.github.com/repos/' + self.repository + '/releases/latest',
                headers={'Accept': 'application/vnd.github+json', 'User-Agent': 'Bazaar-POS-Updater'})
            with self.opener.open(request, timeout=20) as response:
                raw = response.read(2 * 1024 * 1024 + 1)
                if len(raw) > 2 * 1024 * 1024:
                    raise UpdateError('invalidGitHubRelease')
                release = json.loads(raw)
            url, digest, size = validate_release(release, self.repository, tag, current)
            with tempfile.TemporaryDirectory(prefix='.web-update-', dir=self.root.parent) as temp:
                temp = Path(temp)
                archive = temp / 'update.zip'
                checksum = hashlib.sha256()
                downloaded = 0
                request = urllib.request.Request(url, headers={'User-Agent': 'Bazaar-POS-Updater'})
                with self.opener.open(request, timeout=30) as response, archive.open('xb') as output:
                    if response.status != 200:
                        raise UpdateError('updateInstallFailed')
                    while True:
                        chunk = response.read(1024 * 1024)
                        if not chunk:
                            break
                        downloaded += len(chunk)
                        if downloaded > size or downloaded > MAX_DOWNLOAD:
                            raise UpdateError('updateArchiveInvalid')
                        checksum.update(chunk)
                        output.write(chunk)
                        self.progress(progress=downloaded / size)
                self.progress(stage='updateVerifying', progress=None)
                if downloaded != size or checksum.hexdigest() != digest:
                    raise UpdateError('updateArchiveInvalid')
                staged = temp / 'app'
                staged.mkdir()
                extract_bundle(archive, staged, tag)
                self.progress(stage='updateInstalling')
                self.activate(staged)
            self.progress(state='complete', stage='updateRestarting', progress=1)
        except Exception as error:
            key = str(error) if isinstance(error, UpdateError) else 'updateInstallFailed'
            self.progress(state='failed', error=key, progress=None)

    def activate(self, staged):
        previous = self.root.with_name(self.root.name + '.previous')
        with self.files_lock:
            if previous.is_symlink():
                raise UpdateError('updateArchiveInvalid')
            if previous.exists():
                shutil.rmtree(previous)
            os.replace(self.root, previous)
            try:
                os.replace(staged, self.root)
            except BaseException:
                os.replace(previous, self.root)
                raise


class LocalHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(args[2].updates.root), **kwargs)

    def allowed(self, mutate=False):
        port = self.server.server_port
        hosts = ('localhost:' + str(port), '127.0.0.1:' + str(port))
        if self.headers.get('Host') not in hosts:
            return False
        origins = tuple('http://' + host for host in hosts)
        origin = self.headers.get('Origin')
        if origin is not None and origin not in origins:
            return False
        if self.headers.get('Sec-Fetch-Site') not in (None, 'same-origin', 'none'):
            return False
        return not mutate or (origin in origins and secrets.compare_digest(
            self.headers.get('X-Bazaar-Update-Token', ''), self.server.updates.token))

    def end_headers(self):
        self.send_header('Cache-Control', 'no-store')
        self.send_header('Referrer-Policy', 'no-referrer-when-downgrade')
        self.send_header('X-Content-Type-Options', 'nosniff')
        super().end_headers()

    def json_response(self, status, value):
        data = json.dumps(value).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if not self.allowed():
            self.send_error(403)
            return
        if urllib.parse.urlsplit(self.path).path == API_PATH:
            self.json_response(200, self.server.updates.snapshot())
        else:
            with self.server.updates.files_lock:
                super().do_GET()

    def do_HEAD(self):
        if not self.allowed():
            self.send_error(403)
            return
        with self.server.updates.files_lock:
            super().do_HEAD()

    def do_POST(self):
        if not self.allowed(mutate=True):
            self.json_response(403, {'error': 'updateInstallFailed'})
            return
        if urllib.parse.urlsplit(self.path).path != API_PATH:
            self.send_error(404)
            return
        try:
            length = int(self.headers.get('Content-Length', '0'))
            if not 0 < length <= 1024 or self.headers.get_content_type() != 'application/json':
                raise UpdateError('updateInstallFailed')
            body = json.loads(self.rfile.read(length))
            tag = body.get('tag')
            if not isinstance(tag, str) or len(tag) > 80:
                raise UpdateError('invalidGitHubRelease')
            job_id = self.server.updates.start(tag)
            self.json_response(202, {'id': job_id})
        except Exception as error:
            key = str(error) if isinstance(error, UpdateError) else 'updateInstallFailed'
            self.json_response(400, {'error': key})


def create_server(root, port=8080, repository='safin97/MarketBazaar'):
    root = Path(root).resolve()
    previous = root.with_name(root.name + '.previous')
    # Recover if the process stopped between the two directory renames.
    if not root.exists() and previous.is_dir() and not previous.is_symlink():
        os.replace(previous, root)
    if not (root / 'index.html').is_file():
        raise ValueError('Build the app with bash tool/build_web.sh first.')
    server = ThreadingHTTPServer(('127.0.0.1', port), LocalHandler)
    server.updates = UpdateState(root, repository)
    return server


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port', type=int, default=8080)
    parser.add_argument('--directory', type=Path, default=Path(__file__).resolve().parents[1] / 'build/web')
    parser.add_argument('--repository', default='safin97/MarketBazaar')
    options = parser.parse_args()
    with create_server(options.directory, options.port, options.repository) as server:
        print('Bazaar POS: http://localhost:' + str(server.server_port), flush=True)
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            pass
