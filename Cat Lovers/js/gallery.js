/*
 gallery.js
 Manages gallery-specific features and some shared UI components for Cat Lovers website.

 Responsibilities across all pages:
 - Mobile navigation toggle (redundant fallback to main.js)
 - Active navigation highlight
 - Enhanced form validation
 - Smooth anchor scrolling
 - Accessibility improvements
 - Keyboard shortcuts
 - Gallery image lightbox with keyboard navigation and controls

 Production ready, ES6+ with clean structure, event delegation, and error handling.
 */

'use strict';

(() => {
 const $ = (selector, scope = document) => scope.querySelector(selector);
 const $$ = (selector, scope = document) => Array.from(scope.querySelectorAll(selector));

 let galleryContainer = null;
 let galleryItems = [];
 let lightboxOverlay = null;
 let lightboxImage = null;
 let lightboxCaption = null;
 let lightboxCloseBtn = null;
 let lightboxPrevBtn = null;
 let lightboxNextBtn = null;
 let currentIndex = -1;

 // Mobile navigation toggle component
 const initMobileNavToggle = () => {
 try {
 const header = $('#main-header');
 if (!header) return;
 if ($('#mobile-nav-toggle')) return;

 const nav = $('#main-nav', header);
 if (!nav) return;

 const toggleBtn = document.createElement('button');
 toggleBtn.id = 'mobile-nav-toggle';
 toggleBtn.type = 'button';
 toggleBtn.className = 'mobile-nav-toggle';
 toggleBtn.setAttribute('aria-expanded', 'false');
 toggleBtn.setAttribute('aria-label', 'Toggle navigation menu');
 toggleBtn.innerHTML = '&#9776;';

 header.insertBefore(toggleBtn, nav);

 toggleBtn.addEventListener('click', () => {
 const expanded = toggleBtn.getAttribute('aria-expanded') === 'true';
 toggleBtn.setAttribute('aria-expanded', String(!expanded));
 toggleBtn.classList.toggle('active');
 nav.classList.toggle('active');
 });

 nav.addEventListener('focusout', () => {
 setTimeout(() => {
 if (!nav.contains(document.activeElement)) {
 toggleBtn.setAttribute('aria-expanded', 'false');
 toggleBtn.classList.remove('active');
 nav.classList.remove('active');
 }
 }, 100);
 });
 } catch (error) {
 console.error('initMobileNavToggle error:', error);
 }
 };

 // Highlight active nav link
 const highlightActiveNavLink = () => {
 try {
 const navLinks = $$('.nav-link');
 if (!navLinks.length) return;

 let currentPath = window.location.pathname.split('/').pop().toLowerCase();
 if (!currentPath) currentPath = 'index.html';

 navLinks.forEach(link => {
 const href = link.getAttribute('href') || '';
 const hrefPage = href.split('/').pop().toLowerCase();

 if (hrefPage === currentPath || (hrefPage === 'index.html' && currentPath === '')) {
 link.classList.add('active');
 link.setAttribute('aria-current', 'page');
 } else {
 link.classList.remove('active');
 link.removeAttribute('aria-current');
 }
 });
 } catch (error) {
 console.error('highlightActiveNavLink error:', error);
 }
 };

 // Setup and create lightbox DOM elements
 const createLightbox = () => {
 try {
 lightboxOverlay = document.createElement('div');
 lightboxOverlay.id = 'lightbox-overlay';
 lightboxOverlay.className = 'lightbox-overlay';
 lightboxOverlay.setAttribute('role', 'dialog');
 lightboxOverlay.setAttribute('aria-modal', 'true');
 lightboxOverlay.setAttribute('aria-labelledby', 'lightbox-caption');
 lightboxOverlay.setAttribute('tabindex', '-1');
 lightboxOverlay.style.display = 'none';

 const lightboxContent = document.createElement('div');
 lightboxContent.className = 'lightbox-content';

 lightboxCloseBtn = document.createElement('button');
 lightboxCloseBtn.className = 'lightbox-close-btn';
 lightboxCloseBtn.setAttribute('aria-label', 'Close image');
 lightboxCloseBtn.innerHTML = '&times;';

 lightboxPrevBtn = document.createElement('button');
 lightboxPrevBtn.className = 'lightbox-prev-btn';
 lightboxPrevBtn.setAttribute('aria-label', 'Previous image');
 lightboxPrevBtn.innerHTML = '&#9664;';

 lightboxNextBtn = document.createElement('button');
 lightboxNextBtn.className = 'lightbox-next-btn';
 lightboxNextBtn.setAttribute('aria-label', 'Next image');
 lightboxNextBtn.innerHTML = '&#9654;';

 lightboxImage = document.createElement('img');
 lightboxImage.className = 'lightbox-image';
 lightboxImage.alt = '';

 lightboxCaption = document.createElement('p');
 lightboxCaption.id = 'lightbox-caption';
 lightboxCaption.className = 'lightbox-caption';

 lightboxContent.appendChild(lightboxCloseBtn);
 lightboxContent.appendChild(lightboxPrevBtn);
 lightboxContent.appendChild(lightboxNextBtn);
 lightboxContent.appendChild(lightboxImage);
 lightboxContent.appendChild(lightboxCaption);

 lightboxOverlay.appendChild(lightboxContent);
 document.body.appendChild(lightboxOverlay);

 // Event listeners
 lightboxCloseBtn.addEventListener('click', closeLightbox);
 lightboxOverlay.addEventListener('click', e => {
 if (e.target === lightboxOverlay) closeLightbox();
 });
 lightboxPrevBtn.addEventListener('click', showPreviousImage);
 lightboxNextBtn.addEventListener('click', showNextImage);

 document.addEventListener('keydown', keyboardHandler);
 } catch (error) {
 console.error('createLightbox error:', error);
 }
 };

 // Open lightbox at index
 const openLightbox = index => {
 if (!galleryItems.length || index < 0 || index >= galleryItems.length) return;
 currentIndex = index;
 updateLightboxContent();
 lightboxOverlay.style.display = 'flex';
 lightboxOverlay.focus();
 };

 // Close lightbox
 const closeLightbox = () => {
 if (!lightboxOverlay) return;
 lightboxOverlay.style.display = 'none';
 currentIndex = -1;
 };

 // Update lightbox image and caption
 const updateLightboxContent = () => {
 if (currentIndex < 0 || currentIndex >= galleryItems.length) return;
 const item = galleryItems[currentIndex];
 if (!item) return;

 const img = item.querySelector('img');
 const caption = item.querySelector('.caption');
 if (!img || !lightboxImage || !lightboxCaption) return;

 lightboxImage.src = img.src;
 lightboxImage.alt = img.alt || '';
 lightboxCaption.textContent = caption ? caption.textContent : '';
 };

 // Show previous image
 const showPreviousImage = () => {
 if (!galleryItems.length) return;
 currentIndex = (currentIndex - 1 + galleryItems.length) % galleryItems.length;
 updateLightboxContent();
 };

 // Show next image
 const showNextImage = () => {
 if (!galleryItems.length) return;
 currentIndex = (currentIndex + 1) % galleryItems.length;
 updateLightboxContent();
 };

 // Keyboard event handler
 const keyboardHandler = e => {
 if (lightboxOverlay && lightboxOverlay.style.display === 'flex') {
 switch (e.key) {
 case 'Escape':
 e.preventDefault();
 closeLightbox();
 break;
 case 'ArrowLeft':
 e.preventDefault();
 showPreviousImage();
 break;
 case 'ArrowRight':
 e.preventDefault();
 showNextImage();
 break;
 default:
 break;
 }
 } else {
 // Global shortcuts
 if (['INPUT', 'TEXTAREA'].includes(e.target.tagName) || e.target.isContentEditable) return;
 if (e.key.toLowerCase() === 'h') {
 window.location.href = 'index.html';
 }
 }
 };

 // Initialize gallery click to open lightbox
 const initGallery = () => {
 try {
 galleryContainer = $('#gallery');
 if (!galleryContainer) return;

 galleryItems = Array.from(galleryContainer.querySelectorAll('.gallery-item'));

 galleryContainer.addEventListener('click', e => {
 const figure = e.target.closest('.gallery-item');
 if (!figure) return;
 const idx = galleryItems.indexOf(figure);
 if (idx >= 0) openLightbox(idx);
 });
 } catch (error) {
 console.error('initGallery error:', error);
 }
 };

 // Enhance forms with validation UX
 const enhanceFormsValidation = () => {
 try {
 const forms = $$('form.form');
 if (!forms.length) return;

 forms.forEach(form => {
 const requiredFields = $$('input[required],textarea[required],select[required]', form);

 requiredFields.forEach(input => {
 input.addEventListener('input', () => input.setCustomValidity(''));
 });

 form.addEventListener('submit', e => {
 if (!form.checkValidity()) {
 e.preventDefault();
 const firstInvalid = form.querySelector(':invalid');
 if (firstInvalid) firstInvalid.focus();
 }
 });
 });
 } catch (error) {
 console.error('enhanceFormsValidation error:', error);
 }
 };

 // Smooth scrolling for anchors
 const initSmoothScrolling = () => {
 try {
 const anchors = $$('a[href^="#"]');
 if (!anchors.length) return;

 anchors.forEach(anchor => {
 anchor.addEventListener('click', e => {
 e.preventDefault();
 const targetId = anchor.getAttribute('href').slice(1);
 const target = document.getElementById(targetId);
 if (target) {
 target.scrollIntoView({ behavior: 'smooth' });
 }
 });
 });
 } catch (error) {
 console.error('initSmoothScrolling error:', error);
 }
 };

 // Accessibility fixes
 const initAccessibilityFixes = () => {
 try {
 const buttons = $$('button');
 buttons.forEach(button => {
 if (!button.textContent.trim() && !button.hasAttribute('aria-label')) {
 button.setAttribute('aria-label', 'Button');
 }
 });

 const externalLinks = $$('a[href^="http"]');
 externalLinks.forEach(link => {
 if (!link.hasAttribute('target')) {
 link.setAttribute('target', '_blank');
 link.setAttribute('rel', 'noopener noreferrer');
 }
 });
 } catch (error) {
 console.error('initAccessibilityFixes error:', error);
 }
 };

 // Navigation click logging placeholder
 const initNavClickLogging = () => {
 try {
 const nav = $('#main-nav');
 if (!nav) return;

 nav.addEventListener('click', e => {
 const link = e.target.closest('a.nav-link');
 if (!link) return;
 // Placeholder for analytics integration
 // console.log('Nav click:', link.href);
 });
 } catch (error) {
 console.error('initNavClickLogging error:', error);
 }
 };

 document.addEventListener('DOMContentLoaded', () => {
 initMobileNavToggle();
 highlightActiveNavLink();
 createLightbox();
 initGallery();
 enhanceFormsValidation();
 initSmoothScrolling();
 initAccessibilityFixes();
 initNavClickLogging();
 });

})();

//# sourceURL=gallery.js
