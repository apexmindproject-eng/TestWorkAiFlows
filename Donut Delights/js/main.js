// main.js - Core JavaScript functionality for Donut Delights site

(() => {
 'use strict';

 // Cache DOM elements used across pages
 const body = document.body;
 const mainHeader = document.getElementById('main-header');
 const mainNav = document.getElementById('main-nav');
 const navList = mainNav ? mainNav.querySelector('.nav-list') : null;
 const siteTitle = document.querySelector('.site-title');

 /**
 * Utility: Checks if element is a valid HTMLElement
 * @param {*} el
 * @returns {boolean}
 */
 const isValidElement = (el) => el instanceof HTMLElement;

 /**
 * MOBILE NAVIGATION
 * Dynamically adds a mobile navigation toggle (hamburger button)
 * Manages aria attributes and toggling of navigation menu
 */
 const initMobileNavToggle = () => {
 try {
 if (!isValidElement(mainHeader) || !isValidElement(mainNav)) return;

 let toggleBtn = mainHeader.querySelector('.mobile-nav-toggle');
 if (!toggleBtn) {
 toggleBtn = document.createElement('button');
 toggleBtn.type = 'button';
 toggleBtn.className = 'mobile-nav-toggle';
 toggleBtn.setAttribute('aria-controls', 'main-nav');
 toggleBtn.setAttribute('aria-expanded', 'false');
 toggleBtn.setAttribute('aria-label', 'Toggle navigation menu');
 toggleBtn.innerHTML = '<span class="hamburger-icon">\u2630</span>';

 // Insert toggle button before nav for better tab order
 mainHeader.insertBefore(toggleBtn, mainNav);
 }

 toggleBtn.addEventListener('click', () => {
 const expanded = toggleBtn.getAttribute('aria-expanded') === 'true';
 if (mainNav) {
 mainNav.classList.toggle('nav-open');
 toggleBtn.setAttribute('aria-expanded', String(!expanded));
 }
 });

 // Close nav if clicking outside or resizing window
 document.addEventListener('click', (event) => {
 if (!mainNav.classList.contains('nav-open')) return;
 if (!mainNav.contains(event.target) && event.target !== toggleBtn) {
 mainNav.classList.remove('nav-open');
 toggleBtn.setAttribute('aria-expanded', 'false');
 }
 });

 window.addEventListener('resize', () => {
 if (mainNav.classList.contains('nav-open')) {
 mainNav.classList.remove('nav-open');
 toggleBtn.setAttribute('aria-expanded', 'false');
 }
 });
 } catch (err) {
 // eslint-disable-next-line no-console
 console.error('Failed to initialize mobile navigation toggle:', err);
 }
 };

 /**
 * NAVIGATION ACTIVE LINK HIGHLIGHT
 * Detects the current page and sets the active class on matching nav link
 * Handles relative and absolute paths robustly
 */
 const highlightActiveNavLink = () => {
 try {
 if (!navList) return;

 const currentPath = window.location.pathname.replace(/\/g, '/');
 const navLinks = navList.querySelectorAll('a.nav-link');

 navLinks.forEach(link => {
 const href = link.getAttribute('href');
 if (!href) return;

 // Generate absolute url for href
 const linkUrl = new URL(href, window.location.origin).pathname.replace(/\/g, '/');

 // Logic to mark active links:
 // if current path ends with linkUrl (handles root paths and subfolders)
 // or current path equals linkUrl
 // e.g. '/index.html' and '/' treated suitably
 if (
 currentPath === linkUrl ||
 (currentPath.endsWith(linkUrl) && linkUrl !== '/') ||
 (currentPath === '/' && (linkUrl === '/index.html' || linkUrl === '/'))
 ) {
 link.classList.add('active');
 } else {
 link.classList.remove('active');
 }
 });
 } catch (err) {
 // eslint-disable-next-line no-console
 console.error('Failed to highlight active navigation link:', err);
 }
 };

 /**
 * SMOOTH SCROLL FOR INTERNAL LINKS
 * Applies smooth scrolling for anchor links that target in-page elements
 */
 const enableSmoothScrolling = () => {
 try {
 body.addEventListener('click', event => {
 const target = event.target;
 if (!(target instanceof HTMLElement)) return;

 // Look for closest anchor with href starting with '#'
 const anchor = target.closest('a[href^="#"]');
 if (!anchor) return;

 const href = anchor.getAttribute('href');
 if (!href) return;

 const targetId = href.slice(1);
 if (!targetId) return;

 const scrollTarget = document.getElementById(targetId);
 if (!scrollTarget) return;

 event.preventDefault();

 scrollTarget.scrollIntoView({ behavior: 'smooth' });

 // Update URL hash without jumping page
 history.pushState(null, '', href);
 });
 } catch (err) {
 // eslint-disable-next-line no-console
 console.error('Failed to enable smooth scrolling:', err);
 }
 };

 /**
 * HEADER SCROLL SHADOW
 * Adds a shadow to header when page is scrolled to improve visual clarity
 */
 const initHeaderScrollShadow = () => {
 try {
 if (!isValidElement(mainHeader)) return;

 const scrollHandler = () => {
 if (window.scrollY > 10) {
 mainHeader.classList.add('scrolled');
 } else {
 mainHeader.classList.remove('scrolled');
 }
 };

 window.addEventListener('scroll', scrollHandler, { passive: true });
 scrollHandler(); // initialize on page load
 } catch (err) {
 // eslint-disable-next-line no-console
 console.error('Failed to initialize header scroll shadow:', err);
 }
 };

 /**
 * FEATURED SECTION HOVER/FORCUS ENHANCEMENTS ON HOMEPAGE
 * Adds hover/focus effect to feature cards
 */
 const enhanceFeaturedSections = () => {
 try {
 const featuredSection = document.getElementById('featured-sections');
 if (!isValidElement(featuredSection)) return;

 featuredSection.addEventListener('mouseover', e => {
 const card = e.target.closest('.feature-card');
 if (isValidElement(card)) {
 card.classList.add('hovered');
 }
 });

 featuredSection.addEventListener('mouseout', e => {
 const card = e.target.closest('.feature-card');
 if (isValidElement(card)) {
 card.classList.remove('hovered');
 }
 });

 featuredSection.addEventListener('focusin', e => {
 const card = e.target.closest('.feature-card');
 if (isValidElement(card)) {
 card.classList.add('hovered');
 }
 });

 featuredSection.addEventListener('focusout', e => {
 const card = e.target.closest('.feature-card');
 if (isValidElement(card)) {
 card.classList.remove('hovered');
 }
 });
 } catch (err) {
 // eslint-disable-next-line no-console
 console.error('Failed to enhance featured sections:', err);
 }
 };

 /**
 * ACCESSIBILITY: KEYBOARD NAVIGATION FOR MOBILE NAV
 * Supports keyboard toggle using Enter or Space
 * Traps focus within nav when open
 */
 const improveNavAccessibility = () => {
 try {
 const toggleBtn = mainHeader ? mainHeader.querySelector('.mobile-nav-toggle') : null;
 if (!toggleBtn || !mainNav) return;

 const focusableSelectors = 'a[href], button:not([disabled]), input, select, textarea, [tabindex]:not([tabindex="-1"])';
 let focusableElements = [];
 let firstFocusable = null;
 let lastFocusable = null;

 const updateFocusable = () => {
 focusableElements = Array.from(mainNav.querySelectorAll(focusableSelectors)).filter(el => el.offsetParent !== null);
 firstFocusable = focusableElements[0];
 lastFocusable = focusableElements[focusableElements.length - 1];
 };

 toggleBtn.addEventListener('keydown', e => {
 if (e.key === 'Enter' || e.key === ' ') {
 e.preventDefault();
 toggleBtn.click();
 }
 });

 mainNav.addEventListener('keydown', e => {
 updateFocusable();

 if (!mainNav.classList.contains('nav-open')) return;

 if (e.key === 'Tab') {
 if (e.shiftKey) {
 if (document.activeElement === firstFocusable) {
 e.preventDefault();
 lastFocusable.focus();
 }
 } else {
 if (document.activeElement === lastFocusable) {
 e.preventDefault();
 firstFocusable.focus();
 }
 }
 }

 if (e.key === 'Escape') {
 mainNav.classList.remove('nav-open');
 toggleBtn.setAttribute('aria-expanded', 'false');
 toggleBtn.focus();
 }
 });
 } catch (err) {
 // eslint-disable-next-line no-console
 console.error('Failed to improve nav accessibility:', err);
 }
 };

 /**
 * VALIDATE IMAGE ALT TEXTS
 * Logs a warning in console for images without alt attribute or empty alt
 * Runs only on development hosts
 */
 const validateImageAlts = () => {
 try {
 const devHosts = ['localhost', '127.0.0.1'];
 if (!devHosts.includes(window.location.hostname)) return;

 const images = document.querySelectorAll('img');
 images.forEach(img => {
 if (!img.hasAttribute('alt') || img.getAttribute('alt').trim() === '') {
 // eslint-disable-next-line no-console
 console.warn('Image missing alt attribute or has empty alt text:', img);
 }
 });
 } catch (err) {
 // eslint-disable-next-line no-console
 console.error('Failed to validate image alt attributes:', err);
 }
 };

 /**
 * INITIALIZE global event handlers (placeholder for future features)
 */
 const initGlobalEventHandlers = () => {
 // e.g. analytics, keyboard shortcuts, global modals
 };

 // Initialize when DOM is fully loaded
 document.addEventListener('DOMContentLoaded', () => {
 initMobileNavToggle();
 highlightActiveNavLink();
 enableSmoothScrolling();
 initHeaderScrollShadow();
 enhanceFeaturedSections();
 improveNavAccessibility();
 validateImageAlts();
 initGlobalEventHandlers();
 });

})();

/*
 NOTES:
 - Navigation toggle is dynamically added for progressive enhancement.
 - Active nav link supports deeper path matching and robust handling.
 - Smooth scrolling leverages native browser support for performance.
 - Accessibility improvements include ARIA attributes and keyboard trap.
 - Defensive programming via try-catch blocks and checking DOM availability.
 - Featured section animations improve user engagement on homepage.
 - Image alt text validation helps maintain accessibility standards in development.
 - This script only manages core site-wide UI and behaviors; gallery interactions delegated to gallery.js.
*/
