// main.js - Core JavaScript for Coconut Tree Info website
// Handles navigation, global UI interactions, and common utilities

// Use strict mode for safer JavaScript
'use strict';

// Immediately Invoked Function Expression (IIFE) to avoid global scope pollution
(() => {
 const select = (selector, parent = document) => parent.querySelector(selector);
 const selectAll = (selector, parent = document) => Array.from(parent.querySelectorAll(selector));

 // Cache references to common DOM elements
 const nav = select('#main-navigation');
 const navList = select('.nav-list', nav);
 const navLinks = selectAll('.nav-link', nav);
 const header = select('#site-header');
 const footer = select('#site-footer');

 // Mobile navigation toggle variables
 let mobileNavToggle = null;
 let isMobileNavOpen = false;

 // Global keyboard event handler for accessibility and UX
 const handleGlobalKeyDown = (event) => {
 // Close mobile nav on Escape key
 if (event.key === 'Escape' && isMobileNavOpen) {
 closeMobileNav();
 }
 };

 // Create and append mobile navigation toggle button if mobile width detected
 // This toggle button will show/hide the main navigation on small screens
 const createMobileNavToggle = () => {
 try {
 mobileNavToggle = document.createElement('button');
 mobileNavToggle.setAttribute('aria-label', 'Toggle navigation menu');
 mobileNavToggle.setAttribute('aria-expanded', 'false');
 mobileNavToggle.setAttribute('aria-controls', 'main-navigation');
 mobileNavToggle.id = 'mobile-nav-toggle';
 mobileNavToggle.classList.add('mobile-nav-toggle');
 mobileNavToggle.innerHTML = '<span class="bar"></span><span class="bar"></span><span class="bar"></span>';

 header.appendChild(mobileNavToggle);

 mobileNavToggle.addEventListener('click', () => {
 if (isMobileNavOpen) {
 closeMobileNav();
 } else {
 openMobileNav();
 }
 });
 } catch (error) {
 // In case DOM manipulation fails, log error
 // This should not halt script execution
 console.error('Failed to create mobile nav toggle:', error);
 }
 };

 // Function to open mobile navigation menu
 const openMobileNav = () => {
 try {
 nav.classList.add('open');
 if (mobileNavToggle) {
 mobileNavToggle.setAttribute('aria-expanded', 'true');
 mobileNavToggle.classList.add('active');
 }
 isMobileNavOpen = true;
 document.body.style.overflow = 'hidden'; // Prevent background scrolling
 } catch (error) {
 console.error('Error opening mobile nav:', error);
 }
 };

 // Function to close mobile navigation menu
 const closeMobileNav = () => {
 try {
 nav.classList.remove('open');
 if (mobileNavToggle) {
 mobileNavToggle.setAttribute('aria-expanded', 'false');
 mobileNavToggle.classList.remove('active');
 }
 isMobileNavOpen = false;
 document.body.style.overflow = '';
 } catch (error) {
 console.error('Error closing mobile nav:', error);
 }
 };

 // Function to detect and highlight active page in navigation
 const highlightActiveNavLink = () => {
 try {
 const currentPath = window.location.pathname;
 navLinks.forEach(link => {
 // Remove any existing active/current class
 link.classList.remove('current');
 link.removeAttribute('aria-current');
 // Normalize URL for comparison
 const linkUrl = new URL(link.href, window.location.origin).pathname;
 if (linkUrl === currentPath) {
 link.classList.add('current');
 link.setAttribute('aria-current', 'page');
 }
 });
 } catch (error) {
 console.error('Error highlighting active nav link:', error);
 }
 };

 // Smooth scroll to linked anchor (for all nav links within the page)
 // Handles links with hashes that refer to elements on the same page
 const smoothScrollTo = (targetId, offset = 0) => {
 if (!targetId) return;
 try {
 const targetEl = select(targetId);
 if (targetEl) {
 // Calculate top position relative to viewport + current scroll position
 const top = targetEl.getBoundingClientRect().top + window.pageYOffset - offset;
 window.scrollTo({ top, behavior: 'smooth' });
 }
 } catch (error) {
 console.error('Smooth scroll error:', error);
 }
 };

 // Scroll to top button functionality (if implemented later, placeholder)
 // For now, not present in provided HTML, so not implemented here

 // CHARACTERISTICS section toggle for index.html (expand/collapse extras if added - placeholder for future)
 // Currently no interactive toggles in content sections, however setup for future
 const setupExpandableSections = () => {
 // No interactive expandable sections present in HTML as of now
 };

 // Setup global event delegation for nav - close mobile nav when clicking on a link
 // Also support smooth scroll for anchor links
 const setupNavDelegation = () => {
 if (!nav) return;
 nav.addEventListener('click', event => {
 const target = event.target;
 if (!target) return;

 // Check if clicked element is a nav link
 if (target.classList.contains('nav-link')) {
 // Close mobile nav if open
 if (isMobileNavOpen) {
 closeMobileNav();
 }

 // Handle smooth scroll if link is an anchor link with hash referencing an element on the page
 const href = target.getAttribute('href');
 if (href && href.startsWith('#')) {
 event.preventDefault();
 smoothScrollTo(href, header.offsetHeight);
 }
 }
 });
 };

 // Form validation and UI feedback is in utils.js as per project structure
 // Here we just ensure progressive enhancement by detecting form presence and setting up listeners
 const setupContactFormEnhancement = () => {
 try {
 const contactForm = select('#contact-form');
 if (!contactForm) return;

 // Add event listener for form submission
 contactForm.addEventListener('submit', event => {
 event.preventDefault();

 // Defensive: Check form controls exist
 const nameInput = select('#name', contactForm);
 const emailInput = select('#email', contactForm);
 const messageInput = select('#message', contactForm);

 if (!nameInput || !emailInput || !messageInput) {
 console.error('Contact form inputs are missing');
 return;
 }

 const name = nameInput.value.trim();
 const email = emailInput.value.trim();
 const message = messageInput.value.trim();

 // Minimal client-side validation (additional validation handled in utils.js)
 if (!name || !email || !message) {
 alert('Please fill in all required fields before submitting.');
 return;
 }

 // Simulate form submission process (since action="#" and no backend)
 // Could integrate with fetch API if backend was defined

 // Disable submit button to prevent multiple submits
 const submitButton = select('#submit-button', contactForm);
 if (submitButton) {
 submitButton.disabled = true;
 submitButton.textContent = 'Sending...';
 }

 // Simulate asynchronous sending with timeout
 setTimeout(() => {
 alert('Thank you for contacting us, ' + name + '! Your message has been received.');
 contactForm.reset();
 if (submitButton) {
 submitButton.disabled = false;
 submitButton.textContent = 'Send Message';
 }
 }, 1000);
 });
 } catch (error) {
 console.error('Error setting up contact form enhancement:', error);
 }
 };

 // Accessible focus outlines management (show outline only when navigating with keyboard)
 const setupFocusOutlineManagement = () => {
 let hadKeyboardEvent = false;

 const handleKeyDown = (e) => {
 if (e.key === 'Tab' || e.key === 'Shift') {
 hadKeyboardEvent = true;
 document.body.classList.add('user-is-tabbing');
 }
 };

 const handleMouseDown = () => {
 if (hadKeyboardEvent) {
 hadKeyboardEvent = false;
 document.body.classList.remove('user-is-tabbing');
 }
 };

 window.addEventListener('keydown', handleKeyDown);
 window.addEventListener('mousedown', handleMouseDown);
 };

 // Window resize listener for responsive features
 // Currently, just closes mobile nav if viewport expands beyond mobile breakpoint (768px)
 const handleResize = () => {
 if (window.innerWidth > 768 && isMobileNavOpen) {
 closeMobileNav();
 }
 };

 // Initialize scripts after DOM content loaded
 const init = () => {
 try {
 highlightActiveNavLink();
 createMobileNavToggle();
 setupNavDelegation();
 setupContactFormEnhancement();
 setupExpandableSections();
 setupFocusOutlineManagement();

 // Listen to global keyboard for accessibility
 window.addEventListener('keydown', handleGlobalKeyDown);

 // Listen for window resize
 window.addEventListener('resize', handleResize);
 } catch (error) {
 console.error('Initialization error:', error);
 }
 };

 document.addEventListener('DOMContentLoaded', init);

})();

//# sourceMappingURL=main.js.map
