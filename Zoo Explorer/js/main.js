// main.js - Core JavaScript for Zoo Explorer website

(() => {
 'use strict';

 // Cache common DOM elements
 const body = document.body;
 const mainHeader = document.getElementById('main-header');
 const mainNav = document.getElementById('main-nav');
 const navList = mainNav ? mainNav.querySelector('.nav-list') : null;
 const siteTitle = document.querySelector('.site-title');

 /**
 * Utility: check if element is a valid HTMLElement
 * @param {*} el
 * @returns {boolean}
 */
 const isValidElement = (el) => el instanceof HTMLElement;

 /**
 * MOBILE NAVIGATION TOGGLE
 * Dynamically inject hamburger button for mobile nav toggle
 * Handles aria attributes and 'nav-open' class toggling
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

 // Insert toggle button before nav (or fallback to mainHeader and siteTitle parent)
 if (mainNav.parentNode) {
 mainNav.parentNode.insertBefore(toggleBtn, mainNav);
 } else if (siteTitle && siteTitle.parentNode) {
 siteTitle.parentNode.insertBefore(toggleBtn, mainNav);
 } else {
 mainHeader.insertBefore(toggleBtn, mainNav);
 }
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
 if (toggleBtn) toggleBtn.setAttribute('aria-expanded', 'false');
 }
 });
 } catch (err) {
 // eslint-disable-next-line no-console
 console.error('Error initializing mobile nav toggle:', err);
 }
 };

 /**
 * NAVIGATION ACTIVE LINK HIGHLIGHT
 * Compares nav link href with current URL pathname and adds 'active' class
 * Robust for relative and absolute paths
 */
 const highlightActiveNavLink = () => {
 try {
 if (!navList) return;
 const navLinks = navList.querySelectorAll('a.nav-link');
 const currPath = window.location.pathname.replace(/\\/g, '/');

 navLinks.forEach(link => {
 const href = link.getAttribute('href');
 if (!href) return;

 const linkPath = new URL(href, window.location.origin).pathname.replace(/\\/g, '/');

 const active = 
 currPath === linkPath ||
 (currPath.endsWith(linkPath) && linkPath !== '/') ||
 (currPath === '/' && (linkPath === '/index.html' || linkPath === '/'));

 if (active) {
 link.classList.add('active');
 } else {
 link.classList.remove('active');
 }
 });
 } catch (err) {
 // eslint-disable-next-line no-console
 console.error('Error highlighting active nav link:', err);
 }
 };

 /**
 * SMOOTH SCROLL FOR INTERNAL HASH LINKS
 * Delegates click events, animates scroll for anchors
 */
 const enableSmoothScrolling = () => {
 try {
 body.addEventListener('click', event => {
 const target = event.target;
 if (!(target instanceof HTMLElement)) return;

 // Find closest anchor with href starting with '#'
 const anchor = target.closest('a[href^="#"]');
 if (!anchor) return;

 const href = anchor.getAttribute('href');
 if (!href || href.length < 2) return;

 const targetId = href.substring(1);
 if (!targetId) return;

 const scrollTarget = document.getElementById(targetId);
 if (!scrollTarget) return;

 event.preventDefault();
 scrollTarget.scrollIntoView({ behavior: 'smooth' });
 history.pushState(null, '', href);
 });
 } catch (err) {
 // eslint-disable-next-line no-console
 console.error('Error enabling smooth scrolling:', err);
 }
 };

 /**
 * HEADER SCROLL EFFECT
 * Adds class 'scrolled' to header when page is scrolled down
 */
 const initHeaderScrollEffect = () => {
 try {
 if (!isValidElement(mainHeader)) return;

 const onScroll = () => {
 if (window.scrollY > 10) {
 mainHeader.classList.add('scrolled');
 } else {
 mainHeader.classList.remove('scrolled');
 }
 };

 window.addEventListener('scroll', onScroll, { passive: true });
 onScroll(); // initial check
 } catch (err) {
 // eslint-disable-next-line no-console
 console.error('Error initializing header scroll effect:', err);
 }
 };

 /**
 * FEATURED ANIMALS HOVER AND FOCUS EFFECTS (on index.html)
 * Adds subtle hover/focus highlight to animal cards
 */
 const enhanceFeaturedAnimals = () => {
 try {
 const featuredSection = document.getElementById('featured-animals');
 if (!isValidElement(featuredSection)) return;

 // Use event delegation
 featuredSection.addEventListener('mouseover', e => {
 const card = e.target.closest('.animal-card');
 if (isValidElement(card)) {
 card.classList.add('hovered');
 }
 });

 featuredSection.addEventListener('mouseout', e => {
 const card = e.target.closest('.animal-card');
 if (isValidElement(card)) {
 card.classList.remove('hovered');
 }
 });

 featuredSection.addEventListener('focusin', e => {
 const card = e.target.closest('.animal-card');
 if (isValidElement(card)) {
 card.classList.add('hovered');
 }
 });

 featuredSection.addEventListener('focusout', e => {
 const card = e.target.closest('.animal-card');
 if (isValidElement(card)) {
 card.classList.remove('hovered');
 }
 });
 } catch (err) {
 // eslint-disable-next-line no-console
 console.error('Error enhancing featured animals:', err);
 }
 };

 /**
 * NAVIGATION ACCESSIBILITY
 * Keyboard accessible toggle button, focus trap modal if nav open
 */
 const improveNavAccessibility = () => {
 try {
 const toggleBtn = mainHeader ? mainHeader.querySelector('.mobile-nav-toggle') : null;
 if (!toggleBtn || !mainNav) return;

 let focusableElements = [];
 let firstFocusable = null;
 let lastFocusable = null;

 const updateFocusable = () => {
 focusableElements = Array.from(mainNav.querySelectorAll('a[href], button:not([disabled]), input, select, textarea, [tabindex]:not([tabindex="-1"])')).filter(el => el.offsetParent !== null);
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
 console.error('Error improving nav accessibility:', err);
 }
 };

 /**
 * Validate image alt attributes on development environments
 * Logs warnings for any image missing alt or empty alt
 */
 const validateImageAlts = () => {
 try {
 if (!['localhost', '127.0.0.1'].includes(window.location.hostname)) return;

 const images = document.querySelectorAll('img');
 images.forEach(img => {
 if (!img.hasAttribute('alt') || img.getAttribute('alt').trim() === '') {
 // eslint-disable-next-line no-console
 console.warn('Image missing alt attribute or empty alt:', img);
 }
 });
 } catch (err) {
 // eslint-disable-next-line no-console
 console.error('Error validating image alts:', err);
 }
 };

 /**
 * Global event handlers placeholder
 * Could be expanded with analytics or keyboard shortcut handling
 */
 const initGlobalEventHandlers = () => {
 // Placeholder for future global features
 };

 // Initialize all features on DOM ready
 document.addEventListener('DOMContentLoaded', () => {
 initMobileNavToggle();
 highlightActiveNavLink();
 enableSmoothScrolling();
 initHeaderScrollEffect();
 enhanceFeaturedAnimals();
 improveNavAccessibility();
 validateImageAlts();
 initGlobalEventHandlers();
 });

})();

/*
 Notes:
 - The script handles global site behaviors across all pages.
 - Mobile navigation toggle and accessibility enhancements are injected dynamically.
 - Active navigation link is dynamically determined based on current URL.
 - Smooth scrolling improves user experience on in-page anchor links.
 - Scroll effects applied to header to improve UI feedback.
 - Featured animals on homepage get hover/focus effects for better interactivity.
 - Accessibility features include keyboard navigation and focus trapping for menus.
 - Image alt attributes are validated in development to ensure accessibility compliance.
 - Defensive programming with try/catch and element existence checks to avoid runtime errors.
 - Script is modular and maintainable for future feature additions.
*/