// main.js - Core functionality, navigation, and global features for Coffee Lovers website

// Immediately Invoked Function Expression for encapsulation
(() => {
 'use strict';

 // Cache DOM elements used globally
 const domCache = {
 navList: null,
 navToggleBtn: null, // For mobile navigation toggle if any
 navLinks: null,
 mainContent: null,
 heroImage: null,
 };

 // Utility: Safely query a single element
 const getEl = (selector, parent = document) => parent.querySelector(selector);
 const getAllEls = (selector, parent = document) => Array.from(parent.querySelectorAll(selector));

 // Utility: Debounce function for performance optimization
 const debounce = (func, delay = 200) => {
 let timer;
 return (...args) => {
 clearTimeout(timer);
 timer = setTimeout(() => func.apply(this, args), delay);
 };
 };

 // Manage active state on navigation based on current location
 const setActiveNavLink = () => {
 try {
 if (!domCache.navLinks) return;

 const path = window.location.pathname.replace(/\/g, '/');
 // Normalize path to match hrefs
 // Also handle relative paths by comparing last parts
 domCache.navLinks.forEach(link => {
 const href = link.getAttribute('href');
 // Remove query and hash for comparison
 const cleanHref = href ? href.split(/[?#]/)[0] : '';
 const url = new URL(cleanHref, window.location.origin);
 const linkPath = url.pathname.replace(/\/g, '/');

 // Determine if link matches the current path or page
 if (linkPath === path ||
 (linkPath.endsWith('index.html') && path.endsWith('/')) ||
 (path.endsWith(linkPath) && linkPath !== '/')) {
 link.classList.add('current');
 link.setAttribute('aria-current', 'page');
 } else {
 link.classList.remove('current');
 link.removeAttribute('aria-current');
 }
 });
 } catch (error) {
 console.error('Error setting active navigation link:', error);
 }
 };

 // Mobile navigation toggle for responsive menu (if needed)
 const initMobileNavToggle = () => {
 try {
 // Assuming no toggle button markup on instant view, create one if needed
 if (!domCache.navList) return;
 const navContainer = domCache.navList.parentNode;
 if (!navContainer) return;

 // Check if toggle button exists
 let toggleBtn = getEl('.nav-toggle');
 if (!toggleBtn) {
 toggleBtn = document.createElement('button');
 toggleBtn.className = 'nav-toggle';
 toggleBtn.setAttribute('aria-expanded', 'false');
 toggleBtn.setAttribute('aria-label', 'Toggle menu');
 toggleBtn.innerHTML = '<span class="hamburger"></span>';
 navContainer.insertBefore(toggleBtn, domCache.navList);
 }
 domCache.navToggleBtn = toggleBtn;

 toggleBtn.addEventListener('click', () => {
 const expanded = toggleBtn.getAttribute('aria-expanded') === 'true';
 toggleBtn.setAttribute('aria-expanded', String(!expanded));
 domCache.navList.classList.toggle('nav-open');
 });

 // Close menu if link clicked (use event delegation)
 domCache.navList.addEventListener('click', (e) => {
 const target = e.target;
 if (target && target.matches('a.nav-link')) {
 // Close the menu if opened on mobile
 if (domCache.navList.classList.contains('nav-open')) {
 toggleBtn.setAttribute('aria-expanded', 'false');
 domCache.navList.classList.remove('nav-open');
 }
 }
 });

 // Accessibility: close on Escape key
 document.addEventListener('keydown', (e) => {
 if (e.key === 'Escape' && domCache.navList.classList.contains('nav-open')) {
 toggleBtn.setAttribute('aria-expanded', 'false');
 domCache.navList.classList.remove('nav-open');
 toggleBtn.focus();
 }
 });
 } catch (error) {
 console.error('Error initializing mobile navigation toggle:', error);
 }
 };

 // Smooth scrolling for internal links
 const initSmoothScrolling = () => {
 try {
 document.addEventListener('click', (e) => {
 const target = e.target.closest('a[href^="#"]');
 if (!target) return;

 const href = target.getAttribute('href');
 if (href === '#' || href === '') return;

 const targetEl = getEl(href);
 if (targetEl) {
 e.preventDefault();
 targetEl.scrollIntoView({ behavior: 'smooth' });
 // Update focus for accessibility
 targetEl.setAttribute('tabindex', '-1');
 targetEl.focus({ preventScroll: true });
 }
 });
 } catch (error) {
 console.error('Error in smooth scrolling init:', error);
 }
 };

 // Hero image fade-in animation on index.html
 const initHeroImageAnimation = () => {
 try {
 if (!domCache.heroImage) return;
 domCache.heroImage.style.opacity = '0';
 domCache.heroImage.style.transition = 'opacity 1.5s ease-in-out';

 // Use requestAnimationFrame for smoothness
 window.requestAnimationFrame(() => {
 domCache.heroImage.style.opacity = '1';
 });
 } catch (error) {
 console.error('Error initializing hero image animation:', error);
 }
 };

 // Section reveal on scroll for feature sections, about, coffees, methods
 const initScrollReveal = () => {
 try {
 const sections = getAllEls('section, article');
 if (!sections.length) return;

 const revealClass = 'reveal-visible';

 const observer = new IntersectionObserver((entries) => {
 entries.forEach(entry => {
 if (entry.isIntersecting) {
 entry.target.classList.add(revealClass);
 // We can unobserve if reveal only needed once
 observer.unobserve(entry.target);
 }
 });
 }, { rootMargin: '0px 0px -100px 0px', threshold: 0.1 });

 sections.forEach(section => {
 if (!section.classList.contains(revealClass)) {
 observer.observe(section);
 }
 });
 } catch (error) {
 console.error('Error initializing scroll reveal:', error);
 }
 };

 // Keyboard accessibility enhancements for navigation
 const initNavKeyboardAccessibility = () => {
 try {
 if (!domCache.navList) return;
 domCache.navList.addEventListener('keydown', (e) => {
 if (e.key === 'ArrowRight' || e.key === 'ArrowLeft') {
 e.preventDefault();
 const links = domCache.navLinks;
 if (!links || links.length === 0) return;
 const activeElement = document.activeElement;
 let index = links.indexOf(activeElement);
 if (index === -1) return;

 if (e.key === 'ArrowRight') {
 index = (index + 1) % links.length;
 } else if (e.key === 'ArrowLeft') {
 index = (index - 1 + links.length) % links.length;
 }

 links[index].focus();
 }
 });
 } catch (error) {
 console.error('Error initializing navigation keyboard accessibility:', error);
 }
 };

 // Initialize all global features
 const initGlobalFeatures = () => {
 try {
 domCache.navList = getEl('.nav-list');
 if (domCache.navList) {
 domCache.navLinks = getAllEls('.nav-list .nav-link');
 }
 domCache.heroImage = getEl('#hero-image');
 domCache.mainContent = getEl('#main-content');

 setActiveNavLink();
 initMobileNavToggle();
 initSmoothScrolling();
 initScrollReveal();
 initNavKeyboardAccessibility();

 // If on home page, init hero image animation
 if (document.body.id === 'home' && domCache.heroImage) {
 initHeroImageAnimation();
 }

 // Additional page-specific enhancements
 initPageSpecificFeatures();
 } catch (error) {
 console.error('Error initializing global features:', error);
 }
 };

 // Page-specific features or enhancements
 const initPageSpecificFeatures = () => {
 try {
 const bodyId = document.body.id;

 if (bodyId === 'contact-page') {
 // Contact page handled separately in contact-form.js
 // But we can add global keyboard and focus improvements if needed
 } else if (bodyId === 'coffee-types-page') {
 initCoffeeTypesInteractivity();
 } else if (bodyId === 'brewing-methods-page') {
 initBrewingMethodsInteractivity();
 } else if (bodyId === 'about-page') {
 // No explicit interactions detected on about page
 // Could add lazy loading for images if needed
 }
 } catch (error) {
 console.error('Error initializing page-specific features:', error);
 }
 };

 // Coffee Types page - Add toggles to show/hide description paragraphs (progressive enhancement)
 const initCoffeeTypesInteractivity = () => {
 try {
 const coffeeTypeSections = getAllEls('.coffee-type');
 if (coffeeTypeSections.length === 0) return;

 coffeeTypeSections.forEach(section => {
 const header = getEl('h2', section);
 const description = header ? header.nextElementSibling : null;
 if (!header || !description) return;

 description.style.display = 'block'; // default visible

 // Add a toggle button to header for accessibility
 const toggleBtn = document.createElement('button');
 toggleBtn.type = 'button';
 toggleBtn.className = 'toggle-description-btn';
 toggleBtn.setAttribute('aria-expanded', 'true');
 toggleBtn.setAttribute('aria-controls', description.id || '');
 toggleBtn.textContent = 'Hide Description';

 header.appendChild(toggleBtn);

 toggleBtn.addEventListener('click', () => {
 const isVisible = description.style.display !== 'none';
 description.style.display = isVisible ? 'none' : 'block';
 toggleBtn.textContent = isVisible ? 'Show Description' : 'Hide Description';
 toggleBtn.setAttribute('aria-expanded', String(!isVisible));
 });
 });
 } catch (error) {
 console.error('Error initializing coffee types interactivity:', error);
 }
 };

 // Brewing Methods page - Add scrollspy-like highlight on method sections
 const initBrewingMethodsInteractivity = () => {
 try {
 const methodSections = getAllEls('section.method');
 if (methodSections.length === 0) return;

 // Create a side navigation or highlight nav links if present for each method
 // Since nav doesn't link to sections, we can highlight the section title
 const nav = getEl('.main-navigation .nav-list');

 // Map IDs to corresponding nav links or create a small side toc
 // For simplicity, highlight the h2 elements on scroll

 const activeClass = 'method-active';

 const onScroll = () => {
 let currentSectionId = '';
 // Find the section most in viewport
 const scrollPosition = window.scrollY + window.innerHeight / 3;

 methodSections.forEach(section => {
 const rect = section.getBoundingClientRect();
 const top = window.scrollY + rect.top;
 if (scrollPosition >= top) {
 currentSectionId = section.id;
 }
 });

 methodSections.forEach(section => {
 const h2 = getEl('h2', section);
 if (!h2) return;
 if (section.id === currentSectionId) {
 h2.classList.add(activeClass);
 } else {
 h2.classList.remove(activeClass);
 }
 });
 };

 window.addEventListener('scroll', debounce(onScroll, 100));
 // Initial call
 onScroll();
 } catch (error) {
 console.error('Error initializing brewing methods interactivity:', error);
 }
 };

 // Initialization on DOMContentLoaded
 document.addEventListener('DOMContentLoaded', () => {
 initGlobalFeatures();
 });

})();

//# sourceURL=main.js
