// gallery.js - Manages image galleries and lightbox functionality across Coffee Lovers website

// Utility: Safe querySelector and querySelectorAll
const qS = (selector, scope = document) => scope.querySelector(selector);
const qSA = (selector, scope = document) => Array.from(scope.querySelectorAll(selector));

// Utility: Check if element exists
const exists = (el) => el !== null && el !== undefined;

// Gallery and Lightbox Core
class ImageGallery {
  constructor(galleryRoot) {
    this.galleryRoot = galleryRoot;
    this.images = qSA('img', galleryRoot).filter(img => img.getAttribute('data-full') || img.src);
    this.currentIndex = -1;
    this.lightbox = null;
    this.lightboxImage = null;
    this.prevBtn = null;
    this.nextBtn = null;
    this.closeBtn = null;
    this.caption = null;
    this.handleKeyDown = this.handleKeyDown.bind(this);

    if(this.images.length > 0) {
      this.buildLightbox();
      this.attachEventListeners();
    }
  }
if(this.images.length > 0) {
      this.buildLightbox();
      this.attachEventListeners();
    }
  }

  buildLightbox() {
    // Create lightbox overlay and controls
    try {
      this.lightbox = document.createElement('div');
      this.lightbox.className = 'lightbox hidden';
      this.lightbox.setAttribute('role', 'dialog');
      this.lightbox.setAttribute('aria-modal', 'true');
      this.lightbox.setAttribute('aria-label', 'Image viewer');
      this.lightbox.tabIndex = -1;

      const lightboxContent = document.createElement('div');
      lightboxContent.className = 'lightbox-content';

      this.lightboxImage = document.createElement('img');
      this.lightboxImage.className = 'lightbox-image';
      this.lightboxImage.alt = '';

      this.caption = document.createElement('p');
      this.caption.className = 'lightbox-caption';
this.caption = document.createElement('p');
      this.caption.className = 'lightbox-caption';

      this.prevBtn = document.createElement('button');
      this.prevBtn.className = 'lightbox-prev';
      this.prevBtn.setAttribute('aria-label', 'Previous image');
      this.prevBtn.textContent = '\u25C0'; // Left arrow

      this.nextBtn = document.createElement('button');
      this.nextBtn.className = 'lightbox-next';
      this.nextBtn.setAttribute('aria-label', 'Next image');
      this.nextBtn.textContent = '\u25B6'; // Right arrow

      this.closeBtn = document.createElement('button');
      this.closeBtn.className = 'lightbox-close';
      this.closeBtn.setAttribute('aria-label', 'Close viewer');
      this.closeBtn.textContent = '×';
lightboxContent.appendChild(this.prevBtn);
      lightboxContent.appendChild(this.lightboxImage);
      lightboxContent.appendChild(this.nextBtn);
      lightboxContent.appendChild(this.caption);
      this.lightbox.appendChild(this.closeBtn);
      this.lightbox.appendChild(lightboxContent);

      document.body.appendChild(this.lightbox);
    } catch (error) {
      console.error('Error building lightbox:', error);
    }
  }

  attachEventListeners() {
    try {
      // Click on gallery images
      this.galleryRoot.addEventListener('click', (e) => {
        try {
          const img = e.target.closest('img');
          if (!img || !this.images.includes(img)) return;
          e.preventDefault();
          const index = this.images.indexOf(img);
          if (index !== -1) {
            this.openLightbox(index);
          }
        } catch (error) {
          console.error('Error handling gallery image click:', error);
        }
      });
// Lightbox controls
      this.prevBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        this.showPrevious();
      });

      this.nextBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        this.showNext();
      });

      this.closeBtn.addEventListener('click', () => {
        this.closeLightbox();
      });

      // Close lightbox on click outside image
      this.lightbox.addEventListener('click', (e) => {
        if (e.target === this.lightbox) {
          this.closeLightbox();
        }
      });

      // Keyboard navigation
      document.addEventListener('keydown', this.handleKeyDown);

      // Resize image on window resize for responsiveness
      window.addEventListener('resize', () => {
        if(this.lightbox && !this.lightbox.classList.contains('hidden')) {
          this.adjustImageSize();
        }
      });
    } catch (error) {
      console.error('Error attaching event listeners to gallery:', error);
    }
  }
openLightbox(index) {
    try {
      if (index < 0 || index >= this.images.length) return;
      this.currentIndex = index;
      const img = this.images[index];
      const fullSrc = img.getAttribute('data-full') || img.src;
      const altText = img.alt || 'Coffee image';
      const captionText = img.title || img.getAttribute('data-caption') || altText;

      this.lightboxImage.src = fullSrc;
      this.lightboxImage.alt = altText;
      this.caption.textContent = captionText;

      this.lightbox.classList.remove('hidden');
      this.lightbox.focus();

      this.updateNavigationButtons();
      this.adjustImageSize();

      // Prevent scrolling on body
      document.body.style.overflow = 'hidden';
    } catch (error) {
      console.error('Error opening lightbox:', error);
    }
  }
