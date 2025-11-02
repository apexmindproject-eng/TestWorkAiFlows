// slider.js - Handles interactive sliders or technique displays for USDA Kenpo Karate site

(() => {
 'use strict';

 // Since no explicit slider markup found in HTML, this script will enable a general "techniques slider" feature
 // for the #featured-techniques section on index.html and also provide utility functions for similar
 // interactive slider/carousel functionality on other pages if added later.

 // Cache selectors for slider components
 const domCache = {
 sliderContainer: null,
 slides: [],
 currentIndex: 0,
 sliderTrack: null,
 prevBtn: null,
 nextBtn: null,
 slideCount: 0,
 autoSlideInterval: null,
 };

 // Configuration
 const config = {
 autoSlideDelay: 5000,
 transitionDuration: 500, // ms
 };

 /**
 * Initialize slider: find slider container, slides, set up controls
 */
 const initSlider = () => {
 try {
 domCache.sliderContainer = document.getElementById('featured-techniques');
 if (!domCache.sliderContainer) return; // No slider on this page

 // Find slides container
 // We expect .techniques-container div contains .technique-item elements
 domCache.sliderTrack = domCache.sliderContainer.querySelector('.techniques-container');
 if (!domCache.sliderTrack) return;

 domCache.slides = Array.from(domCache.sliderTrack.children).filter(child => child.classList.contains('technique-item'));
 domCache.slideCount = domCache.slides.length;
 if (domCache.slideCount === 0) return;

 domCache.currentIndex = 0;

 // Create controls if not present
 createControls();
 setupAccessibility();
 updateSliderPosition();
 addEventListeners();
 startAutoSlide();
 setupResizeObserver();

 } catch (error) {
 console.error('Error initializing slider:', error);
 }
 };

 /**
 * Create prev / next buttons if missing
 */
 const createControls = () => {
 try {
 domCache.prevBtn = domCache.sliderContainer.querySelector('.slider-prev');
 domCache.nextBtn = domCache.sliderContainer.querySelector('.slider-next');

 if (!domCache.prevBtn) {
 domCache.prevBtn = document.createElement('button');
 domCache.prevBtn.className = 'slider-prev';
 domCache.prevBtn.setAttribute('aria-label', 'Previous technique');
 domCache.prevBtn.textContent = '‹';
 domCache.sliderContainer.appendChild(domCache.prevBtn);
 }

 if (!domCache.nextBtn) {
 domCache.nextBtn = document.createElement('button');
 domCache.nextBtn.className = 'slider-next';
 domCache.nextBtn.setAttribute('aria-label', 'Next technique');
 domCache.nextBtn.textContent = '›';
 domCache.sliderContainer.appendChild(domCache.nextBtn);
 }
 } catch (error) {
 console.error('Error creating slider controls:', error);
 }
 };

 /**
 * Setup ARIA roles, tab order for accessibility
 */
 const setupAccessibility = () => {
 try {
 if (!domCache.sliderTrack) return;
 domCache.sliderContainer.setAttribute('role', 'region');
 domCache.sliderContainer.setAttribute('aria-label', 'Featured Kenpo Karate techniques slider');
 domCache.sliderTrack.setAttribute('role', 'list');

 domCache.slides.forEach((slide, index) => {
 slide.setAttribute('role', 'listitem');
 slide.setAttribute('aria-hidden', index === domCache.currentIndex ? 'false' : 'true');
 slide.tabIndex = index === domCache.currentIndex ? 0 : -1;
 });

 if (domCache.prevBtn) {
 domCache.prevBtn.tabIndex = 0;
 }

 if (domCache.nextBtn) {
 domCache.nextBtn.tabIndex = 0;
 }
 } catch (error) {
 console.error('Error setting up slider accessibility:', error);
 }
 };

 /**
 * Update slider position (translateX) to show the current slide
 * Supports horizontal sliding. For two items, we center and slide accordingly.
 */
 const updateSliderPosition = () => {
 try {
 if (!domCache.sliderTrack) return;

 const slideWidth = domCache.slides[0].offsetWidth || 0;

 // Calculate translateX value
 // Only slide full slide widths. Show all slides horizontally in row.
 // For multiple slides, show all in a row with horizontal scroll or slide

 // For simplicity, we horizontally translate the slides container:
 const offset = -domCache.currentIndex * slideWidth;

 domCache.sliderTrack.style.transition = `transform ${config.transitionDuration}ms ease`;
 domCache.sliderTrack.style.transform = `translateX(${offset}px)`;

 // Update aria-hidden and tabindex for slides
 domCache.slides.forEach((slide, idx) => {
 if (idx === domCache.currentIndex) {
 slide.setAttribute('aria-hidden', 'false');
 slide.tabIndex = 0;
 } else {
 slide.setAttribute('aria-hidden', 'true');
 slide.tabIndex = -1;
 }
 });
 } catch (error) {
 console.error('Error updating slider position:', error);
 }
 };

 /**
 * Move to next slide wrapping around
 */
 const goToNextSlide = () => {
 domCache.currentIndex = (domCache.currentIndex + 1) % domCache.slideCount;
 updateSliderPosition();
 };

 /**
 * Move to previous slide wrapping around
 */
 const goToPrevSlide = () => {
 domCache.currentIndex = (domCache.currentIndex - 1 + domCache.slideCount) % domCache.slideCount;
 updateSliderPosition();
 };

 /**
 * Start automatic sliding with interval
 */
 const startAutoSlide = () => {
 if (domCache.autoSlideInterval) {
 clearInterval(domCache.autoSlideInterval);
 }
 domCache.autoSlideInterval = setInterval(goToNextSlide, config.autoSlideDelay);
 };

 /**
 * Stop automatic sliding
 */
 const stopAutoSlide = () => {
 if (domCache.autoSlideInterval) {
 clearInterval(domCache.autoSlideInterval);
 domCache.autoSlideInterval = null;
 }
 };

 /**
 * Add event listeners for controls and pause on hover/focus
 */
 const addEventListeners = () => {
 try {
 if (domCache.prevBtn) {
 domCache.prevBtn.addEventListener('click', () => {
 goToPrevSlide();
 stopAutoSlide();
 startAutoSlide();
 });
 }

 if (domCache.nextBtn) {
 domCache.nextBtn.addEventListener('click', () => {
 goToNextSlide();
 stopAutoSlide();
 startAutoSlide();
 });
 }

 // Pause auto slide on mouse enter & focus
 domCache.sliderContainer.addEventListener('mouseenter', stopAutoSlide);
 domCache.sliderContainer.addEventListener('mouseleave', startAutoSlide);

 domCache.sliderContainer.addEventListener('focusin', stopAutoSlide);
 domCache.sliderContainer.addEventListener('focusout', startAutoSlide);

 // Keyboard navigation for slider
 domCache.sliderContainer.addEventListener('keydown', (e) => {
 if (e.key === 'ArrowRight') {
 e.preventDefault();
 goToNextSlide();
 stopAutoSlide();
 startAutoSlide();
 } else if (e.key === 'ArrowLeft') {
 e.preventDefault();
 goToPrevSlide();
 stopAutoSlide();
 startAutoSlide();
 }
 });
 } catch (error) {
 console.error('Error adding slider event listeners:', error);
 }
 };

 /**
 * Handle window resize to update slide dimensions
 */
 const handleResize = debounce(() => {
 updateSliderPosition();
 }, 200);

 /**
 * Setup resize observer or window resize listener
 */
 const setupResizeObserver = () => {
 try {
 if ('ResizeObserver' in window && domCache.sliderContainer) {
 const resizeObserver = new ResizeObserver(handleResize);
 resizeObserver.observe(domCache.sliderContainer);
 } else {
 window.addEventListener('resize', handleResize);
 }
 } catch (error) {
 console.error('Error setting up resize observer:', error);
 }
 };

 // Initialize slider on DOMContentLoaded
 document.addEventListener('DOMContentLoaded', () => {
 initSlider();
 });

})();

//# sourceURL=slider.js
