// The loopback service installs web files; browser market data stays in IndexedDB.
(() => {
  const endpoint = new URL('/_bazaar/updater', location.origin);
  let capability;
  let pending = false;
  const pause = ms => new Promise(resolve => setTimeout(resolve, ms));
  async function request(options = {}) {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 12000);
    try {
      const response = await fetch(endpoint, {
        cache: 'no-store', mode: 'same-origin', ...options, signal: controller.signal,
      });
      const value = await response.json();
      if (!response.ok) throw new Error(value.error || 'updateInstallFailed');
      return value;
    } finally { clearTimeout(timeout); }
  }
  window.bazaarUpdateCapabilities = async () => {
    if (location.protocol !== 'http:' || !['localhost', '127.0.0.1'].includes(location.hostname)) {
      return JSON.stringify({kind: 'none'});
    }
    try {
      capability = await request();
      if (capability.protocol !== 1 || typeof capability.token !== 'string') throw new Error();
      return JSON.stringify({kind: 'localWeb', repository: capability.repository});
    } catch (_) {
      capability = null;
      return JSON.stringify({kind: 'none'});
    }
  };
  window.bazaarInstallWebUpdate = async (tag, onProgress) => {
    if (pending) return JSON.stringify({error: 'updateBusy'});
    if (!capability) return JSON.stringify({error: 'updateInstallerUnavailable'});
    pending = true;
    try {
      const latest = await request();
      if (latest.protocol !== 1 || latest.repository !== capability.repository) {
        throw new Error('updateInstallerUnavailable');
      }
      const job = await request({
        method: 'POST',
        headers: {'Content-Type': 'application/json', 'X-Bazaar-Update-Token': latest.token},
        body: JSON.stringify({tag}),
      });
      const deadline = Date.now() + 10 * 60 * 1000;
      while (Date.now() < deadline) {
        const state = (await request()).job;
        if (!state || state.id !== job.id) throw new Error('updateInstallFailed');
        onProgress(JSON.stringify(state));
        if (state.state === 'failed') throw new Error(state.error || 'updateInstallFailed');
        if (state.state === 'complete') return JSON.stringify({ok: true});
        await pause(500);
      }
      throw new Error('updateInstallFailed');
    } catch (error) {
      return JSON.stringify({error: error.message || 'updateInstallFailed'});
    } finally { pending = false; }
  };
})();
