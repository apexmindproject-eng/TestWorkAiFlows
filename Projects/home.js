document.addEventListener('DOMContentLoaded', () => {
  // Example: You might want to add some interactive behavior to the hero section
  const heroText = document.querySelector('.hero-text');

  // Simple fade-in animation on page load for the hero text
  if (heroText) {
    heroText.style.opacity = 0;
    heroText.style.transition = 'opacity 2s ease-in-out';
    setTimeout(() => {
      heroText.style.opacity = 1;
    }, 100);
  }

  // Example future enhancement: Log message when user clicks the hero image
  const heroImage = document.querySelector('.hero img');
  if (heroImage) {
    heroImage.addEventListener('click', () => {
      console.log('Hero image clicked: Enjoy the cute kittens!');
    });
  }
});