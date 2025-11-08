// gallery.js - Manages the Donut Delights gallery and related interactive UI elements

(() => {
 'use strict';

 /**
 * Checks if an element is a valid HTMLElement
 * @param {any} el
 * @returns {boolean}
 */
 const isValidElement = (el) => el instanceof HTMLElement;

 /**
 * Lightbox Overlay Elements
 */
 let lightboxOverlay = null;
 let lightboxImage = null;
 let lightboxCaption = null;
 let closeButton = null;
 let nextButton = null;
 let prevButton = null;

 /**
 * Stores images and current index of displayed image
 * @type {Array<HTMLImageElement>}
 */
 let galleryImages = [];
 let currentIndex = 0;

 /**
 * Initialize lightbox elements and inject into DOM
 */
 const initLightboxElements = () => {
 if (document.getElementById('lightbox-overlay')) return; // Already initialized

 lightboxOverlay = document.createElement('div');
 lightboxOverlay.id = 'lightbox-overlay';
 lightboxOverlay.setAttribute('role', 'dialog');
 lightboxOverlay.setAttribute('aria-modal', 'true');
 lightboxOverlay.setAttribute('aria-label', 'Image gallery lightbox');
 lightboxOverlay.style.cssText = `
 position: fixed;
 top: 0; left: 0; right: 0; bottom: 0;
 background: rgba(0,0,0,0.8);
 display: none;
 justify-content: center;
 align-items: center;
 z-index: 9999;
 flex-direction: column;
 `;

 // Image container
 const imgContainer = document.createElement('div');
 imgContainer.style.cssText = 'position: relative; max-width: 90vw; max-height: 80vh;';

 lightboxImage = document.createElement('img');
 lightboxImage.id = 'lightbox-image';
 lightboxImage.style.cssText = 'max-width: 100%; max-height: 100%; border-radius: 8px;';
 lightboxImage.setAttribute('alt', '');

 lightboxCaption = document.createElement('div');
 lightboxCaption.id = 'lightbox-caption';
 lightboxCaption.style.cssText = `
 color: #fff;
 text-align: center;
 margin-top: 10px;
 font-size: 1.2rem;
 max-width: 90vw;
 word-wrap: break-word;
 `;

 // Close button
 closeButton = document.createElement('button');
 closeButton.id = 'lightbox-close';
 closeButton.setAttribute('aria-label', 'Close gallery');
 closeButton.textContent = '\u2715'; // Multiplication sign
 closeButton.style.cssText = `
 position: absolute;
 top: 10px;
 right: 10px;
 font-size: 2rem;
 color: #fff;
 background: transparent;
 border: none;
 cursor: pointer;
 `;

 // Next button
 nextButton = document.createElement('button');
 nextButton.id = 'lightbox-next';
 nextButton.setAttribute('aria-label', 'Next image');
 nextButton.innerHTML = '&#9654;'; // Right arrow
 nextButton.style.cssText = `
 position: absolute;
 top: 50%;
 right: 20px;
 font-size: 2rem;
 color: #fff;
 background: transparent;
 border: none;
 cursor: pointer;
 transform: translateY(-50%);
 user-select: none;
 `;

 // Prev button
 prevButton = document.createElement('button');
 prevButton.id = 'lightbox-prev';
 prevButton.setAttribute('aria-label', 'Previous image');
 prevButton.innerHTML = '&#9664;'; // Left arrow
 prevButton.style.cssText = `
 position: absolute;
 top: 50%;
 left: 20px;
 font-size: 2rem;
 color: #fff;
 background: transparent;
 border: none;
 cursor: pointer;
 transform: translateY(-50%);
 user-select: none;
 `;

 imgContainer.appendChild(lightboxImage);
 imgContainer.appendChild(closeButton);
 imgContainer.appendChild(nextButton);
 imgContainer.appendChild(prevButton);
 lightboxOverlay.appendChild(imgContainer);
 lightboxOverlay.appendChild(lightboxCaption);

 document.body.appendChild(lightboxOverlay);
 };

 /**
 * Show the lightbox overlay
 */
 const showLightbox = () => {
 if (!lightboxOverlay) return;
 lightboxOverlay.style.display = 'flex';
 // Trap focus inside
 trapFocus(lightboxOverlay);
 };

 /**
 * Hide the lightbox overlay
 */
 const hideLightbox = () => {
 if (!lightboxOverlay) return;
 lightboxOverlay.style.display = 'none';
 releaseFocusTrap();
 };

 /**
 * Update lightbox content (image and caption) for given index
 * @param {number} index
 */
 const updateLightbox = (index) => {
 if (!galleryImages || galleryImages.length === 0 || !lightboxImage || !lightboxCaption) return;

 currentIndex = (index + galleryImages.length) % galleryImages.length; // wraparound
 const img = galleryImages[currentIndex];

 lightboxImage.src = img.src;
 lightboxImage.alt = img.alt || '';

 // Use figcaption text as caption if available
 const figure = img.closest('figure');
 let captionText = img.alt || '';
 if (figure) {
 const figcaption = figure.querySelector('figcaption');
 if (figcaption && figcaption.textContent.trim() !== '') {
 captionText = figcaption.textContent.trim();
 }
 }
 lightboxCaption.textContent = captionText;
 };

 /**
 * Go to next image
 */
 const nextImage = () => {
 updateLightbox(currentIndex + 1);
 };

 /**
 * Go to previous image
 */
 const prevImage = () => {
 updateLightbox(currentIndex - 1);
 };

 /**
 * Keyboard navigation handler
 * @param {KeyboardEvent} e
 */
 const handleKeyDown = (e) => {
 if (!lightboxOverlay || lightboxOverlay.style.display !== 'flex') return;

 switch (e.key) {
 case 'ArrowRight':
 e.preventDefault();
 nextImage();
 break;
 case 'ArrowLeft':
 e.preventDefault();
 prevImage();
 break;
 case 'Escape':
 e.preventDefault();
 hideLightbox();
 break;
 default:
 break;
 }
 };

 /**
 * Focus trap implementation for accessibility inside lightbox
 * @param {HTMLElement} container
 */
 let lastFocusedElement = null;
 let focusTrapElements = [];
 const trapFocus = (container) => {
 lastFocusedElement = document.activeElement;

 focusTrapElements = Array.from(container.querySelectorAll('button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])')).filter(el => !el.hasAttribute('disabled') && el.offsetParent !== null);

 if (focusTrapElements.length === 0) return;

 const firstEl = focusTrapElements[0];
 const lastEl = focusTrapElements[focusTrapElements.length - 1];

 // Focus first element
 firstEl.focus();

 container.addEventListener('keydown', handleFocusTrap);

 function handleFocusTrap(event) {
 if (event.key === 'Tab') {
 if (event.shiftKey) { // Shift + Tab
 if (document.activeElement === firstEl) {
 event.preventDefault();
 lastEl.focus();
 }
 } else { // Tab
 if (document.activeElement === lastEl) {
 event.preventDefault();
 firstEl.focus();
 }
 }
 } 
 }
 };

 /**
 * Release focus trap, restore previous focus
 */
 const releaseFocusTrap = () => {
 if (lightboxOverlay) {
 lightboxOverlay.removeEventListener('keydown', handleFocusTrap);
 }
 if (lastFocusedElement) {
 lastFocusedElement.focus();
 }
 };

 /**
 * Initialize gallery images and bind click events
 */
 const initGallery = () => {
 try {
 const gallerySection = document.getElementById('gallery');
 if (!gallerySection) return;

 galleryImages = Array.from(gallerySection.querySelectorAll('img.gallery-image'));
 if (galleryImages.length === 0) return;

 initLightboxElements();

 // Event delegation: listen clicks on gallery images
 gallerySection.addEventListener('click', event => {
 const target = event.target;
 if (!(target instanceof HTMLImageElement)) return;

 const clickedIndex = galleryImages.indexOf(target);
 if (clickedIndex === -1) return;

 updateLightbox(clickedIndex);
 showLightbox();
 });

 // Bind controls
 closeButton.addEventListener('click', () => {
 hideLightbox();
 });

 nextButton.addEventListener('click', () => {
 nextImage();
 });

 prevButton.addEventListener('click', () => {
 prevImage();
 });

 // Clicking overlay background closes lightbox
 lightboxOverlay.addEventListener('click', (event) => {
 if (event.target === lightboxOverlay) {
 hideLightbox();
 }
 });

 // Keyboard navigation
 document.addEventListener('keydown', handleKeyDown);

 } catch (error) {
 // eslint-disable-next-line no-console
 console.error('Failed to initialize gallery:', error);
 }
 };

 /**
 * On DOM ready initialize gallery if exists
 */
 document.addEventListener('DOMContentLoaded', () => {
 initGallery();
 });

})();

/*
 Notes:
 - This script targets the gallery on the gallery.html page.
 - Provides lightbox modal functionality for viewing gallery images.
 - Supports keyboard navigation (Arrow keys, Escape) for accessibility.
 - Implements focus trap within the lightbox for better accessibility.
 - Closes modal when clicking outside the image or pressing Escape.
 - Uses event delegation for efficiency.
 - Defensive coding with error handling to prevent script failures.
*/