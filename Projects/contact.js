document.addEventListener('DOMContentLoaded', function() {
  const contactForm = document.getElementById('contactForm');

  contactForm.addEventListener('submit', function(event) {
    event.preventDefault();

    // Basic validation check
    const name = contactForm.name.value.trim();
    const email = contactForm.email.value.trim();
    const message = contactForm.message.value.trim();

    if (!name) {
      alert('Please enter your name.');
      contactForm.name.focus();
      return;
    }

    if (!email) {
      alert('Please enter your email address.');
      contactForm.email.focus();
      return;
    }

    if (!validateEmail(email)) {
      alert('Please enter a valid email address.');
      contactForm.email.focus();
      return;
    }

    if (!message) {
      alert('Please enter your message.');
      contactForm.message.focus();
      return;
    }

    // Simulate sending message
    alert('Thank you for contacting us, ' + name + '! Your message has been sent.');

    // Reset form after successful submission
    contactForm.reset();
  });

  function validateEmail(email) {
    // Simple email validation regex
    const re = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return re.test(email);
  }
});