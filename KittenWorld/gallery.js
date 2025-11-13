// gallery.js - Specialized gallery and lightbox functionality for KittenWorld

(() => {
  const KEY_CODES = {
    ESC: 'Escape',
    LEFT: 'ArrowLeft',
    RIGHT: 'ArrowRight'
  };

  // Utility selectors
  const select = (selector, scope = document) => scope.querySelector(selector);
  const selectAll = (selector, scope = document) => Array.from(scope.querySelectorAll(selector));

  // Safe query guard
  const safeQuery = (selector, scope = document) => {
    try {
      const el = select(selector, scope);
      return el || null;
    } catch (e) {
      console.error(`Failed to select element ${selector}: `, e);
      return null;
    }
  };

  // Lightbox state and elements
  let lightbox = null;
  let lightboxImg = null;
  let lightboxCloseBtn = null;
  let lightboxBackdrop = null;

  // Gallery container
  let galleryContainer = null;

  // List of gallery image elements
  let galleryItems = [];

  // Current image index displayed in lightbox
  let currentIndex = -1;

  // Initialize lightbox elements and event listeners
  function initLightbox() {
    lightbox = safeQuery('#lightbox');
    lightboxImg = safeQuery('#lightbox-img');
    lightboxCloseBtn = safeQuery('#lightbox-close-btn');
    lightboxBackdrop = safeQuery('#lightbox-backdrop');

    if (!lightbox || !lightboxImg || !lightboxCloseBtn || !lightboxBackdrop) {
      console.warn('Lightbox elements not found, skipping lightbox init.');
      return;
    }

    // Close handlers
    lightboxCloseBtn.addEventListener('click', closeLightbox);
    lightboxBackdrop.addEventListener('click', closeLightbox);

    // Keyboard navigation inside lightbox
    document.addEventListener('keydown', e => {
      if (!isLightboxOpen()) return;

      switch (e.key) {
        case KEY_CODES.ESC:
          e.preventDefault();
          closeLightbox();
          break;
        case KEY_CODES.LEFT:
          e.preventDefault();
          showPrevImage();
          break;
        case KEY_CODES.RIGHT:
          e.preventDefault();
          showNextImage();
          break;
      }
    });

    // Custom event to close from main.js
    document.addEventListener('lightboxClose', closeLightbox);
  }

  // Check if lightbox is open
  function isLightboxOpen() {
    return lightbox && lightbox.classList.contains('open');
  }

  // Open lightbox with image at given index
  function openLightbox(index) {
    if (!galleryItems.length || index < 0 || index >= galleryItems.length) return;

    currentIndex = index;
    updateLightboxImage();

    lightbox.classList.add('open');
    document.body.style.overflow = 'hidden'; // Prevent background scroll

    // Set focus for accessibility
    lightboxCloseBtn.focus();
  }

  // Close lightbox
  function closeLightbox() {
    if (!isLightboxOpen()) return;

    lightbox.classList.remove('open');
    document.body.style.overflow = '';

    // Return focus to the thumbnail that opened the lightbox
    if (currentIndex >= 0 && galleryItems[currentIndex]) {
      galleryItems[currentIndex].focus();
    }

    currentIndex = -1;
  }

  // Update lightbox image src and alt
  function updateLightboxImage() {
    if (currentIndex < 0 || currentIndex >= galleryItems.length) return;

    const thumb = galleryItems[currentIndex];
    if (!thumb) return;

    const largeSrc = thumb.getAttribute('data-large-src') || thumb.src || thumb.getAttribute('src');
    const altText = thumb.getAttribute('alt') || 'Kitten image';

    // Load image and handle errors
    try {
      lightboxImg.src = '';
      lightboxImg.alt = altText;
      // Preload image
      const imgPreload = new Image();
      imgPreload.onload = () => {
        lightboxImg.src = largeSrc;
      };
      imgPreload.onerror = () => {
        console.warn('Failed to load large image:', largeSrc);
        lightboxImg.src = largeSrc; // fallback
      };
      imgPreload.src = largeSrc;
    } catch (e) {
      console.error('Error updating lightbox image:', e);
      lightboxImg.src = largeSrc;
      lightboxImg.alt = altText;
    }
  }

  // Show previous image in gallery
  function showPrevImage() {
    if (currentIndex <= 0) {
      currentIndex = galleryItems.length - 1;
    } else {
      currentIndex--;
    }
    updateLightboxImage();
  }
// Show next image in gallery
  function showNextImage() {
    if (currentIndex === galleryItems.length - 1) {
      currentIndex = 0;
    } else {
      currentIndex++;
    }
    updateLightboxImage();
  }

  // Initialize gallery and attach click event delegation
  function initGallery() {
    galleryContainer = safeQuery('.gallery-container');
    if (!galleryContainer) {
      // Possibly no gallery on this page; no error.
      return;
    }

    // Prepare list of all clickable thumbnails
    galleryItems = selectAll('.gallery-item img, .gallery-item picture img', galleryContainer);

    if (!galleryItems.length) {
      console.warn('No gallery items found.');
      return;
    }

    // Delegate click event to open lightbox
    galleryContainer.addEventListener('click', event => {
      const target = event.target;
      if (!(target.matches('img') || target.closest('img'))) return;

      event.preventDefault();

      // Find index of clicked image
      let clickedImg = target.matches('img') ? target : target.closest('img');

      let index = galleryItems.indexOf(clickedImg);
      if (index === -1) return; // Not part of gallery

      openLightbox(index);
    });

    // Make gallery images keyboard accessible
    galleryItems.forEach(img => {
      img.setAttribute('tabindex', '0');
      img.setAttribute('role', 'button');
      img.setAttribute('aria-label', 'Open image in lightbox');
      img.style.cursor = 'pointer';
    });
// Keyboard activation for gallery items
    galleryContainer.addEventListener('keydown', event => {
      const {target, key} = event;
      if ((key === 'Enter' || key === ' ') && (target.matches('img') || target.closest('img'))) {
        event.preventDefault();
        const img = target.matches('img') ? target : target.closest('img');
        const idx = galleryItems.indexOf(img);
        if (idx >= 0) openLightbox(idx);
      }
    });
  }

  // Lazy load for gallery images, separate from main.js to optimize gallery page
  function initLazyLoadGalleryImages() {
    if (!('IntersectionObserver' in window)) {
      // Fallback: load all gallery images immediately
      galleryItems.forEach(img => {
        const dataSrc = img.getAttribute('data-src');
        if (dataSrc) {
          img.src = dataSrc;
          img.removeAttribute('data-src');
        }
      });
      return;
    }
const io = new IntersectionObserver((entries, observer) => {
      entries.forEach(entry => {
        if (!entry.isIntersecting) return;
        const img = entry.target;
        const src = img.getAttribute('data-src');
        if (src) {
          img.src = src;
          img.removeAttribute('data-src');
        }
        observer.unobserve(img);
      });
    }, { rootMargin: '100px 0px' });

    galleryItems.forEach(img => io.observe(img));
  }

  // Initialize filtering functionality if filter UI is present
  function initGalleryFilter() {
    const filterContainer = safeQuery('.gallery-filter');
    if (!filterContainer) return;

    const filters = selectAll('button[data-filter]', filterContainer);
    if (!filters.length) return;

    filters.forEach(button => {
      button.addEventListener('click', () => {
        const filterValue = button.getAttribute('data-filter');

        filters.forEach(btn => btn.classList.remove('active'));
        button.classList.add('active');

        if (!galleryItems.length) return;

        galleryItems.forEach(img => {
          const parentItem = img.closest('.gallery-item');
          if (!parentItem) return;

          if (filterValue === '*' || !filterValue) {
            parentItem.style.display = '';
          } else {
            const categories = parentItem.getAttribute('data-categories');
            // Categories are comma separated
            if (categories && categories.split(',').map(s => s.trim()).includes(filterValue)) {
              parentItem.style.display = '';
            } else {
              parentItem.style.display = 'none';
            }
          }
        });
      });
    });
  }
// Initialization
  document.addEventListener('DOMContentLoaded', () => {
    try {
      initGallery();
      initLightbox();
      initLazyLoadGalleryImages();
      initGalleryFilter();
    } catch (e) {
      console.error('Failed to initialize gallery.js:', e);
    }
  });

})();

// End of gallery.js