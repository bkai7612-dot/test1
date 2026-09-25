// ---------------------------------------------------------------------------
// EDIT HERE when the apps go live: paste the store links between the quotes.
// Leave a link empty ('') and its button shows "Coming soon".
// ---------------------------------------------------------------------------
const LINKS = {
  appStore: '', // e.g. 'https://apps.apple.com/gb/app/homefolio/id1234567890'
  googlePlay: '', // e.g. 'https://play.google.com/store/apps/details?id=uk.co.homefolio.app'
};

// Mark the visitor's device on <html> so the right download button stands out.
(function detectDevice() {
  const ua = navigator.userAgent;
  const root = document.documentElement;
  if (/iPhone|iPad|iPod/i.test(ua) || (/Macintosh/i.test(ua) && navigator.maxTouchPoints > 1)) root.classList.add('is-ios');
  else if (/Android/i.test(ua)) root.classList.add('is-android');
  else if (/Windows/i.test(ua)) root.classList.add('is-windows');
  else if (/Macintosh/i.test(ua)) root.classList.add('is-mac');
})();

document.querySelectorAll('[data-store]').forEach((el) => {
  const url = LINKS[el.getAttribute('data-store')];
  if (url) {
    el.setAttribute('href', url);
    el.removeAttribute('aria-disabled');
  } else {
    el.setAttribute('aria-disabled', 'true');
    el.removeAttribute('href');
    const label = el.querySelector('.store-label');
    if (label) label.textContent += ' — coming soon';
  }
});

document.querySelectorAll('[data-year]').forEach((el) => {
  el.textContent = String(new Date().getFullYear());
});
