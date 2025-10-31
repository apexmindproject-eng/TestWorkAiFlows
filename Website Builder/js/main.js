// main.js - Core functionality, navigation, global features

const MainScript = (() => {
 // Global selectors
 const selectors = {
 nav: '#main-nav',
 navLinks: '.nav-link',
 mobileNavToggleClass: 'nav-toggle',
 siteHeader: '#site-header',
 siteFooter: '#site-footer',
 mainContent: '#main-content',
 // Currently no forms on any pages, placeholder for future
 };

 // Utility functions
 const utils = {
 safeQuerySelector: (selector, base = document) => {
 try {
 return base.querySelector(selector);
 } catch {
 return null;
 }
 },
 safeQuerySelectorAll: (selector, base = document) => {
 try {
 return Array.from(base.querySelectorAll(selector));
 } catch {
 return [];
 }
 },
 isMobileView: () => window.matchMedia('(max-width: 768px)').matches,
 debounce: (func, wait = 150) => {
 let timeout;
 return (...args) => {
 clearTimeout(timeout);
 timeout = setTimeout(() => func.apply(null, args), wait);
 };
 },
 addClass: (el, className) => {
 if (el && !el.classList.contains(className)) el.classList.add(className);
 },
 removeClass: (el, className) => {
 if (el && el.classList.contains(className)) el.classList.remove(className);
 },
 // Simple smooth scroll for anchor links
 smoothScrollTo: (targetEl) => {
 if (targetEl && targetEl.scrollIntoView) {
 targetEl.scrollIntoView({ behavior: 'smooth', block: 'start' });
 }
 }
 };

 // Mobile navigation toggle setup
 function setupMobileNavToggle() {
 const nav = utils.safeQuerySelector(selectors.nav);
 if (!nav) return;

 // Check if toggle btn exists
 if (!document.querySelector(`.${selectors.mobileNavToggleClass}`)) {
 const toggleBtn = document.createElement('button');
 toggleBtn.className = selectors.mobileNavToggleClass;
 toggleBtn.setAttribute('aria-label', 'Toggle navigation menu');
 toggleBtn.setAttribute('aria-expanded', 'false');
 toggleBtn.type = 'button';
 toggleBtn.innerHTML = '<span class="hamburger-icon">&#9776;</span>';

 nav.parentNode.insertBefore(toggleBtn, nav);

 toggleBtn.addEventListener('click', () => {
 nav.classList.toggle('nav-open');
 const expanded = nav.classList.contains('nav-open');
 toggleBtn.setAttribute('aria-expanded', expanded);
 });

 // Close nav when clicking outside or resizing
 document.addEventListener('click', (e) => {
 if (nav.classList.contains('nav-open') && !nav.contains(e.target) && e.target !== toggleBtn) {
 nav.classList.remove('nav-open');
 toggleBtn.setAttribute('aria-expanded', 'false');
 }
 });

 window.addEventListener('resize', utils.debounce(() => {
 if (!utils.isMobileView() && nav.classList.contains('nav-open')) {
 nav.classList.remove('nav-open');
 toggleBtn.setAttribute('aria-expanded', 'false');
 }
 }));
 }
 }

 // Highlight active navigation link to reflect current page
 function highlightActiveNavLink() {
 const navLinks = utils.safeQuerySelectorAll(selectors.navLinks);
 if (!navLinks.length) return;

 const currentPage = window.location.pathname.split('/').pop() || 'index.html';

 navLinks.forEach(link => {
 const href = link.getAttribute('href');
 if (href === currentPage) {
 link.classList.add('current');
 link.setAttribute('aria-current', 'page');
 } else {
 link.classList.remove('current');
 link.removeAttribute('aria-current');
 }
 });
 }

 // Global keyboard shortcut handler
 function setupKeyboardShortcuts() {
 // Example: Escape closes mobile nav if open
 document.addEventListener('keydown', e => {
 if (e.key === 'Escape' || e.key === 'Esc') {
 const nav = utils.safeQuerySelector(selectors.nav);
 const toggleBtn = document.querySelector(`.${selectors.mobileNavToggleClass}`);
 if (nav && nav.classList.contains('nav-open')) {
 nav.classList.remove('nav-open');
 if (toggleBtn) toggleBtn.setAttribute('aria-expanded', 'false');
 e.preventDefault();
 }
 }
 });
 }

 // Scroll to top button and behavior (optional example)
 function setupScrollToTop() {
 // Create scroll-to-top button dynamically
 const btn = utils.createElement('button', {
 className: 'scroll-to-top',
 type: 'button',
 'aria-label': 'Scroll to top',
 title: 'Back to top'
 },
 utils.createElement('span', {innerHTML: '&#8679;'}) // Up arrow
 );

 // Append to body
 document.body.appendChild(btn);

 // Show/hide button on scroll
 window.addEventListener('scroll', utils.debounce(() => {
 if (window.scrollY > 300) {
 btn.style.display = 'block';
 } else {
 btn.style.display = 'none';
 }
 }, 100));

 // Click behavior
 btn.addEventListener('click', () => {
 window.scrollTo({ top: 0, behavior: 'smooth' });
 });
 }

 // Focus management for accessibility
 function setupFocusManagement() {
 const links = utils.safeQuerySelectorAll('a[href^="#"]');
 links.forEach(link => {
 link.addEventListener('click', e => {
 const targetId = link.getAttribute('href').slice(1);
 const targetEl = document.getElementById(targetId);
 if (targetEl) {
 utils.smoothScrollTo(targetEl);
 e.preventDefault();
 // Set focus after scroll
 setTimeout(() => {
 targetEl.setAttribute('tabindex', '-1');
 targetEl.focus();
 }, 400);
 }
 });
 });
 }

 // Initialize core site features
 function init() {
 document.addEventListener('DOMContentLoaded', () => {
 try {
 setupMobileNavToggle();
 highlightActiveNavLink();
 setupKeyboardShortcuts();
 setupScrollToTop();
 setupFocusManagement();
 } catch (error) {
 console.error('Error initializing main.js:', error);
 }
 });
 }

 // Public API
 return {
 init
 };
})();

MainScript.init();

//# sourceURL=main.js
