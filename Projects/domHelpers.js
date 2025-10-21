export function createElement(type, attributes = {}, ...children) {
  const elem = document.createElement(type);
  for (let attr in attributes) {
    if (attr.startsWith('on') && typeof attributes[attr] === 'function') {
      elem.addEventListener(attr.substring(2).toLowerCase(), attributes[attr]);
    } else if (attr === 'className') {
      elem.className = attributes[attr];
    } else {
      elem.setAttribute(attr, attributes[attr]);
    }
  }
  children.forEach(child => {
    if (typeof child === 'string') {
      elem.appendChild(document.createTextNode(child));
    } else if (child instanceof Node) {
      elem.appendChild(child);
    }
  });
  return elem;
}

export function clearElement(element) {
  while (element.firstChild) {
    element.removeChild(element.firstChild);
  }
}

export function getById(id) {
  return document.getElementById(id);
}

export function showElement(element) {
  element.style.display = '';
}

export function hideElement(element) {
  element.style.display = 'none';
}

export function toggleClass(element, className) {
  element.classList.toggle(className);
}

export function addClass(element, className) {
  element.classList.add(className);
}

export function removeClass(element, className) {
  element.classList.remove(className);
}