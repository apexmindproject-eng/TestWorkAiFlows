document.addEventListener('DOMContentLoaded', () => {
  const quizForm = document.getElementById('recyclingQuiz');
  const quizResults = document.getElementById('quizResults');
  const scoreText = document.getElementById('scoreText');
  const feedbackText = document.getElementById('feedbackText');
  const submitBtn = document.getElementById('submitQuiz');
  const resetBtn = document.getElementById('resetQuiz');

  const correctAnswers = {
    q1: ['paper', 'plastic', 'glass'],
    q2: 'cleaning',
    q3: 'plastic_bag',
    q4: '450_years'
  };

  function calculateScore(formData) {
    let score = 0;
    let total = Object.keys(correctAnswers).length;

    // Question 1: multiple checkboxes
    const q1Answers = formData.getAll('q1');
    const correctQ1 = correctAnswers.q1;
    const q1CorrectCount = q1Answers.filter(ans => correctQ1.includes(ans)).length;
    if (q1CorrectCount === correctQ1.length && q1Answers.length === correctQ1.length) {
      score++;
    }

    // Questions 2-4: single radio selections
    for (let i = 2; i <= 4; i++) {
      const qKey = 'q' + i;
      if (formData.get(qKey) === correctAnswers[qKey]) {
        score++;
      }
    }

    return { score, total };
  }

  function getFeedback(score, total) {
    const percent = (score / total) * 100;
    if (percent === 100) {
      return 'Excellent! You have great knowledge about recycling.';
    } else if (percent >= 75) {
      return 'Good job! You know a lot, but there is room to learn more.';
    } else if (percent >= 50) {
      return 'Not bad, but consider reviewing recycling guides for more info.';
    } else {
      return 'Keep learning about recycling to help protect our planet!';
    }
  }

  quizForm.addEventListener('submit', e => {
    e.preventDefault();
    const formData = new FormData(quizForm);
    const { score, total } = calculateScore(formData);

    scoreText.textContent = `You scored ${score} out of ${total}.`;
    feedbackText.textContent = getFeedback(score, total);

    quizResults.hidden = false;
    quizResults.focus();
  });

  resetBtn.addEventListener('click', () => {
    quizForm.reset();
    quizResults.hidden = true;
    scoreText.textContent = '';
    feedbackText.textContent = '';
  });
});