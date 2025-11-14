/* gallery.js - Gallery, lightbox, and image utilities for Xodus Studios
 * Covers galleries across all pages: image lightboxes, lazy-loading, keyboard navigation,
 * thumbnail prefetching, simple newsletter form handler, and lightweight accessibility helpers.
 * Uses event delegation and defensive coding to work with dynamic content loaded via transitions.js.
 */

(() => {
  'use strict';

  // ---------- Utilities ----------
  const $ = (sel, ctx = document) => (ctx || document).querySelector(sel) || null;
  const $$ = (sel, ctx = document) => Array.from((ctx || document).querySelectorAll(sel));

  const noop = () => {};
  const clamp = (v, a, b) => Math.min(Math.max(v, a), b);

  const debounce = (fn, wait = 100) => {
    let t = null;
    return (...args) => {
      clearTimeout(t);
      t = setTimeout(() => fn(...args), wait);
    };
  };

  const safeFocus = (el) => {
    try { if (el && typeof el.focus === 'function') el.focus(); } catch (e) {}
  };

  // ---------- Lightbox DOM ----------
  const LIGHTBOX_ID = 'xodus-gallery-lightbox';
  let lightbox = null;
  let lbImage = null;
  let lbCaption = null;
  let lbCloseBtn = null;
  let lbPrevBtn = null;
  let lbNextBtn = null;
  let lbBackdrop = null;

  // State of currently open gallery
  const state = {
    items: [], // array of {el, src, alt, caption, large}
    currentIndex: -1,
    isOpen: false
  };

  // Create lightbox on demand
  function ensureLightbox() {
    if (lightbox) return lightbox;

    lightbox = document.createElement('div');
    lightbox.id = LIGHTBOX_ID;
    lightbox.className = 'xodus-lightbox';
    lightbox.setAttribute('aria-hidden', 'true');
    lightbox.innerHTML = `
      <div class="xodus-lightbox-backdrop" id="${LIGHTBOX_ID}-backdrop" tabindex="-1"></div>
      <div class="xodus-lightbox-wrap" role="dialog" aria-modal="true">
        <button class="xodus-lightbox-close" aria-label="Close">×</button>
        <button class="xodus-lightbox-prev" aria-label="Previous image">‹</button>
        <div class="xodus-lightbox-content">
          <img class="xodus-lightbox-image" src="" alt="" />
          <div class="xodus-lightbox-caption" aria-live="polite"></div>
        </div>
        <button class="xodus-lightbox-next" aria-label="Next image">›</button>
      </div>`;

    document.body.appendChild(lightbox);

    lbImage = lightbox.querySelector('.xodus-lightbox-image');
    lbCaption = lightbox.querySelector('.xodus-lightbox-caption');
    lbCloseBtn = lightbox.querySelector('.xodus-lightbox-close');
    lbPrevBtn = lightbox.querySelector('.xodus-lightbox-prev');
    lbNextBtn = lightbox.querySelector('.xodus-lightbox-next');
    lbBackdrop = lightbox.querySelector(`#${LIGHTBOX_ID}-backdrop`);

    // Event listeners
    lbCloseBtn.addEventListener('click', closeLightbox);
    lbBackdrop.addEventListener('click', closeLightbox);
    lbPrevBtn.addEventListener('click', showPrev);
    lbNextBtn.addEventListener('click', showNext);

    document.addEventListener('keydown', (e) => {
      if (!state.isOpen) return;
      if (e.key === 'Escape') closeLightbox();
      if (e.key === 'ArrowLeft') showPrev();
      if (e.key === 'ArrowRight') showNext();
    });
// preload large image
      const src = it.large || it.src;
      const alt = it.alt || '';
      const caption = it.caption || alt || '';

      // accessibility
      lightbox.setAttribute('aria-hidden', 'false');
      state.isOpen = true;
      document.documentElement.classList.add('no-scroll');

      // set temporary low-res image first if available
      lbImage.style.opacity = '0';
      lbImage.src = src; lbImage.alt = alt;
      lbCaption.textContent = caption;

      // focus close for keyboard
      safeFocus(lbCloseBtn);

      // dispatch custom event
      document.dispatchEvent(new CustomEvent('xodus:gallery:opened', { detail: { index, item: it } }));
    } catch (err) { console.error('openLightboxAt', err); }
  }

  function closeLightbox() {
    try {
      if (!lightbox) return;
      lightbox.setAttribute('aria-hidden', 'true');
      state.isOpen = false;
      document.documentElement.classList.remove('no-scroll');
      // return focus to thumbnail if possible
      const idx = state.currentIndex;
      if (typeof idx === 'number' && state.items[idx] && state.items[idx].el) safeFocus(state.items[idx].el);
      state.currentIndex = -1;
      document.dispatchEvent(new Event('xodus:gallery:closed'));
    } catch (err) { console.error('closeLightbox', err); }
  }
function showPrev() { if (!state.items.length) return; openLightboxAt((state.currentIndex - 1 + state.items.length) % state.items.length); }
  function showNext() { if (!state.items.length) return; openLightboxAt((state.currentIndex + 1) % state.items.length); }
// ---------- Gallery Discovery & Management ----------
  // Collect images inside any gallery grid into state.items
  function collectGalleryItems(root = document) {
    try {
      const thumbs = Array.from(root.querySelectorAll('.gallery-grid .gallery-item img, .gallery-item img, img.gallery-thumb'));
      // Deduplicate by src
      const map = new Map();
      const items = [];
      thumbs.forEach(img => {
        try {
          const src = img.getAttribute('data-src') || img.src || img.getAttribute('src');
          if (!src) return;
          if (map.has(src)) return; // skip duplicates
          map.set(src, true);
          const large = img.getAttribute('data-large') || img.getAttribute('data-large-src') || src;
          const caption = img.getAttribute('data-caption') || img.alt || img.title || '';
          items.push({ el: img, src, large, alt: img.alt || '', caption });
        } catch (err) { /* ignore per-image error */ }
      });
      state.items = items;
      return items;
    } catch (err) { console.error('collectGalleryItems', err); return []; }
  }
imgs.forEach(img => io.observe(img));
    } catch (err) { console.error('initLazyImages', err); }
  }

  // ---------- Hover prefetch of large images ----------
  const hoveredPrefetch = new Set();
  const prefetchLarge = debounce((url) => {
    try {
      if (!url || hoveredPrefetch.has(url)) return;
      hoveredPrefetch.add(url);
      const img = new Image(); img.src = url;
    } catch (err) { /* ignore */ }
  }, 40);

  // ---------- Delegated click & keyboard handlers ----------
  function initDelegation() {
    // Open lightbox when clicking thumbnails
    document.body.addEventListener('click', (e) => {
      try {
        const thumb = e.target.closest('.gallery-item img, img.gallery-thumb, [data-open-lightbox]');
        if (!thumb) return;
        e.preventDefault();
// Keyboard accessibility: Enter or Space on thumbnail
    document.body.addEventListener('keydown', (e) => {
      try {
        if (e.key !== 'Enter' && e.key !== ' ') return;
        const focused = document.activeElement;
        if (!focused) return;
        if (focused.matches('.gallery-item img, img.gallery-thumb, [data-open-lightbox]')) {
          e.preventDefault();
          focused.click();
        }
      } catch (err) { console.error('gallery keyboard error', err); }
    });

    // Hover prefetch for large image
    document.body.addEventListener('mouseover', (e) => {
      try {
        const img = e.target.closest('img.gallery-thumb, .gallery-item img');
        if (!img) return;
        const large = img.getAttribute('data-large') || img.getAttribute('data-large-src') || img.getAttribute('data-src') || img.src;
        if (large) prefetchLarge(large);
      } catch (err) { /* ignore */ }
    }, { passive: true });
  }
// ---------- Initialize galleries found on the page ----------
  function initGalleries(root = document) {
    try {
      // collect items for future lightbox usage
      collectGalleryItems(root);
      initLazyImages(root);

      // make thumbnails keyboard accessible
      const thumbs = Array.from(root.querySelectorAll('.gallery-grid .gallery-item img, img.gallery-thumb, .gallery-item img'));
      thumbs.forEach(img => {
        try {
          img.setAttribute('tabindex', img.getAttribute('tabindex') || '0');
          img.setAttribute('role', img.getAttribute('role') || 'button');
          img.setAttribute('aria-label', img.getAttribute('aria-label') || `Open image: ${img.alt || img.title || 'gallery image'}`);
          img.style.cursor = 'pointer';
        } catch (err) {}
      });

    } catch (err) { console.error('initGalleries', err); }
  }

  // ---------- Newsletter simple validation (social page) ----------
  function initNewsletterForm(root = document) {
    try {
      const form = root.querySelector('#newsletter-form');
      if (!form) return;
      if (form._xodusNewsletterInit) return; form._xodusNewsletterInit = true;

      const email = form.querySelector('#newsletter-email') || form.querySelector('input[type="email"]');
      const status = document.createElement('div'); status.className = 'newsletter-status sr-only'; status.setAttribute('aria-live', 'polite');
      form.appendChild(status);

      const isValidEmail = (v) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test((v||'').trim());

      form.addEventListener('submit', (e) => {
        try {
          e.preventDefault();
          const val = email ? email.value.trim() : '';
          if (!isValidEmail(val)) {
            status.textContent = 'Please enter a valid email address.';
            status.classList.add('error');
            if (email) { email.classList.add('input-error'); email.focus(); }
            return;
          }

          // simulate success (action likely '#')
          status.textContent = 'Thanks for subscribing!'; status.classList.remove('error');
          form.reset();
          setTimeout(() => { status.textContent = ''; }, 4000);
        } catch (err) { console.error('newsletter submit error', err); }
      });

      form.addEventListener('input', (e) => {
        const t = e.target; if (!t) return; t.classList.remove('input-error'); status.textContent = '';
      });

    } catch (err) { console.error('initNewsletterForm', err); }
  }

  // ---------- Public-ready reinit runner (used after SPA navigation) ----------
  function reinitialize(root = document) {
    try {
      initGalleries(root);
      initNewsletterForm(root);
      // bind delegated only once
      if (!document._xodusGalleryDelegationInit) { initDelegation(); document._xodusGalleryDelegationInit = true; }
    } catch (err) { console.error('gallery.reinitialize', err); }
  }

  // listen to SPA navigation complete
  document.addEventListener('xodus:navigateComplete', (e) => {
    try { reinitialize(document); } catch (err) { console.error('after navigateComplete', err); }
  });
// On DOM ready, initialize
  document.addEventListener('DOMContentLoaded', () => {
    try {
      reinitialize(document);
    } catch (err) {
      console.error('gallery DOMContentLoaded error', err);
    }
  });

  // Expose small API
  window.XodusGallery = {
    openAt: (index) => openLightboxAt(index),
    openBySrc: (src) => {
      const idx = state.items.findIndex(i => i.src === src || i.large === src);
      if (idx >= 0) openLightboxAt(idx);
    },
    close: () => closeLightbox(),
    reinitialize
  };

})();