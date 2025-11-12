// app.js - Core functionality for CryptoCurrency Hub

// Immediately-Invoked Function Expression (IIFE) to encapsulate code and avoid polluting global scope
(() => {
  'use strict';

  /**
   * Utility Functions
   */
  const select = (selector, all = false) => {
    try {
      if (all) {
        return Array.from(document.querySelectorAll(selector));
      } else {
        return document.querySelector(selector);
      }
    } catch (error) {
      console.error(`Error selecting element(s) with selector: ${selector}`, error);
      return null;
  };

  const on = (type, selector, listener, all = false) => {
      const els = select(selector, all);
      if (!els) return;
        els.forEach(el => el.addEventListener(type, listener));
        els.addEventListener(type, listener);
      console.error(`Failed to add event listener to elements: ${selector}`, error);
   * Navigation Handling
   * Handles mobile menu toggling and active page highlighting
  const setupNavigation = () => {
    const nav = select('#main-nav');
    if (!nav) return; // Defensive

    // Add a mobile menu toggle button dynamically for mobile menus if not present
    let toggleBtn = select('#mobile-nav-toggle');
    if (!toggleBtn) {
      toggleBtn = document.createElement('button');
      toggleBtn.id = 'mobile-nav-toggle';
      toggleBtn.setAttribute('aria-expanded', 'false');
      toggleBtn.setAttribute('aria-label', 'Toggle navigation menu');
      toggleBtn.classList.add('mobile-nav-toggle');
      toggleBtn.innerHTML = '&#9776;'; // Hamburger icon

      // Insert button before nav in the header
      const headerContainer = select('.header > .container');
      if (headerContainer) {
        headerContainer.insertBefore(toggleBtn, nav);
toggleBtn.addEventListener('click', () => {
      const expanded = toggleBtn.getAttribute('aria-expanded') === 'true';
      toggleBtn.setAttribute('aria-expanded', String(!expanded));

      nav.classList.toggle('nav-open');
      toggleBtn.classList.toggle('open');
    });

    // Close menu if click outside navigation on mobile
    document.addEventListener('click', (e) => {
      if (!nav.contains(e.target) && e.target !== toggleBtn) {
        if (nav.classList.contains('nav-open')) {
          nav.classList.remove('nav-open');
          toggleBtn.classList.remove('open');

    // Keyboard accessibility on toggle button
    toggleBtn.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault();
        toggleBtn.click();
// Active page link highlighting
    const navLinks = select('.nav-item', true);
    if (navLinks && navLinks.length) {
      const currentPage = window.location.pathname.split('/').pop() || 'index.html';
      navLinks.forEach(link => {
        const href = link.getAttribute('href');
        if (href === currentPage || (href === 'index.html' && currentPage === '')) {
          link.classList.add('active');
          link.classList.remove('active');

   * Smooth Scroll for Anchor Links
   * Smoothly scrolls to sections on the page with anchors
  const setupSmoothScroll = () => {
    document.addEventListener('click', (event) => {
        const target = event.target.closest('a[href^="#"]');
        if (!target) return;

        const href = target.getAttribute('href');
        const section = select(href);
        if (!section) return;

        // Only handle if href points to an element on the same page
        event.preventDefault();
        section.scrollIntoView({ behavior: 'smooth', block: 'start' });
        console.error('Smooth scroll failed:', error);

   * News Section Accordion / Expand More Feature
   * If there is a lot of news, we could toggle more articles (assuming dynamic content)
  const setupNewsInteraction = () => {
    const newsSection = select('#latest-news');
    if (!newsSection) return;

    // Example: Collapsing long news sections with more/less toggle
    const articles = newsSection.querySelectorAll('.news-article');
    if (!articles.length) return;

    // If more than 2 articles, add a toggle button
    if (articles.length > 2) {
      const toggleBtn = document.createElement('button');
      toggleBtn.className = 'news-toggle';
      toggleBtn.textContent = 'Show More';

      // We start hiding articles after index 1 (show first two)
      articles.forEach((article, index) => {
        if (index > 1) article.style.display = 'none';

          const isShown = toggleBtn.textContent === 'Show Less';
            if (index > 1) article.style.display = isShown ? 'none' : 'block';
          toggleBtn.textContent = isShown ? 'Show More' : 'Show Less';
          console.error('Error toggling news articles:', error);

      newsSection.appendChild(toggleBtn);

   * Market Trends Interactive List
   * Show tooltips/details on hover/tap, or filter functionality for cryptos
  const setupMarketInteraction = () => {
    const marketSection = select('#market-trends');
    if (!marketSection) return;
// Tooltips or info bubble on hover for market items
    const marketItems = marketSection.querySelectorAll('.market-item');

    if (!marketItems.length) return;

    // Create tooltip container
    const tooltip = document.createElement('div');
    tooltip.className = 'market-tooltip';
    tooltip.style.position = 'absolute';
    tooltip.style.padding = '8px 12px';
    tooltip.style.backgroundColor = 'rgba(0,0,0,0.75)';
    tooltip.style.color = '#fff';
    tooltip.style.borderRadius = '4px';
    tooltip.style.fontSize = '0.9rem';
    tooltip.style.pointerEvents = 'none';
    tooltip.style.opacity = 0;
    tooltip.style.transition = 'opacity 0.3s ease';
    document.body.appendChild(tooltip);

    let activeItem = null;

    const showTooltip = (event, content) => {
      tooltip.textContent = content;
      const x = event.pageX;
      const y = event.pageY;
      tooltip.style.top = `${y + 15}px`;
      tooltip.style.left = `${x + 15}px`;
      tooltip.style.opacity = '1';

    const hideTooltip = () => {
      tooltip.style.opacity = '0';

    marketItems.forEach((item) => {
      // Defensive: ensure item
      if (!item) return;

      // Hover to show brief info - we will try to get a data-tooltip attribute if it exists
      const tooltipContent = item.getAttribute('data-tooltip') || item.innerText || 'Market Item';

      item.addEventListener('mouseenter', (e) => {
        activeItem = item;
        showTooltip(e, tooltipContent);

      item.addEventListener('mousemove', (e) => {
        if (activeItem === item) showTooltip(e, tooltipContent);

      item.addEventListener('mouseleave', () => {
        activeItem = null;
        hideTooltip();

      // On touch, toggle tooltip on tap (with timeout to hide)
      item.addEventListener('touchstart', (e) => {
        e.preventDefault(); // Prevent touch mouse event emulation
        if (activeItem === item) {
          showTooltip(e.touches[0], tooltipContent);
          setTimeout(hideTooltip, 3000); // Hide after 3 secs

   * Logo click quick scroll to top
  const setupLogoClick = () => {
    const logo = select('#logo');
    if (!logo) return;

    logo.style.cursor = 'pointer';
    logo.addEventListener('click', (e) => {
      window.scrollTo({
        top: 0,
        behavior: 'smooth'

   * Global error listener for unexpected errors
  const setupGlobalErrorHandler = () => {
    window.addEventListener('error', event => {
      // Could send this info to a logging service
      console.error('Global error captured:', event.message, 'At:', event.filename, ':', event.lineno);

    window.addEventListener('unhandledrejection', event => {
      console.error('Unhandled promise rejection:', event.reason);

   * Initialization function on DOM ready
  const init = () => {
    setupGlobalErrorHandler();
    setupNavigation();
    setupSmoothScroll();
    setupNewsInteraction();
    setupMarketInteraction();
    setupLogoClick();

  // Kick off when DOM is loaded
  document.addEventListener('DOMContentLoaded', init);

})();


/*
  Notes:
  - The navigation includes a mobile toggle button inserted if not present.
  - Active page in navigation is detected by matching the href of links to current URL path.
  - A 'Show More' toggle is added dynamically for news articles if more than two.
  - Market items show tooltip info on interaction (mouse+touch).
  - Smooth scrolling is applied to anchor links.
  - Defensive checks and try/catch blocks are added for robustness.
  - Global error handlers log errors for better visibility.
  - Logo click scrolls smoothly to top.