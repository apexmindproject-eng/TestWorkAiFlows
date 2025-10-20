const domHelpers = (() => {
  // Get element by selector
  function getElement(selector) {
    return document.querySelector(selector);
  }

  // Get all elements by selector
  function getElements(selector) {
    return document.querySelectorAll(selector);
  }

  // Create an element with optional class and attributes
  function createElement(tag, options = {}) {
    const el = document.createElement(tag);
    if (options.className) {
      el.className = options.className;
    }
    if (options.attributes) {
      for (const attr in options.attributes) {
        el.setAttribute(attr, options.attributes[attr]);
      }
    }
    if (options.text) {
      el.textContent = options.text;
    }
    return el;
  }

  // Append child element
  function appendChild(parent, child) {
    if (parent && child) {
      parent.appendChild(child);
    }
  }

  // Remove all child nodes
  function clearChildren(parent) {
    while (parent.firstChild) {
      parent.removeChild(parent.firstChild);
    }
  }

  // Set text content safely
  function setText(element, text) {
    if (element) {
      element.textContent = text;
    }
  }

  return {
    getElement,
    getElements,
    createElement,
    appendChild,
    clearChildren,
    setText
  };
})();

export default domHelpers;
