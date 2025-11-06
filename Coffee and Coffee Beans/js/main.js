// main.js
// Core functionality across all pages in the Coffee and Coffee Beans website
// Features: Mobile nav toggle, active nav link highlight, smooth scrolling, interactive UI enhancements, form validation triggers, event delegation, error handling

(() => {
 'use strict';

 /**
 * Select single element safely
 * @param {string} selector
 * @param {Element} parent
 * @returns {Element|null}
 */
 const qs = (selector, parent = document) => parent.querySelector(selector);

 /**
 * Select all elements safely and return array
 * @param {string} selector
 * @param {Element} parent
 * @returns {Element[]}
 */
 const qsa = (selector, parent = document) => Array.from(parent.querySelectorAll(selector));

 /**
 * Debounce utility function for performance
 * @param {Function} fn
 * @param {number} delay
 * @returns {Function}
 */
 const debounce = (fn, delay = 150) => {
 let timeoutId;
 return (...args) => {
 clearTimeout(timeoutId);
 timeoutId = setTimeout(() => fn.apply(this, args), delay);
 };
 };

 /**
 * Sets up mobile navigation toggle button and ARIA attributes
 */
 const setupMobileNavToggle = () => {
 try {
 const mainNav = qs('#main-nav');
 if (!mainNav) return;

 let toggleBtn = qs('#mobile-nav-toggle');
 if (!toggleBtn) {
 toggleBtn = document.createElement('button');
 toggleBtn.id = 'mobile-nav-toggle';
 toggleBtn.className = 'mobile-nav-toggle';
 toggleBtn.setAttribute('aria-label', 'Toggle navigation menu');
 toggleBtn.setAttribute('aria-expanded', 'false');
 toggleBtn.innerHTML = '&#9776;'; // Hamburger menu icon

 const headerContainer = qs('.header-container');
 if (!headerContainer) return;
 headerContainer.insertBefore(toggleBtn, mainNav);
 }

 toggleBtn.addEventListener('click', () => {
 const expanded = mainNav.classList.toggle('nav-open');
 toggleBtn.setAttribute('aria-expanded', expanded);
 });
 } catch (error) {
 console.error('Error setting up mobile nav toggle:', error);
 }
 };

 /**
 * Highlights active navigation links in header and footer based on current URL path
 */
 const highlightActiveNavigationLinks = () => {
 try {
 const currentPath = window.location.pathname.split('/').pop() || 'index.html';
 const navLinks = qsa('.nav-link, .footer-nav-link');
 navLinks.forEach(link => {
 const href = link.getAttribute('href');
 if (href === currentPath) link.classList.add('active');
 else link.classList.remove('active');
 });
 } catch (error) {
 console.error('Error highlighting active navigation:', error);
 }
 };

 /**
 * Setup smooth scrolling behavior on internal anchor links
 */
 const setupSmoothScrolling = () => {
 try {
 document.body.addEventListener('click', event => {
 const anchor = event.target.closest('a[href^="#"]');
 if (!anchor) return;

 const targetId = anchor.getAttribute('href').substring(1);
 const targetElement = qs(`#${targetId}`);
 if (targetElement) {
 event.preventDefault();
 targetElement.scrollIntoView({ behavior: 'smooth' });
 }
 });
 } catch (error) {
 console.error('Error setting up smooth scrolling:', error);
 }
 };

 /**
 * Enhance accessibility by ensuring images have alt attributes
 */
 const enhanceImageAlts = () => {
 try {
 const images = qsa('img');
 images.forEach(img => {
 if (!img.alt || img.alt.trim() === '') {
 img.alt = 'Coffee and Coffee Beans image';
 }
 });
 } catch (error) {
 console.error('Error enhancing image alt attributes:', error);
 }
 };

 /**
 * Setup keyboard accessibility for interactive elements
 * Ensures role="button" elements respond to Enter/Space keys
 */
 const setupKeyboardAccessibility = () => {
 try {
 document.body.addEventListener('keydown', event => {
 const el = event.target;
 if (!el) return;

 if (['Enter', ' '].includes(event.key)) {
 if (el.getAttribute('role') === 'button' || el.tagName === 'BUTTON') {
 event.preventDefault();
 el.click();
 }
 }
 });
 } catch (error) {
 console.error('Error setting up keyboard accessibility:', error);
 }
 };

 /**
 * Lazy load images using IntersectionObserver API
 */
 const setupLazyLoadingImages = () => {
 try {
 if (!('IntersectionObserver' in window)) return;
 const lazyImages = qsa('img[data-src]');

 if (lazyImages.length === 0) return;

 const observer = new IntersectionObserver((entries, obs) => {
 entries.forEach(entry => {
 if (entry.isIntersecting) {
 const img = entry.target;
 img.src = img.getAttribute('data-src');
 img.removeAttribute('data-src');
 obs.unobserve(img);
 }
 });
 }, {
 rootMargin: '0px 0px 50px 0px',
 threshold: 0.01
 });

 lazyImages.forEach(img => observer.observe(img));
 } catch (error) {
 console.error('Error setting up lazy loading images:', error);
 }
 };

 /**
 * Setup basic scroll-triggered animations on featured sections
 * Adds .animate-in class when elements come into viewport
 */
 const setupScrollAnimations = () => {
 try {
 if (!('IntersectionObserver' in window)) return;

 const animateTargets = ['#hero', '#introduction', '.about-container', '#beans', '#brewing', '#contact'];
 animateTargets.forEach(selector => {
 const elem = qs(selector);
 if (!elem) return;

 const observer = new IntersectionObserver(entries => {
 entries.forEach(entry => {
 if (entry.isIntersecting) {
 elem.classList.add('animate-in');
 }
 });
 }, { threshold: 0.15 });

 observer.observe(elem);
 });
 } catch (error) {
 console.error('Error setting up scroll animations:', error);
 }
 };

 /**
 * Handle deep linking to anchors on page load
 */
 const handleDeepLinks = () => {
 try {
 const { hash } = window.location;
 if (!hash) return;

 const target = qs(hash);
 if (target) {
 setTimeout(() => {
 target.scrollIntoView({ behavior: 'smooth' });
 }, 300);
 }
 } catch (error) {
 console.error('Error handling deep links:', error);
 }
 };

 /**
 * Manage focus ring visibility to show only for keyboard users (accessibility enhancement)
 */
 const setupFocusRingManagement = () => {
 try {
 let keyboardUser = false;

 window.addEventListener('keydown', e => {
 if (e.key === 'Tab') {
 if (!keyboardUser) {
 document.body.classList.add('user-is-tabbing');
 keyboardUser = true;
 }
 }
 });

 window.addEventListener('mousedown', () => {
 if (keyboardUser) {
 document.body.classList.remove('user-is-tabbing');
 keyboardUser = false;
 }
 });
 } catch (error) {
 console.error('Error setting up focus ring management:', error);
 }
 };

 /**
 * Initialization function that sets all features
 */
 const init = () => {
 setupMobileNavToggle();
 highlightActiveNavigationLinks();
 setupSmoothScrolling();
 enhanceImageAlts();
 setupKeyboardAccessibility();
 setupLazyLoadingImages();
 setupScrollAnimations();
 handleDeepLinks();
 setupFocusRingManagement();
 };

 // Initialize when DOM is fully loaded
 document.addEventListener('DOMContentLoaded', () => {
 try {
 init();
 } catch (error) {
 console.error('Error during main.js initialization:', error);
 }
 });

})();

// End of main.js
