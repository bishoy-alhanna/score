const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');
const cors = require('cors');

const app = express();

// Enable CORS for all routes
app.use(cors({
  origin: true, // Allow all origins for local development
  credentials: true
}));

// Proxy middleware for API requests
app.use('/api', createProxyMiddleware({
  target: 'http://score.al-hanna.com',
  changeOrigin: true,
  timeout: 60000,
  onError: (err, req, res) => {
    console.error('Proxy error:', err);
    res.status(500).json({ error: 'Proxy error', message: err.message });
  },
  onProxyReq: (proxyReq, req, res) => {
    console.log(`Proxying request: ${req.method} ${req.url}`);
  }
}));

const PORT = process.env.PORT || 3001;

app.listen(PORT, () => {
  console.log(`CORS Proxy server running on http://localhost:${PORT}`);
  console.log(`Proxying API requests to http://score.al-hanna.com`);
});