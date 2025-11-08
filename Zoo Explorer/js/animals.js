// animals.js - Interactive features focused on animal-related content across Zoo Explorer website

(() => {
 'use strict';

 // Cache commonly used elements
 const body = document.body;

 /**
 * Utility function to check if element is HTMLElement
 * @param {*} el
 * @returns {boolean}
 */
 const isValidElement = (el) => el instanceof HTMLElement;

 /**
 * Interactive Animal Cards Expansion
 * On pages where animal cards have more detailed info,
 * allow expanding/collapsing additional content for better UX.
 * 
 * The HTML does not show explicit extra detail sections,
 * so we build optional toggling for future extensibility.
 */
 const initAnimalCardToggles = () => {
 try {
 // Animal cards with class 'animal-card', looking for toggle triggers
 const animalGrid = document.getElementById('animal-list');
 if (!isValidElement(animalGrid)) return;

 // If no children or cards, skip
 const cards = animalGrid.querySelectorAll('.animal-card');
 if (!cards || cards.length === 0) return;

 // We will create a toggle button inside each card if it has extra details
 cards.forEach(card => {
 // Check if already has toggle button to avoid duplicating
 if (card.querySelector('.expand-toggle')) return;

 // Ideally hidden content marked with .extra-info
 const extraInfo = card.querySelector('.extra-info');
 if (extraInfo) {
 // Create button
 const toggleBtn = document.createElement('button');
 toggleBtn.type = 'button';
 toggleBtn.className = 'expand-toggle';
 toggleBtn.setAttribute('aria-expanded', 'false');
 toggleBtn.setAttribute('aria-controls', extraInfo.id || '');
 toggleBtn.textContent = 'More info';
 toggleBtn.style.marginTop = '0.5rem';

 card.appendChild(toggleBtn);

 // Hide extra info initially
 extraInfo.style.display = 'none';

 toggleBtn.addEventListener('click', () => {
 const expanded = toggleBtn.getAttribute('aria-expanded') === 'true';
 toggleBtn.setAttribute('aria-expanded', String(!expanded));
 toggleBtn.textContent = expanded ? 'More info' : 'Less info';
 extraInfo.style.display = expanded ? 'none' : 'block';
 });
 }
 });
 } catch (error) {
 // eslint-disable-next-line no-console
 console.error('Error initializing animal card toggles:', error);
 }
 };

 /**
 * Deep linking to animal by hash (e.g., #lion)
 * Scrolls smoothly to animal card and highlights it briefly
 */
 const scrollToAnimalFromHash = () => {
 try {
 if (!window.location.hash) return;
 const id = window.location.hash.substring(1);
 if (!id) return;

 const element = document.getElementById(id);
 if (!isValidElement(element)) return;

 // Scroll smoothly to element
 element.scrollIntoView({ behavior: 'smooth', block: 'start' });

 // Temporarily highlight the element
 element.classList.add('highlighted');
 setTimeout(() => {
 element.classList.remove('highlighted');
 }, 3000);
 } catch (error) {
 // eslint-disable-next-line no-console
 console.error('Error scrolling to animal from hash:', error);
 }
 };

 /**
 * Drag to scroll animal grid if exists
 * Allows click and drag horizontally to scroll animal grid
 * Useful on smaller screens or dense grids
 */
 const initAnimalGridDragScroll = () => {
 try {
 const animalGrid = document.getElementById('animal-list');
 if (!isValidElement(animalGrid)) return;

 let isDown = false;
 let startX;
 let scrollLeft;

 animalGrid.style.cursor = 'grab';

 animalGrid.addEventListener('mousedown', e => {
 isDown = true;
 animalGrid.classList.add('active');
 startX = e.pageX - animalGrid.offsetLeft;
 scrollLeft = animalGrid.scrollLeft;
 animalGrid.style.cursor = 'grabbing';
 e.preventDefault();
 });

 animalGrid.addEventListener('mouseleave', () => {
 isDown = false;
 animalGrid.classList.remove('active');
 animalGrid.style.cursor = 'grab';
 });

 animalGrid.addEventListener('mouseup', () => {
 isDown = false;
 animalGrid.classList.remove('active');
 animalGrid.style.cursor = 'grab';
 });

 animalGrid.addEventListener('mousemove', e => {
 if (!isDown) return;
 e.preventDefault();
 const x = e.pageX - animalGrid.offsetLeft;
 const walk = (x - startX) * 3; //scroll-fast
 animalGrid.scrollLeft = scrollLeft - walk;
 });

 // Touch events for mobile
 let touchStartX = 0;
 let touchScrollLeft = 0;

 animalGrid.addEventListener('touchstart', e => {
 touchStartX = e.touches[0].pageX - animalGrid.offsetLeft;
 touchScrollLeft = animalGrid.scrollLeft;
 });

 animalGrid.addEventListener('touchmove', e => {
 const x = e.touches[0].pageX - animalGrid.offsetLeft;
 const walk = (x - touchStartX) * 3;
 animalGrid.scrollLeft = touchScrollLeft - walk;
 });
 } catch (error) {
 // eslint-disable-next-line no-console
 console.error('Error initializing animal grid drag scroll:', error);
 }
 };

 /**
 * Image lazy loading enhancement
 * Uses IntersectionObserver to lazy-load animal images
 * falls back gracefully if unsupported
 */
 const initLazyLoadingImages = () => {
 try {
 const images = document.querySelectorAll('img.animal-image[data-src]');
 if (images.length === 0) return;

 if ('IntersectionObserver' in window) {
 const observer = new IntersectionObserver((entries, obs) => {
 entries.forEach(entry => {
 if (entry.isIntersecting) {
 const img = entry.target;
 const src = img.getAttribute('data-src');
 if (src) {
 img.src = src;
 img.removeAttribute('data-src');
 }
 obs.unobserve(img);
 }
 });
 }, {rootMargin: '50px 0px', threshold: 0.01});

 images.forEach(img => observer.observe(img));
 } else {
 // Fallback: load all images immediately
 images.forEach(img => {
 const src = img.getAttribute('data-src');
 if (src) img.src = src;
 img.removeAttribute('data-src');
 });
 }
 } catch (error) {
 // eslint-disable-next-line no-console
 console.error('Error initializing lazy loading images:', error);
 }
 };

 /**
 * Accessibility: Provide keyboard navigation for animal cards
 * Adds tabindex and keyboard focus styles to cards
 * Supports Enter and Space to simulate clicking Explore More
 */
 const initKeyboardAccessibilityOnCards = () => {
 try {
 const animalGrid = document.getElementById('animal-list');
 if (!isValidElement(animalGrid)) return;

 const cards = animalGrid.querySelectorAll('.animal-card');
 if (cards.length === 0) return;

 cards.forEach(card => {
 card.setAttribute('tabindex', '0'); // Make focusable

 card.addEventListener('keydown', e => {
 if (e.key === 'Enter' || e.key === ' ') {
 e.preventDefault();
 // Trigger first .button-link inside card if exists
 const link = card.querySelector('.button-link');
 if (link && typeof link.click === 'function') {
 link.click();
 }
 }
 });
 });
 } catch (error) {
 // eslint-disable-next-line no-console
 console.error('Error initializing keyboard accessibility on animal cards:', error);
 }
 };

 /**
 * Validation helper: Logs warnings if any animal images missing alt text
 * Useful to maintain accessibility standards
 */
 const validateAnimalImageAlts = () => {
 try {
 if (!['localhost', '127.0.0.1'].includes(window.location.hostname)) return;
 const images = document.querySelectorAll('img.animal-image');
 images.forEach(img => {
 if (!img.hasAttribute('alt') || img.getAttribute('alt').trim() === '') {
 // eslint-disable-next-line no-console
 console.warn('Animal image missing alt attribute or empty alt:', img);
 }
 });
 } catch (error) {
 // eslint-disable-next-line no-console
 console.error('Error validating animal image alts:', error);
 }
 };

 /**
 * Initialize all animal related scripts on page load
 */
 const initAnimals = () => {
 initAnimalCardToggles();
 scrollToAnimalFromHash();
 initAnimalGridDragScroll();
 initLazyLoadingImages();
 initKeyboardAccessibilityOnCards();
 validateAnimalImageAlts();
 };

 document.addEventListener('DOMContentLoaded', () => {
 initAnimals();
 });

})();

/*
 NOTES:
 - The animals.js script focuses on interactive features related to animal cards and content.
 - Supports expandable cards if extra info present, enhancing UX for deeper content.
 - Smooth scroll and highlight feature enables hash navigation to specific animals.
 - Enables drag-scroll on animal grid for desktop and touch devices.
 - Adds keyboard accessibility allowing cards to be selected and activated via keyboard.
 - Lazy loading images improve performance, falling back gracefully.
 - Image alt attribute validations aid accessibility compliance during development.
 - Defensive programming with try/catch to prevent crashes on any page.
 - Modular and maintainable for easy enhancement and debugging.
*/