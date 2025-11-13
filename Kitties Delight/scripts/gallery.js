// gallery.js - Gallery and lightbox functionality for Kitties Delight

(() => {
  'use strict';

  // Utility selectors
  const select = (selector, scope = document) => scope.querySelector(selector) || null;
  const selectAll = (selector, scope = document) => Array.from(scope.querySelectorAll(selector));

  // Safe query with error handling
  const safeQuery = (selector, scope = document) => {
    try {
      const el = select(selector, scope);
      return el || null;
    } catch (e) {
      console.error(`Failed to select element ${selector}: `, e);
      return null;
    }
  };

  // Lightbox Elements
  let lightbox = null;
  let lightboxImg = null;
  let lightboxCaption = null;
  let lightboxCloseBtn = null;
  let lightboxBackdrop = null;

  // Gallery container and items
  let galleryContainer = null;
  let galleryItems = [];
  let currentIndex = -1;

  // Initialize Lightbox elements and setup events
  function initLightbox() {
    lightbox = safeQuery('#lightbox');
    lightboxImg = safeQuery('#lightbox-img');
    lightboxCaption = safeQuery('#lightbox-caption');
    lightboxCloseBtn = safeQuery('#lightbox-close-btn');
    lightboxBackdrop = safeQuery('#lightbox-backdrop');

    if (!lightbox || !lightboxImg || !lightboxCloseBtn || !lightboxBackdrop) {
      console.warn('Gallery: Lightbox elements missing, skipping lightbox init.');
      return;
    }

    // Close lightbox handlers
    lightboxCloseBtn.addEventListener('click', closeLightbox);
    lightboxBackdrop.addEventListener('click', closeLightbox);

    document.addEventListener('keydown', e => {
      if (!isLightboxOpen()) return;
      switch (e.key) {
        case 'Escape':
          e.preventDefault();
          closeLightbox();
          break;
        case 'ArrowLeft':
          e.preventDefault();
          showPrevImage();
          break;
        case 'ArrowRight':
          e.preventDefault();
          showNextImage();
          break;
      }
    });

    document.addEventListener('lightboxClose', closeLightbox);
  }

  // Check if lightbox is open
  function isLightboxOpen() {
    return lightbox && lightbox.classList.contains('open');
  }

  // Open lightbox at index
  function openLightbox(index) {
    if (!galleryItems.length || index < 0 || index >= galleryItems.length) return;

    currentIndex = index;
    updateLightbox();
    lightbox.classList.add('open');
    document.body.style.overflow = 'hidden'; // prevent background scroll
    lightboxCloseBtn.focus();
  }

  // Close lightbox
  function closeLightbox() {
    if (!isLightboxOpen()) return;
    lightbox.classList.remove('open');
    document.body.style.overflow = '';
    // Return focus to original thumbnail
    if (currentIndex >= 0 && galleryItems[currentIndex]) {
      galleryItems[currentIndex].focus();
    }
    currentIndex = -1;
  }

  // Update lightbox image and caption
  function updateLightbox() {
    if (currentIndex < 0 || currentIndex >= galleryItems.length) return;
    const item = galleryItems[currentIndex];
    if (!item) return;
const largeSrc = item.getAttribute('data-large') || item.src || item.getAttribute('src');
    const altText = item.alt || 'Kitten image';
    const captionText = item.getAttribute('data-caption') || altText;

    // Preload large image before updating
    const img = new Image();
    img.onload = () => {
      lightboxImg.src = largeSrc;
      lightboxImg.alt = altText;
      lightboxCaption.textContent = captionText;
    };
    img.onerror = () => {
      console.warn('Failed to load large image:', largeSrc);
      lightboxImg.src = largeSrc;
      lightboxCaption.textContent = captionText;
    };
    img.src = largeSrc;
  }

  // Show previous image
  function showPrevImage() {
    currentIndex = (currentIndex - 1 + galleryItems.length) % galleryItems.length;
    updateLightbox();
  }

  // Show next image
  function showNextImage() {
    currentIndex = (currentIndex + 1) % galleryItems.length;
    updateLightbox();
  }

  // Initialize gallery: Delegated click to open lightbox
  function initGallery() {
    galleryContainer = safeQuery('.gallery-grid');
    if (!galleryContainer) {
      // Possibly no gallery on this page
      return;
    }

    // Gather gallery images
    galleryItems = selectAll('.gallery-image', galleryContainer);

    if (!galleryItems.length) return;

    // Add keyboard accessibility
    galleryItems.forEach(img => {
      img.setAttribute('tabindex', '0');
      img.setAttribute('role', 'button');
      img.setAttribute('aria-label', `View large image of ${img.alt || 'kitten'}`);
      img.style.cursor = 'pointer';
    });
// Click and keyboard event delegation
    galleryContainer.addEventListener('click', event => {
      const target = event.target.closest('img.gallery-image');
      if (!target) return;
      event.preventDefault();
      const idx = galleryItems.indexOf(target);
      if (idx >= 0) openLightbox(idx);
    });

    galleryContainer.addEventListener('keydown', event => {
      const target = event.target.closest('img.gallery-image');
      if (!target) return;
      if (event.key === 'Enter' || event.key === ' ') {
        event.preventDefault();
        const idx = galleryItems.indexOf(target);
        if (idx >= 0) openLightbox(idx);
      }
    });
  }
// Lazy load gallery images
  function initLazyLoadGalleryImages() {
    if (!('IntersectionObserver' in window)) {
      galleryItems.forEach(img => {
        const src = img.getAttribute('data-src');
        if (src) {
          img.src = src;
          img.removeAttribute('data-src');
        }
      });
      return;
    }

    const observer = new IntersectionObserver((entries, obs) => {
      entries.forEach(entry => {
        if (!entry.isIntersecting) return;
        const img = entry.target;
        const src = img.getAttribute('data-src');
        if (src) {
          img.src = src;
          img.removeAttribute('data-src');
        }
        obs.unobserve(img);
      });
    }, { rootMargin: '100px 0px' });

    galleryItems.forEach(img => observer.observe(img));
  }

  // Initialization
  document.addEventListener('DOMContentLoaded', () => {
    try {
      initGallery();
      initLightbox();
      if (galleryItems.length > 0) initLazyLoadGalleryImages();
    } catch (e) {
      console.error('Error initializing gallery.js:', e);
    }
  });

})();

// End of gallery.js