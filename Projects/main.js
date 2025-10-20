document.addEventListener('DOMContentLoaded', function() {
  // Example common functionality for all pages

  // Highlight active navigation link based on current URL
  const navLinks = document.querySelectorAll('nav ul li a');
  const currentPage = window.location.pathname.split('/').pop();

  navLinks.forEach(link => {
    if(link.getAttribute('href') === currentPage) {
      link.classList.add('active');
    }
  });

  // Responsive navigation toggle for mobile views (if needed)
  const nav = document.querySelector('nav');
  const toggleButton = document.createElement('button');
  toggleButton.textContent = 'Menu';
  toggleButton.setAttribute('aria-expanded', 'false');
  toggleButton.setAttribute('aria-controls', 'primary-navigation');
  toggleButton.classList.add('nav-toggle');

  // Insert button before nav list
  if(nav) {
    const navList = nav.querySelector('ul');
    navList.id = 'primary-navigation';
    nav.insertBefore(toggleButton, navList);

    toggleButton.addEventListener('click', () => {
      const isExpanded = toggleButton.getAttribute('aria-expanded') === 'true';
      toggleButton.setAttribute('aria-expanded', String(!isExpanded));
      navList.classList.toggle('active');
    });
  }

  // Other global JS code can be added here
});