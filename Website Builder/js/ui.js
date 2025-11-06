// ui.js
// Manages UI and interactive components across all pages
// Handles common interactive features, animations, accessibility, and performance enhancements

(() => {
 'use strict';

 // Utility to select single element safely
 const qs = (selector, parent = document) => parent.querySelector(selector);
 // Utility to select all elements safely
 const qsa = (selector, parent = document) => Array.from(parent.querySelectorAll(selector));

 // Debounce utility to limit invocation frequency
 const debounce = (func, wait = 200) => {
 let timeout;
 return (...args) => {
 clearTimeout(timeout);
 timeout = setTimeout(() => func.apply(this, args), wait);
 };
 };

 // Setup mobile navigation toggle button
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
 toggleBtn.innerHTML = '&#9776;'; // hamburger icon

 const headerContainer = qs('.header-container');
 if (headerContainer) headerContainer.insertBefore(toggleBtn, mainNav);
 }

 toggleBtn.addEventListener('click', () => {
 const isOpen = mainNav.classList.toggle('nav-open');
 toggleBtn.setAttribute('aria-expanded', isOpen);
 });
 } catch (error) {
 console.error('Error setting up mobile navigation:', error);
 }
 };

 // Highlight active navigation links globally (header and footer)
 const highlightActiveNavigation = () => {
 try {
 const currentPage = window.location.pathname.split('/').pop() || 'index.html';
 const navLinks = qsa('.nav-link, .footer-nav-link');
 navLinks.forEach(link => {
 const href = link.getAttribute('href');
 if (href === currentPage) {
 link.classList.add('active');
 } else {
 link.classList.remove('active');
 }
 });
 } catch (error) {
 console.error('Error highlighting navigation links:', error);
 }
 };

 // Smooth scrolling for anchor links within page
 const setupSmoothScrolling = () => {
 try {
 document.body.addEventListener('click', (event) => {
 const anchor = event.target.closest('a[href^="#"]');
 if (!anchor) return;
 const targetId = anchor.getAttribute('href').substring(1);
 const targetElem = qs(`#${targetId}`);
 if (targetElem) {
 event.preventDefault();
 targetElem.scrollIntoView({ behavior: 'smooth' });
 }
 });
 } catch (error) {
 console.error('Error setting up smooth scrolling:', error);
 }
 };

 // Enhance start building button on index.html with hover animation
 const setupStartBuildingButton = () => {
 try {
 // Only on home page
 if (!(window.location.pathname.endsWith('index.html') || window.location.pathname === '/')) return;
 const startBtn = qs('#start-building-btn');
 if (!startBtn) return;

 startBtn.style.transition = 'transform 0.3s ease';

 startBtn.addEventListener('mouseenter', () => {
 startBtn.style.transform = 'scale(1.05)';
 });
 startBtn.addEventListener('mouseleave', () => {
 startBtn.style.transform = 'scale(1)';
 });
 } catch (error) {
 console.error('Error setting up start building button:', error);
 }
 };

 // Ensure all images have alt for accessibility, fallback with generic text
 const enhanceImageAccessibility = () => {
 try {
 const images = qsa('img');
 images.forEach(img => {
 if (!img.alt || img.alt.trim() === '') {
 img.alt = 'Website Builder image';
 }
 });
 } catch (error) {
 console.error('Error enhancing image accessibility:', error);
 }
 };

 // Keyboard interaction enhancements for accessible buttons and custom interactive elements
 const setupKeyboardInteractions = () => {
 try {
 document.body.addEventListener('keydown', (event) => {
 const el = event.target;
 if (!el) return;
 if (['Enter', ' '].includes(event.key)) {
 if (el.tagName === 'BUTTON' || el.getAttribute('role') === 'button') {
 el.click();
 }
 }
 });
 } catch (error) {
 console.error('Error setting up keyboard interactions:', error);
 }
 };

 // Lazy load images using IntersectionObserver 
 const setupLazyLoadingImages = () => {
 try {
 if (!('IntersectionObserver' in window)) return;

 const lazyImages = qsa('img[data-src]');
 if (lazyImages.length === 0) return;

 const imageObserver = new IntersectionObserver((entries, observer) => {
 entries.forEach(entry => {
 if (entry.isIntersecting) {
 const img = entry.target;
 img.src = img.getAttribute('data-src');
 img.removeAttribute('data-src');
 observer.unobserve(img);
 }
 });
 }, { rootMargin: '0px 0px 50px 0px', threshold: 0.01});

 lazyImages.forEach(img => imageObserver.observe(img));
 } catch (error) {
 console.error('Error setting up lazy loading images:', error);
 }
 };

 // Animate features section and about page content on scroll into view
 const setupScrollAnimations = () => {
 try {
 if (!('IntersectionObserver' in window)) return;
 const animateSelectors = ['#features', '.about-container'];
 animateSelectors.forEach(selector => {
 const elem = qs(selector);
 if (!elem) return;

 const observer = new IntersectionObserver((entries) => {
 entries.forEach(entry => {
 if (entry.isIntersecting) {
 elem.classList.add('animate-in');
 }
 });
 }, { threshold: 0.1 });

 observer.observe(elem);
 });
 } catch (error) {
 console.error('Error setting up scroll animations:', error);
 }
 };

 // Handle deep linking for in-page anchors on load
 const handleDeepLinks = () => {
 try {
 if (window.location.hash) {
 const target = qs(window.location.hash);
 if (target) {
 setTimeout(() => {
 target.scrollIntoView({ behavior: 'smooth' });
 }, 300);
 }
 }
 } catch (error) {
 console.error('Error handling deep links:', error);
 }
 };

 // Manage focus ring visibility only for keyboard users (accessibility enhancement)
 const setupFocusRingManagement = () => {
 try {
 let keyboardUser = false;

 window.addEventListener('keydown', (e) => {
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

 // Initialization function for all UI features
 const init = () => {
 setupMobileNavigation();
 highlightActiveNavigation();
 setupSmoothScrolling();
 setupStartBuildingButton();
 enhanceImageAccessibility();
 setupKeyboardInteractions();
 setupLazyLoadingImages();
 setupScrollAnimations();
 handleDeepLinks();
 setupFocusRingManagement();
 };

 // Run on DOM content loaded
 document.addEventListener('DOMContentLoaded', () => {
 try {
 init();
 } catch (error) {
 console.error('UI initialization error:', error);
 }
 });

})();

// End of ui.js
