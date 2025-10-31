// chartRenderer.js - Manages rendering stock market interactive charts and UI controls across the site
// This script is focused on the analysis page primarily but adds graceful handling on other pages

const chartRenderer = (() => {
 const canvasId = 'stock-chart';
 let chart = null; // Canvas 2D context or chart instance
 let animationFrameId = null;

 // Chart data and config
 let chartData = [];
 let chartOptions = {
 width: 800,
 height: 400,
 padding: 50,
 lineColor: '#0074D9',
 gridColor: '#ddd',
 axisColor: '#333',
 backgroundColor: '#fff',
 };

 // Get DOM elements
 const canvas = document.getElementById(canvasId);

 // Utility: clear canvas
 const clearCanvas = () => {
 if (!canvas) return;
 const ctx = canvas.getContext('2d');
 ctx.clearRect(0, 0, canvas.width, canvas.height);
 };

 // Draw grid lines
 const drawGrid = (ctx, width, height, padding) => {
 ctx.strokeStyle = chartOptions.gridColor;
 ctx.lineWidth = 1;
 ctx.beginPath();

 const horizontalLines = 5;
 const verticalLines = 10;

 for (let i = 0; i <= horizontalLines; i++) {
 const y = padding + i * (height - 2 * padding) / horizontalLines;
 ctx.moveTo(padding, y);
 ctx.lineTo(width - padding, y);
 }

 for (let j = 0; j <= verticalLines; j++) {
 const x = padding + j * (width - 2 * padding) / verticalLines;
 ctx.moveTo(x, padding);
 ctx.lineTo(x, height - padding);
 }

 ctx.stroke();
 };

 // Draw axes
 const drawAxes = (ctx, width, height, padding) => {
 ctx.strokeStyle = chartOptions.axisColor;
 ctx.lineWidth = 2;
 ctx.beginPath();

 // Y-axis
 ctx.moveTo(padding, padding);
 ctx.lineTo(padding, height - padding);

 // X-axis
 ctx.lineTo(width - padding, height - padding);

 ctx.stroke();
 };

 // Draw line chart
 const drawLineChart = (ctx, data, width, height, padding) => {
 if (!data || data.length === 0) return;

 const maxY = Math.max(...data.map(d => d.value)) || 0;
 const minY = Math.min(...data.map(d => d.value)) || 0;
 const spreadY = maxY - minY || 1;

 const maxX = data.length - 1;

 ctx.strokeStyle = chartOptions.lineColor;
 ctx.lineWidth = 3;
 ctx.beginPath();

 data.forEach((point, index) => {
 const x = padding + (index / maxX) * (width - 2 * padding);
 // Map y to canvas coordinates (inverted y)
 const y = height - padding - ((point.value - minY) / spreadY) * (height - 2 * padding);

 if (index === 0) {
 ctx.moveTo(x, y);
 } else {
 ctx.lineTo(x, y);
 }
 });

 ctx.stroke();
 };

 // Draw labels on axes
 const drawLabels = (ctx, data, width, height, padding) => {
 if (!data || data.length === 0) return;

 ctx.fillStyle = chartOptions.axisColor;
 ctx.font = '12px Arial';
 ctx.textAlign = 'center';
 ctx.textBaseline = 'top';

 // X-axis labels: use data labels, but reduce label count to avoid crowding
 const maxLabels = 10;
 const step = Math.max(1, Math.floor(data.length / maxLabels));

 for (let i = 0; i < data.length; i += step) {
 const x = padding + (i / (data.length - 1)) * (width - 2 * padding);
 const label = data[i].label || '';
 ctx.fillText(label, x, height - padding + 5);
 }

 // Y-axis labels - evenly spaced numeric labels
 ctx.textAlign = 'right';
 ctx.textBaseline = 'middle';
 const horizontalLines = 5;
 const maxY = Math.max(...data.map(d => d.value)) || 0;
 const minY = Math.min(...data.map(d => d.value)) || 0;
 const spreadY = maxY - minY || 1;

 for (let i = 0; i <= horizontalLines; i++) {
 const y = padding + i * (height - 2 * padding) / horizontalLines;
 const value = (maxY - (i / horizontalLines) * spreadY).toFixed(2);
 ctx.fillText(value, padding - 10, y);
 }
 };

 // Resize canvas dynamically
 const resizeCanvas = () => {
 if (!canvas) return;

 // Use container width for responsive sizing
 const container = canvas.parentElement;
 if (!container) return;

 const containerWidth = container.clientWidth;
 canvas.width = containerWidth;
 canvas.height = chartOptions.height;
 };

 // Render full chart
 const renderChart = () => {
 if (!canvas) return;

 const ctx = canvas.getContext('2d');
 const width = canvas.width;
 const height = canvas.height;
 const padding = chartOptions.padding;

 clearCanvas();
 ctx.fillStyle = chartOptions.backgroundColor;
 ctx.fillRect(0, 0, width, height);

 drawGrid(ctx, width, height, padding);
 drawAxes(ctx, width, height, padding);
 drawLineChart(ctx, chartData, width, height, padding);
 drawLabels(ctx, chartData, width, height, padding);
 };

 // Generate dummy stock data for demonstration
 const generateDummyData = (points = 30) => {
 const data = [];
 let lastValue = 100 + Math.random() * 20;
 for (let i = 0; i < points; i++) {
 // Simulate small random walk
 lastValue += (Math.random() - 0.5) * 2;
 lastValue = Math.max(10, lastValue); // Clamp to positive

 // Generate label as date for the last N days
 const date = new Date();
 date.setDate(date.getDate() - (points - 1 - i));
 const label = `${date.getMonth() + 1}/${date.getDate()}`;

 data.push({ label, value: lastValue });
 }
 return data;
 };

 // Update chart data dynamically - could be hooked to live data source
 const updateChartData = (newData) => {
 if (!Array.isArray(newData)) return;
 chartData = newData.map(item => {
 // Defensive shape checking
 return {
 label: String(item.label || ''),
 value: Number(item.value) || 0
 };
 });
 renderChart();
 };

 // Smooth animation using requestAnimationFrame - example of simple animation for chart updating
 let animationProgress = 0;
 let animationDirection = 1;
 const animateChart = () => {
 if (!canvas) return;
 const ctx = canvas.getContext('2d');
 const width = canvas.width;
 const height = canvas.height;
 const padding = chartOptions.padding;

 clearCanvas();
 ctx.fillStyle = chartOptions.backgroundColor;
 ctx.fillRect(0, 0, width, height);

 drawGrid(ctx, width, height, padding);
 drawAxes(ctx, width, height, padding);

 // Animate data points by scaling their value
 const animatedData = chartData.map(d => ({
 label: d.label,
 value: d.value * animationProgress
 }));

 drawLineChart(ctx, animatedData, width, height, padding);
 drawLabels(ctx, animatedData, width, height, padding);

 animationProgress += 0.02 * animationDirection;
 if (animationProgress >= 1) {
 animationProgress = 1;
 animationDirection = -1;
 } else if (animationProgress <= 0) {
 animationProgress = 0;
 animationDirection = 1;
 }

 animationFrameId = window.requestAnimationFrame(animateChart);
 };

 // Setup event listeners for interactive controls (placeholders)
 const setupAnalysisTools = () => {
 // Search for #tools-panel and add controls for chart customization
 const toolsPanel = document.getElementById('tools-panel');
 if (!toolsPanel) return;

 toolsPanel.innerHTML = '';

 const labelSelect = document.createElement('select');
 labelSelect.id = 'indicator-select';
 labelSelect.setAttribute('aria-label', 'Select chart indicator');

 const defaultOption = document.createElement('option');
 defaultOption.value = '';
 defaultOption.textContent = 'Select Indicator';
 labelSelect.appendChild(defaultOption);

 ['Moving Average', 'Relative Strength Index (RSI)', 'MACD'].forEach(indicator => {
 const option = document.createElement('option');
 option.value = indicator.toLowerCase().replace(/[\s()]/g, '-');
 option.textContent = indicator;
 labelSelect.appendChild(option);
 });

 toolsPanel.appendChild(labelSelect);

 // Event delegation for future controls
 toolsPanel.addEventListener('change', event => {
 if (event.target.id === 'indicator-select') {
 const selected = event.target.value;
 // Simulate updating chart based on indicator
 try {
 if (!selected) {
 // Reset to default dummy data
 updateChartData(generateDummyData());
 return;
 }
 // For demo, just change line color or refresh data
 // In real app, would compute indicator data and refresh
 console.log(`Selected indicator: ${selected}`);
 const indicatorData = generateDummyData();
 updateChartData(indicatorData);
 } catch (e) {
 console.error('Error applying indicator:', e);
 }
 }
 });
 };

 // Responsive canvas resizing on window resize
 const onResize = () => {
 try {
 resizeCanvas();
 renderChart();
 } catch (e) {
 console.error('Resize error:', e);
 }
 };

 // Initialization
 const init = () => {
 // Only proceed if canvas exists (mostly on analysis.html)
 if (!canvas) return;

 resizeCanvas();

 // Load initial dummy data
 chartData = generateDummyData();

 renderChart();

 // Uncomment below to see animation demo
 // animateChart();

 setupAnalysisTools();

 window.addEventListener('resize', onResize);
 };

 // Cleanup
 const destroy = () => {
 if (animationFrameId) {
 window.cancelAnimationFrame(animationFrameId);
 animationFrameId = null;
 }
 window.removeEventListener('resize', onResize);
 };

 return {
 init,
 destroy,
 updateChartData
 };
})();

// Initialize on DOM ready

document.addEventListener('DOMContentLoaded', () => {
 try {
 chartRenderer.init();
 } catch (err) {
 console.error('Error initializing chartRenderer:', err);
 }
});

window.addEventListener('beforeunload', () => {
 chartRenderer.destroy();
});

//# sourceMappingURL=chartRenderer.js.map
