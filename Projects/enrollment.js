document.addEventListener('DOMContentLoaded', () => {
  const enrollmentForm = document.getElementById('enrollmentForm');

  enrollmentForm.addEventListener('submit', (event) => {
    event.preventDefault();

    // Simple validation and data gathering
    const fullName = enrollmentForm.fullName.value.trim();
    const dob = enrollmentForm.dob.value;
    const email = enrollmentForm.email.value.trim();
    const phone = enrollmentForm.phone.value.trim();
    const program = enrollmentForm.program.value;
    const experience = enrollmentForm.experience.value.trim();

    if (!fullName || !dob || !email || !phone || !program) {
      alert('Please fill out all required fields before submitting.');
      return;
    }

    // Additional validations can be done here (e.g. email format, phone pattern)

    // Package enrollment data
    const enrollmentData = {
      fullName,
      dob,
      email,
      phone,
      program,
      experience
    };

    // Simulate form submission or integration
    console.log('Enrollment Form Submitted:', enrollmentData);

    // Provide user feedback
    alert('Thank you for enrolling in the ' + program.replace(/([A-Z])/g, ' $1').trim() + ' program. We will contact you shortly via email.');

    // Reset the form after submission
    enrollmentForm.reset();
  });
});