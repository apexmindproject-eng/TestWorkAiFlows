// gallery.js - Image gallery and lightbox functionalities for Zoo Explorer

// Utility functions
const GalleryUtils = {
 // Safe querySelector
 qs: (selector, scope = document) => {
 try {
 return scope.querySelector(selector);
 } catch (e) {
 console.error(`GalleryUtils: Invalid selector ${selector}`, e);
 return null;
 }
 },

 // Safe querySelectorAll
 qsa: (selector, scope = document) => {
 try {
 return Array.from(scope.querySelectorAll(selector));
 } catch (e) {
 console.error(`GalleryUtils: Invalid selector ${selector}`, e);
 return [];
 }
 },

 // Trap focus within specified element for accessibility
 trapFocus: (element) => {
 if (!element) return;

 const focusableSelectors = [
 'a[href]:not([disabled])',
 'area[href]:not([disabled])',
 'input:not([disabled]):not([type="hidden"])',
 'select:not([disabled])',
 'textarea:not([disabled])',
 'button:not([disabled])',
 'iframe',
 'object',
 'embed',
 '[tabindex]:not([tabindex="-1"])',
 '[contenteditable]'
 ];
 const focusableElements = element.querySelectorAll(focusableSelectors.join(','));
 if (!focusableElements.length) return;

 const firstFocusable = focusableElements[0];
 const lastFocusable = focusableElements[focusableElements.length - 1];

 function handleTrap(e) {
 if (e.key !== 'Tab') return;

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

 element.addEventListener('keydown', handleTrap);

 // Return function to remove listener
 return () => element.removeEventListener('keydown', handleTrap);
 },

 // Create element with attributes
 createEl: (tag, options = {}) => {
 const el = document.createElement(tag);
 Object.entries(options).forEach(([key, value]) => {
 if (key === 'className') el.className = value;
 else if (key === 'textContent') el.textContent = value;
 else if (key === 'innerHTML') el.innerHTML = value;
 else el.setAttribute(key, value);
 });
 return el;
 }
};

// Lightbox module for image galleries
const Lightbox = (() => {
 let overlay = null;
 let imageContainer = null;
 let captionEl = null;
 let btnPrev = null;
 let btnNext = null;
 let btnClose = null;
 let currentIndex = 0;
 let images = [];
 let removeTrapFocusListener = null;

 // Create lightbox elements
 const createLightbox = () => {
 overlay = GalleryUtils.createEl('div', { className: 'lightbox-overlay', 'aria-hidden': 'true', role: 'dialog', 'aria-modal': 'true' });
 overlay.style.cssText = 'position:fixed;top:0;left:0;width:100vw;height:100vh;background:rgba(0,0,0,0.8);display:flex;justify-content:center;align-items:center;z-index:9999;visibility:hidden;opacity:0;transition:opacity 0.3s ease;';

 imageContainer = GalleryUtils.createEl('div', { className: 'lightbox-content' });
 imageContainer.style.cssText = 'position:relative;max-width:90vw;max-height:90vh;';

 captionEl = GalleryUtils.createEl('div', { className: 'lightbox-caption', role: 'document' });
 captionEl.style.cssText = 'color:#fff;text-align:center;margin-top:10px;font-size:1rem;';

 btnClose = GalleryUtils.createEl('button', { className: 'lightbox-close', 'aria-label': 'Close lightbox' });
 btnClose.innerHTML = '&#x2715;'; // Cross mark
 btnClose.style.cssText = 'position:absolute;top:10px;right:10px;background:none;border:none;color:#fff;font-size:2rem;cursor:pointer;';

 btnPrev = GalleryUtils.createEl('button', { className: 'lightbox-prev', 'aria-label': 'Previous image' });
 btnPrev.innerHTML = '&#10094;'; // Left arrow
 btnPrev.style.cssText = 'position:absolute;top:50%;left:10px;transform:translateY(-50%);background:none;border:none;color:#fff;font-size:3rem;cursor:pointer;';

 btnNext = GalleryUtils.createEl('button', { className: 'lightbox-next', 'aria-label': 'Next image' });
 btnNext.innerHTML = '&#10095;'; // Right arrow
 btnNext.style.cssText = 'position:absolute;top:50%;right:10px;transform:translateY(-50%);background:none;border:none;color:#fff;font-size:3rem;cursor:pointer;';

 imageContainer.appendChild(btnClose);
 imageContainer.appendChild(btnPrev);
 imageContainer.appendChild(btnNext);
 overlay.appendChild(imageContainer);
 overlay.appendChild(captionEl);

 document.body.appendChild(overlay);

 // Event listeners
 btnClose.addEventListener('click', closeLightbox);
 btnPrev.addEventListener('click', () => showPrev());
 btnNext.addEventListener('click', () => showNext());
 overlay.addEventListener('click', (e) => {
 if (e.target === overlay) closeLightbox();
 });

 // Keyboard navigation
 document.addEventListener('keydown', handleKeydown);
 };

 // Remove lightbox and listeners
 const destroyLightbox = () => {
 if (!overlay) return;
 document.removeEventListener('keydown', handleKeydown);
 if (removeTrapFocusListener) {
 removeTrapFocusListener();
 removeTrapFocusListener = null;
 }
 overlay.remove();
 overlay = null;
 };

 // Show lightbox
 const openLightbox = (index) => {
 if (!overlay) createLightbox();
 images = GalleryUtils.qsa('.animal-gallery .animal-image, .animal-list .animal-image');
 if (!images.length) images = [];

 if (index < 0 || index >= images.length) {
 index = 0;
 }
 currentIndex = index;
 updateLightboxContent();
 overlay.style.visibility = 'visible';
 overlay.style.opacity = '1';
 overlay.setAttribute('aria-hidden', 'false');

 // Trap focus inside lightbox
 removeTrapFocusListener = GalleryUtils.trapFocus(overlay);

 // Set initial focus
 btnClose.focus();
 };

 // Close lightbox
 const closeLightbox = () => {
 if (!overlay) return;
 overlay.style.opacity = '0';
 overlay.setAttribute('aria-hidden', 'true');
 setTimeout(() => {
 if (overlay) {
 overlay.style.visibility = 'hidden';
 }
 destroyLightbox();
 }, 300);

 // Return focus to last focused image
 if (lastFocusedImage) {
 lastFocusedImage.focus();
 }
 };

 // Update displayed image and caption
 const updateLightboxContent = () => {
 if (!overlay || !images.length) return;
 // Clear previous image
 while (imageContainer.firstChild && imageContainer.firstChild !== btnClose && imageContainer.firstChild !== btnPrev && imageContainer.firstChild !== btnNext) {
 imageContainer.removeChild(imageContainer.firstChild);
 }

 const currentImage = images[currentIndex];
 if (!currentImage) return;

 // Clone image for lightbox display
 const imgClone = currentImage.cloneNode(true);
 imgClone.style.width = '100%';
 imgClone.style.height = 'auto';
 imgClone.className = 'lightbox-image';
 imgClone.setAttribute('tabindex', '-1');
 imageContainer.insertBefore(imgClone, btnClose);

 // Set caption text from alt attribute and nearby text if available
 let captionText = currentImage.alt || '';

 // Try to get animal name or description nearby
 let animalName = '';
 let description = '';
 const item = currentImage.closest('.animal-item, .animal-card');
 if (item) {
 const nameEl = GalleryUtils.qs('.animal-name', item);
 if (nameEl) {
 animalName = nameEl.textContent.trim();
 }
 const descEl = GalleryUtils.qs('.animal-description', item);
 if (descEl) {
 description = descEl.textContent.trim();
 }
 }

 captionText = `${animalName}` + (description ? ` - ${description}` : '');
 captionEl.textContent = captionText;
 };

 // Show next image
 const showNext = () => {
 if (!images.length) return;
 currentIndex = (currentIndex + 1) % images.length;
 updateLightboxContent();
 };

 // Show previous image
 const showPrev = () => {
 if (!images.length) return;
 currentIndex = (currentIndex - 1 + images.length) % images.length;
 updateLightboxContent();
 };

 // Keyboard controls
 const handleKeydown = (e) => {
 if (!overlay || overlay.getAttribute('aria-hidden') === 'true') return;
 switch (e.key) {
 case 'Escape':
 e.preventDefault();
 closeLightbox();
 break;
 case 'ArrowRight':
 e.preventDefault();
 showNext();
 break;
 case 'ArrowLeft':
 e.preventDefault();
 showPrev();
 break;
 default:
 break;
 }
 };

 // Keep track of last focused image to return focus on close
 let lastFocusedImage = null;

 // Delegate click event on images with animal-image class to open lightbox
 const setupGalleryClick = () => {
 document.body.addEventListener('click', (e) => {
 try {
 const target = e.target;
 if (!target) return;
 if (target.classList.contains('animal-image')) {
 e.preventDefault();

 lastFocusedImage = target;

 const galleryImages = GalleryUtils.qsa('.animal-gallery .animal-image, .animal-list .animal-image');
 const idx = galleryImages.findIndex(img => img === target);
 if (idx >= 0) {
 openLightbox(idx);
 }
 }
 } catch (error) {
 console.error('Error in gallery click handler:', error);
 }
 });
 };

 return {
 init: () => {
 setupGalleryClick();
 }
 };
})();

// Initialize gallery functionalities on DOM content loaded
document.addEventListener('DOMContentLoaded', () => {
 Lightbox.init();
});

//# sourceURL=gallery.js
