// Utility functions for USDA Dojo website

// DOM element selectors
const $ = (selector) => document.querySelector(selector);
const $$ = (selector) => document.querySelectorAll(selector);

// Price parsing utility
const parsePrice = (priceString) => {
  return parseFloat(priceString.replace('$', ''));
};

// Format price utility
const formatPrice = (price) => {
  return `$${price.toFixed(2)}`;
};

// Debounce utility for search input
const debounce = (func, wait) => {
  let timeout;
  return function executedFunction(...args) {
    const later = () => {
      clearTimeout(timeout);
      func(...args);
    };
    clearTimeout(timeout);
    timeout = setTimeout(later, wait);
  };
};

// Text matching utility for search
const matchesSearchTerm = (text, searchTerm) => {
  return text.toLowerCase().includes(searchTerm.toLowerCase());
};

// Category filtering utility
const matchesCategory = (element, category) => {
  if (category === 'all') return true;
  return element.dataset.category === category;
};

// Show/hide elements utility
const showElement = (element) => {
  element.style.display = 'block';
};

const hideElement = (element) => {
  element.style.display = 'none';
};

// Array sorting utilities
const sortByPriceAsc = (a, b) => {
  const priceA = parsePrice(a.querySelector('.product-price').textContent);
  const priceB = parsePrice(b.querySelector('.product-price').textContent);
  return priceA - priceB;
};

const sortByPriceDesc = (a, b) => {
  const priceA = parsePrice(a.querySelector('.product-price').textContent);
  const priceB = parsePrice(b.querySelector('.product-price').textContent);
  return priceB - priceA;
};

// URL parameter utilities
const getUrlParameter = (name) => {
  const urlParams = new URLSearchParams(window.location.search);
  return urlParams.get(name);
};

// Scroll to top utility
const scrollToTop = () => {
  window.scrollTo({ top: 0, behavior: 'smooth' });
};

// Check if element is in viewport
const isInViewport = (element) => {
  const rect = element.getBoundingClientRect();
  return (
    rect.top >= 0 &&
    rect.left >= 0 &&
    rect.bottom <= (window.innerHeight || document.documentElement.clientHeight) &&
    rect.right <= (window.innerWidth || document.documentElement.clientWidth)
  );
};

// Export utilities for use in other modules
window.Utils = {
  $,
  $$,
  parsePrice,
  formatPrice,
  debounce,
  matchesSearchTerm,
  matchesCategory,
  showElement,
  hideElement,
  sortByPriceAsc,
  sortByPriceDesc,
  getUrlParameter,
  scrollToTop,
  isInViewport
};