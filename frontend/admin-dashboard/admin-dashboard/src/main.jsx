import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import App from './App.jsx'
import i18n from './i18n'

const mountApp = () => {
  try {
    console.log('Mounting React application...')
    createRoot(document.getElementById('root')).render(
      <App />
    )
    console.log('React application mounted successfully')
  } catch (error) {
    console.error('Failed to mount React application:', error)
    document.getElementById('root').innerHTML = `
      <div style="padding: 20px; text-align: center;">
        <h1>Error Loading Application</h1>
        <p>${error.message}</p>
        <button onclick="window.location.reload()">Reload Page</button>
      </div>
    `
  }
}

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
