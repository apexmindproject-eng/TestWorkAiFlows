// Utility functions for ApexMind Ordering and Vendors

/**
 * Format a number as currency string
 * @param {number} amount
 * @param {string} currency - currency code, e.g. 'USD'
 * @returns {string}
 */
function formatCurrency(amount, currency = 'USD') {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency
  }).format(amount);
}

/**
 * Debounce function to limit rate of function calls
 * @param {Function} func
 * @param {number} wait
 * @returns {Function}
 */
function debounce(func, wait) {
  let timeout;
  return function (...args) {
    clearTimeout(timeout);
    timeout = setTimeout(() => func.apply(this, args), wait);
  };
}

/**
 * Simple helper to create DOM element with attributes and children
 * @param {string} tag
 * @param {Object} attributes
 * @param {Array|Node|string} children
 * @returns {Element}
 */
function createElement(tag, attributes = {}, children = []) {
  const el = document.createElement(tag);
  Object.entries(attributes).forEach(([key, value]) => {
    if (key === 'className') {
      el.className = value;
    } else if (key === 'innerHTML') {
      el.innerHTML = value;
    } else if (key === 'textContent') {
      el.textContent = value;
    } else {
      el.setAttribute(key, value);
    }
  });
  if (!Array.isArray(children)) children = [children];
  children.forEach(child => {
    if (typeof child === 'string') {
      el.appendChild(document.createTextNode(child));
    } else if(child instanceof Node) {
      el.appendChild(child);
    }
  });
  return el;
}

/**
 * Validate email format
 * @param {string} email
 * @returns {boolean}
 */
function validateEmail(email) {
  const re = /^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$/g;
  return re.test(email);
}

/**
 * Utility to toggle class on element
 * @param {Element} el
 * @param {string} className
 * @param {boolean} force
 */
function toggleClass(el, className, force) {
  if (force === undefined) {
    el.classList.toggle(className);
  } else if (force) {
    el.classList.add(className);
  } else {
    el.classList.remove(className);
  }
}

// Exporting utilities for use in other scripts
export { formatCurrency, debounce, createElement, validateEmail, toggleClass };