// about.js
// Since about.html is a static page in the project memory with no explicit dynamic script loaded,
// we will provide a basic JS for any interactive enhancements such as navigation highlight or simple DOM interactions.

// Wait for DOM content loaded
window.addEventListener('DOMContentLoaded', () => {
  // Navigation highlight for About page
  const navLinks = document.querySelectorAll('nav ul li a');
  navLinks.forEach(link => {
    if (link.getAttribute('href') === 'about.html') {
      link.classList.add('active');
    }
  });

  // Any additional interactivity for About page can be added here

});