// Prevent scrolling on body
      document.body.style.overflow = 'hidden';
    } catch (error) {
      console.error('Error opening lightbox:', error);
    }
  }

  closeLightbox() {
    try {
      this.lightbox.classList.add('hidden');
      this.currentIndex = -1;
      this.lightboxImage.src = '';
      this.caption.textContent = '';
      document.body.style.overflow = '';
    } catch (error) {
      console.error('Error closing lightbox:', error);
    }
  }

  showPrevious() {
    try {
      if (this.currentIndex > 0) {
        this.openLightbox(this.currentIndex - 1);
      }
    } catch (error) {
      console.error('Error showing previous image:', error);
    }
  }

  showNext() {
    try {
      if (this.currentIndex < this.images.length - 1) {
        this.openLightbox(this.currentIndex + 1);
      }
    } catch (error) {
      console.error('Error showing next image:', error);
    }
  }
updateNavigationButtons() {
    if (!this.prevBtn || !this.nextBtn) return;
    this.prevBtn.disabled = this.currentIndex <= 0;
    this.nextBtn.disabled = this.currentIndex >= this.images.length - 1;
  }

  adjustImageSize() {
    try {
      // For now, rely on CSS max-width and max-height, but we could implement custom sizing if needed
      // Keeping method for possible future enhancements
    } catch (error) {
      console.error('Error adjusting image size:', error);
    }
  }

  handleKeyDown(e) {
    if (!this.lightbox || this.lightbox.classList.contains('hidden')) return;

    switch (e.key) {
      case 'ArrowLeft':
        e.preventDefault();
        this.showPrevious();
        break;
      case 'ArrowRight':
        e.preventDefault();
        this.showNext();
        break;
      case 'Escape':
        e.preventDefault();
        this.closeLightbox();
        break;
      default:
        break;
    }
  }
}
// Initialize all galleries on page
const initGalleries = () => {
  try {
    // Detect galleries by section or container with images
    // Pages like index.html have .brewing-cards with brewing-card articles containing images
    // About page references gallery featuring coffee art and equipment - assuming sections with images

    // Generic galleries: find common container classes that hold multiple images
    // This example will initialize ImageGallery for any element with 'gallery' class or 'brewing-cards' or 'types-section' etc
    const gallerySelectors = ['.brewing-cards', '.types-section', '.gallery', '.about-content', '.featured-section', '.coffee-type', '.brewing-method'];

    gallerySelectors.forEach(selector => {
      qSA(selector).forEach(galleryEl => new ImageGallery(galleryEl));
    });
// Also check the hero image on index.html for possible enlarged view
    const heroSection = qS('#hero');
    if(heroSection) {
      const heroImg = qS('.hero-image', heroSection);
      if(heroImg) {
        // Wrap hero image in a mini gallery to enable lightbox
        const heroGallery = document.createElement('div');
        heroGallery.style.display = 'none'; // Hide div wrapper
        heroGallery.appendChild(heroImg.cloneNode(true));
        document.body.appendChild(heroGallery);
        new ImageGallery(heroGallery); // Initiate but hidden
        // For usability, also add click handler on hero image to open lightbox
        heroImg.addEventListener('click', (e) => {
          e.preventDefault();
          // Temporarily show gallery div and open lightbox
          heroGallery.style.display = '';
          const heroGalleryInstance = new ImageGallery(heroGallery);
          heroGalleryInstance.openLightbox(0);
// Once lightbox closes, remove gallery div
          const observer = new MutationObserver((mutations, obs) => {
            if(heroGalleryInstance.lightbox.classList.contains('hidden')) {
              heroGallery.style.display = 'none';
              obs.disconnect();
            }
          });
          observer.observe(heroGalleryInstance.lightbox, { attributes: true, attributeFilter: ['class'] });
        });
      }
    }

  } catch (error) {
    console.error('Error initializing galleries:', error);
  }
};

// DOM Ready
document.addEventListener('DOMContentLoaded', () => {
  try {
    initGalleries();
  } catch (error) {
    console.error('Error on DOMContentLoaded in gallery.js:', error);
  }
});



// Optional: Future enhancements
// - Support lazy loading images within galleries
// - Add touch support for swipe gestures on mobile
// - Gallery filtering or categorization
// - Integration with gallery lightbox overlays for social sharing or metadata
// End of gallery.js