/*
 * transitions.js - Handles page transitions, link navigation effects,
 * and smooth fade in/out animations across the entire Xodus Studios website.
 *
 * Ensures seamless navigation with enhanced UX and visual consistency.
 * Implements event delegation, history management, performance optimization,
 * and comprehensive error handling.
 */

(() => {
  'use strict';

  const fadeOutClass = 'fade-out';
  const fadeInClass = 'fade-in';
  const transitionDurationMs = 400; // Match with CSS animation duration

  /**
   * Utility: Adds fade-out class and returns Promise resolved after animation
   * @param {Element} el
   * @returns {Promise<void>}
   */
  const fadeOut = el => {
    return new Promise(resolve => {
      if (!el) {
        resolve();
        return;
      }

      const handleAnimationEnd = e => {
        if (e.target === el) {
          el.removeEventListener('animationend', handleAnimationEnd);
          resolve();
        }
      };

      el.addEventListener('animationend', handleAnimationEnd);
      el.classList.remove(fadeInClass);
      el.classList.add(fadeOutClass);
    });
  };

  /**
   * Utility: Adds fade-in class and removes fade-out class
   * @param {Element} el
   */
  const fadeIn = el => {
    if (!el) return;
    el.classList.remove(fadeOutClass);
    el.classList.add(fadeInClass);
  };

  /**
   * Checks if a link is internal to the website
   * @param {HTMLAnchorElement} link
   * @returns {boolean}
   */
  const isInternalLink = link => {
    if (!link || !link.href) return false;
    const url = new URL(link.href, window.location.origin);
    return url.origin === window.location.origin;
  };
/**
   * Handles link clicks to play transition animation before navigation
   * @param {MouseEvent} e
   */
  const handleLinkClick = async e => {
    try {
      const target = e.target;
      if (!(target instanceof Element)) return;

      // Find closest anchor element (in case nested elements clicked)
      const link = target.closest('a');
      if (!link) return;

      // Ignore if anchor is external, or has target='_blank', download or no href
      if (!isInternalLink(link) || link.target === '_blank' || link.hasAttribute('download') || !link.href) return;

      // Ignore anchor links on current page
      if (link.hash && link.href.split('#')[0] === window.location.href.split('#')[0]) return;

      e.preventDefault();

      const mainContent = document.getElementById('main-content');
      if (!mainContent) {
        window.location.href = link.href; // Fallback
        return;
      }

      await fadeOut(mainContent);

      // Navigate
      window.location.href = link.href;
    } catch (err) {
      console.error('Error on link transition', err);
    }
  };

  /**
   * Handles window popstate event to enable transition on browser back/forward
   * Fades in main content on page load (popstate)
   */
  const handlePopState = () => {
    const mainContent = document.getElementById('main-content');
    if (mainContent) {
      fadeIn(mainContent);
    }
  };

  /**
   * Initialize page transition handlers:
   * - Fade in main content on load
   * - Fade out main content when internal links are clicked
   * - Handle popstate for browser navigation
   */
  const initPageTransitions = () => {
    try {
      const mainContent = document.getElementById('main-content');

      if (mainContent) {
        // Fade in on initial load
        fadeIn(mainContent);
      }

      // Delegate clicks for the whole document body
      document.body.addEventListener('click', e => {
        handleLinkClick(e);
      });

      // Listen for browser history navigation
      window.addEventListener('popstate', handlePopState);

      // Accessibility: Reduce motion respect
      const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
      if (prefersReducedMotion.matches) {
        // Disable all transition animations if reduced motion preferred
        if (mainContent) {
          mainContent.style.animation = 'none';
        }
      }

      console.log('transitions.js initialized successfully');
    } catch (err) {
      console.error('Error initializing transitions.js', err);
    }
  };

  // Initialize transitions on DOMContentLoaded
  document.addEventListener('DOMContentLoaded', () => {
    initPageTransitions();
  });

})();

//# sourceURL=transitions.js