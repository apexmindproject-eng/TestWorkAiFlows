document.addEventListener('DOMContentLoaded', function() {
  // Example interactive functionality for programs page

  // Get all program articles
  const programArticles = document.querySelectorAll('.program-list .program');

  // Add click event to toggle details expand/collapse
  programArticles.forEach(article => {
    article.style.cursor = 'pointer';
    article.addEventListener('click', () => {
      // Toggle an expanded class to highlight or show more details
      article.classList.toggle('expanded');
      // For demonstration, toggle the paragraph text style
      const p = article.querySelector('p');
      if (article.classList.contains('expanded')) {
        p.style.fontWeight = 'bold';
        p.style.color = '#2a2a2a';
      } else {
        p.style.fontWeight = '';
        p.style.color = '';
      }
    });
  });
});