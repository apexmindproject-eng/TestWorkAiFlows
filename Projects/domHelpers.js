const domHelpers = {
  // Retrieve element by id
  getById: function(id) {
    return document.getElementById(id);
  },

  // Retrieve elements by class name
  getByClass: function(className) {
    return document.getElementsByClassName(className);
  },

  // Retrieve elements by tag name
  getByTag: function(tagName) {
    return document.getElementsByTagName(tagName);
  },

  // Create and return new element by tag name
  createElement: function(tagName) {
    return document.createElement(tagName);
  },

  // Add an event listener to an element
  on: function(element, event, handler) {
    if(element) {
      element.addEventListener(event, handler);
    }
  },

  // Remove an event listener from an element
  off: function(element, event, handler) {
    if(element) {
      element.removeEventListener(event, handler);
    }
  },

  // Add a class to an element
  addClass: function(element, className) {
    if(element) {
      element.classList.add(className);
    }
  },

  // Remove a class from an element
  removeClass: function(element, className) {
    if(element) {
      element.classList.remove(className);
    }
  },

  // Check if element has a class
  hasClass: function(element, className) {
    return element ? element.classList.contains(className) : false;
  },

  // Set one or more attributes on an element
  setAttributes: function(element, attrs) {
    if(element && attrs && typeof attrs === 'object') {
      Object.keys(attrs).forEach(attr => {
        element.setAttribute(attr, attrs[attr]);
      });
    }
  },

  // Clear all children of an element
  clearChildren: function(element) {
    if(element) {
      while(element.firstChild) {
        element.removeChild(element.firstChild);
      }
    }
  }
};

export default domHelpers;
