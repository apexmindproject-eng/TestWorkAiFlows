// main.js - Core functionality for Coffee Lovers website

// Utility: Safe querySelector and querySelectorAll
const qS = (selector, scope = document) => scope.querySelector(selector);
const qSA = (selector, scope = document) => Array.from(scope.querySelectorAll(selector));

// Utility: Check if element exists
const exists = (el) => el !== null && el !== undefined;

// Utility: Get current page filename
const getCurrentPage = () => {
  try {
    const path = window.location.pathname;
    const page = path.substring(path.lastIndexOf('/') + 1);
    return page || 'index.html';
  } catch (error) {
    console.error('Error getting current page:', error);
    return 'index.html';
  }
};
// Manage active navigation link highlighting
const highlightActiveNavLink = () => {
  try {
    const currentPage = getCurrentPage();
    const navLinks = qSA('#main-nav .nav-link');
    navLinks.forEach(link => {
      // Remove all current active styles
      link.classList.remove('current');
      link.removeAttribute('aria-current');

      // Normalize href to compare only filename
      let linkHref = link.getAttribute('href');
      if(linkHref) {
        // Remove query params and hashes
        linkHref = linkHref.split(/[?#]/)[0];
        // Remove any preceding folders (last segment)
        linkHref = linkHref.substring(linkHref.lastIndexOf('/') + 1);
      }

      if(linkHref && linkHref === currentPage) {
        link.classList.add('current');
        link.setAttribute('aria-current', 'page');
      }
    });
  } catch (error) {
    console.error('Error highlighting active nav link:', error);
  }
};
// Mobile navigation toggle functionality
const setupMobileNavToggle = () => {
  try {
    // Create a toggle button and insert it if not exists
    let toggleBtn = qS('#mobile-nav-toggle');
    if(!toggleBtn) {
      toggleBtn = document.createElement('button');
      toggleBtn.id = 'mobile-nav-toggle';
      toggleBtn.setAttribute('aria-expanded', 'false');
      toggleBtn.setAttribute('aria-controls', 'main-nav');
      toggleBtn.className = 'mobile-nav-toggle';
      toggleBtn.innerHTML = '<span class="visually-hidden">Toggle navigation menu</span><span aria-hidden="true">☰</span>';
      const header = qS('#site-header .header-container');
      if(header) {
        header.insertBefore(toggleBtn, header.querySelector('#main-nav'));
      }
    }

    const mainNav = qS('#main-nav');
    if(!mainNav) return;

    toggleBtn.addEventListener('click', () => {
      // Expand or collapse nav
      const expanded = toggleBtn.getAttribute('aria-expanded') === 'true';
      toggleBtn.setAttribute('aria-expanded', String(!expanded));
      mainNav.classList.toggle('open');
    });

    // Close nav when clicking outside on mobile
    document.addEventListener('click', (e) => {
      if (!mainNav.classList.contains('open')) return;
      if (!mainNav.contains(e.target) && e.target !== toggleBtn) {
        mainNav.classList.remove('open');
        toggleBtn.setAttribute('aria-expanded', 'false');
      }
    });
// Close nav on Escape key
    document.addEventListener('keydown', (e) => {
      if(e.key === 'Escape' && mainNav.classList.contains('open')) {
        mainNav.classList.remove('open');
        toggleBtn.setAttribute('aria-expanded', 'false');
        toggleBtn.focus();
      }
    });
  } catch (error) {
    console.error('Error setting up mobile navigation toggle:', error);
  }
};

// Smooth scroll for internal anchor links
const setupSmoothScrolling = () => {
  try {
    document.body.addEventListener('click', e => {
      const link = e.target.closest('a');
      if (!link) return;
      const href = link.getAttribute('href');
      if (!href || href.charAt(0) !== '#') return;

      const targetElement = qS(href);
      if (targetElement) {
        e.preventDefault();
        targetElement.scrollIntoView({ behavior: 'smooth' });
      }
    });
  } catch (error) {
    console.error('Error setting up smooth scrolling:', error);
  }
};
// Accessibility improvements
const setupAccessibilityHelpers = () => {
  try {
    // Fix skip link focus issue (useful for keyboard users)
    const skipLink = qS('.skip-link');
    if(skipLink) {
      skipLink.addEventListener('click', () => {
        const mainContent = qS('#main-content');
        if(mainContent) mainContent.setAttribute('tabindex', '-1');
        mainContent && mainContent.focus();
      });
    }
  } catch (error) {
    console.error('Error setting up accessibility helpers:', error);
  }
};

// Utility: debounce function to optimize event handlers
const debounce = (func, wait = 100) => {
  let timeout;
  return (...args) => {
    clearTimeout(timeout);
    timeout = setTimeout(() => func.apply(this, args), wait);
  };
};

// Sticky header on scroll - adds class when scrolled past hero image
const setupStickyHeader = () => {
  try {
    const header = qS('#site-header');
    if (!header) return;

    const heroSection = qS('#hero');

    // Throttled scroll handler
    const onScroll = debounce(() => {
      if(!heroSection) {
        // If no hero section, use 0 as threshold
        if(window.scrollY > 0) {
          header.classList.add('sticky');
        } else {
          header.classList.remove('sticky');
        }
        return;
      }

      const heroBottom = heroSection.getBoundingClientRect().bottom;
      if(heroBottom <= 0) {
        header.classList.add('sticky');
      } else {
        header.classList.remove('sticky');
      }
    }, 50);

    window.addEventListener('scroll', onScroll);

    // Initial call
    onScroll();
  } catch (error) {
    console.error('Error setting up sticky header:', error);
  }
};

// Keyboard navigation for skip links and landmarks
const setupKeyboardNavigation = () => {
  try {
    // Example: trap focus inside open mobile nav for accessibility
    const mainNav = qS('#main-nav');
    const toggleBtn = qS('#mobile-nav-toggle');
    if(!mainNav || !toggleBtn) return;

    document.addEventListener('keydown', (event) => {
      if(event.key !== 'Tab') return;

      if(mainNav.classList.contains('open')) {
        const focusableEls = qSA('a, button, input, textarea, select, [tabindex]:not([tabindex="-1"])', mainNav).filter(el => !el.hasAttribute('disabled'));
        if(focusableEls.length === 0) return;

        const firstEl = focusableEls[0];
        const lastEl = focusableEls[focusableEls.length - 1];

        if(event.shiftKey) { // Shift + Tab
          if(document.activeElement === firstEl) {
            lastEl.focus();
            event.preventDefault();
          }
        } else { // Tab
          if(document.activeElement === lastEl) {
            firstEl.focus();
            event.preventDefault();
          }
        }
      }
    });
  } catch (error) {
    console.error('Error setting up keyboard navigation:', error);
  }
};
// Handle focus outlines for better UX
const setupFocusOutlineHandling = () => {
  try {
    let mouseUser = false;
    document.body.addEventListener('mousedown', () => {
      mouseUser = true;
      document.body.classList.add('using-mouse');
    });
    document.body.addEventListener('keydown', (e) => {
      if(e.key === 'Tab') {
        if(mouseUser) {
          mouseUser = false;
          document.body.classList.remove('using-mouse');
        }
      }
    });
  } catch (error) {
    console.error('Error setting up focus outline handling:', error);
  }
};

// Initialize all core features
const initCoreFeatures = () => {
  highlightActiveNavLink();
  setupMobileNavToggle();
  setupSmoothScrolling();
  setupAccessibilityHelpers();
  setupStickyHeader();
  setupKeyboardNavigation();
  setupFocusOutlineHandling();
};
// Expose a public API or run on DOMContentLoaded
document.addEventListener('DOMContentLoaded', () => {
  try {
    initCoreFeatures();
  } catch (error) {
    console.error('Error initializing core features:', error);
  }
});


// Additional global event delegation example: External links open in new tab
const enhanceExternalLinks = () => {
  try {
    document.body.addEventListener('click', (e) => {
      const link = e.target.closest('a');
      if(!link) return;
      const href = link.getAttribute('href');
      if(!href) return;

      // Only handle external absolute URLs
      const isExternal = href.startsWith('http') && !href.includes(window.location.hostname);
      if(isExternal) {
        e.preventDefault();
        window.open(href, '_blank', 'noopener,noreferrer');
      }
    });
  } catch (error) {
    console.error('Error enhancing external links:', error);
  }
};

document.addEventListener('DOMContentLoaded', enhanceExternalLinks);


// Defensive support for later UI enhancements or dynamic content
const setupDynamicUIUpdates = () => {
  try {
    // Example placeholder: could be used for fetching updates or user data
    // Currently no dynamic content specified
  } catch (error) {
    console.error('Error setting up dynamic UI updates:', error);
  }
};

document.addEventListener('DOMContentLoaded', setupDynamicUIUpdates);

// Additional utilities and handlers could be added here but as per scope main.js covers global/core site functions

// End of main.js