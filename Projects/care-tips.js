document.addEventListener('DOMContentLoaded', function () {
  // Elements for care tip articles
  const careTips = document.querySelectorAll('.care-tip');

  // Optional: Add simple interaction or animation for care tips on click or hover
  careTips.forEach(tip => {
    tip.addEventListener('mouseenter', () => {
      tip.style.backgroundColor = '#f9f9f9';
      tip.style.transition = 'background-color 0.3s ease';
    });
    tip.addEventListener('mouseleave', () => {
      tip.style.backgroundColor = '';
    });
  });

  // Lazy load care illustration image for performance enhancement
  const careIllustration = document.querySelector('.care-illustration img');
  if (careIllustration) {
    careIllustration.setAttribute('loading', 'lazy');
  }
});