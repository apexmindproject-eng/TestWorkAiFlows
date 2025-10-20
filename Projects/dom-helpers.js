export function qs(selector, scope = document) {
  return scope.querySelector(selector);
}

export function qsa(selector, scope = document) {
  return Array.from(scope.querySelectorAll(selector));
}

export function on(target, event, handler, options) {
  target.addEventListener(event, handler, options);
}

export function delegate(target, selector, event, handler) {
  target.addEventListener(event, function(e) {
    const possibleTargets = qsa(selector, target);
    const el = e.target;
    if (possibleTargets.includes(el)) {
      handler.call(el, e);
    }
  });
}

export function createElem(tag, options = {}) {
  const element = document.createElement(tag);
  if (options.classNames) {
    element.classList.add(...options.classNames);
  }
  if (options.attrs) {
    for (const attr in options.attrs) {
      element.setAttribute(attr, options.attrs[attr]);
    }
  }
  if (options.text) {
    element.textContent = options.text;
  }
  return element;
}

export function removeChildren(element) {
  while (element.firstChild) {
    element.removeChild(element.firstChild);
  }
}

export function toggleClass(element, className) {
  element.classList.toggle(className);
}