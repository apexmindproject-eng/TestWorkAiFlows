export function debounce(func, wait) {
  let timeout;
  return function executedFunction(...args) {
    const later = () => {
      clearTimeout(timeout);
      func(...args);
    };
    clearTimeout(timeout);
    timeout = setTimeout(later, wait);
  };
}

export function throttle(func, limit) {
  let lastFunc;
  let lastRan;
  return function(...args) {
    if (!lastRan) {
      func(...args);
      lastRan = Date.now();
    } else {
      clearTimeout(lastFunc);
      lastFunc = setTimeout(function() {
        if ((Date.now() - lastRan) >= limit) {
          func(...args);
          lastRan = Date.now();
        }
      }, limit - (Date.now() - lastRan));
    }
  };
}

// Utility to fetch JSON data with error handling
export async function fetchJSON(url) {
  try {
    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    return await response.json();
  } catch (error) {
    console.error('fetchJSON error:', error);
    throw error;
  }
}

// Simple function to add class to element safely
export function addClass(element, className) {
  if (element && className) {
    element.classList.add(className);
  }
}

// Simple function to remove class from element safely
export function removeClass(element, className) {
  if (element && className) {
    element.classList.remove(className);
  }
}

// Helper to fade in an element (using CSS classes or inline styles)
export function fadeIn(element, duration = 400) {
  if (!element) return;
  element.style.opacity = 0;
  element.style.display = '';
  let last = +new Date();
  let tick = function() {
    element.style.opacity = +element.style.opacity + (new Date() - last) / duration;
    last = +new Date();

    if (+element.style.opacity < 1) {
      (window.requestAnimationFrame && requestAnimationFrame(tick)) || setTimeout(tick, 16);
    }
  };
  tick();
}

// Helper to fade out an element
export function fadeOut(element, duration = 400) {
  if (!element) return;
  element.style.opacity = 1;
  let last = +new Date();
  let tick = function() {
    element.style.opacity = +element.style.opacity - (new Date() - last) / duration;
    last = +new Date();

    if (+element.style.opacity > 0) {
      (window.requestAnimationFrame && requestAnimationFrame(tick)) || setTimeout(tick, 16);
    } else {
      element.style.display = 'none';
    }
  };
  tick();
}
