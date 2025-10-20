document.addEventListener('DOMContentLoaded', function() {
  const galleryContainer = document.querySelector('.gallery-container');
  if (!galleryContainer) return;

  // Create lightbox elements
  const lightboxOverlay = document.createElement('div');
  lightboxOverlay.id = 'lightbox-overlay';
  lightboxOverlay.style.position = 'fixed';
  lightboxOverlay.style.top = 0;
  lightboxOverlay.style.left = 0;
  lightboxOverlay.style.width = '100%';
  lightboxOverlay.style.height = '100%';
  lightboxOverlay.style.backgroundColor = 'rgba(0,0,0,0.8)';
  lightboxOverlay.style.display = 'flex';
  lightboxOverlay.style.alignItems = 'center';
  lightboxOverlay.style.justifyContent = 'center';
  lightboxOverlay.style.visibility = 'hidden';
  lightboxOverlay.style.opacity = 0;
  lightboxOverlay.style.transition = 'opacity 0.3s ease';
  lightboxOverlay.style.zIndex = 1000;

  const lightboxImage = document.createElement('img');
  lightboxImage.id = 'lightbox-image';
  lightboxImage.style.maxWidth = '90%';
  lightboxImage.style.maxHeight = '90%';
  lightboxImage.style.borderRadius = '8px';
  lightboxImage.style.boxShadow = '0 0 15px rgba(0,0,0,0.5)';

  lightboxOverlay.appendChild(lightboxImage);
  document.body.appendChild(lightboxOverlay);

  // Function to open lightbox with given image
  function openLightbox(src, alt) {
    lightboxImage.src = src;
    lightboxImage.alt = alt || '';
    lightboxOverlay.style.visibility = 'visible';
    lightboxOverlay.style.opacity = 1;
    document.body.style.overflow = 'hidden'; // prevent scroll
  }

  // Function to close lightbox
  function closeLightbox() {
    lightboxOverlay.style.opacity = 0;
    setTimeout(() => {
      lightboxOverlay.style.visibility = 'hidden';
      lightboxImage.src = '';
      document.body.style.overflow = '';
    }, 300);
  }

  // Add click event to gallery thumbnails
  galleryContainer.addEventListener('click', function(event) {
    if (event.target && event.target.classList.contains('gallery-thumbnail')) {
      openLightbox(event.target.src, event.target.alt);
    }
  });

  // Allow keyboard accessibility (Enter/Space) on gallery thumbnails
  galleryContainer.addEventListener('keydown', function(event) {
    if ((event.key === 'Enter' || event.key === ' ') && event.target.classList.contains('gallery-thumbnail')) {
      event.preventDefault();
      openLightbox(event.target.src, event.target.alt);
    }
  });

  // Close lightbox when clicking outside the image
  lightboxOverlay.addEventListener('click', function(event) {
    if (event.target === lightboxOverlay) {
      closeLightbox();
    }
  });

  // Close lightbox on ESC key press
  document.addEventListener('keydown', function(event) {
    if (event.key === 'Escape' && lightboxOverlay.style.visibility === 'visible') {
      closeLightbox();
    }
  });
});