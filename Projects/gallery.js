document.addEventListener('DOMContentLoaded', function() {
  const galleryItems = document.querySelectorAll('.gallery-item');

  galleryItems.forEach(item => {
    item.addEventListener('click', function() {
      // Open the clicked image in a new tab/window for a larger view
      window.open(this.src, '_blank');
    });
  });
});