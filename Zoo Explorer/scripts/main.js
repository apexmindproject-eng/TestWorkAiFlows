// main.js - Core functionalities for Zoo Explorer website

// Helper utilities
const Utils = {
 // Throttle function for performance optimizations
 throttle: (func, limit) => {
 let inThrottle;
 return function () {
 const args = arguments;
 const context = this;
 if (!inThrottle) {
 func.apply(context, args);
 inThrottle = true;
 setTimeout(() => (inThrottle = false), limit);
 }
 };
 },

 // Safe querySelector
 qs: (selector, scope = document) => {
 try {
 return scope.querySelector(selector);
 } catch (e) {
 console.error(`Invalid selector: ${selector}`, e);
 return null;
 }
 },

 // Safe querySelectorAll
 qsa: (selector, scope = document) => {
 try {
 return Array.from(scope.querySelectorAll(selector));
 } catch (e) {
 console.error(`Invalid selector: ${selector}`, e);
 return [];
 }
 },

 // Create ARIA live region for announcements
 createLiveRegion: () => {
 let liveRegion = document.getElementById('aria-live-region');
 if (!liveRegion) {
 liveRegion = document.createElement('div');
 liveRegion.id = 'aria-live-region';
 liveRegion.setAttribute('aria-live', 'polite');
 liveRegion.setAttribute('aria-atomic', 'true');
 liveRegion.style.position = 'absolute';
 liveRegion.style.left = '-9999px';
 liveRegion.style.height = '1px';
 liveRegion.style.width = '1px';
 liveRegion.style.overflow = 'hidden';
 document.body.appendChild(liveRegion);
 }
 return liveRegion;
 },

 announce: (message) => {
 const liveRegion = Utils.createLiveRegion();
 liveRegion.textContent = '';
 setTimeout(() => {
 liveRegion.textContent = message;
 }, 100); // Delay to re-announce same message
 },

 // Smooth scroll to element by selector
 smoothScrollTo: (selector) => {
 const el = Utils.qs(selector);
 if (el) {
 el.scrollIntoView({ behavior: 'smooth', block: 'start' });
 }
 },
};

// Navigation module
const Navigation = (() => {
 const navListSelector = '.nav-list';
 const navLinksSelector = '.nav-link';
 let navList = null;

 // Highlights active link based on current URL path
 const highlightActiveLink = () => {
 try {
 const navLinks = Utils.qsa(navLinksSelector);
 const currentPath = window.location.pathname.split('/').pop() || 'index.html';
 navLinks.forEach(link => {
 const href = link.getAttribute('href');
 if (href) {
 const filename = href.split('/').pop();
 if (filename === currentPath) {
 link.classList.add('active');
 link.setAttribute('aria-current', 'page');
 } else {
 link.classList.remove('active');
 link.removeAttribute('aria-current');
 }
 }
 });
 } catch (error) {
 console.error('Error in highlightActiveLink:', error);
 }
 };

 // Toggle mobile navigation menu
 const toggleMobileNav = () => {
 if (!navList) return;
 navList.classList.toggle('nav-open');
 if (navList.classList.contains('nav-open')) {
 navList.setAttribute('aria-expanded', 'true');
 Utils.announce('Navigation menu expanded');
 } else {
 navList.setAttribute('aria-expanded', 'false');
 Utils.announce('Navigation menu collapsed');
 }
 };

 const setupMobileNavToggle = () => {
 try {
 const nav = Utils.qs('nav.main-navigation');
 if (!nav) return;

 // Add nav list reference
 navList = Utils.qs(navListSelector, nav);
 if (!navList) return;

 // Create toggle button for mobile
 let toggleBtn = Utils.qs('.nav-toggle');
 if (!toggleBtn) {
 toggleBtn = document.createElement('button');
 toggleBtn.className = 'nav-toggle';
 toggleBtn.setAttribute('aria-label', 'Toggle navigation menu');
 toggleBtn.setAttribute('aria-expanded', 'false');
 toggleBtn.innerHTML = '&#9776;'; // Hamburger icon
 nav.insertBefore(toggleBtn, nav.firstChild);
 }

 toggleBtn.addEventListener('click', (e) => {
 e.preventDefault();
 toggleMobileNav();
 });
 } catch (error) {
 console.error('Error setting up mobile navigation toggle:', error);
 }
 };

 return {
 init: () => {
 highlightActiveLink();
 setupMobileNavToggle();

 // Close mobile nav on outside click
 document.addEventListener('click', (e) => {
 if (!navList) return;
 if (!navList.classList.contains('nav-open')) return;

 const nav = Utils.qs('nav.main-navigation');
 if (!nav) return;

 if (!nav.contains(e.target)) {
 navList.classList.remove('nav-open');
 navList.setAttribute('aria-expanded', 'false');
 Utils.announce('Navigation menu collapsed');
 }
 });

 // Close nav on resize if desktop
 window.addEventListener('resize', Utils.throttle(() => {
 if (!navList) return;
 if (window.innerWidth > 768 && navList.classList.contains('nav-open')) {
 navList.classList.remove('nav-open');
 navList.setAttribute('aria-expanded', 'false');
 Utils.announce('Navigation menu collapsed');
 }
 }, 250));
 },
 };
})();

