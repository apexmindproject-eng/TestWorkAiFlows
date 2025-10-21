document.addEventListener('DOMContentLoaded', function() {
    const contactForm = document.getElementById('contact-form');
    const formFields = {
        name: document.getElementById('name'),
        email: document.getElementById('email'),
        subject: document.getElementById('subject'),
        message: document.getElementById('message')
    };
    const submitBtn = document.getElementById('submit-btn');
    const formStatus = document.getElementById('form-status');

    // Form validation
    function validateForm() {
        let isValid = true;
        const errors = [];

        // Clear previous error states
        Object.values(formFields).forEach(field => {
            field.classList.remove('error');
        });

        // Validate name
        if (!formFields.name.value.trim()) {
            formFields.name.classList.add('error');
            errors.push('Name is required');
            isValid = false;
        }

        // Validate email
        const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (!formFields.email.value.trim()) {
            formFields.email.classList.add('error');
            errors.push('Email is required');
            isValid = false;
        } else if (!emailPattern.test(formFields.email.value)) {
            formFields.email.classList.add('error');
            errors.push('Please enter a valid email address');
            isValid = false;
        }

        // Validate message
        if (!formFields.message.value.trim()) {
            formFields.message.classList.add('error');
            errors.push('Message is required');
            isValid = false;
        } else if (formFields.message.value.trim().length < 10) {
            formFields.message.classList.add('error');
            errors.push('Message must be at least 10 characters long');
            isValid = false;
        }

        return { isValid, errors };
    }

    // Display form status
    function showFormStatus(message, type) {
        formStatus.textContent = message;
        formStatus.className = `form-status ${type}`;
        formStatus.style.display = 'block';
        
        setTimeout(() => {
            formStatus.style.display = 'none';
        }, 5000);
    }

    // Handle form submission
    function handleFormSubmit(event) {
        event.preventDefault();
        
        const validation = validateForm();
        
        if (!validation.isValid) {
            showFormStatus(validation.errors.join(', '), 'error');
            return;
        }

        // Show loading state
        submitBtn.disabled = true;
        submitBtn.textContent = 'Sending...';
        
        // Simulate form submission (since this is a catalog-only site)
        setTimeout(() => {
            showFormStatus('Thank you for your message! We will get back to you soon.', 'success');
            contactForm.reset();
            submitBtn.disabled = false;
            submitBtn.textContent = 'Send Message';
        }, 1500);
    }

    // Real-time validation feedback
    Object.entries(formFields).forEach(([fieldName, field]) => {
        field.addEventListener('blur', () => {
            const validation = validateForm();
            if (!validation.isValid) {
                // Only show error for the specific field being validated
                if (fieldName === 'name' && !field.value.trim()) {
                    field.classList.add('error');
                } else if (fieldName === 'email') {
                    const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
                    if (!field.value.trim() || !emailPattern.test(field.value)) {
                        field.classList.add('error');
                    }
                } else if (fieldName === 'message' && (!field.value.trim() || field.value.trim().length < 10)) {
                    field.classList.add('error');
                }
            }
        });

        field.addEventListener('input', () => {
            field.classList.remove('error');
        });
    });

    // Attach form submission handler
    if (contactForm) {
        contactForm.addEventListener('submit', handleFormSubmit);
    }

    // Character counter for message field
    if (formFields.message) {
        const messageCounter = document.createElement('div');
        messageCounter.className = 'character-counter';
        formFields.message.parentNode.appendChild(messageCounter);

        formFields.message.addEventListener('input', function() {
            const currentLength = this.value.length;
            const maxLength = 500;
            messageCounter.textContent = `${currentLength}/${maxLength} characters`;
            
            if (currentLength > maxLength) {
                this.value = this.value.substring(0, maxLength);
                messageCounter.textContent = `${maxLength}/${maxLength} characters`;
            }
        });
    }
});