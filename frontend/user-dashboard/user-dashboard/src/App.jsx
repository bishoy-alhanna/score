import React, { useState, useEffect } from 'react'
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { Badge } from '@/components/ui/badge'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { Progress } from '@/components/ui/progress'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { User, Trophy, Target, Users, LogOut, Medal, TrendingUp } from 'lucide-react'
import { BarChart, Bar, LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Legend } from 'recharts'
import axios from 'axios'
import ErrorBoundary from '@/components/ErrorBoundary'
import LoadingSpinner from '@/components/ui/loading-spinner'
import UserProfile from '@/components/UserProfile'
import LanguageSwitcher from '@/components/LanguageSwitcher'
import TranslationWrapper from '@/components/TranslationWrapper'
import { useTranslation } from 'react-i18next'
import './i18n'
import './rtl.css'
import './App.css'

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

// Auth context
const AuthContext = React.createContext()

function AuthProvider({ children }) {
  const [user, setUser] = useState(null)
  const [currentOrganization, setCurrentOrganization] = useState(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const token = localStorage.getItem('authToken')
    if (token) {
      verifyToken(token)
    } else {
      setLoading(false)
    }
  }, [])

  const verifyToken = async (token) => {
    try {
      const response = await api.post('/auth/verify')
      setUser(response.data.user)
      if (response.data.current_organization_id) {
        const org = response.data.user.organizations?.find(
          org => org.organization_id === response.data.current_organization_id
        )
        setCurrentOrganization(org)
      }
    } catch (error) {
      localStorage.removeItem('authToken')
    } finally {
      setLoading(false)
    }
  }

  const login = async (credentials) => {
    const response = await api.post('/auth/login', credentials)
    const { token, user, organization_id } = response.data
    localStorage.setItem('authToken', token)
    setUser(user)
    
    // Set current organization from login response or find it in user organizations
    if (organization_id) {
      const org = user.organizations?.find(
        org => org.organization_id === organization_id
      )
      setCurrentOrganization(org)
    } else if (user.organizations && user.organizations.length > 0) {
      setCurrentOrganization(user.organizations[0])
    }
    
    return response.data
  }

  const logout = () => {
    localStorage.removeItem('authToken')
    setUser(null)
    setCurrentOrganization(null)
  }

  return (
    <AuthContext.Provider value={{ 
      user, 
      currentOrganization, 
      login, 
      logout, 
      loading 
    }}>
      {children}
    </AuthContext.Provider>
  )
}

function useAuth() {
  return React.useContext(AuthContext)
}

