document.addEventListener('DOMContentLoaded', function() {
  const gallery = document.getElementById('gallery');

  if (!gallery) return;

  // Enhance gallery items if needed - example: add click event to open image in a modal
  gallery.querySelectorAll('.gallery-item img').forEach(img => {
    img.style.cursor = 'pointer';
    img.addEventListener('click', () => {
      openModal(img.src, img.alt);
    });
  });

  function openModal(src, alt) {
    let modal = document.getElementById('image-modal');
    if (!modal) {
      modal = document.createElement('div');
      modal.id = 'image-modal';
      modal.style.position = 'fixed';
      modal.style.top = 0;
      modal.style.left = 0;
      modal.style.width = '100%';
      modal.style.height = '100%';
      modal.style.backgroundColor = 'rgba(0,0,0,0.8)';
      modal.style.display = 'flex';
      modal.style.alignItems = 'center';
      modal.style.justifyContent = 'center';
      modal.style.zIndex = 1000;

      const img = document.createElement('img');
      img.style.maxWidth = '90%';
      img.style.maxHeight = '90%';
      img.id = 'modal-image';
      modal.appendChild(img);

      modal.addEventListener('click', () => {
        modal.style.display = 'none';
      });

      document.body.appendChild(modal);
    }
    const modalImage = document.getElementById('modal-image');
    modalImage.src = src;
    modalImage.alt = alt;
    modal.style.display = 'flex';
  }
});