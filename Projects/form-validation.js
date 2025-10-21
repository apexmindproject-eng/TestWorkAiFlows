'use strict';

// Form validation for signup.html
// Assumes form with id 'signup-form' with inputs: username, email, password, confirm-password

// Validates email format using built-in validity of input type=email
// Password min length 8 enforced by HTML minLength attribute
// Confirm password must match password

const signupForm = document.getElementById('signup-form');

if (signupForm) {
  const usernameInput = signupForm.querySelector('#username');
  const emailInput = signupForm.querySelector('#email');
  const passwordInput = signupForm.querySelector('#password');
  const confirmPasswordInput = signupForm.querySelector('#confirm-password');

  // Utility function to set error message on input's adjacent .error-message span
  function setError(input, message) {
    const errorSpan = input.parentElement.querySelector('.error-message');
    if (errorSpan) {
      errorSpan.textContent = message;
    }
    input.setAttribute('aria-invalid', 'true');
  }

  function clearError(input) {
    const errorSpan = input.parentElement.querySelector('.error-message');
    if (errorSpan) {
      errorSpan.textContent = '';
    }
    input.removeAttribute('aria-invalid');
  }

  // Validates all fields and returns true if valid
  function validateForm() {
    let valid = true;

    // Username required
    if (!usernameInput.value.trim()) {
      setError(usernameInput, 'Username is required.');
      valid = false;
    } else {
      clearError(usernameInput);
    }

    // Email required and valid email format
    if (!emailInput.value.trim()) {
      setError(emailInput, 'Email is required.');
      valid = false;
    } else if (!emailInput.checkValidity()) {
      setError(emailInput, 'Please enter a valid email address.');
      valid = false;
    } else {
      clearError(emailInput);
    }

    // Password required and minlength 8
    if (!passwordInput.value) {
      setError(passwordInput, 'Password is required.');
      valid = false;
    } else if (passwordInput.value.length < 8) {
      setError(passwordInput, 'Password must be at least 8 characters long.');
      valid = false;
    } else {
      clearError(passwordInput);
    }

    // Confirm password required and matches password
    if (!confirmPasswordInput.value) {
      setError(confirmPasswordInput, 'Please confirm your password.');
      valid = false;
    } else if (confirmPasswordInput.value !== passwordInput.value) {
      setError(confirmPasswordInput, 'Passwords do not match.');
      valid = false;
    } else {
      clearError(confirmPasswordInput);
    }

    return valid;
  }

  signupForm.addEventListener('submit', event => {
    event.preventDefault();
    if (validateForm()) {
      // Optionally you can submit the form or do further processing here
      signupForm.submit();
    }
  });

  // Real-time validation on input blur
  [usernameInput, emailInput, passwordInput, confirmPasswordInput].forEach(input => {
    input.addEventListener('blur', () => {
      validateForm();
    });
  });

}

// Additional generalized form validation could be included here if needed
