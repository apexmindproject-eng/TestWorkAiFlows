/*
 main.js - Core JavaScript for Zombie TV Shows Wiki
 Powers global features, navigation, and interactive UI across index.html, shows.html, and about.html
 Author: Generated for project requirement
*/

// Immediately Invoked Function Expression (IIFE) to avoid polluting global scope
(() => {
 'use strict';

 // Utility function to safely query single element
 const qs = (selector, scope = document) => scope.querySelector(selector);

 // Utility function to safely query multiple elements
 const qsa = (selector, scope = document) => Array.from(scope.querySelectorAll(selector));

 // Debounce utility for resize or scroll event optimization
 const debounce = (func, wait) => {
 let timeout;
 return (...args) => {
 clearTimeout(timeout);
 timeout = setTimeout(() => func.apply(null, args), wait);
 };
 };

 // ======== Global variables ========
 const html = document.documentElement;
 const body = document.body;

 // ======== Mobile Navigation Toggle ========
 // Adding mobile menu toggle button dynamically for accessibility and responsive
 const initMobileNav = () => {
 try {
 const header = qs('#site-header');
 if (!header) return;

 // Check if toggle already exists
 if (qs('#mobile-nav-toggle')) return;

 // Create button
 const btn = document.createElement('button');
 btn.id = 'mobile-nav-toggle';
 btn.setAttribute('aria-controls', 'main-navigation');
 btn.setAttribute('aria-expanded', 'false');
 btn.setAttribute('aria-label', 'Toggle navigation menu');
 btn.classList.add('mobile-nav-toggle');
 btn.innerHTML = '&#9776;'; // Hamburger icon

 // Insert button before nav for accessibility and UI order
 const nav = qs('#main-navigation', header);
 if (!nav) return;
 header.insertBefore(btn, nav);

 // Toggle functionality
 btn.addEventListener('click', () => {
 try {
 const expanded = btn.getAttribute('aria-expanded') === 'true';
 btn.setAttribute('aria-expanded', (!expanded).toString());
 nav.classList.toggle('nav-open');
 btn.classList.toggle('active');
 // Also toggle body class to disable scroll when nav open on mobile
 body.classList.toggle('nav-open');
 } catch (err) {
 console.error('Error toggling mobile nav:', err);
 }
 });

 // Close nav on click outside or on link selection (event delegation)
 document.addEventListener('click', (event) => {
 try {
 if (!nav.classList.contains('nav-open')) return;
 const isClickInsideNav = nav.contains(event.target);
 const isButton = btn.contains(event.target);
 if (!isClickInsideNav && !isButton) {
 nav.classList.remove('nav-open');
 btn.setAttribute('aria-expanded', 'false');
 btn.classList.remove('active');
 body.classList.remove('nav-open');
 }
 } catch (err) {
 console.error('Error closing mobile nav on outside click:', err);
 }
 });

 // Close nav on nav link click
 nav.addEventListener('click', (event) => {
 try {
 if (event.target.matches('.nav-link')) {
 nav.classList.remove('nav-open');
 btn.setAttribute('aria-expanded', 'false');
 btn.classList.remove('active');
 body.classList.remove('nav-open');
 }
 } catch (err) {
 console.error('Error closing mobile nav on link click:', err);
 }
 });
 } catch (error) {
 console.error('Failed to initialize mobile nav:', error);
 }
 };

 // ======== Active Page Detection ========
 // Highlights the active nav link based on current URL or body id
 const setActiveNavLink = () => {
 try {
 const navLinks = qsa('.nav-link');
 if (!navLinks.length) return;

 // Determine current path or body id
 const currentPath = window.location.pathname;
 const bodyId = body?.id || '';

 navLinks.forEach(link => {
 const href = link.getAttribute('href');

 // Remove existing active and aria-current
 link.classList.remove('active');
 link.removeAttribute('aria-current');

 // Match by exact href pathname or by body id approximation
 if (href === currentPath || href === `#${bodyId}`) {
 link.classList.add('active');
 link.setAttribute('aria-current', 'page');
 } else {
 // Extra heuristic: match by filename (last segment)
 const linkFile = href.split('/').pop();
 const pathFile = currentPath.split('/').pop();
 if (linkFile === pathFile) {
 link.classList.add('active');
 link.setAttribute('aria-current', 'page');
 }
 }
 });
 } catch (err) {
 console.error('Error setting active navigation link:', err);
 }
 };

 // ======== Show Card Interaction (index.html & shows.html) ========
 // Clicking show cards navigates to shows.html with hashtag or just highlight on index
 // For shows.html, could enhance with keyboard focus styles or expand/collapse details if needed
 const initShowCardsInteraction = () => {
 try {
 // Only if .show-card or .show-item elements exist
 const showCards = qsa('.show-card');
 const showItems = qsa('.show-item');

 // Enable keyboard accessible navigation for show cards on index.html
 if (showCards.length) {
 showCards.forEach(card => {
 card.setAttribute('tabindex', '0');
 card.style.cursor = 'pointer';
 card.addEventListener('click', () => {
 try {
 const showId = card.id || '';
 if (showId) {
 // Navigate to shows.html with hash
 window.location.href = `shows.html#${showId}`;
 }
 } catch (err) {
 console.error('Failed to navigate to show detail:', err);
 }
 });
 card.addEventListener('keydown', e => {
 if (e.key === 'Enter' || e.key === ' ') {
 e.preventDefault();
 card.click();
 }
 });
 });
 }

 // On shows.html, check if hash present and highlight the show
 if (showItems.length) {
 const highlightShowById = (id) => {
 try {
 showItems.forEach(item => {
 if (item.id === id) {
 item.classList.add('highlighted-show');
 // Scroll into view with smooth behavior
 item.scrollIntoView({ behavior: 'smooth', block: 'center' });
 } else {
 item.classList.remove('highlighted-show');
 }
 });
 } catch (err) {
 console.error('Error highlighting show:', err);
 }
 };

 const currentHash = window.location.hash.replace('#', '');
 if (currentHash) {
 highlightShowById(currentHash);
 }

 // Optional: allow clicking show list scroll and highlight
 showItems.forEach(item => {
 item.style.cursor = 'pointer';
 item.addEventListener('click', () => {
 highlightShowById(item.id);
 // Update URL hash without page reload
 history.replaceState(null, '', `#${item.id}`);
 });
 });
 }
 } catch (error) {
 console.error('Error initializing show cards interaction:', error);
 }
 };

 // ======== Accessibility Enhancements ========
 // Trap focus inside nav when open on mobile
 const manageFocusTrapInMobileNav = () => {
 try {
 const nav = qs('#main-navigation');
 const toggleBtn = qs('#mobile-nav-toggle');
 if (!nav || !toggleBtn) return;

 const focusableSelectors = [
 'a[href]', 'button:not([disabled])', 'input:not([disabled])', 'select:not([disabled])', 'textarea:not([disabled])', '[tabindex]:not([tabindex="-1"])'
 ];

 const getFocusableElements = () => qsa(focusableSelectors.join(','), nav).filter(el => el.offsetParent !== null);

 let firstFocusable = null;
 let lastFocusable = null;

 const keyListener = (event) => {
 if (!nav.classList.contains('nav-open')) return;
 if (event.key !== 'Tab') return;
 const focusableElems = getFocusableElements();
 firstFocusable = focusableElems[0];
 lastFocusable = focusableElems[focusableElems.length - 1];

 if (event.shiftKey) {
 if (document.activeElement === firstFocusable) {
 event.preventDefault();
 lastFocusable.focus();
 }
 } else {
 if (document.activeElement === lastFocusable) {
 event.preventDefault();
 firstFocusable.focus();
 }
 }
 };

 document.addEventListener('keydown', keyListener);

 // Clean up on page unload
 window.addEventListener('unload', () => {
 document.removeEventListener('keydown', keyListener);
 });
 } catch (err) {
 console.error('Error managing focus trap in mobile nav:', err);
 }
 };

 // ======== Initialization on DOMContentLoaded ========
 document.addEventListener('DOMContentLoaded', () => {
 try {
 initMobileNav();
 setActiveNavLink();
 initShowCardsInteraction();
 manageFocusTrapInMobileNav();

 // Additional global accessibility improvements
 // Add skip to content link focus handling if needed

 } catch (err) {
 console.error('Error during DOMContentLoaded initialization:', err);
 }
 });

 // ======== Window Resize Handler (example usage of debounce) ========
 window.addEventListener('resize', debounce(() => {
 // We might want to close mobile nav or adjust UI on resize
 const nav = qs('#main-navigation');
 const toggleBtn = qs('#mobile-nav-toggle');
 if (nav && toggleBtn && window.innerWidth > 768) {
 if (nav.classList.contains('nav-open')) {
 nav.classList.remove('nav-open');
 toggleBtn.setAttribute('aria-expanded', 'false');
 toggleBtn.classList.remove('active');
 body.classList.remove('nav-open');
 }
 }
 }, 150));

})();

/*
Additional Notes:
- No forms were found in all pages, so no form validation or submission logic was implemented.
- Interactive elements are primarily navigation links and show cards.
- All navigation accessibility enhancements and mobile menu toggling are handled.
- Show highlight and navigation on the shows page enhanced via JS.
- Defensive programming and error handling via try/catch implemented.
*/
