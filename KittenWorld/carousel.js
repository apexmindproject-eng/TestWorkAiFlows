// carousel.js - Carousel slider functionality for KittenWorld

(() => {
  // Utility selectors
  const select = (selector, scope = document) => scope.querySelector(selector);
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
// Carousel class to handle multiple carousels
  class Carousel {
    constructor(root) {
      this.root = root;
      this.track = safeQuery('.carousel-track', root);
      this.items = selectAll('.carousel-item', root);
      this.prevBtn = safeQuery('.carousel-prev', root);
      this.nextBtn = safeQuery('.carousel-next', root);
      this.indicatorsContainer = safeQuery('.carousel-indicators', root);
      this.indicators = [];
      this.currentIndex = 0;
      this.timer = null;
      this.autoPlayInterval = 5000; // 5 seconds

      if (!this.validateElements()) {
        console.warn('Carousel missing required elements, skipping init.');
        return;
      }

      this.init();
    }

    validateElements() {
      return this.root && this.track && this.items.length && this.prevBtn && this.nextBtn;
    }

    init() {
      try {
        this.updateIndicators();
        this.goToSlide(0);
        this.bindEvents();
        this.startAutoPlay();
        this.makeAccessible();
      } catch (e) {
        console.error('Error initializing carousel:', e);
      }
    }

    bindEvents() {
      this.prevBtn.addEventListener('click', () => this.showPrev());
      this.nextBtn.addEventListener('click', () => this.showNext());

      if (this.indicatorsContainer) {
        this.indicatorsContainer.addEventListener('click', e => {
          const target = e.target;
          if (target && target.matches('button[data-slide-to]')) {
            const index = parseInt(target.getAttribute('data-slide-to'), 10);
            if (!isNaN(index)) {
              this.goToSlide(index);
              this.restartAutoPlay();
            }
          }
        });
      }

      // Pause on mouse enter, resume on mouse leave
      this.root.addEventListener('mouseenter', () => {
        this.stopAutoPlay();
      });
      this.root.addEventListener('mouseleave', () => {
        this.startAutoPlay();
      });
// Keyboard navigation support
      this.root.addEventListener('keydown', e => {
        switch (e.key) {
          case 'ArrowLeft':
            e.preventDefault();
            this.showPrev();
            this.restartAutoPlay();
            break;
          case 'ArrowRight':
            e.preventDefault();
            this.showNext();
            this.restartAutoPlay();
            break;
          case 'Home':
            e.preventDefault();
            this.goToSlide(0);
            this.restartAutoPlay();
            break;
          case 'End':
            e.preventDefault();
            this.goToSlide(this.items.length - 1);
            this.restartAutoPlay();
            break;
        }
      });
    }

    updateIndicators() {
      if (!this.indicatorsContainer) return;

      // Clear existing indicators
      this.indicatorsContainer.innerHTML = '';
      this.indicators = [];

      this.items.forEach((_, idx) => {
        const btn = document.createElement('button');
        btn.setAttribute('type', 'button');
        btn.setAttribute('aria-label', `Slide ${idx + 1} of ${this.items.length}`);
        btn.setAttribute('data-slide-to', idx);
        btn.className = 'carousel-indicator';
        this.indicatorsContainer.appendChild(btn);
        this.indicators.push(btn);
      });
    }

    makeAccessible() {
      this.root.setAttribute('role', 'region');
      this.root.setAttribute('aria-roledescription', 'carousel');
      this.root.setAttribute('tabindex', '0');

      this.track.setAttribute('role', 'list');

      this.items.forEach((item, idx) => {
        item.setAttribute('role', 'listitem');
        item.setAttribute('aria-hidden', 'true');
        item.setAttribute('tabindex', '-1');
      });
    }

    goToSlide(index) {
      if (index < 0) index = this.items.length - 1;
      if (index >= this.items.length) index = 0;

      // Change transform to show slide
      const slideWidth = this.items[0].offsetWidth;
      this.track.style.transform = `translateX(-${slideWidth * index}px)`;

      // Update aria attributes
      this.items.forEach((item, idx) => {
        if (idx === index) {
          item.setAttribute('aria-hidden', 'false');
          item.setAttribute('tabindex', '0');
          if (item.querySelector('a, button, input, textarea, select')) {
            // Focus inner focusable element for accessibility
            setTimeout(() => {
              const focusable = item.querySelector('a, button, input, textarea, select');
              if (focusable) focusable.focus();
            }, 100);
          }
        } else {
          item.setAttribute('aria-hidden', 'true');
          item.setAttribute('tabindex', '-1');
        }
      });
// Update indicators
      if (this.indicators.length) {
        this.indicators.forEach((btn, idx) => {
          btn.classList.toggle('active', idx === index);
          btn.setAttribute('aria-current', idx === index ? 'true' : 'false');
        });
      }

      this.currentIndex = index;
    }

    showPrev() {
      this.goToSlide(this.currentIndex - 1);
    }

    showNext() {
      this.goToSlide(this.currentIndex + 1);
    }

    startAutoPlay() {
      if (this.timer) return;
      this.timer = setInterval(() => {
        this.showNext();
      }, this.autoPlayInterval);
    }

    stopAutoPlay() {
      if (this.timer) {
        clearInterval(this.timer);
        this.timer = null;
      }
    }

    restartAutoPlay() {
      this.stopAutoPlay();
      this.startAutoPlay();
    }
  }

  // Initialize all carousels on the page
  function initCarousels() {
    const carouselRoots = selectAll('.carousel');
    if (!carouselRoots.length) return;

    carouselRoots.forEach(root => {
      new Carousel(root);
    });
  }

  // Defensive window resize handler to adjust carousel positioning
  function initResizeHandler() {
    let resizeTimer = null;
    window.addEventListener('resize', () => {
      if (resizeTimer) clearTimeout(resizeTimer);
resizeTimer = setTimeout(() => {
        // Re-init carousels on resize
        const carouselRoots = selectAll('.carousel');
        carouselRoots.forEach(root => {
          try {
            const track = safeQuery('.carousel-track', root);
            const items = selectAll('.carousel-item', root);
            if (!track || !items.length) return;
            // Reset transform based on current slide
            const carouselInstance = root.__carouselInstance;
            if (carouselInstance && typeof carouselInstance.goToSlide === 'function') {
              carouselInstance.goToSlide(carouselInstance.currentIndex);
            } else {
              // fallback: reset transform
              track.style.transform = 'translateX(0px)';
            }
          } catch (e) {
            // ignore
          }
        });
      }, 200);
    });
  }
// Associate carousel instance with DOM element for external code (optional)
  function associateInstances() {
    const carouselRoots = selectAll('.carousel');
    carouselRoots.forEach(root => {
      if (!root.__carouselInstance) {
        root.__carouselInstance = new Carousel(root);
      }
    });
  }

  // DOM ready initialization
  document.addEventListener('DOMContentLoaded', () => {
    try {
      // Initialize carousels and store instances
      associateInstances();
      // Setup resize listener to maintain responsiveness
      initResizeHandler();
    } catch (e) {
      console.error('Error initializing carousel.js:', e);
    }
  });

})();

// End of carousel.js