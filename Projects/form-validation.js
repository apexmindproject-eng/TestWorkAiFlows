document.addEventListener('DOMContentLoaded', function () {
  function validateVolunteerForm() {
    const form = document.getElementById('volunteer-form');
    if (!form) return;

    form.addEventListener('submit', function (event) {
      let valid = true;
      const fullName = form.fullName.value.trim();
      const email = form.email.value.trim();
      const availability = form.availability.value.trim();
      const areas = Array.from(form.areas.options).filter(o => o.selected).map(o => o.value);

      // Full Name validation - at least 2 characters
      if (fullName.length < 2) {
        valid = false;
        alert('Please enter your full name (at least 2 characters).');
      }

      // Email validation basic pattern
      const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
      if (!emailPattern.test(email)) {
        valid = false;
        alert('Please enter a valid email address.');
      }

      // Availability validation - required
      if (availability.length === 0) {
        valid = false;
        alert('Please specify your availability.');
      }

      // Areas of Interest validation - at least one selected
      if (areas.length === 0) {
        valid = false;
        alert('Please select at least one area of interest.');
      }

      if (!valid) {
        event.preventDefault();
      }
    });
  }

  function validateContactForm() {
    const form = document.getElementById('contactForm');
    if (!form) return;

    form.addEventListener('submit', function (event) {
      let valid = true;
      const name = form.name.value.trim();
      const email = form.email.value.trim();
      const subject = form.subject.value.trim();
      const message = form.message.value.trim();

      if (name.length < 2) {
        valid = false;
        alert('Please enter your name (at least 2 characters).');
      }

      const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
      if (!emailPattern.test(email)) {
        valid = false;
        alert('Please enter a valid email address.');
      }

      if (subject.length === 0) {
        valid = false;
        alert('Please enter a subject.');
      }

      if (message.length < 5) {
        valid = false;
        alert('Please enter a message with at least 5 characters.');
      }

      if (!valid) {
        event.preventDefault();
      }
    });
  }

  validateVolunteerForm();
  validateContactForm();
});