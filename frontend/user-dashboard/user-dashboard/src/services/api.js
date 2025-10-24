import axios from 'axios'

// API configuration
const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || '/api'

// API service
const api = axios.create({
  baseURL: API_BASE_URL,
})

// Add auth token to requests
api.interceptors.request.use((config) => {
  const token = localStorage.getItem('authToken')
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

export default api