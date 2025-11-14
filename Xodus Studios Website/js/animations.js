/*
 * animations.js - Controls animations and interactive visual effects
 * across the Xodus Studios website.
 * Handles scroll reveal animations, neon-glow effects, video play
 * enhancements, and other visual interactive behavior.
 *
 * Uses Intersection Observer API for performance optimized animations.
 * Includes event delegation for interactive media elements.
 * Production-ready with defensive coding and error handling.
 */

(() => {
  'use strict';

  // Cache commonly used selectors
  const neonGlowSelector = '.neon-glow';
  const sectionTitleSelector = '.section-title.neon-text';
  const heroTitleSelector = '.hero-title';
  const videoSelector = 'video.trailer-video, video.short-video';

  /**
   * Check if IntersectionObserver is supported
   * @returns {boolean}
   */
  const isIntersectionObserverSupported = () => 'IntersectionObserver' in window;

  /**
   * Helper to add animation class to element
   * @param {Element} el
   * @param {string} animationClass
   */
  const addAnimationClass = (el, animationClass) => {
    if (!el) return;
    el.classList.add(animationClass);
  };

  /**
   * Intersection Observer callback for elements to reveal on scroll
   * Adds 'visible' class which triggers CSS animations
   * @param {IntersectionObserverEntry[]} entries
   */
  const onIntersection = entries => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        addAnimationClass(entry.target, 'visible');
      }
    });
  };
/**
   * Initialize scroll reveal animations for elements with .neon-glow and section titles
   * Sets up Intersection Observer to animate when elements enter viewport
   */
  const initScrollRevealAnimations = () => {
    if (!isIntersectionObserverSupported()) {
      // Fallback: show all elements immediately if no observer support
      const elements = document.querySelectorAll(`${neonGlowSelector}, ${sectionTitleSelector}`);
      elements.forEach(el => addAnimationClass(el, 'visible'));
      return;
    }

    const observerOptions = {
      root: null, // viewport
      rootMargin: '0px',
      threshold: 0.15 // 15% of element visible
    };

    const observer = new IntersectionObserver(onIntersection, observerOptions);

    // Observe neon glow sections and section titles
    const targets = document.querySelectorAll(`${neonGlowSelector}, ${sectionTitleSelector}, .hero-title`);
    targets.forEach(el => {
      observer.observe(el);
    });
  };
/**
   * Enhance video playback controls with custom visual enhancements
   * e.g. Neon glow on play, pause overlays, and keyboard accessibility
   * Uses event delegation on document for video elements
   */
  const initVideoEnhancements = () => {
    const handleVideoPlay = e => {
      const video = e.target;
      if (!(video instanceof HTMLVideoElement)) return;
      video.classList.add('video-playing-neon');
    };

    const handleVideoPause = e => {
      const video = e.target;
      if (!(video instanceof HTMLVideoElement)) return;
      video.classList.remove('video-playing-neon');
    };

    // Toggle play/pause on Space key when focused on video
    const handleVideoKeyDown = e => {
      if (!(e.target instanceof HTMLVideoElement)) return;
      if (e.key === ' ' || e.key === 'Spacebar') {
        e.preventDefault();
        if (e.target.paused) {
          e.target.play().catch(err => console.warn('Video play interrupted', err));
        } else {
          e.target.pause();
        }
      }
    };

    // Attach delegated event listeners
    document.body.addEventListener('play', handleVideoPlay, true);
    document.body.addEventListener('pause', handleVideoPause, true);
    document.body.addEventListener('keydown', handleVideoKeyDown, true);
  };
/**
   * Initialize hover scale effect for interactive cards
   * Applies to project-cards, character-cards, merch-item-cards, and videogame-cards
   * Uses event delegation for mouseenter/mouseleave
   */
  const initCardHoverEffects = () => {
    const cardSelectors = ['.project-card', '.character-card', '.merch-item-card', '.videogame-card'];
    const cardSelector = cardSelectors.join(',');

    const handleMouseEnter = e => {
      const card = e.target.closest(cardSelector);
      if (!card) return;
      card.classList.add('card-hovered');
    };

    const handleMouseLeave = e => {
      const card = e.target.closest(cardSelector);
      if (!card) return;
      card.classList.remove('card-hovered');
    };

    document.body.addEventListener('mouseenter', handleMouseEnter, true);
    document.body.addEventListener('mouseleave', handleMouseLeave, true);
  };

  /**
   * Animate neon text flicker effect intermittently
   * Targets elements with .neon-text that have data-flicker attribute true
   */
  const initNeonTextFlicker = () => {
    const flickerElements = document.querySelectorAll('.neon-text[data-flicker="true"]');

    if (!flickerElements.length) return;

    // Flicker logic using random intervals
    flickerElements.forEach(el => {
      const flicker = () => {
        const flickerDuration = Math.random() * 250 + 150; // 150-400ms
        const flickerDelay = Math.random() * 5000 + 4000; // 4-9s

        // Toggle flicker class
        el.classList.add('neon-flicker');

        setTimeout(() => {
          el.classList.remove('neon-flicker');
          setTimeout(flicker, flickerDelay);
        }, flickerDuration);
      };
      flicker();
    });
  };

  /**
   * Accessibility enhancement: Reduce motion for users who prefer it
   * Disables animations if prefers-reduced-motion is set
   */
  const respectPrefersReducedMotion = () => {
    const mediaQuery = window.matchMedia('(prefers-reduced-motion: reduce)');
    if (!mediaQuery || !mediaQuery.matches) return;

    // Disable animation classes and handle
    const animatedElements = document.querySelectorAll('.neon-glow, .neon-text, .hero-title, .card-hovered');
    animatedElements.forEach(el => {
      el.style.animation = 'none';
    });
  };

  /**
   * Initialize all animations
   */
  const initAnimations = () => {
    try {
      respectPrefersReducedMotion();
      initScrollRevealAnimations();
      initVideoEnhancements();
      initCardHoverEffects();
      initNeonTextFlicker();
console.log('animations.js initialized successfully');
    } catch (err) {
      console.error('Error initializing animations.js', err);
    }
  };

  // Run on DOMContentLoaded
  document.addEventListener('DOMContentLoaded', initAnimations);

})();

//# sourceURL=animations.js