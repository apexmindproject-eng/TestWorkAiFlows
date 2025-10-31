// analysisLogic.js - Contains advanced analysis algorithms and integration of tools with UI
// This script focuses primarily on the analysis page but gracefully integrates across site

const analysisLogic = (() => {
 // DOM Elements
 const toolsPanel = document.getElementById('tools-panel');
 const liveStockDataContainer = document.getElementById('live-stock-data');
 const chartCanvas = document.getElementById('stock-chart');

 // Private state to hold selected indicators and parameters
 let currentIndicators = [];

 /**
 * Helper: Calculate Simple Moving Average (SMA)
 * @param {Array<number>} data 
 * @param {number} windowSize 
 * @returns {Array<number>} smaData
 */
 const calculateSMA = (data, windowSize) => {
 if (!Array.isArray(data) || windowSize <= 0) return [];
 const sma = [];
 for (let i = 0; i < data.length; i++) {
 if (i < windowSize - 1) {
 sma.push(null); // Not enough data
 continue;
 }
 let sum = 0;
 for (let j = 0; j < windowSize; j++) {
 sum += data[i - j];
 }
 sma.push(sum / windowSize);
 }
 return sma;
 };

 /**
 * Helper: Calculate Relative Strength Index (RSI)
 * @param {Array<number>} data
 * @param {number} period
 * @returns {Array<number>} rsiData
 */
 const calculateRSI = (data, period = 14) => {
 if (!Array.isArray(data) || data.length < period) return [];
 const rsi = [];
 let gains = 0;
 let losses = 0;
 for (let i = 1; i <= period; i++) {
 const diff = data[i] - data[i - 1];
 if (diff >= 0) gains += diff;
 else losses -= diff;
 }
 let avgGain = gains / period;
 let avgLoss = losses / period;

 rsi[period] = avgLoss === 0 ? 100 : 100 - (100 / (1 + (avgGain / avgLoss)));

 for (let i = period + 1; i < data.length; i++) {
 const diff = data[i] - data[i - 1];
 if (diff >= 0) {
 avgGain = (avgGain * (period - 1) + diff) / period;
 avgLoss = (avgLoss * (period - 1)) / period;
 } else {
 avgGain = (avgGain * (period - 1)) / period;
 avgLoss = (avgLoss * (period - 1) - diff) / period;
 }
 rsi[i] = avgLoss === 0 ? 100 : 100 - (100 / (1 + (avgGain / avgLoss)));
 }

 // Pad initial values to null
 for (let i = 0; i < period; i++) {
 rsi[i] = null;
 }
 return rsi;
 };

 /**
 * Helper: Calculate Moving Average Convergence Divergence (MACD)
 * Returns an object with macdLine and signalLine arrays
 * @param {Array<number>} data
 * @param {number} shortPeriod
 * @param {number} longPeriod
 * @param {number} signalPeriod
 */
 const calculateMACD = (data, shortPeriod = 12, longPeriod = 26, signalPeriod = 9) => {
 if (!Array.isArray(data)) return { macdLine: [], signalLine: [] };

 const ema = (prices, period) => {
 const k = 2 / (period + 1);
 let emaArray = [];
 emaArray[0] = prices[0];
 for (let i = 1; i < prices.length; i++) {
 emaArray[i] = prices[i] * k + emaArray[i - 1] * (1 - k);
 }
 return emaArray;
 };

 const shortEMA = ema(data, shortPeriod);
 const longEMA = ema(data, longPeriod);

 const macdLine = shortEMA.map((v, i) => v - (longEMA[i] || 0));
 const signalLine = ema(macdLine, signalPeriod);

 return { macdLine, signalLine };
 };

 /**
 * Parse live stock data from data container to array of numbers for analysis
 * @returns {Array<number>} priceData
 */
 const parseLivePriceData = () => {
 if (!liveStockDataContainer) return [];
 try {
 const priceElements = liveStockDataContainer.querySelectorAll('.stock-price');
 const prices = [];
 priceElements.forEach(el => {
 const text = el.textContent || '';
 const value = parseFloat(text.replace(/[^0-9\.]/g, ''));
 if (!isNaN(value)) prices.push(value);
 });
 return prices;
 } catch (e) {
 console.error('Error parsing live price data:', e);
 return [];
 }
 };

 /**
 * Integrate indicator analysis results with UI (example: updates tools panel with results)
 * @param {string} indicator
 * @param {Array<number|null>} data
 */
 const displayAnalysisResults = (indicator, data) => {
 if (!toolsPanel) return;
 const resultsDivId = 'indicator-results';
 let resultsDiv = document.getElementById(resultsDivId);

 if (!resultsDiv) {
 resultsDiv = document.createElement('div');
 resultsDiv.id = resultsDivId;
 resultsDiv.setAttribute('aria-live', 'polite');
 resultsDiv.className = 'indicator-results';
 toolsPanel.appendChild(resultsDiv);
 }

 // Format output for display
 const formattedData = data.map(d => (d === null ? '-' : d.toFixed(2))).slice(-10); // last 10 points
 resultsDiv.innerHTML = `
 <h3>${indicator} Analysis (last 10 points)</h3>
 <p>${formattedData.join(', ')}</p>
 `; 
 };

 /**
 * Perform the selected indicator calculation and update chart and UI
 * @param {string} indicator
 */
 const performAnalysis = (indicator) => {
 if (!indicator || !chartCanvas) return;

 try {
 const priceData = parseLivePriceData();
 if (!priceData || priceData.length === 0) {
 console.warn('No price data available for analysis.');
 return;
 }

 let analysisData = [];

 switch (indicator) {
 case 'moving-average':
 analysisData = calculateSMA(priceData, 5); // 5-day SMA example
 displayAnalysisResults('Moving Average', analysisData);
 break;
 case 'relative-strength-index--rsi-':
 analysisData = calculateRSI(priceData, 14); // 14 days commonly used
 displayAnalysisResults('RSI', analysisData);
 break;
 case 'macd':
 const macdResult = calculateMACD(priceData);
 // For demo, display macdLine last 10 points
 displayAnalysisResults('MACD Line', macdResult.macdLine);
 break;
 default:
 console.warn('Unknown indicator selected:', indicator);
 displayAnalysisResults('None Selected', []);
 break;
 }

 // Potentially integrate with chartRenderer.js to update the displayed chart
 // This requires exporting updateChartData from chartRenderer
 if (typeof window.chartRenderer !== 'undefined' && window.chartRenderer.updateChartData) {
 // Map data points onto labels from chart if possible
 const labels = [];
 for (let i = 0; i < priceData.length; i++) {
 labels.push(i.toString());
 }

 let chartPoints = [];

 if (indicator === 'macd') {
 const macdData = calculateMACD(priceData);
 chartPoints = macdData.macdLine.map((val, idx) => ({ label: labels[idx] || '', value: val || 0 }));
 } else {
 chartPoints = analysisData.map((val, idx) => ({ label: labels[idx] || '', value: val || 0 }));
 }

 window.chartRenderer.updateChartData(chartPoints);
 }

 } catch (e) {
 console.error('Error performing analysis:', e);
 }
 };

 /**
 * Setup event delegation to handle interactive elements for analysis tools
 */
 const setupEventDelegation = () => {
 if (!toolsPanel) return;

 toolsPanel.addEventListener('change', event => {
 try {
 if (event.target.id === 'indicator-select') {
 const selected = event.target.value;
 performAnalysis(selected);
 }
 } catch (e) {
 console.error('Error handling toolsPanel change event:', e);
 }
 });
 };

 /**
 * Initialize analysis logic (only invoked on analysis.html)
 */
 const init = () => {
 if (!toolsPanel) return;
 setupEventDelegation();

 // Initialize with no indicator selected
 performAnalysis('');
 };

 // Cleanup to remove listeners or state
 const destroy = () => {
 if (toolsPanel) {
 toolsPanel.removeEventListener('change', () => {}); // Remove generic listener
 }
 currentIndicators = [];
 };

 return {
 init,
 destroy,
 performAnalysis
 };
})();

// Only initialize on analysis.html

document.addEventListener('DOMContentLoaded', () => {
 try {
 if (window.location.pathname.endsWith('analysis.html')) {
 analysisLogic.init();
 }
 } catch (err) {
 console.error('Error initializing analysisLogic:', err);
 }
});

window.addEventListener('beforeunload', () => {
 analysisLogic.destroy();
});

// Expose globally for integration with other modules
window.analysisLogic = analysisLogic;
