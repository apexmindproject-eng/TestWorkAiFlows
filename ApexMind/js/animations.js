// animations.js - Manage scroll-triggered animations and UI transitions for ApexMind website
// Includes intersection observer setups, animation triggers, performance optimization and fallback

'use strict';

(() => {
  // Configuration for animation observer
  const animationSelector = '.animate-on-scroll'; // Elements with this class get animated on scroll
  const animationClass = 'animated'; // Class to toggle for animation
  const animationRootMargin = '0px 0px -100px 0px'; // Start animation just before entering viewport
  const animationThreshold = 0.1;

  // Stores observer instance
  let animationObserver = null;

  /**
   * Initialize IntersectionObserver for animations.
   * Adds animationClass to elements when they scroll into view, removes if they scroll out.
   */
  const initAnimationObserver = () => {
    try {
      if (!('IntersectionObserver' in window)) {
        // Fallback: Animate all elements immediately
        document.querySelectorAll(animationSelector).forEach(el => {
          el.classList.add(animationClass);
        });
        return;
      }
animationObserver = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
          const el = entry.target;
          if (entry.isIntersecting) {
            el.classList.add(animationClass);
            // Optionally unobserve after animation if one-time animation desired
            animationObserver.unobserve(el);
          }
        });
      }, {
        root: null,
        rootMargin: animationRootMargin,
        threshold: animationThreshold
      });

      // Observe all animate-on-scroll elements
      document.querySelectorAll(animationSelector).forEach(el => {
        animationObserver.observe(el);
      });

    } catch (error) {
      console.error('Failed to initialize animation observer:', error);
    }
  };

  /**
   * Animate hero image fade-in and text slide-in on homepage.
   * Applies on pages with id="home".
   */
  const animateHomepageHero = () => {
    try {
      if (document.body.id !== 'home') return;
const heroImage = document.querySelector('.hero-section .hero-image');
      const heroText = document.querySelector('.hero-section .hero-content');

      if (!heroImage || !heroText) return;

      // Apply fade-in to image and slide-in to text after page load
      heroImage.classList.add('fade-in-animation');
      heroText.classList.add('slide-in-animation');

    } catch (error) {
      console.error('Error animating homepage hero:', error);
    }
  };

  /**
   * Animate expertise cards on about page - stagger animation for visual effect.
   */
  const animateExpertiseCards = () => {
    try {
      if (document.body.id !== 'about') return;

      const cards = document.querySelectorAll('.expertise-card');
      if (!cards.length) return;

      cards.forEach((card, index) => {
        card.style.animationDelay = `${index * 200}ms`;
        card.classList.add('fade-up-animation');
      });
    } catch (error) {
      console.error('Error animating expertise cards:', error);
    }
  };

  /**
   * Animate service cards on services page - fade and zoom in staggered.
   */
  const animateServiceCards = () => {
    try {
      if (document.body.id !== 'services') return;

      const cards = document.querySelectorAll('.service-card');
      if (!cards.length) return;

      cards.forEach((card, index) => {
        card.style.animationDelay = `${index * 150}ms`;
        card.classList.add('zoom-in-animation');
      });
    } catch (error) {
      console.error('Error animating service cards:', error);
    }
  };
/**
   * Portfolio projects gallery animations - slide in from left individually
   */
  const animateProjectCards = () => {
    try {
      if (document.body.id !== 'portfolio') return;

      const cards = document.querySelectorAll('.project-card');
      if (!cards.length) return;

      cards.forEach((card, index) => {
        card.style.animationDelay = `${index * 180}ms`;
        card.classList.add('slide-left-animation');
      });
    } catch (error) {
      console.error('Error animating project cards:', error);
    }
  };

  /**
   * Contact page hero and form fade-in
   */
  const animateContactPage = () => {
    try {
      if (document.body.id !== 'contact') return;

      const heroImage = document.querySelector('.hero-section .hero-image');
      const heroText = document.querySelector('.hero-section .hero-content');
      const contactForm = document.querySelector('#contact-form');
if (heroImage) heroImage.classList.add('fade-in-animation');
      if (heroText) heroText.classList.add('slide-in-animation');
      if (contactForm) contactForm.classList.add('fade-in-animation');
    } catch (error) {
      console.error('Error animating contact page:', error);
    }
  };

  // General smooth fade-in animation for elements with .fade-in-trigger class when they scroll into view
  const initSmoothFadeInOnScroll = () => {
    try {
      const fadeInItemsSelector = '.fade-in-trigger';

      if (!('IntersectionObserver' in window)) {
        document.querySelectorAll(fadeInItemsSelector).forEach(el => {
          el.classList.add('fade-in-animation');
        });
        return;
      }
const observer = new IntersectionObserver((entries, observer) => {
        entries.forEach(entry => {
          if (entry.isIntersecting) {
            entry.target.classList.add('fade-in-animation');
            observer.unobserve(entry.target);
          }
        });
      }, {
        root: null,
        rootMargin: '0px 0px -100px 0px',
        threshold: 0.1
      });

      document.querySelectorAll(fadeInItemsSelector).forEach(el => observer.observe(el));
    } catch (error) {
      console.error('Error initializing smooth fade-in animations:', error);
    }
  };

  // Initialization
  const init = () => {
    initAnimationObserver();
    animateHomepageHero();
    animateExpertiseCards();
    animateServiceCards();
    animateProjectCards();
    animateContactPage();
    initSmoothFadeInOnScroll();
  };

  document.addEventListener('DOMContentLoaded', init);

})();

//# sourceURL=animations.js