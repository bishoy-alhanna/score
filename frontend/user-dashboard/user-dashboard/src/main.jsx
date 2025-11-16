import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import App from './App.jsx'
import i18n from './i18n'

// Wait for i18n to be initialized before mounting React
console.log('Waiting for i18n initialization...')
i18n.on('initialized', () => {
  console.log('i18n initialized successfully')
  mountApp()
})

// Fallback: mount after 1 second if i18n doesn't emit initialized event
setTimeout(() => {
  if (!document.getElementById('root').hasChildNodes()) {
    console.log('i18n initialization timeout - mounting anyway')
    mountApp()
  }
}, 1000)

function mountApp() {
  try {
    const rootElement = document.getElementById('root')
    if (!rootElement) {
      throw new Error('Root element not found')
    }

    console.log('Mounting React application...')
    createRoot(rootElement).render(
      <StrictMode>
        <App />
      </StrictMode>,
    )
    console.log('React application mounted successfully')
  } catch (error) {
    console.error('Failed to mount React application:', error)
    // Fallback: Show error message
    document.getElementById('root').innerHTML = `
      <div style="padding: 20px; text-align: center; font-family: Arial, sans-serif;">
        <h1 style="color: #e74c3c;">Application Error</h1>
        <p>Failed to load the application. Please refresh the page.</p>
        <p style="color: #666; font-size: 14px;">${error.message}</p>
        <button onclick="location.reload()" style="margin-top: 20px; padding: 10px 20px; background: #3498db; color: white; border: none; border-radius: 4px; cursor: pointer;">
          Refresh Page
        </button>
      </div>
    `
  }
}