// Contact form module
const ContactForm = (() => {
 const formSelector = '#contact-form';
 const form = Utils.qs(formSelector);

 // Validate email with regex (simple)
 const isValidEmail = (email) => {
 const re = /^[\w-.]+@[\w-]+\.[a-z]{2,}$/i;
 return re.test(String(email).toLowerCase());
 };

 // Generic input validation function
 const validateInput = (input) => {
 if (!input) return false;
 const value = input.value.trim();
 if (input.required && !value) {
 return false;
 }
 if (input.type === 'email' && !isValidEmail(value)) {
 return false;
 }
 return true;
 };

 // Show error message next to input or aria-describedby
 const showError = (input, message) => {
 if (!input) return;
 // Try to find existing error message
 let errorEl = input.nextElementSibling;
 if (!errorEl || !errorEl.classList.contains('input-error-message')) {
 errorEl = document.createElement('div');
 errorEl.className = 'input-error-message';
 errorEl.setAttribute('aria-live', 'polite');
 input.insertAdjacentElement('afterend', errorEl);
 }
 errorEl.textContent = message;
 input.setAttribute('aria-invalid', 'true');
 };

 // Clear error message
 const clearError = (input) => {
 if (!input) return;
 let errorEl = input.nextElementSibling;
 if (errorEl && errorEl.classList.contains('input-error-message')) {
 errorEl.textContent = '';
 input.removeAttribute('aria-invalid');
 }
 };

 // Validate all form fields
 const validateForm = () => {
 if (!form) return false;
 let valid = true;
 const elements = Array.from(form.elements).filter(
 el => ['INPUT', 'TEXTAREA'].includes(el.tagName) && el.required
 );
 elements.forEach(input => {
 if (!validateInput(input)) {
 showError(input, input.type === 'email' ? 'Please enter a valid email.' : 'This field is required.');
 valid = false;
 } else {
 clearError(input);
 }
 });
 return valid;
 };

 // Handle form submit
 const handleSubmit = (event) => {
 event.preventDefault();
 if (!form) return;
 try {
 if (validateForm()) {
 // For now, simulate successful submission
 alert('Thank you for contacting Zoo Explorer! We will get back to you soon.');
 form.reset();
 Utils.announce('Contact form successfully submitted');
 } else {
 Utils.announce('Please fix the errors in the form before submitting');
 }
 } catch (error) {
 console.error('Form submission error:', error);
 alert('An unexpected error occurred. Please try again later.');
 }
 };

 // Setup input event listeners for realtime validation
 const setupRealtimeValidation = () => {
 if (!form) return;
 form.addEventListener('input', (event) => {
 const target = event.target;
 if (target && (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA')) {
 if (validateInput(target)) {
 clearError(target);
 }
 }
 });
 };

 return {
 init: () => {
 if (!form) return;

 form.addEventListener('submit', handleSubmit);
 setupRealtimeValidation();
 },
 };
})();

// Feature: Accessible Skip Link for keyboard users
const SkipLink = (() => {
 const skipLinkId = 'skip-to-content';
 let skipLink = null;

 const createSkipLink = () => {
 try {
 skipLink = document.createElement('a');
 skipLink.href = '#main-content';
 skipLink.id = skipLinkId;
 skipLink.className = 'skip-link';
 skipLink.textContent = 'Skip to main content';
 skipLink.style.position = 'absolute';
 skipLink.style.top = '-40px';
 skipLink.style.left = '0';
 skipLink.style.background = '#000';
 skipLink.style.color = '#fff';
 skipLink.style.padding = '8px';
 skipLink.style.zIndex = '1000';
 skipLink.style.transition = 'top 0.3s ease';

 skipLink.addEventListener('focus', () => {
 skipLink.style.top = '0';
 });
 skipLink.addEventListener('blur', () => {
 skipLink.style.top = '-40px';
 });

 document.body.insertBefore(skipLink, document.body.firstChild);
 } catch (error) {
 console.error('Error creating skip link:', error);
 }
 };

 return {
 init: () => createSkipLink(),
 };
})();

// Smooth scroll for internal links with hash
const SmoothScroll = (() => {
 const handleClick = (event) => {
 try {
 const target = event.target;
 if (!target) return;
 if (target.tagName !== 'A') return;
 const href = target.getAttribute('href');
 if (href && href.startsWith('#')) {
 const targetEl = Utils.qs(href);
 if (targetEl) {
 event.preventDefault();
 targetEl.scrollIntoView({ behavior: 'smooth', block: 'start' });
 targetEl.focus({ preventScroll: true });
 if (document.activeElement !== targetEl) {
 targetEl.setAttribute('tabindex', '-1');
 targetEl.focus({ preventScroll: true });
 }
 }
 }
 } catch (error) {
 console.error('Error in smooth scroll handler:', error);
 }
 };

 return {
 init: () => {
 document.body.addEventListener('click', handleClick);
 },
 };
})();

// Main initialization
const Main = (() => {
 const init = () => {
 try {
 Navigation.init();
 ContactForm.init();
 SkipLink.init();
 SmoothScroll.init();

 // Additional page-specific enhancements can be added here

 // Accessibility improvements: focus visible polyfill or enhancement
 document.body.addEventListener('keydown', (e) => {
 if (e.key === 'Tab') {
 document.body.classList.add('user-is-tabbing');
 }
 });
 document.body.addEventListener('mousedown', () => {
 document.body.classList.remove('user-is-tabbing');
 });

 // If on the animals page, announce the number of animals
 if (document.body.id === 'page-animals') {
 const animals = Utils.qsa('.animal-card');
 Utils.announce(`${animals.length} animals are displayed on this page.`);
 }

 // If on the index page, ensure featured animal list accessible description
 if (document.body.id === 'page-index') {
 const featuredSection = Utils.qs('#featured-animals');
 if (featuredSection) {
 featuredSection.setAttribute('aria-label', 'Featured animals of the zoo with their pictures and descriptions');
 }
 }
 } catch (error) {
 console.error('Error during main initialization:', error);
 }
 };

 return { init };
})();

// DOM ready
document.addEventListener('DOMContentLoaded', () => {
 Main.init();
});

//# sourceURL=main.js
