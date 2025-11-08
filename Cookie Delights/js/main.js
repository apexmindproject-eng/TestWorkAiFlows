// main.js - Core functionality for Cookie Delights across all pages

// Utility function for safe DOM query
const safeQuery = (selector, context = document) => {
 try {
 const element = context.querySelector(selector);
 return element || null;
 } catch (error) {
 console.error(`safeQuery error for selector: ${selector}`, error);
 return null;
 }
};

// Utility for delegation based on selector
const delegate = (parent, selector, type, handler) => {
 parent.addEventListener(type, event => {
 const target = event.target;
 if (!target) return;
 if (target.matches(selector)) {
 handler(event, target);
 } else {
 // Check closest for delegated elements
 const delegatedTarget = target.closest(selector);
 if (delegatedTarget && parent.contains(delegatedTarget)) {
 handler(event, delegatedTarget);
 }
 }
 });
};

// Detect current page and add active class to nav link
const activateCurrentNavLink = () => {
 try {
 const navLinks = document.querySelectorAll('#main-navigation .nav-link');
 if (!navLinks || navLinks.length === 0) return;

 const currentPath = window.location.pathname.split('/').pop() || 'index.html';

 navLinks.forEach(link => {
 const href = link.getAttribute('href');
 if (!href) return;

 // Normalize and compare
 if (href === currentPath) {
 link.classList.add('current');
 link.setAttribute('aria-current', 'page');
 } else {
 link.classList.remove('current');
 link.removeAttribute('aria-current');
 }
 });
 } catch (error) {
 console.error('Error activating current nav link:', error);
 }
};

// Mobile navigation toggle for small screens
const mobileNavToggle = () => {
 try {
 const nav = safeQuery('#main-navigation');
 if (!nav) return;

 // Create a toggle button only if not already present
 let toggleButton = safeQuery('#nav-toggle-button');
 if (!toggleButton) {
 toggleButton = document.createElement('button');
 toggleButton.id = 'nav-toggle-button';
 toggleButton.setAttribute('aria-expanded', 'false');
 toggleButton.setAttribute('aria-controls', 'main-navigation');
 toggleButton.className = 'nav-toggle';
 toggleButton.innerHTML = '<span class="sr-only">Toggle navigation</span>&#9776;';

 nav.parentNode.insertBefore(toggleButton, nav);
 }

 toggleButton.addEventListener('click', () => {
 const isExpanded = toggleButton.getAttribute('aria-expanded') === 'true';
 toggleButton.setAttribute('aria-expanded', String(!isExpanded));
 nav.classList.toggle('nav-open');
 });
 } catch (error) {
 console.error('Error in mobileNavToggle:', error);
 }
};

// Smooth scroll for internal anchor links across the site
const setupSmoothScroll = () => {
 try {
 delegate(document.body, 'a[href^="#"]', 'click', (event, target) => {
 const href = target.getAttribute('href');
 if (href && href.length > 1) {
 const scrollTarget = safeQuery(href);
 if (scrollTarget) {
 event.preventDefault();
 scrollTarget.scrollIntoView({ behavior: 'smooth', block: 'start' });
 history.pushState(null, '', href);
 }
 }
 });
 } catch (error) {
 console.error('Smooth scroll setup failed:', error);
 }
};

// Focus management for accessibility when navigating via keyboard
const setupFocusManagement = () => {
 try {
 const nav = safeQuery('#main-navigation');
 if (!nav) return;

 // Add focus styles to nav links
 const navLinks = nav.querySelectorAll('.nav-link');
 navLinks.forEach(link => {
 link.addEventListener('focus', () => link.classList.add('focus-visible'));
 link.addEventListener('blur', () => link.classList.remove('focus-visible'));
 });
 } catch (error) {
 console.error('Focus management setup failed:', error);
 }
};

// Lazy load images for performance optimization
const setupLazyLoadImages = () => {
 try {
 if ('loading' in HTMLImageElement.prototype) {
 // Native lazy loading supported
 const images = document.querySelectorAll('img[data-src]');
 images.forEach(img => {
 const dataSrc = img.getAttribute('data-src');
 if (dataSrc) {
 img.setAttribute('src', dataSrc);
 img.removeAttribute('data-src');
 }
 });
 } else if ('IntersectionObserver' in window) {
 // Polyfill lazy loading
 const images = document.querySelectorAll('img[data-src]');
 const imgObserver = new IntersectionObserver((entries, observer) => {
 entries.forEach(entry => {
 if (entry.isIntersecting) {
 const img = entry.target;
 const dataSrc = img.getAttribute('data-src');
 if (dataSrc) {
 img.src = dataSrc;
 img.removeAttribute('data-src');
 }
 imgObserver.unobserve(img);
 }
 });
 }, { rootMargin: '50px 0px', threshold: 0.01 });

 images.forEach(img => imgObserver.observe(img));
 }
 } catch (error) {
 console.error('Lazy load images setup failed:', error);
 }
};

// Accessible keyboard shortcuts for navigation (e.g., skip to main content)
const setupKeyboardShortcuts = () => {
 try {
 // Common: Skip to content with Alt+S
 document.addEventListener('keydown', event => {
 if (event.altKey && (event.key === 's' || event.key === 'S')) {
 const mainContent = safeQuery('#main-content');
 if (mainContent) {
 event.preventDefault();
 mainContent.setAttribute('tabindex', '-1');
 mainContent.focus();
 // Remove tabindex after focus
 const removeTabIndex = () => {
 mainContent.removeAttribute('tabindex');
 mainContent.removeEventListener('blur', removeTabIndex);
 };
 mainContent.addEventListener('blur', removeTabIndex);
 }
 }
 });
 } catch (error) {
 console.error('Keyboard shortcuts setup failed:', error);
 }
};

// Footer date dynamic update to current year
const updateFooterYear = () => {
 try {
 const footer = safeQuery('#site-footer');
 if (!footer) return;
 const footerText = footer.querySelector('.footer-text');
 if (!footerText) return;
 const currentYear = (new Date()).getFullYear();
 const text = footerText.textContent || footerText.innerText || '';
 const newText = text.replace(/\d{4}/, currentYear);
 footerText.textContent = newText;
 } catch (error) {
 console.error('Error updating footer year:', error);
 }
};

// Main initialization on DOMContentLoaded
const init = () => {
 activateCurrentNavLink();
 mobileNavToggle();
 setupSmoothScroll();
 setupFocusManagement();
 setupLazyLoadImages();
 setupKeyboardShortcuts();
 updateFooterYear();

 // Additional global event listeners can be added here if needed
};

// Execute init on DOMContentLoaded
document.addEventListener('DOMContentLoaded', init);

// Export for testing if needed (in module environments)
// export { init, activateCurrentNavLink, mobileNavToggle, setupSmoothScroll, setupFocusManagement, setupLazyLoadImages, setupKeyboardShortcuts, updateFooterYear };

//# sourceURL=main.js
