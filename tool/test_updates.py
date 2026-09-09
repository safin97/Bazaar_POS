"""Exercise the web update bridge in headless Chrome without a release server."""
import os
from pathlib import Path
import subprocess
import tempfile

bridge = Path('web/app_updates.js').read_text()
script = '''
const assert = (ok) => { if (!ok) throw new Error('Assertion failed'); };
Object.defineProperty(document, 'baseURI', {value: 'http://localhost:8080/pos/'});
let response = {ok: true, json: async () => ({buildId: '20260910010203000000'})};
window.fetch = async (url, options) => {
  assert(url.origin === 'http://localhost:8080');
  assert(url.pathname === '/pos/app-update.json');
  assert(options.cache === 'no-store' && url.searchParams.has('check'));
  return response;
};
'''
checks = '''
(async () => {
  assert(await bazaarFetchBuildId() === '20260910010203000000');
  for (const invalid of [{ok: false}, {ok: true, json: async () => ({buildId: 'bad'})}]) {
    response = invalid;
    let rejected = false;
    try { await bazaarFetchBuildId(); } catch (_) { rejected = true; }
    assert(rejected);
  }
  document.body.textContent = 'UPDATE TESTS PASSED';
})().catch(error => document.body.textContent = 'FAILED: ' + error);
'''
with tempfile.TemporaryDirectory() as directory:
    page = Path(directory) / 'test.html'
    page.write_text('<html><body><script>' + script + bridge + checks + '</script></body></html>')
    result = subprocess.run([os.environ['CHROME_EXECUTABLE'], '--no-sandbox', '--dump-dom', page.as_uri()], capture_output=True, text=True, timeout=30)
    if '<body>UPDATE TESTS PASSED</body>' not in result.stdout:
        raise RuntimeError(result.stdout + result.stderr)
print('Update bridge tests passed')
