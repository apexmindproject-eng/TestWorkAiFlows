/*
 * main.js - Core functionality for Xodus Studios website
 * Handles navigation, theme toggling, active link highlighting,
 * global interactive features and utility functions.
 * Written in modern ES6+, production-ready with event delegation and error handling.
 */

(() => {
  'use strict';

  // Cached DOM elements for performance
  let navContainer = null;
  let navToggleBtn = null;
  let navList = null;
  let htmlElement = null;

  /**
   * Utility: Safely query selector
   * @param {string} selector 
   * @param {HTMLElement} [parent=document] 
   * @returns {HTMLElement|null}
   */
  const qs = (selector, parent = document) => {
    try {
      return parent.querySelector(selector);
    } catch (e) {
      console.error(`Invalid selector: ${selector}`, e);
      return null;
    }
  };
/**
   * Utility: Safely query selector all
   * @param {string} selector
   * @param {HTMLElement} [parent=document]
   * @returns {NodeListOf<Element>} 
   */
  const qsa = (selector, parent = document) => {
    try {
      return parent.querySelectorAll(selector);
    } catch (e) {
      console.error(`Invalid selector: ${selector}`, e);
      return [];
    }
  };

  /**
   * Handle mobile navigation toggle button click
   * Adds/removes 'open' class to nav container and toggles aria-expanded
   */
  const handleNavToggle = () => {
    if (!navContainer || !navToggleBtn) return;
    const isOpen = navContainer.classList.contains('open');
    if (isOpen) {
      navContainer.classList.remove('open');
      navToggleBtn.setAttribute('aria-expanded', 'false');
    } else {
      navContainer.classList.add('open');
      navToggleBtn.setAttribute('aria-expanded', 'true');
    }
  };
/**
   * Sets the active navigation link based on current location pathname
   * Removes active class from others
   * Supports relative urls in href attribute
   */
  const setActiveNavLink = () => {
    if (!navList) return;
    const links = navList.querySelectorAll('a.nav-link');
    if (!links) return;

    const currentPath = window.location.pathname.split('/').pop() || 'index.html';

    links.forEach(link => {
      const hrefPath = link.getAttribute('href');
      if (!hrefPath) return;

      // Normalize paths for comparison
      const linkPath = hrefPath.split('/').pop();

      if (linkPath === currentPath) {
        link.classList.add('active');
      } else {
        link.classList.remove('active');
      }
    });
  };

  /**
   * Close mobile menu if click outside navigation when open
   * Improves UX/mobile navigation behavior
   * @param {Event} e 
   */
  const handleOutsideClick = e => {
    if (!navContainer || !navToggleBtn) return;
if (!navContainer.classList.contains('open')) return; // Menu not open

    // If click target is outside nav container and toggle button, close menu
    if (!navContainer.contains(e.target) && e.target !== navToggleBtn) {
      navContainer.classList.remove('open');
      navToggleBtn.setAttribute('aria-expanded', 'false');
    }
  };

  /**
   * Handles keyboard navigation accessibility for mobile menu
   * Specifically allows ESC key to close mobile nav if open
   * @param {KeyboardEvent} e 
   */
  const handleKeydown = e => {
    if (!navContainer) return;

    if (e.key === 'Escape' && navContainer.classList.contains('open')) {
      navContainer.classList.remove('open');
      if (navToggleBtn) navToggleBtn.setAttribute('aria-expanded', 'false');
      navToggleBtn?.focus();
    }
  };
/**
   * Initialize Mobile Navigation Toggle: 
   * Create toggle button if not present and set event listeners
   */
  const initMobileNavigation = () => {
    navContainer = qs('#main-nav');
    if (!navContainer) {
      console.warn('Navigation container (#main-nav) not found');
      return;
    }

    // Check if toggle button already exists
    navToggleBtn = qs('.nav-toggle-btn', navContainer);

    if (!navToggleBtn) {
      // Create mobile nav toggle button
      navToggleBtn = document.createElement('button');
      navToggleBtn.className = 'nav-toggle-btn';
      navToggleBtn.setAttribute('aria-label', 'Toggle navigation menu');
      navToggleBtn.setAttribute('aria-expanded', 'false');
      navToggleBtn.setAttribute('aria-controls', 'main-nav-list');

      // Typically a hamburger icon
      navToggleBtn.innerHTML = `
        <span class="hamburger-bar"></span>
        <span class="hamburger-bar"></span>
        <span class="hamburger-bar"></span>
      `;
// Insert toggle button before nav list
      navList = qs('.nav-list', navContainer);
      if (navList) {
        navList.id = 'main-nav-list';
        navContainer.insertBefore(navToggleBtn, navList);
      } else {
        navContainer.appendChild(navToggleBtn);
      }
    } else {
      navList = qs('.nav-list', navContainer);
      if (navList && !navList.id) {
        navList.id = 'main-nav-list';
      }
    }

    // Attach click listener to toggle button
    navToggleBtn.addEventListener('click', handleNavToggle);

    // Attach listeners for accessibility and closing menu
    document.addEventListener('click', handleOutsideClick);
    document.addEventListener('keydown', handleKeydown);
  };

  /**
   * Theme toggle using a button or automatic from stored preference
   * Here as placeholder for possible future enhancement
   * Currently, theme is set in body class
   */
  const applyStoredTheme = () => {
    try {
      const storedTheme = localStorage.getItem('xodus-theme');
      if (!storedTheme) return;

      htmlElement = qs('body');
      if (!htmlElement) return;

      if (storedTheme === 'dark') {
        htmlElement.classList.add('dark-theme');
        htmlElement.classList.remove('light-theme');
      } else if (storedTheme === 'light') {
        htmlElement.classList.add('light-theme');
        htmlElement.classList.remove('dark-theme');
      }
    } catch (e) {
      console.error('Error applying stored theme', e);
    }
  };
/**
   * Initialize Global Event Delegation for buttons with .btn-primary that may have interactive functionality
   * Example: Alert or simple purchase button handler for merch buy buttons
   * @param {Event} e
   */
  const handleGlobalButtonClicks = e => {
    try {
      if (!e.target) return;

      // Handle purchase buttons from merch page (class merch-purchase-btn)
      if (e.target.classList.contains('merch-purchase-btn')) {
        e.preventDefault();
        // Simulate purchase flow
        alert('Thank you for your interest! Purchasing functionality coming soon.');
      }

      // Handle explore project button on index (btn-primary)
      if (e.target.matches('a.btn-primary[href="projects.html"]')) {
        // Navigation handled by default anchor, but could do additional analytics here
        console.log('Navigating to projects page');
      }
    } catch (err) {
      console.error('Error handling button click event', err);
    }
  };
/**
   * Init User Accessibility Focus Ring visibility
   * Shows focus outlines only if user is navigating via keyboard
   * Hides outlines if user is using mouse
   * Improves UI polish
   */
  const initFocusRing = () => {
    let hadKeyboardEvent = false;

    document.body.classList.add('using-mouse');

    const handleKeyDown = e => {
      if (e.key === 'Tab' || e.key === 'Shift') {
        hadKeyboardEvent = true;
        document.body.classList.remove('using-mouse');
      }
    };

    const handleMouseDown = () => {
      if (hadKeyboardEvent) {
        hadKeyboardEvent = false;
        document.body.classList.add('using-mouse');
      }
    };

    document.addEventListener('keydown', handleKeyDown, true);
    document.addEventListener('mousedown', handleMouseDown, true);
  };

  /**
   * Main initializer run on DOMContentLoaded
   */
  const main = () => {
    try {
      initMobileNavigation();
      setActiveNavLink();
      applyStoredTheme();
      initFocusRing();

      // Global event delegation for interactive elements
      document.body.addEventListener('click', handleGlobalButtonClicks);

      console.log('main.js initialization complete');
    } catch (error) {
      console.error('Error during main.js initialization:', error);
    }
  };

  // Attaching main to DOMContentLoaded
  document.addEventListener('DOMContentLoaded', main);

})();

//# sourceURL=main.js