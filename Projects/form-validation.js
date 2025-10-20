document.addEventListener('DOMContentLoaded', function() {
  const form = document.getElementById('contactForm');

  form.addEventListener('submit', function(event) {
    event.preventDefault();
    clearErrors();

    let hasErrors = false;

    // Validate Name
    const nameInput = form.elements['name'];
    if (!nameInput.value.trim()) {
      showError(nameInput, 'Please enter your name.');
      hasErrors = true;
    }

    // Validate Email
    const emailInput = form.elements['email'];
    if (!emailInput.value.trim()) {
      showError(emailInput, 'Please enter your email.');
      hasErrors = true;
    } else if (!validateEmail(emailInput.value)) {
      showError(emailInput, 'Please enter a valid email address.');
      hasErrors = true;
    }

    // Validate Message
    const messageInput = form.elements['message'];
    if (!messageInput.value.trim()) {
      showError(messageInput, 'Please enter your message.');
      hasErrors = true;
    }

    if (!hasErrors) {
      form.submit(); // or handle form submission with AJAX
    }
  });

  function showError(inputElement, message) {
    const formGroup = inputElement.parentElement;
    let errorElem = formGroup.querySelector('.error-message');
    if (!errorElem) {
      errorElem = document.createElement('div');
      errorElem.classList.add('error-message');
      formGroup.appendChild(errorElem);
    }
    errorElem.textContent = message;
    inputElement.classList.add('input-error');
  }

  function clearErrors() {
    const errors = form.querySelectorAll('.error-message');
    errors.forEach(err => err.remove());
    const inputs = form.querySelectorAll('.input-error');
    inputs.forEach(input => input.classList.remove('input-error'));
  }

  function validateEmail(email) {
    // Simple email regex
    const re = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return re.test(email);
  }
});