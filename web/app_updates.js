window.bazaarFetchBuildId = async function () {
  const url = new URL('app-update.json', document.baseURI);
  url.searchParams.set('check', Date.now().toString());
  const response = await fetch(url, {cache: 'no-store'});
  if (!response.ok) throw new Error('Update check unavailable');
  const release = await response.json();
  if (typeof release.buildId !== 'string' || !/^\d{20}$/.test(release.buildId)) {
    throw new Error('Invalid release manifest');
  }
  return release.buildId;
};
window.bazaarReloadApp = function () {
  window.location.reload();
};
