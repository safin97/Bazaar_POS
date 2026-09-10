// Google tokens stay in memory and are never stored in the POS database.
(() => {
  let loading;
  let cancelPending;
  window.bazaarDrivePrepare = function () {
    if (window.google?.accounts?.oauth2) return Promise.resolve();
    if (loading) return loading;
    loading = new Promise((resolve, reject) => {
      const script = document.createElement('script');
      script.src = 'https://accounts.google.com/gsi/client';
      script.async = true;
      const timeout = setTimeout(() => fail(), 20000);
      const fail = () => {
        clearTimeout(timeout);
        script.remove();
        loading = null;
        reject(new Error('Google sign-in is unavailable'));
      };
      script.onerror = fail;
      script.onload = () => {
        clearTimeout(timeout);
        if (window.google?.accounts?.oauth2) resolve();
        else fail();
      };
      document.head.appendChild(script);
    });
    return loading;
  };
  window.bazaarDriveCancel = () => cancelPending?.();
  window.bazaarDriveConnect = function (clientId) {
    if (!window.google?.accounts?.oauth2) {
      return Promise.resolve(JSON.stringify({error: 'driveConnectionFailed'}));
    }
    return new Promise(resolve => {
      let finished = false;
      const finish = value => {
        if (finished) return;
        finished = true;
        clearTimeout(timeout);
        cancelPending = null;
        resolve(JSON.stringify(value));
      };
      const timeout = setTimeout(() => finish({error: 'driveSignInCancelled'}), 120000);
      cancelPending = () => finish({error: 'driveSignInCancelled'});
      const scope = 'https://www.googleapis.com/auth/drive.appdata';
      try {
        const client = google.accounts.oauth2.initTokenClient({
        client_id: clientId,
        scope: `openid email ${scope}`,
        include_granted_scopes: false,
        callback: response => {
          if (response.error || !response.access_token) {
            finish({error: 'driveSignInCancelled'});
          } else if (!google.accounts.oauth2.hasGrantedAllScopes(response, scope)) {
            finish({error: 'drivePermissionMissing'});
          } else {
            finish({accessToken: response.access_token, expiresIn: Number(response.expires_in)});
          }
        },
        error_callback: () => finish({error: 'driveSignInCancelled'}),
        });
        client.requestAccessToken({prompt: 'select_account'});
      } catch (_) {
        finish({error: 'driveConnectionFailed'});
      }
    });
  };
})();
