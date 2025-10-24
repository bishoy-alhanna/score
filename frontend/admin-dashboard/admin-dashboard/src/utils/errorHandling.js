/**
 * Error handling and logging utilities
 */

class Logger {
  constructor() {
    this.logLevel = import.meta.env.VITE_LOG_LEVEL || 'info'
    this.debugMode = import.meta.env.VITE_DEBUG_MODE === 'true'
  }

  debug(message, data = null) {
    if (this.debugMode && ['debug'].includes(this.logLevel)) {
      console.debug(`[DEBUG] ${message}`, data)
    }
  }

  info(message, data = null) {
    if (['debug', 'info'].includes(this.logLevel)) {
      console.info(`[INFO] ${message}`, data)
    }
  }

  warn(message, data = null) {
    if (['debug', 'info', 'warn'].includes(this.logLevel)) {
      console.warn(`[WARN] ${message}`, data)
    }
  }

  error(message, error = null) {
    console.error(`[ERROR] ${message}`, error)
    
    // In production, you might want to send errors to a logging service
    if (import.meta.env.NODE_ENV === 'production') {
      // Send to logging service (e.g., Sentry, LogRocket, etc.)
      this.sendToLoggingService(message, error)
    }
  }

  sendToLoggingService(message, error) {
    // Implementation would depend on your logging service
    // Example: Sentry.captureException(error)
  }
}

export const logger = new Logger()

/**
 * API Error Handler
 */
export class ApiError extends Error {
  constructor(message, status, response) {
    super(message)
    this.name = 'ApiError'
    this.status = status
    this.response = response
  }
}

/**
 * Handle API errors consistently
 */
export const handleApiError = (error, context = '') => {
  const contextPrefix = context ? `[${context}] ` : ''
  
  if (error.response) {
    // Server responded with error status
    const status = error.response.status
    const message = error.response.data?.error || error.response.data?.message || 'An error occurred'
    
    logger.error(`${contextPrefix}API Error ${status}: ${message}`, {
      url: error.config?.url,
      method: error.config?.method,
      status,
      response: error.response.data
    })
    
    switch (status) {
      case 401:
        // Unauthorized - redirect to login
        localStorage.removeItem('authToken')
        localStorage.removeItem('superAdminToken')
        window.location.reload()
        break
      case 403:
        return 'Access denied. You do not have permission to perform this action.'
      case 404:
        return 'The requested resource was not found.'
      case 422:
        return message // Validation errors
      case 500:
        return 'Internal server error. Please try again later.'
      default:
        return message
    }
  } else if (error.request) {
    // Network error
    logger.error(`${contextPrefix}Network Error: No response received`, {
      url: error.config?.url,
      method: error.config?.method
    })
    return 'Network error. Please check your connection and try again.'
  } else {
    // Other error
    logger.error(`${contextPrefix}Error: ${error.message}`, error)
    return error.message || 'An unexpected error occurred.'
  }
}

/**
 * Safe async function wrapper with error handling
 */
export const safeAsync = (asyncFn, context = '') => {
  return async (...args) => {
    try {
      return await asyncFn(...args)
    } catch (error) {
      const errorMessage = handleApiError(error, context)
      throw new Error(errorMessage)
    }
  }
}

/**
 * Validation utilities
 */
export const validators = {
  email: (email) => {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
    return emailRegex.test(email)
  },
  
  password: (password) => {
    // At least 8 characters, 1 uppercase, 1 lowercase, 1 number
    const passwordRegex = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)[a-zA-Z\d@$!%*?&]{8,}$/
    return passwordRegex.test(password)
  },
  
  username: (username) => {
    // 3-30 characters, alphanumeric and underscores only
    const usernameRegex = /^[a-zA-Z0-9_]{3,30}$/
    return usernameRegex.test(username)
  },
  
  organizationName: (name) => {
    // 2-100 characters, no special characters except spaces and hyphens
    const nameRegex = /^[a-zA-Z0-9\s\-]{2,100}$/
    return nameRegex.test(name)
  }
}

/**
 * Form validation helper
 */
export const validateForm = (data, rules) => {
  const errors = {}
  
  Object.keys(rules).forEach(field => {
    const value = data[field]
    const rule = rules[field]
    
    if (rule.required && (!value || value.trim() === '')) {
      errors[field] = `${rule.label || field} is required`
      return
    }
    
    if (value && rule.validator && !rule.validator(value)) {
      errors[field] = rule.message || `Invalid ${rule.label || field}`
    }
    
    if (value && rule.minLength && value.length < rule.minLength) {
      errors[field] = `${rule.label || field} must be at least ${rule.minLength} characters`
    }
    
    if (value && rule.maxLength && value.length > rule.maxLength) {
      errors[field] = `${rule.label || field} must be no more than ${rule.maxLength} characters`
    }
  })
  
  return {
    isValid: Object.keys(errors).length === 0,
    errors
  }
}

export default {
  logger,
  ApiError,
  handleApiError,
  safeAsync,
  validators,
  validateForm
}