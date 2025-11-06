// beans.js
// Enhances UI interactions and features specific and common to all pages having coffee beans content and site-wide interactive enhancements.

(() => {
 'use strict';

 // Helper selectors
 const qs = (selector, parent = document) => parent.querySelector(selector);
 const qsa = (selector, parent = document) => Array.from(parent.querySelectorAll(selector));

 // Debounce utility for performance
 const debounce = (fn, delay = 200) => {
 let timer = null;
 return (...args) => {
 clearTimeout(timer);
 timer = setTimeout(() => fn(...args), delay);
 };
 };

 // Mobile Navigation Toggle Setup (common feature, reinforcing for beans.js page)
 const setupMobileNavigation = () => {
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
 toggleBtn.innerHTML = '&#9776;';

 const headerContainer = qs('.header-container');
 if (headerContainer) headerContainer.insertBefore(toggleBtn, mainNav);
 }

 toggleBtn.addEventListener('click', () => {
 const isOpen = mainNav.classList.toggle('nav-open');
 toggleBtn.setAttribute('aria-expanded', isOpen);
 });
 } catch (error) {
 console.error('beans.js mobile navigation error:', error);
 }
 };

 // Highlight Active Navigation Links
 const highlightActiveLinks = () => {
 try {
 const currentPage = window.location.pathname.split('/').pop() || 'index.html';
 const navLinks = qsa('.nav-link, .footer-nav-link');

 navLinks.forEach(link => {
 if (link.getAttribute('href') === currentPage) {
 link.classList.add('active');
 } else {
 link.classList.remove('active');
 }
 });
 } catch (error) {
 console.error('beans.js highlightActiveLinks error:', error);
 }
 };

 // Lazy Load Images for Performance
 const setupLazyLoadImages = () => {
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
 console.error('beans.js lazy loading error:', error);
 }
 };

 // Ensure Images have Meaningful alt attributes
 const ensureAltAttributes = () => {
 try {
 const images = qsa('img');
 images.forEach(img => {
 if (!img.alt || img.alt.trim() === '') {
 img.alt = 'Coffee and Coffee Beans image';
 }
 });
 } catch (error) {
 console.error('beans.js alt attribute error:', error);
 }
 };

 // Scroll Reveal Animations Setup
 const setupScrollRevealAnimations = () => {
 try {
 if (!('IntersectionObserver' in window)) return;

 const revealSelectors = ['#beans', '.beans-container', '#hero', '#introduction'];
 revealSelectors.forEach(selector => {
 const elem = qs(selector);
 if (!elem) return;

 const observer = new IntersectionObserver(entries => {
 entries.forEach(entry => {
 if (entry.isIntersecting) {
 elem.classList.add('reveal-visible');
 }
 });
 }, { threshold: 0.12 });

 observer.observe(elem);
 });
 } catch (error) {
 console.error('beans.js scroll reveal error:', error);
 }
 };

 // Smooth scroll for internal anchor navigations
 const setupSmoothScrolling = () => {
 try {
 document.body.addEventListener('click', event => {
 const anchor = event.target.closest('a[href^="#"]');
 if (!anchor) return;

 event.preventDefault();
 const targetId = anchor.getAttribute('href').substring(1);
 const targetElem = qs(`#${targetId}`);
 if (targetElem) {
 targetElem.scrollIntoView({ behavior: 'smooth' });
 }
 });
 } catch (error) {
 console.error('beans.js smooth scrolling error:', error);
 }
 };

 // Accessible keyboard interaction for buttons and role=button elements
 const setupKeyboardAccessibility = () => {
 try {
 document.body.addEventListener('keydown', event => {
 const el = event.target;
 if (!el) return;
 if (['Enter', ' '].includes(event.key)) {
 if (el.tagName === 'BUTTON' || el.getAttribute('role') === 'button') {
 event.preventDefault();
 el.click();
 }
 }
 });
 } catch (error) {
 console.error('beans.js keyboard accessibility error:', error);
 }
 };

 // Focus ring visibility toggling for keyboard users only (accessibility)
 const setupFocusRingManagement = () => {
 try {
 let keyboardMode = false;

 window.addEventListener('keydown', e => {
 if (e.key === 'Tab') {
 if (!keyboardMode) {
 document.body.classList.add('user-is-tabbing');
 keyboardMode = true;
 }
 }
 });

 window.addEventListener('mousedown', () => {
 if (keyboardMode) {
 document.body.classList.remove('user-is-tabbing');
 keyboardMode = false;
 }
 });
 } catch (error) {
 console.error('beans.js focus ring management error:', error);
 }
 };

 // Handle deep linking on page load
 const handleDeepLinking = () => {
 try {
 if (!window.location.hash) return;
 const target = qs(window.location.hash);
 if (!target) return;
 setTimeout(() => {
 target.scrollIntoView({ behavior: 'smooth' });
 }, 300);
 } catch (error) {
 console.error('beans.js deep linking error:', error);
 }
 };

 // Initialization function
 const init = () => {
 setupMobileNavigation();
 highlightActiveLinks();
 setupLazyLoadImages();
 ensureAltAttributes();
 setupScrollRevealAnimations();
 setupSmoothScrolling();
 setupKeyboardAccessibility();
 setupFocusRingManagement();
 handleDeepLinking();
 };

 // Initialize when DOM is ready
 document.addEventListener('DOMContentLoaded', () => {
 try {
 init();
 } catch (error) {
 console.error('beans.js initialization error:', error);
 }
 });

})();

// End of beans.js