// Login component
function Login() {
  const [isLogin, setIsLogin] = useState(true)
  const [credentials, setCredentials] = useState({ username: '', password: '', organization_name: '' })
  const [registerData, setRegisterData] = useState({ 
    username: '', 
    email: '', 
    password: '', 
    confirmPassword: '',
    first_name: '', 
    last_name: '',
    organization_name: ''
  })
  const [organizations, setOrganizations] = useState([])
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const { login } = useAuth()
  const { t } = useTranslation()

  // Fetch organizations when component mounts
  useEffect(() => {
    const fetchOrganizations = async () => {
      try {
        const response = await api.get('/auth/organizations')
        setOrganizations(response.data.organizations)
      } catch (error) {
        console.error('Failed to fetch organizations:', error)
      }
    }
    
    fetchOrganizations()
  }, [])

  const handleLoginSubmit = async (e) => {
    e.preventDefault()
    setLoading(true)
    setError('')

    try {
      await login(credentials)
    } catch (error) {
      const errorData = error.response?.data
      
      if (errorData?.join_request_submitted) {
        setError(`Join request submitted to "${errorData.organization_name}". You will be able to login once your request is approved by an administrator.`)
      } else if (errorData?.join_request_exists) {
        setError(`You already have a pending join request for "${errorData.organization_name}". Please wait for approval or contact your administrator.`)
      } else if (errorData?.organization_not_found) {
        setError(errorData.error)
      } else {
        setError(errorData?.error || t('auth.loginError'))
      }
    } finally {
      setLoading(false)
    }
  }

  const handleRegisterSubmit = async (e) => {
    e.preventDefault()
    setLoading(true)
    setError('')

    if (registerData.password !== registerData.confirmPassword) {
      setError(t('auth.passwordsDoNotMatch'))
      setLoading(false)
      return
    }

    try {
      const response = await api.post('/auth/register', {
        username: registerData.username,
        email: registerData.email,
        password: registerData.password,
        first_name: registerData.first_name,
        last_name: registerData.last_name,
        organization_name: registerData.organization_name
      })

      // Auto-login after successful registration
      if (response.data.token) {
        localStorage.setItem('authToken', response.data.token)
        // Redirect or refresh to load user data
        window.location.reload()
      } else {
        // If no auto-login, switch to login tab
        setIsLogin(true)
        setError('Registration successful! Please log in.')
      }
    } catch (error) {
      setError(error.response?.data?.error || 'Registration failed')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-blue-50 to-indigo-100">
      <Card className="w-full max-w-md">
        <CardHeader>
          <div className="flex justify-between items-center mb-4">
            <div className="flex-1"></div>
            <LanguageSwitcher />
          </div>
          <CardTitle className="text-2xl text-center">
            {isLogin ? t('auth.welcomeBack') : t('auth.joinUs')}
          </CardTitle>
          <CardDescription className="text-center">
            {isLogin ? t('auth.signInToViewDashboard') : t('auth.createAccountToGetStarted')}
          </CardDescription>
        </CardHeader>
        <CardContent>
          <Tabs value={isLogin ? 'login' : 'register'} className="w-full">
            <TabsList className="grid w-full grid-cols-2">
              <TabsTrigger value="login" onClick={() => setIsLogin(true)}>
                {t('auth.login')}
              </TabsTrigger>
              <TabsTrigger value="register" onClick={() => setIsLogin(false)}>
                {t('auth.register')}
              </TabsTrigger>
            </TabsList>
            
            <TabsContent value="login" className="mt-4">
              <form onSubmit={handleLoginSubmit} className="space-y-4">
                <div className="space-y-2">
                  <Label htmlFor="username">{t('auth.username')}</Label>
                  <Input
                    id="username"
                    type="text"
                    value={credentials.username}
                    onChange={(e) => setCredentials({ ...credentials, username: e.target.value })}
                    required
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="password">{t('auth.password')}</Label>
                  <Input
                    id="password"
                    type="password"
                    value={credentials.password}
                    onChange={(e) => setCredentials({ ...credentials, password: e.target.value })}
                    required
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="organization">{t('organizations.organizationName')}</Label>
                  <Select
                    value={credentials.organization_name}
                    onValueChange={(value) => setCredentials({ ...credentials, organization_name: value })}
                    required
                  >
                    <SelectTrigger>
                      <SelectValue placeholder={t('auth.selectOrganization')} />
                    </SelectTrigger>
                    <SelectContent>
                      {organizations.map((org) => (
                        <SelectItem key={org.id} value={org.name}>
                          {org.name}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                {error && (
                  <Alert variant="destructive">
                    <AlertDescription>{error}</AlertDescription>
                  </Alert>
                )}
                <Button type="submit" className="w-full" disabled={loading}>
                  {loading ? t('auth.signingIn') : t('auth.signIn')}
                </Button>
              </form>
            </TabsContent>

            <TabsContent value="register" className="mt-4">
              <form onSubmit={handleRegisterSubmit} className="space-y-4">
                <div className="grid grid-cols-2 gap-3">
                  <div className="space-y-2">
                    <Label htmlFor="firstName">{t('auth.firstName')}</Label>
                    <Input
                      id="firstName"
                      type="text"
                      value={registerData.first_name}
                      onChange={(e) => setRegisterData({ ...registerData, first_name: e.target.value })}
                      required
                    />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="lastName">{t('auth.lastName')}</Label>
                    <Input
                      id="lastName"
                      type="text"
                      value={registerData.last_name}
                      onChange={(e) => setRegisterData({ ...registerData, last_name: e.target.value })}
                      required
                    />
                  </div>
                </div>
                <div className="space-y-2">
                  <Label htmlFor="regUsername">{t('auth.username')}</Label>
                  <Input
                    id="regUsername"
                    type="text"
                    value={registerData.username}
                    onChange={(e) => setRegisterData({ ...registerData, username: e.target.value })}
                    required
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="email">{t('auth.email')}</Label>
                  <Input
                    id="email"
                    type="email"
                    value={registerData.email}
                    onChange={(e) => setRegisterData({ ...registerData, email: e.target.value })}
                    required
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="regOrganization">{t('organizations.organizationName')}</Label>
                  <Select
                    value={registerData.organization_name}
                    onValueChange={(value) => setRegisterData({ ...registerData, organization_name: value })}
                    required
                  >
                    <SelectTrigger>
                      <SelectValue placeholder={t('auth.selectOrganization')} />
                    </SelectTrigger>
                    <SelectContent>
                      {organizations.map((org) => (
                        <SelectItem key={org.id} value={org.name}>
                          {org.name}
                          {org.description && (
                            <span className="text-gray-500 text-sm"> - {org.description}</span>
                          )}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <div className="space-y-2">
                  <Label htmlFor="regPassword">{t('auth.password')}</Label>
                  <Input
                    id="regPassword"
                    type="password"
                    value={registerData.password}
                    onChange={(e) => setRegisterData({ ...registerData, password: e.target.value })}
                    required
                    minLength="8"
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="confirmPassword">{t('auth.confirmPassword')}</Label>
                  <Input
                    id="confirmPassword"
                    type="password"
                    value={registerData.confirmPassword}
                    onChange={(e) => setRegisterData({ ...registerData, confirmPassword: e.target.value })}
                    required
                    minLength="8"
                  />
                </div>
                {error && (
                  <Alert variant="destructive">
                    <AlertDescription>{error}</AlertDescription>
                  </Alert>
                )}
                <Button type="submit" className="w-full" disabled={loading}>
                  {loading ? t('auth.creatingAccount') : t('auth.createAccount')}
                </Button>
              </form>
            </TabsContent>
          </Tabs>
        </CardContent>
      </Card>
    </div>
  )
}

// Dashboard layout
function DashboardLayout({ children }) {
  const { user, logout } = useAuth()
  const { t } = useTranslation()

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100">
      <header className="bg-white shadow-sm border-b">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center h-16">
            <div className="flex items-center">
              <Trophy className="h-8 w-8 text-blue-600" />
              <h1 className="ml-2 text-xl font-semibold text-gray-900">
                {t('dashboard.title')}
              </h1>
            </div>
            <div className="flex items-center space-x-4">
              <LanguageSwitcher />
              <Badge variant="secondary">{user?.role}</Badge>
              <div className="flex items-center space-x-3">
                <div className="w-8 h-8 rounded-full overflow-hidden bg-gray-200 flex items-center justify-center">
                  {user?.profile_picture_url ? (
                    <img 
                      src={user.profile_picture_url.startsWith('http') ? user.profile_picture_url : `${window.location.origin}${user.profile_picture_url}`} 
                      alt="Profile" 
                      className="w-full h-full object-cover"
                    />
                  ) : (
                    <User className="w-4 h-4 text-gray-400" />
                  )}
                </div>
                <span className="text-sm text-gray-700">{user?.username}</span>
              </div>
              <Button variant="outline" size="sm" onClick={logout}>
                <LogOut className="h-4 w-4 mr-2" />
                {t('auth.logout')}
              </Button>
            </div>
          </div>
        </div>
      </header>
      <main className="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
        {children}
      </main>
    </div>
  )
}

// Dashboard overview
function Dashboard() {
  const { user, currentOrganization } = useAuth()
  const { t } = useTranslation()
  const [userStats, setUserStats] = useState(null)
  const [leaderboard, setLeaderboard] = useState([])
  const [fullLeaderboard, setFullLeaderboard] = useState([])
  const [leaderboardLoading, setLeaderboardLoading] = useState(false)
  const [myGroups, setMyGroups] = useState([])
  const [loading, setLoading] = useState(true)
  const [weeklyData, setWeeklyData] = useState([])
  const [categories, setCategories] = useState([])
  const [chartLoading, setChartLoading] = useState(true)
  
  // Self-reporting state
  const [predefinedCategories, setPredefinedCategories] = useState([])
  const [selfReportData, setSelfReportData] = useState({
    category_id: '',
    date: new Date().toISOString().split('T')[0] // Today's date
  })
  const [selfReportLoading, setSelfReportLoading] = useState(false)
  const [selfReportMessage, setSelfReportMessage] = useState('')
  const [selfReportError, setSelfReportError] = useState('')

  useEffect(() => {
    if (currentOrganization?.organization_id) {
      fetchDashboardData()
      fetchWeeklyData()
      fetchPredefinedCategories()
    }
  }, [currentOrganization])

  useEffect(() => {
    // Load full leaderboard data on component mount
    if (currentOrganization?.organization_id) {
      fetchFullLeaderboard()
    }
  }, [currentOrganization])

  const fetchDashboardData = async () => {
    if (!currentOrganization?.organization_id) return
    
    try {
      const [statsResponse, leaderboardResponse, groupsResponse] = await Promise.all([
        api.get(`/scores/user/${user.id}/total?organization_id=${currentOrganization.organization_id}`).catch(() => ({ data: { total_score: 0, score_count: 0, average_score: 0 } })),
        api.get(`/leaderboards/users?limit=10&category=all&organization_id=${currentOrganization.organization_id}`).catch(() => ({ data: { leaderboard: [] } })),
        api.get('/groups/my-groups').catch(() => ({ data: { groups: [] } }))
      ])
      
      setUserStats(statsResponse.data)
      setLeaderboard(leaderboardResponse.data.leaderboard || [])
      setMyGroups(groupsResponse.data.groups || [])
    } catch (error) {
      console.error('Failed to fetch dashboard data:', error)
    } finally {
      setLoading(false)
    }
  }

  const fetchFullLeaderboard = async () => {
    if (!currentOrganization?.organization_id) return
    
    try {
      setLeaderboardLoading(true)
      const response = await api.get(`/leaderboards/users?limit=100&category=all&organization_id=${currentOrganization.organization_id}`)
      setFullLeaderboard(response.data.leaderboard || [])
    } catch (error) {
      console.error('Failed to fetch full leaderboard:', error)
      setFullLeaderboard([])
    } finally {
      setLeaderboardLoading(false)
    }
  }

  const fetchWeeklyData = async () => {
    if (!currentOrganization?.organization_id || !user?.id) return
    
    try {
      setChartLoading(true)
      const response = await api.get(`/scores/user/${user.id}/weekly-by-category?weeks=20`)
      setWeeklyData(response.data.weekly_data || [])
      setCategories(response.data.categories || [])
    } catch (error) {
      console.error('Failed to fetch weekly data:', error)
      setWeeklyData([])
      setCategories([])
    } finally {
      setChartLoading(false)
    }
  }

  const fetchPredefinedCategories = async () => {
    if (!currentOrganization?.organization_id) return
    
    try {
      const response = await api.get(`/scores/categories?organization_id=${currentOrganization.organization_id}`)
      // Filter only predefined categories
      const predefined = response.data.categories.filter(cat => cat.is_predefined)
      setPredefinedCategories(predefined)
    } catch (error) {
      console.error('Failed to fetch predefined categories:', error)
      setPredefinedCategories([])
    }
  }

  const handleSelfReport = async (e) => {
    e.preventDefault()
    if (!selfReportData.category_id || !selfReportData.date) {
      setSelfReportError('Please select a category and date')
      return
    }

    setSelfReportLoading(true)
    setSelfReportError('')
    setSelfReportMessage('')

    try {
      // First check if score already exists
      const checkResponse = await api.get(`/scores/user/${user.id}/check-score?category_id=${selfReportData.category_id}&date=${selfReportData.date}`)
      
      if (checkResponse.data.exists) {
        setSelfReportError('You already have a score for this category on this date')
        return
      }

      // Submit the self-report
      const response = await api.post(`/scores/user/${user.id}/self-report`, {
        category_id: selfReportData.category_id,
        date: selfReportData.date
      })

      setSelfReportMessage(response.data.message)
      
      // Reset form
      setSelfReportData({
        category_id: '',
        date: new Date().toISOString().split('T')[0]
      })

      // Refresh dashboard data
      fetchDashboardData()
      fetchWeeklyData()

    } catch (error) {
      setSelfReportError(error.response?.data?.error || 'Failed to submit score')
    } finally {
      setSelfReportLoading(false)
    }
  }

  if (loading) {
    return <div className="text-center py-8">{t('dashboard.loadingDashboard')}</div>
  }

  // Find user's rank in leaderboard
  const myRank = leaderboard.findIndex(entry => entry.user_id === user.id) + 1

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-3xl font-bold text-gray-900">
          {t('dashboard.welcomeBack')}, {user?.username}!
        </h2>
        <p className="text-gray-600">{t('dashboard.performanceOverview')}</p>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
        <Card className="bg-gradient-to-r from-blue-500 to-blue-600 text-white">
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">{t('dashboard.totalScore')}</CardTitle>
            <Target className="h-4 w-4" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{userStats?.total_score || 0}</div>
            <p className="text-xs opacity-80">
              {userStats?.score_count || 0} {t('dashboard.scoresRecorded')}
            </p>
          </CardContent>
        </Card>

        <Card className="bg-gradient-to-r from-green-500 to-green-600 text-white">
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">{t('dashboard.averageScore')}</CardTitle>
            <TrendingUp className="h-4 w-4" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">
              {userStats?.average_score ? userStats.average_score.toFixed(1) : '0.0'}
            </div>
            <p className="text-xs opacity-80">
              {t('dashboard.perAssignment')}
            </p>
          </CardContent>
        </Card>

        <Card className="bg-gradient-to-r from-purple-500 to-purple-600 text-white">
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">{t('dashboard.myRank')}</CardTitle>
            <Medal className="h-4 w-4" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">
              {myRank > 0 ? `#${myRank}` : 'N/A'}
            </div>
            <p className="text-xs opacity-80">
              {t('dashboard.inLeaderboard')}
            </p>
          </CardContent>
        </Card>

        <Card className="bg-gradient-to-r from-orange-500 to-orange-600 text-white">
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">{t('dashboard.myGroups')}</CardTitle>
            <Users className="h-4 w-4" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{myGroups.length}</div>
            <p className="text-xs opacity-80">
              {t('dashboard.groupsJoined')}
            </p>
          </CardContent>
        </Card>
      </div>

      {/* Self-Report Section */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center">
            <Target className="h-5 w-5 mr-2 text-green-500" />
            Record Your Activity
          </CardTitle>
          <CardDescription>
            Report your attendance for religious activities to earn points
          </CardDescription>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSelfReport} className="space-y-4">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <Label htmlFor="category">Activity Category</Label>
                <Select 
                  value={selfReportData.category_id} 
                  onValueChange={(value) => setSelfReportData({ ...selfReportData, category_id: value })}
                >
                  <SelectTrigger>
                    <SelectValue placeholder="Select an activity" />
                  </SelectTrigger>
                  <SelectContent>
                    {predefinedCategories.map((category) => (
                      <SelectItem key={category.id} value={category.id}>
                        {category.name} (Max: {category.max_score} points)
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>

              <div>
                <Label htmlFor="date">Date</Label>
                <Input
                  id="date"
                  type="date"
                  value={selfReportData.date}
                  onChange={(e) => setSelfReportData({ ...selfReportData, date: e.target.value })}
                  max={new Date().toISOString().split('T')[0]} // Can't select future dates
                  required
                />
              </div>
            </div>

            {selfReportError && (
              <Alert variant="destructive">
                <AlertDescription>{selfReportError}</AlertDescription>
              </Alert>
            )}

            {selfReportMessage && (
              <Alert className="border-green-200 bg-green-50">
                <AlertDescription className="text-green-800">{selfReportMessage}</AlertDescription>
              </Alert>
            )}

            <Button 
              type="submit" 
              disabled={selfReportLoading || !selfReportData.category_id || !selfReportData.date}
              className="w-full md:w-auto"
            >
              {selfReportLoading ? 'Submitting...' : 'Record Activity'}
            </Button>
          </form>
        </CardContent>
      </Card>

      {/* Main Content */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Leaderboard */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center">
              <Trophy className="h-5 w-5 mr-2 text-yellow-500" />
              {t('leaderboard.title')}
            </CardTitle>
            <CardDescription>{t('dashboard.topPerformers')}</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="space-y-3">
              {leaderboard.slice(0, 10).map((entry, index) => (
                <div 
                  key={entry.user_id} 
                  className={`flex items-center justify-between p-3 rounded-lg ${
                    entry.user_id === user.id ? 'bg-blue-50 border-2 border-blue-200' : 'bg-gray-50'
                  }`}
                >
                  <div className="flex items-center space-x-3">
                    <div className={`w-8 h-8 rounded-full flex items-center justify-center text-sm font-bold ${
                      index === 0 ? 'bg-yellow-500 text-white' :
                      index === 1 ? 'bg-gray-400 text-white' :
                      index === 2 ? 'bg-orange-500 text-white' :
                      'bg-gray-200 text-gray-700'
                    }`}>
                      {entry.rank}
                    </div>
                    <div className="w-10 h-10 rounded-full overflow-hidden bg-gray-200 flex items-center justify-center">
                      {entry.profile_picture_url ? (
                        <img 
                          src={entry.profile_picture_url.startsWith('http') ? entry.profile_picture_url : `${window.location.origin}${entry.profile_picture_url}`} 
                          alt="Profile" 
                          className="w-full h-full object-cover"
                        />
                      ) : (
                        <User className="w-5 h-5 text-gray-400" />
                      )}
                    </div>
                    <div>
                      <p className="font-medium">
                        {entry.user_id === user.id ? 'You' : (entry.display_name || `User ${entry.user_id.slice(0, 8)}`)}
                      </p>
                      <p className="text-sm text-gray-600">{entry.score_count} scores</p>
                    </div>
                  </div>
                  <div className="text-right">
                    <p className="font-bold text-lg">{entry.total_score}</p>
                    <p className="text-sm text-gray-600">avg: {entry.average_score.toFixed(1)}</p>
                  </div>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>

        {/* My Groups */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center">
              <Users className="h-5 w-5 mr-2 text-blue-500" />
              {t('dashboard.myGroups')}
            </CardTitle>
            <CardDescription>{t('dashboard.groupsYoureAMemberOf')}</CardDescription>
          </CardHeader>
          <CardContent>
            {myGroups.length > 0 ? (
              <div className="space-y-3">
                {myGroups.map((group) => (
                  <div key={group.id} className="p-3 bg-gray-50 rounded-lg">
                    <div className="flex items-center justify-between">
                      <div>
                        <p className="font-medium">{group.name}</p>
                        <p className="text-sm text-gray-600">{group.description}</p>
                      </div>
                      <Badge variant={group.my_role === 'ADMIN' ? 'default' : 'secondary'}>
                        {group.my_role}
                      </Badge>
                    </div>
                    <div className="mt-2 text-sm text-gray-500">
                      {group.member_count} {t('dashboard.members')} • {t('dashboard.joined')} {new Date(group.joined_at).toLocaleDateString()}
                    </div>
                  </div>
                ))}
              </div>
            ) : (
              <div className="text-center py-8 text-gray-500">
                <Users className="h-12 w-12 mx-auto mb-4 opacity-50" />
                <p>{t('dashboard.notMemberOfAnyGroups')}</p>
              </div>
            )}
          </CardContent>
        </Card>
      </div>

      {/* Performance Chart */}
      <Card>
        <CardHeader>
          <CardTitle>{t('dashboard.performanceOverviewChart')}</CardTitle>
          <CardDescription>
            {t('dashboard.scoringHistoryAndTrends')} - {t('dashboard.categorizedWeeklyProgress')}
          </CardDescription>
        </CardHeader>
        <CardContent>
          {chartLoading ? (
            <div className="h-64 flex items-center justify-center">
              <LoadingSpinner size="md" text={t('dashboard.loadingChart')} />
            </div>
          ) : weeklyData.length > 0 ? (
            <div className="h-80">
              <ResponsiveContainer width="100%" height="100%">
                <LineChart data={weeklyData}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis dataKey="week" />
                  <YAxis />
                  <Tooltip 
                    formatter={(value, name) => [value, name]}
                    labelFormatter={(label) => `${label}`}
                  />
                  <Legend />
                  {categories.map((category, index) => {
                    const colors = ['#3b82f6', '#10b981', '#f59e0b', '#ef4444', '#8b5cf6', '#06b6d4']
                    return (
                      <Line
                        key={category}
                        type="monotone"
                        dataKey={category}
                        stroke={colors[index % colors.length]}
                        strokeWidth={2}
                        dot={{ r: 4 }}
                        activeDot={{ r: 6 }}
                      />
                    )
                  })}
                </LineChart>
              </ResponsiveContainer>
            </div>
          ) : (
            <div className="h-64 flex items-center justify-center text-gray-500">
              <div className="text-center">
                <TrendingUp className="h-12 w-12 mx-auto mb-4 opacity-50" />
                <p>{t('dashboard.noChartData')}</p>
              </div>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  )
}

// Profile component
function Profile() {
  const { user } = useAuth()
  const { t } = useTranslation()
  
  return (
    <div className="max-w-6xl mx-auto space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-gray-900">{t('profile.title')}</h2>
        <p className="text-gray-600">{t('profile.managePersonalInfo')}</p>
      </div>
      <UserProfile organizationId={user?.current_organization_id} />
    </div>
  )
}

// Main app component
function App() {
  return (
    <ErrorBoundary>
      <TranslationWrapper>
        <AuthProvider>
          <Router>
            <AppContent />
          </Router>
        </AuthProvider>
      </TranslationWrapper>
    </ErrorBoundary>
  )
}

function AppContent() {
  const { user, loading } = useAuth()
  const { t } = useTranslation()

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-blue-50 to-indigo-100">
        <LoadingSpinner size="xl" text="Loading application..." />
      </div>
    )
  }

  if (!user) {
    return <Login />
  }

  return (
    <DashboardLayout>
      <Tabs defaultValue="dashboard" className="w-full">
        <TabsList className="grid w-full grid-cols-3">
          <TabsTrigger value="dashboard">{t('navigation.dashboard')}</TabsTrigger>
          <TabsTrigger value="leaderboard">{t('navigation.leaderboard')}</TabsTrigger>
          <TabsTrigger value="profile">{t('navigation.profile')}</TabsTrigger>
        </TabsList>
        
        <TabsContent value="dashboard" className="mt-6">
          <Dashboard />
        </TabsContent>
        
        <TabsContent value="leaderboard" className="mt-6">
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center">
                <Trophy className="h-5 w-5 mr-2 text-yellow-500" />
                {t('leaderboard.title')}
              </CardTitle>
              <CardDescription>View the top performers in your organization</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="text-center py-8">
                <Trophy className="h-12 w-12 mx-auto text-gray-400 mb-4" />
                <p className="text-gray-600">Full leaderboard coming soon!</p>
                <p className="text-sm text-gray-500 mt-2">Check back later for complete rankings.</p>
              </div>
            </CardContent>
          </Card>
        </TabsContent>
        
        <TabsContent value="profile" className="mt-6">
          <Profile />
        </TabsContent>
      </Tabs>
    </DashboardLayout>
  )
}

export default App

