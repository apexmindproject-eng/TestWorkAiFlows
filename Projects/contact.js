document.addEventListener('DOMContentLoaded', function() {
  const form = document.getElementById('contact-form');

  form.addEventListener('submit', function(event) {
    event.preventDefault();

    // Clear previous errors
    const errorElements = form.querySelectorAll('.error-message');
    errorElements.forEach(el => el.remove());

    // Basic validation
    let valid = true;

    const name = form.name.value.trim();
    const email = form.email.value.trim();
    const message = form.message.value.trim();

    if (name === '') {
      showError('name', 'Please enter your name.');
      valid = false;
    }

    if (email === '') {
      showError('email', 'Please enter your email address.');
      valid = false;
    } else if (!validateEmail(email)) {
      showError('email', 'Please enter a valid email address.');
      valid = false;
    }

    if (message === '') {
      showError('message', 'Please enter your message.');
      valid = false;
    }

    if (!valid) {
      return;
    }

    // Prepare data to send
    const formData = {
      name: name,
      email: email,
      phone: form.phone.value.trim(),
      message: message
    };

    // Here you would send the data to a server or API endpoint
    // Simulate successful submission with alert for this example
    alert('Thank you for contacting us, ' + name + '! We will get back to you shortly.');

    form.reset();
  });

  function showError(fieldId, message) {
    const field = document.getElementById(fieldId);
    const error = document.createElement('div');
    error.className = 'error-message';
    error.style.color = 'red';
    error.style.fontSize = '0.9em';
    error.textContent = message;
    field.parentNode.appendChild(error);
  }

  function validateEmail(email) {
    // Simple email regex for demonstration
    const re = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return re.test(email);
  }
});