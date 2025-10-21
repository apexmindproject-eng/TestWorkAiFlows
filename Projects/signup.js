document.addEventListener('DOMContentLoaded', () => {
  const form = document.getElementById('signup-form');
  const usernameInput = form.querySelector('#username');
  const emailInput = form.querySelector('#email');
  const passwordInput = form.querySelector('#password');
  const confirmPasswordInput = form.querySelector('#confirm-password');

  const showError = (input, message) => {
    const errorSpan = input.parentElement.querySelector('.error-message');
    errorSpan.textContent = message;
    input.setAttribute('aria-invalid', 'true');
  };

  const clearError = (input) => {
    const errorSpan = input.parentElement.querySelector('.error-message');
    errorSpan.textContent = '';
    input.removeAttribute('aria-invalid');
  };

  const validateUsername = () => {
    const username = usernameInput.value.trim();
    if (username === '') {
      showError(usernameInput, 'Username is required.');
      return false;
    }
    clearError(usernameInput);
    return true;
  };

  const validateEmail = () => {
    const email = emailInput.value.trim();
    // Simple email regex for demonstration
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (email === '') {
      showError(emailInput, 'Email address is required.');
      return false;
    } else if (!emailRegex.test(email)) {
      showError(emailInput, 'Please enter a valid email address.');
      return false;
    }
    clearError(emailInput);
    return true;
  };

  const validatePassword = () => {
    const password = passwordInput.value;
    if (password.length < 8) {
      showError(passwordInput, 'Password must be at least 8 characters long.');
      return false;
    }
    clearError(passwordInput);
    return true;
  };

  const validateConfirmPassword = () => {
    const password = passwordInput.value;
    const confirmPassword = confirmPasswordInput.value;
    if (confirmPassword !== password) {
      showError(confirmPasswordInput, 'Passwords do not match.');
      return false;
    }
    clearError(confirmPasswordInput);
    return true;
  };

  usernameInput.addEventListener('input', validateUsername);
  emailInput.addEventListener('input', validateEmail);
  passwordInput.addEventListener('input', validatePassword);
  confirmPasswordInput.addEventListener('input', validateConfirmPassword);

  form.addEventListener('submit', (event) => {
    event.preventDefault();

    const isUsernameValid = validateUsername();
    const isEmailValid = validateEmail();
    const isPasswordValid = validatePassword();
    const isConfirmPasswordValid = validateConfirmPassword();

    if (isUsernameValid && isEmailValid && isPasswordValid && isConfirmPasswordValid) {
      // Normally here we would send data to the server
      // For demo, we just simulate account creation success
      alert('Account created successfully!');
      form.reset();
    }
  });
});