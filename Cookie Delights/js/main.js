// main.js - Core functionality for Cookie Delights website
// Handles navigation, active link highlighting, mobile menu toggle, and common utilities

// Using IIFE to avoid polluting global namespace
(() => {
 'use strict';

 /**
 * Utility function to safely query selector and return null if not found
 * @param {string} selector
 * @param {Element|Document} [parent=document]
 * @returns {Element|null}
 */
 const qs = (selector, parent = document) => {
 try {
 return parent.querySelector(selector);
 } catch (e) {
 console.error(`Error in selector '${selector}':`, e);
 return null;
 }
 };

 /**
 * Utility function to safely query selectorAll and Array.from result
 * @param {string} selector
 * @param {Element|Document} [parent=document]
 * @returns {Element[]}
 */
 const qsa = (selector, parent = document) => {
 try {
 return Array.from(parent.querySelectorAll(selector));
 } catch (e) {
 console.error(`Error in selectorAll '${selector}':`, e);
 return [];
 }
 };

 /**
 * Set active navigation link based on current URL
 * This highlights the active nav link in #main-nav
 */
 const setActiveNavLink = () => {
 const navLinks = qsa('.nav-link');
 if (navLinks.length === 0) return;

 // Get current page URL path for comparison
 // We treat index.html and / same
 const currentPath = window.location.pathname.split('/').pop() || 'index.html';

 navLinks.forEach(link => {
 const href = link.getAttribute('href');
 if (!href) return;

 // Normalize href to filename only
 const linkPage = href.split('/').pop();
 // Remove trailing fragments or query if any
 const linkPageClean = linkPage.split(/[?#]/)[0];

 if ((currentPath === 'index.html' && (linkPageClean === 'index.html' || linkPageClean === '')) ||
 currentPath === linkPageClean) {
 link.classList.add('active');
 } else {
 link.classList.remove('active');
 }
 });
 };

 /**
 * Mobile navigation toggle:
 * Inserts a toggle button for mobile and adds aria attributes for accessibility.
 * Controls showing/hiding the #main-nav navigation on small screens.
 */
 const setupMobileNavToggle = () => {
 const nav = qs('#main-nav');
 if (!nav) return;

 // Create toggle button
 const toggleBtn = document.createElement('button');
 toggleBtn.setAttribute('aria-expanded', 'false');
 toggleBtn.setAttribute('aria-controls', 'main-nav');
 toggleBtn.setAttribute('id', 'mobile-nav-toggle');
 toggleBtn.className = 'mobile-nav-toggle';
 toggleBtn.title = 'Toggle navigation menu';
 toggleBtn.innerHTML = '<span class="sr-only">Toggle menu</span>☰';

 // Insert toggle button before nav
 nav.parentNode.insertBefore(toggleBtn, nav);

 // Toggle handler
 toggleBtn.addEventListener('click', () => {
 const expanded = toggleBtn.getAttribute('aria-expanded') === 'true';
 toggleBtn.setAttribute('aria-expanded', String(!expanded));
 nav.classList.toggle('nav-open');

 // Lock scroll on body when nav open
 document.body.classList.toggle('no-scroll', !expanded);
 });

 // Close mobile menu if clicking outside nav area
 document.addEventListener('click', (e) => {
 if (!nav.contains(e.target) && e.target !== toggleBtn && nav.classList.contains('nav-open')) {
 nav.classList.remove('nav-open');
 toggleBtn.setAttribute('aria-expanded', 'false');
 document.body.classList.remove('no-scroll');
 }
 });

 // Keyboard accessibility: close menu with Escape key
 document.addEventListener('keydown', (e) => {
 if (e.key === 'Escape' && nav.classList.contains('nav-open')) {
 nav.classList.remove('nav-open');
 toggleBtn.setAttribute('aria-expanded', 'false');
 document.body.classList.remove('no-scroll');
 toggleBtn.focus();
 }
 });
 };

 /**
 * Scroll to a target element smoothly
 * @param {Element} target
 */
 const smoothScrollTo = (target) => {
 if (!target) return;
 target.scrollIntoView({ behavior: 'smooth', block: 'start' });
 };

 /**
 * Enhance internal anchor links for smooth scrolling
 */
 const enhanceInternalLinks = () => {
 const links = qsa('a[href^="#"]');
 links.forEach(link => {
 link.addEventListener('click', (e) => {
 const targetId = link.getAttribute('href').slice(1);
 const targetEl = qs(`#${targetId}`);
 if (targetEl) {
 e.preventDefault();
 smoothScrollTo(targetEl);
 // Update location hash without jumping
 history.pushState(null, '', `#${targetId}`);
 }
 });
 });
 };

 /**
 * Lazy-load images with .lazy-load class using IntersectionObserver
 * Fallback to eager loading if unsupported
 */
 const setupLazyLoadImages = () => {
 const images = qsa('img.lazy-load');
 if (images.length === 0) return;

 if ('IntersectionObserver' in window) {
 const observer = new IntersectionObserver((entries, observerInstance) => {
 entries.forEach(entry => {
 if (entry.isIntersecting) {
 const img = entry.target;
 const src = img.getAttribute('data-src');
 if (src) {
 img.src = src;
 img.removeAttribute('data-src');
 }
 const srcset = img.getAttribute('data-srcset');
 if (srcset) {
 img.srcset = srcset;
 img.removeAttribute('data-srcset');
 }
 observerInstance.unobserve(img);
 }
 });
 });

 images.forEach(img => {
 observer.observe(img);
 });
 } else {
 // Fallback: load all images immediately
 images.forEach(img => {
 const src = img.getAttribute('data-src');
 if (src) img.src = src;
 const srcset = img.getAttribute('data-srcset');
 if (srcset) img.srcset = srcset;
 });
 }
 };

 /**
 * Highlight recipe cards on hover/tap for better interactivity on featured recipes section
 * Adds .highlight class to the hovered card
 */
 const setupRecipeCardInteractions = () => {
 const recipeSection = qs('#featured-recipes');
 if (!recipeSection) return;

 recipeSection.addEventListener('mouseover', event => {
 const card = event.target.closest('.recipe-card');
 if (!card) return;
 card.classList.add('highlight');
 });

 recipeSection.addEventListener('mouseout', event => {
 const card = event.target.closest('.recipe-card');
 if (!card) return;
 card.classList.remove('highlight');
 });

 // For touch devices, toggle highlight on tap
 recipeSection.addEventListener('click', event => {
 const card = event.target.closest('.recipe-card');
 if (!card) return;
 card.classList.toggle('highlight');
 });
 };

 /**
 * Global keyboard shortcuts:
 * ? key opens a help alert (example)
 * Esc closes any modal or mobile nav
 */
 const setupGlobalKeyboardShortcuts = () => {
 document.addEventListener('keydown', (e) => {
 if (e.key === '?') {
 alert('Welcome to Cookie Delights! Use navigation to browse recipes, about us, and contact.');
 } else if (e.key === 'Escape') {
 // Close mobile nav if open
 const nav = qs('#main-nav');
 const toggleBtn = qs('#mobile-nav-toggle');
 if (nav && nav.classList.contains('nav-open')) {
 nav.classList.remove('nav-open');
 if (toggleBtn) toggleBtn.setAttribute('aria-expanded', 'false');
 document.body.classList.remove('no-scroll');
 if (toggleBtn) toggleBtn.focus();
 }
 }
 });
 };

 /**
 * Initialize all global features common across all pages
 */
 const init = () => {
 setActiveNavLink();
 setupMobileNavToggle();
 enhanceInternalLinks();
 setupLazyLoadImages();
 setupRecipeCardInteractions();
 setupGlobalKeyboardShortcuts();
 };

 // Run init on DOMContentLoaded to ensure DOM is fully parsed
 document.addEventListener('DOMContentLoaded', () => {
 try {
 init();
 } catch (err) {
 console.error('Error initializing main.js:', err);
 }
 });

})();

/* Additional CSS classes that should be defined in style.css for best experience:
 .mobile-nav-toggle { /* styles for mobile nav toggle button, typically a hamburger icon */
 }
 .nav-open { /* makes nav visible in mobile view */
 }
 .no-scroll { overflow: hidden; } /* disables scroll on body when mobile menu is open */
 .highlight { /* highlights recipe card on hover/touch */
 box-shadow: 0 0 10px rgba(255, 165, 0, 0.8);
 transform: scale(1.05);
 transition: transform 0.3s, box-shadow 0.3s;
 }
*/
