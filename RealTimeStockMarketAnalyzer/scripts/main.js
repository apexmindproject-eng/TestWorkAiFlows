// main.js - Core functionality, navigation, global features for RealTimeStockMarketAnalyzer

const main = (() => {
 // Cache selectors
 const header = document.getElementById('main-header');
 const nav = document.getElementById('main-nav');
 const navList = nav ? nav.querySelector('.nav-list') : null;
 const navLinks = nav ? nav.querySelectorAll('.nav-link') : [];
 const logoLink = document.querySelector('.logo-link');

 // Mobile nav toggle selector and state
 const MOBILE_NAV_TOGGLE_CLASS = 'mobile-nav-toggle';
 let mobileNavToggleButton = null;

 // Utility: throttle function calls
 const throttle = (func, limit) => {
 let inThrottle;
 return function() {
 const args = arguments;
 const context = this;
 if (!inThrottle) {
 func.apply(context, args);
 inThrottle = true;
 setTimeout(() => inThrottle = false, limit);
 }
 };
 };

 // Highlight correct nav link based on current page
 const highlightActiveNav = () => {
 try {
 const path = window.location.pathname.split('/').pop().toLowerCase();
 navLinks.forEach(link => {
 const href = link.getAttribute('href').toLowerCase();
 if ((href === path) || (href === 'index.html' && (path === '' || path === 'index.html'))) {
 link.classList.add('active');
 } else {
 link.classList.remove('active');
 }
 });
 } catch (e) {
 console.warn('Error in highlightActiveNav:', e);
 }
 };

 // Create and setup mobile nav toggle button
 const setupMobileNavToggle = () => {
 if (!header || !nav) return;

 mobileNavToggleButton = header.querySelector(`.${MOBILE_NAV_TOGGLE_CLASS}`);

 if (!mobileNavToggleButton) {
 // Create mobile nav toggle dynamically
 mobileNavToggleButton = document.createElement('button');
 mobileNavToggleButton.className = MOBILE_NAV_TOGGLE_CLASS;
 mobileNavToggleButton.setAttribute('aria-label', 'Toggle navigation menu');
 mobileNavToggleButton.setAttribute('aria-expanded', 'false');
 mobileNavToggleButton.innerHTML = '&#9776;'; // hamburger icon

 // Append toggle button inside header container
 const headerContainer = header.querySelector('.header-container');
 if (headerContainer) {
 headerContainer.appendChild(mobileNavToggleButton);
 }
 }

 // Add click event listener
 mobileNavToggleButton.addEventListener('click', () => {
 const expanded = mobileNavToggleButton.getAttribute('aria-expanded') === 'true';
 mobileNavToggleButton.setAttribute('aria-expanded', String(!expanded));
 if (nav.classList.contains('open')) {
 nav.classList.remove('open');
 nav.setAttribute('aria-expanded', 'false');
 } else {
 nav.classList.add('open');
 nav.setAttribute('aria-expanded', 'true');
 }
 });
 };

 // Close mobile navigation on clicking a navigation link (for better UX)
 const setupNavLinkClicks = () => {
 if (!navList || !mobileNavToggleButton) return;

 navList.addEventListener('click', (event) => {
 const target = event.target;
 if (target.tagName === 'A') {
 if (nav.classList.contains('open')) {
 nav.classList.remove('open');
 nav.setAttribute('aria-expanded', 'false');
 mobileNavToggleButton.setAttribute('aria-expanded', 'false');
 }
 }
 });
 };

 // Accessibility improvements for keyboard navigation on nav
 const setupKeyboardNavAccessibility = () => {
 if (!nav) return;

 // Add keyboard event listener to nav
 nav.addEventListener('keydown', (event) => {
 const { key } = event;
 if (key !== 'ArrowDown' && key !== 'ArrowUp' && key !== 'Escape') return;

 const focusableLinks = Array.from(nav.querySelectorAll('.nav-link'));
 if (focusableLinks.length === 0) return;

 const currentIndex = focusableLinks.indexOf(document.activeElement);

 if (key === 'ArrowDown') {
 event.preventDefault();
 const nextIndex = (currentIndex + 1) % focusableLinks.length;
 focusableLinks[nextIndex].focus();
 } else if (key === 'ArrowUp') {
 event.preventDefault();
 const prevIndex = (currentIndex - 1 + focusableLinks.length) % focusableLinks.length;
 focusableLinks[prevIndex].focus();
 } else if (key === 'Escape') {
 nav.classList.remove('open');
 nav.setAttribute('aria-expanded', 'false');
 if (mobileNavToggleButton) {
 mobileNavToggleButton.setAttribute('aria-expanded', 'false');
 mobileNavToggleButton.focus();
 }
 }
 });
 };

 // Smooth scroll behavior for anchor links within the page (if any)
 const setupSmoothScrolling = () => {
 document.addEventListener('click', (event) => {
 const link = event.target.closest('a[href^="#"]');
 if (!link) return;

 const href = link.getAttribute('href');
 if (!href || href === '#') return;

 const targetElement = document.querySelector(href);
 if (targetElement) {
 event.preventDefault();
 targetElement.scrollIntoView({ behavior: 'smooth' });
 }
 });
 };

 // Accessibility: Focus outline toggle
 const setupFocusOutlineToggle = () => {
 document.body.classList.add('js-focus-visible');

 const handleFirstTab = (e) => {
 if (e.key === 'Tab') {
 document.body.classList.add('user-is-tabbing');
 window.removeEventListener('keydown', handleFirstTab);
 window.addEventListener('mousedown', handleMouseDownOnce);
 }
 };

 const handleMouseDownOnce = () => {
 document.body.classList.remove('user-is-tabbing');
 window.removeEventListener('mousedown', handleMouseDownOnce);
 window.addEventListener('keydown', handleFirstTab);
 };

 window.addEventListener('keydown', handleFirstTab);
 };

 // Lazy load images with intersection observer
 const setupLazyLoadImages = () => {
 if (!('IntersectionObserver' in window)) {
 // Fallback: load all images immediately
 const images = document.querySelectorAll('img[data-src]');
 images.forEach(img => {
 img.src = img.getAttribute('data-src');
 img.removeAttribute('data-src');
 });
 return;
 }

 const observer = new IntersectionObserver((entries, obs) => {
 entries.forEach(entry => {
 if (entry.isIntersecting) {
 const img = entry.target;
 const dataSrc = img.getAttribute('data-src');
 if (dataSrc) {
 img.src = dataSrc;
 img.removeAttribute('data-src');
 }
 obs.unobserve(img);
 }
 });
 }, {
 rootMargin: '50px 0px',
 threshold: 0.01
 });

 const images = document.querySelectorAll('img[data-src]');
 images.forEach(img => {
 observer.observe(img);
 });
 };

 // Initialization
 const init = () => {
 highlightActiveNav();
 setupMobileNavToggle();
 setupNavLinkClicks();
 setupKeyboardNavAccessibility();
 setupSmoothScrolling();
 setupFocusOutlineToggle();
 setupLazyLoadImages();
 };

 // Cleanup
 const destroy = () => {
 if (mobileNavToggleButton) {
 mobileNavToggleButton.removeEventListener('click', () => {});
 }
 window.removeEventListener('keydown', () => {});
 // Other cleanups if needed
 };

 return {
 init,
 destroy
 };
})();

// Initialize once DOM content is loaded

document.addEventListener('DOMContentLoaded', () => {
 try {
 main.init();
 } catch (error) {
 console.error('Error during main.js initialization:', error);
 }
});

// Clean up before unload
window.addEventListener('beforeunload', () => {
 main.destroy();
});

//# sourceMappingURL=main.js.map
