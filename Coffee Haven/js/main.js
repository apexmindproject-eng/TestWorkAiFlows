// main.js - Core site functionality for Coffee Haven

// Immediately Invoked Function Expression (IIFE) to avoid polluting global namespace
(() => {
 'use strict';

 // Cache DOM elements used across multiple places
 const body = document.body;
 const mainNav = document.getElementById('main-nav');
 const navList = mainNav ? mainNav.querySelector('.nav-list') : null;
 const siteTitle = document.querySelector('.site-title');

 /**
 * Utility function to check if an element exists and is an HTMLElement
 * @param {Element | null} el
 * @returns {boolean}
 */
 const isValidElement = (el) => el instanceof HTMLElement;

 /**
 * MOBILE NAVIGATION TOGGLE
 * Adds a hamburger menu toggle for mobile navigation
 * Injects a button into #main-header for toggling nav on small screens
 */
 const initMobileNavToggle = () => {
 try {
 const header = document.getElementById('main-header');
 if (!isValidElement(header) || !isValidElement(mainNav)) return;

 // Create hamburger button
 const btn = document.createElement('button');
 btn.type = 'button';
 btn.className = 'mobile-nav-toggle';
 btn.setAttribute('aria-controls', 'main-nav');
 btn.setAttribute('aria-expanded', 'false');
 btn.setAttribute('aria-label', 'Toggle navigation menu');
 btn.innerHTML = '<span class="hamburger-icon">\u2630</span>';

 // Insert button after site title
 const titleParent = siteTitle ? siteTitle.parentNode : null;
 if (titleParent) {
 titleParent.insertBefore(btn, mainNav);
 } else {
 header.insertBefore(btn, mainNav);
 }

 // Toggle event
 btn.addEventListener('click', () => {
 const expanded = btn.getAttribute('aria-expanded') === 'true';
 if (mainNav) {
 mainNav.classList.toggle('nav-open');
 btn.setAttribute('aria-expanded', String(!expanded));
 }
 });

 // Accessibility: close nav if focus moves outside and it's open
 document.addEventListener('click', (e) => {
 if (!mainNav || !btn) return;
 if (!mainNav.classList.contains('nav-open')) return;

 if (!mainNav.contains(e.target) && e.target !== btn) {
 mainNav.classList.remove('nav-open');
 btn.setAttribute('aria-expanded', 'false');
 }
 });
 } catch (error) {
 // Log error but do not break site
 // eslint-disable-next-line no-console
 console.error('Mobile navigation toggle initialization failed:', error);
 }
 };

 /**
 * SET ACTIVE NAV LINK BASED ON CURRENT URL
 * Iterates all nav links and sets 'active' class on the one that matches current page
 * Supports relative and absolute URLs
 */
 const highlightActiveNavLink = () => {
 try {
 if (!navList) return;
 const navLinks = navList.querySelectorAll('.nav-link');
 const currentUrl = window.location.pathname;

 navLinks.forEach((link) => {
 if (!link instanceof HTMLAnchorElement) return;

 // Normalize links and paths for comparison
 const linkHref = link.getAttribute('href');
 if (!linkHref) return;

 // Extract pathname, ignoring potential query strings and hashes
 const linkUrl = new URL(linkHref, window.location.origin).pathname;

 // Matches if current URL ends with link URL (accounting for relative paths)
 // and handles index.html default
 if (
 currentUrl.endsWith(linkUrl) ||
 (currentUrl === '/' && (linkUrl === '/index.html' || linkUrl === 'index.html'))
 ) {
 link.classList.add('active');
 } else {
 link.classList.remove('active');
 }
 });
 } catch (error) {
 // eslint-disable-next-line no-console
 console.error('Failed to highlight active nav link:', error);
 }
 };

 /**
 * SMOOTH SCROLL FOR INTERNAL LINKS
 * Applies smooth scrolling behavior for in-page anchor navigation
 */
 const enableSmoothScrolling = () => {
 try {
 // Event delegation on body for all clicks
 body.addEventListener('click', (event) => {
 const target = event.target;
 if (!(target instanceof HTMLElement)) return;

 // Find closest anchor link with href starting with '#'
 const anchor = target.closest('a[href^="#"]');
 if (!anchor) return;

 const href = anchor.getAttribute('href');
 if (!href || href.length < 2) return;

 const targetId = href.substring(1);
 const scrollTarget = document.getElementById(targetId);
 if (scrollTarget) {
 event.preventDefault();
 scrollTarget.scrollIntoView({ behavior: 'smooth' });
 // Optionally update the URL hash without jumping
 history.pushState(null, '', href);
 }
 });
 } catch (error) {
 // eslint-disable-next-line no-console
 console.error('Smooth scrolling initialization failed:', error);
 }
 };

 /**
 * KEYBOARD NAVIGATION AND ACCESSIBILITY IMPROVEMENTS FOR NAVIGATION
 * Supports keyboard toggling of mobile nav and trap focus when open
 */
 const improveNavAccessibility = () => {
 try {
 const toggleBtn = document.querySelector('.mobile-nav-toggle');
 if (!toggleBtn || !mainNav) return;

 // Trap focus within nav when open
 const focusableSelectors = 'a[href], button:not([disabled]), input, select, textarea, [tabindex]:not([tabindex="-1"])';
 let focusableElements = [];
 let firstFocusable = null;
 let lastFocusable = null;

 const updateFocusable = () => {
 focusableElements = Array.from(mainNav.querySelectorAll(focusableSelectors)).filter((el) => el.offsetParent !== null);
 firstFocusable = focusableElements[0];
 lastFocusable = focusableElements[focusableElements.length - 1];
 };

 toggleBtn.addEventListener('keydown', (e) => {
 if (e.key === 'Enter' || e.key === ' ') {
 e.preventDefault();
 toggleBtn.click();
 }
 });

 mainNav.addEventListener('keydown', (e) => {
 updateFocusable();
 if (e.key === 'Tab' && mainNav.classList.contains('nav-open')) {
 if (e.shiftKey) { // Shift + Tab
 if (document.activeElement === firstFocusable) {
 e.preventDefault();
 lastFocusable.focus();
 }
 } else { // Tab
 if (document.activeElement === lastFocusable) {
 e.preventDefault();
 firstFocusable.focus();
 }
 }
 }
 // Close nav on Escape
 if (e.key === 'Escape' && mainNav.classList.contains('nav-open')) {
 mainNav.classList.remove('nav-open');
 toggleBtn.setAttribute('aria-expanded', 'false');
 toggleBtn.focus();
 }
 });
 } catch (error) {
 // eslint-disable-next-line no-console
 console.error('Navigation accessibility enhancements failed:', error);
 }
 };

 /**
 * FEATURED SECTION DYNAMIC HOVER EFFECTS
 * Adds subtle hover/focus animations on featured cards on homepage
 */
 const enhanceFeaturedSections = () => {
 try {
 const featuredSection = document.getElementById('featured-sections');
 if (!isValidElement(featuredSection)) return;

 // Event delegation to handle hover/focus on feature cards
 featuredSection.addEventListener('mouseover', (e) => {
 const card = e.target.closest('.feature-card');
 if (isValidElement(card)) {
 card.classList.add('hovered');
 }
 });

 featuredSection.addEventListener('mouseout', (e) => {
 const card = e.target.closest('.feature-card');
 if (isValidElement(card)) {
 card.classList.remove('hovered');
 }
 });

 featuredSection.addEventListener('focusin', (e) => {
 const card = e.target.closest('.feature-card');
 if (isValidElement(card)) {
 card.classList.add('hovered');
 }
 });

 featuredSection.addEventListener('focusout', (e) => {
 const card = e.target.closest('.feature-card');
 if (isValidElement(card)) {
 card.classList.remove('hovered');
 }
 });
 } catch (error) {
 // eslint-disable-next-line no-console
 console.error('Failed to enhance featured sections:', error);
 }
 };

 /**
 * DYNAMIC IMAGE ALT TEXT VALIDATION (DEVELOPMENT UTILITY)
 * Logs warnings for images missing alt text or with empty alt
 * Runs only in non-production environments
 */
 const validateImageAlts = () => {
 try {
 if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
 const images = document.querySelectorAll('img');
 images.forEach(img => {
 if (!img.hasAttribute('alt') || img.getAttribute('alt').trim() === '') {
 // eslint-disable-next-line no-console
 console.warn('Image missing alt attribute or it is empty:', img);
 }
 });
 }
 } catch (error) {
 // eslint-disable-next-line no-console
 console.error('Image alt validation failed:', error);
 }
 };

 /**
 * INIT GLOBAL EVENT HANDLERS
 * Placeholder for additional global event delegation if needed
 */
 const initGlobalEventHandlers = () => {
 // Example: Keyboard shortcuts, analytics click tracking, etc.
 // Currently empty - prepare for future enhancements
 };

 /**
 * DOCUMENT READY INITIALIZATION
 */
 document.addEventListener('DOMContentLoaded', () => {
 initMobileNavToggle();
 highlightActiveNavLink();
 enableSmoothScrolling();
 improveNavAccessibility();
 enhanceFeaturedSections();
 validateImageAlts();
 initGlobalEventHandlers();
 });

})();

/*
 NOTES:
 - Form handling and validation are handled in form-validation.js as per project structure.
 - Navigation highlights are robust to relative paths and deployed site structure.
 - Mobile navigation toggle button injected dynamically to keep markup lean.
 - Accessibility improvements include keyboard traps and ARIA attributes.
 - Smooth scrolling uses native browser support for performance and simplicity.
 - Defensive coding with many null checks and try/catch to ensure no script failures.
 - Modular functions for each feature for maintainability and future extension.
*/
