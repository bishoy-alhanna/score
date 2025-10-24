import React, { useState, useEffect } from 'react'
import { BrowserRouter as Router, Routes, Route, Navigate, Link, useLocation } from 'react-router-dom'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { Badge } from '@/components/ui/badge'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle, DialogTrigger } from '@/components/ui/dialog'
import { 
  Users, UserPlus, Trophy, BarChart3, Settings, LogOut, Building2, 
  UserCheck, UserX, Clock, Plus, CheckCircle, XCircle 
} from 'lucide-react'
import axios from 'axios'
import ErrorBoundary from '@/components/ErrorBoundary'
import LoadingSpinner from '@/components/ui/loading-spinner'
import './App.css'

// API configuration
const API_BASE_URL = 'http://localhost:5000/api'

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
    const { token, user } = response.data
    localStorage.setItem('authToken', token)
    setUser(user)
    
    // Set current organization if user has organizations
    if (user.organizations && user.organizations.length > 0) {
      setCurrentOrganization(user.organizations[0])
    }
    
    return response.data
  }

  const createOrganization = async (orgData) => {
    const response = await api.post('/auth/create-organization', orgData)
    const { token, user, organization } = response.data
    localStorage.setItem('authToken', token)
    setUser(user)
    
    // Set the new organization as current
    const newOrgMembership = user.organizations?.find(
      org => org.organization_id === organization.id
    )
    setCurrentOrganization(newOrgMembership)
    
    return response.data
  }

  const switchOrganization = async (organizationId) => {
    const response = await api.post('/auth/switch-organization', { organization_id: organizationId })
    const { token, user } = response.data
    localStorage.setItem('authToken', token)
    setUser(user)
    
    const org = user.organizations?.find(org => org.organization_id === organizationId)
    setCurrentOrganization(org)
    
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
      createOrganization,
      switchOrganization,
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

// Login/Register component
function LoginRegister() {
  const [isLogin, setIsLogin] = useState(true)
  const [credentials, setCredentials] = useState({ 
    username: '', 
    password: '', 
    email: '',
    first_name: '',
    last_name: ''
  })
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const { login } = useAuth()

  const handleSubmit = async (e) => {
    e.preventDefault()
    setLoading(true)
    setError('')

    try {
      if (isLogin) {
        await login(credentials)
      } else {
        // Register new user
        const response = await api.post('/auth/register', credentials)
        const { token, user } = response.data
        localStorage.setItem('authToken', token)
        window.location.reload() // Refresh to get user data
      }
    } catch (error) {
      setError(error.response?.data?.error || 'Operation failed')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50">
      <Card className="w-full max-w-md">
        <CardHeader>
          <CardTitle>{isLogin ? 'Sign In' : 'Register'}</CardTitle>
          <CardDescription>
            {isLogin ? 'Sign in to your account' : 'Create a new account'}
          </CardDescription>
        </CardHeader>
        <CardContent>
          {error && (
            <Alert variant="destructive" className="mb-4">
              <AlertDescription>{error}</AlertDescription>
            </Alert>
          )}
          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <Label htmlFor="username">Username</Label>
              <Input
                id="username"
                type="text"
                value={credentials.username}
                onChange={(e) => setCredentials({ ...credentials, username: e.target.value })}
                required
              />
            </div>
            
            {!isLogin && (
              <>
                <div>
                  <Label htmlFor="email">Email</Label>
                  <Input
                    id="email"
                    type="email"
                    value={credentials.email}
                    onChange={(e) => setCredentials({ ...credentials, email: e.target.value })}
                    required
                  />
                </div>
                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <Label htmlFor="first_name">First Name</Label>
                    <Input
                      id="first_name"
                      type="text"
                      value={credentials.first_name}
                      onChange={(e) => setCredentials({ ...credentials, first_name: e.target.value })}
                    />
                  </div>
                  <div>
                    <Label htmlFor="last_name">Last Name</Label>
                    <Input
                      id="last_name"
                      type="text"
                      value={credentials.last_name}
                      onChange={(e) => setCredentials({ ...credentials, last_name: e.target.value })}
                    />
                  </div>
                </div>
              </>
            )}
            
            <div>
              <Label htmlFor="password">Password</Label>
              <Input
                id="password"
                type="password"
                value={credentials.password}
                onChange={(e) => setCredentials({ ...credentials, password: e.target.value })}
                required
              />
            </div>
            
            <Button type="submit" className="w-full" disabled={loading}>
              {loading ? 'Processing...' : (isLogin ? 'Sign In' : 'Register')}
            </Button>
          </form>
          
          <div className="mt-4 text-center">
            <Button
              variant="link"
              onClick={() => setIsLogin(!isLogin)}
              className="text-sm"
            >
              {isLogin ? "Don't have an account? Register" : "Already have an account? Sign In"}
            </Button>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}

// Organization selection/creation component
function OrganizationSetup() {
  const [showCreateForm, setShowCreateForm] = useState(false)
  const [availableOrgs, setAvailableOrgs] = useState([])
  const [orgData, setOrgData] = useState({ name: '', description: '' })
  const [joinRequestData, setJoinRequestData] = useState({
    organization_name: '',
    requested_role: 'USER',
    message: ''
  })
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const { createOrganization } = useAuth()

  useEffect(() => {
    fetchAvailableOrganizations()
  }, [])

  const fetchAvailableOrganizations = async () => {
    try {
      const response = await api.get('/auth/organizations')
      setAvailableOrgs(response.data.organizations)
    } catch (error) {
      console.error('Failed to fetch organizations:', error)
    }
  }

  const handleCreateOrganization = async (e) => {
    e.preventDefault()
    setLoading(true)
    setError('')

    try {
      await createOrganization(orgData)
    } catch (error) {
      setError(error.response?.data?.error || 'Failed to create organization')
    } finally {
      setLoading(false)
    }
  }

  const handleJoinRequest = async (e) => {
    e.preventDefault()
    setLoading(true)
    setError('')

    try {
      await api.post('/auth/request-join-organization', joinRequestData)
      alert('Join request submitted successfully!')
      setJoinRequestData({ organization_name: '', requested_role: 'USER', message: '' })
      fetchAvailableOrganizations()
    } catch (error) {
      setError(error.response?.data?.error || 'Failed to submit join request')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50">
      <div className="w-full max-w-4xl space-y-6">
        <Card>
          <CardHeader>
            <CardTitle>Organization Setup</CardTitle>
            <CardDescription>
              Create a new organization or request to join an existing one
            </CardDescription>
          </CardHeader>
          <CardContent>
            {error && (
              <Alert variant="destructive" className="mb-4">
                <AlertDescription>{error}</AlertDescription>
              </Alert>
            )}
            
            <Tabs defaultValue="create" className="w-full">
              <TabsList className="grid w-full grid-cols-2">
                <TabsTrigger value="create">Create Organization</TabsTrigger>
                <TabsTrigger value="join">Join Organization</TabsTrigger>
              </TabsList>
              
              <TabsContent value="create" className="space-y-4">
                <form onSubmit={handleCreateOrganization} className="space-y-4">
                  <div>
                    <Label htmlFor="org-name">Organization Name</Label>
                    <Input
                      id="org-name"
                      type="text"
                      value={orgData.name}
                      onChange={(e) => setOrgData({ ...orgData, name: e.target.value })}
                      required
                    />
                  </div>
                  <div>
                    <Label htmlFor="org-description">Description</Label>
                    <Input
                      id="org-description"
                      type="text"
                      value={orgData.description}
                      onChange={(e) => setOrgData({ ...orgData, description: e.target.value })}
                    />
                  </div>
                  <Button type="submit" disabled={loading}>
                    {loading ? 'Creating...' : 'Create Organization'}
                  </Button>
                </form>
              </TabsContent>
              
              <TabsContent value="join" className="space-y-4">
                <form onSubmit={handleJoinRequest} className="space-y-4">
                  <div>
                    <Label htmlFor="join-org-name">Organization Name</Label>
                    <Input
                      id="join-org-name"
                      type="text"
                      value={joinRequestData.organization_name}
                      onChange={(e) => setJoinRequestData({ 
                        ...joinRequestData, 
                        organization_name: e.target.value 
                      })}
                      placeholder="Enter organization name"
                      required
                    />
                  </div>
                  <div>
                    <Label htmlFor="requested-role">Requested Role</Label>
                    <Select 
                      value={joinRequestData.requested_role} 
                      onValueChange={(value) => setJoinRequestData({ 
                        ...joinRequestData, 
                        requested_role: value 
                      })}
                    >
                      <SelectTrigger>
                        <SelectValue placeholder="Select role" />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="USER">User</SelectItem>
                        <SelectItem value="ORG_ADMIN">Admin</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                  <div>
                    <Label htmlFor="join-message">Message (Optional)</Label>
                    <Input
                      id="join-message"
                      type="text"
                      value={joinRequestData.message}
                      onChange={(e) => setJoinRequestData({ 
                        ...joinRequestData, 
                        message: e.target.value 
                      })}
                      placeholder="Why do you want to join?"
                    />
                  </div>
                  <Button type="submit" disabled={loading}>
                    {loading ? 'Submitting...' : 'Submit Join Request'}
                  </Button>
                </form>

                {availableOrgs.length > 0 && (
                  <div className="mt-6">
                    <h3 className="text-lg font-semibold mb-4">Available Organizations</h3>
                    <div className="grid gap-4">
                      {availableOrgs.map((org) => (
                        <Card key={org.id}>
                          <CardContent className="p-4">
                            <div className="flex justify-between items-center">
                              <div>
                                <h4 className="font-medium">{org.name}</h4>
                                <p className="text-sm text-gray-600">{org.description}</p>
                                <p className="text-xs text-gray-500">{org.member_count} members</p>
                              </div>
                              <div>
                                {org.is_member ? (
                                  <Badge variant="success">Member</Badge>
                                ) : org.has_pending_request ? (
                                  <Badge variant="secondary">
                                    <Clock className="h-3 w-3 mr-1" />
                                    Pending
                                  </Badge>
                                ) : (
                                  <Button
                                    size="sm"
                                    onClick={() => setJoinRequestData({
                                      ...joinRequestData,
                                      organization_name: org.name
                                    })}
                                  >
                                    Request Join
                                  </Button>
                                )}
                              </div>
                            </div>
                          </CardContent>
                        </Card>
                      ))}
                    </div>
                  </div>
                )}
              </TabsContent>
            </Tabs>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}

// Rest of the existing components (Dashboard, DashboardLayout, etc.) would remain similar
// but updated to work with the multi-organization context...

function App() {
  return (
    <ErrorBoundary>
      <AuthProvider>
        <Router>
          <AppContent />
        </Router>
      </AuthProvider>
    </ErrorBoundary>
  )
}

function AppContent() {
  const { user, currentOrganization, loading } = useAuth()

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <LoadingSpinner size="xl" text="Loading application..." />
      </div>
    )
  }

  if (!user) {
    return <LoginRegister />
  }

  // If user has no organizations, show organization setup
  if (!user.organizations || user.organizations.length === 0) {
    return <OrganizationSetup />
  }

  // Check if user is admin of current organization
  const isAdmin = currentOrganization?.role === 'ORG_ADMIN' || currentOrganization?.role === 'SUPER_ADMIN'

  if (!isAdmin) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <Alert variant="destructive">
          <AlertDescription>
            Access denied. This dashboard is only available to organization administrators.
          </AlertDescription>
        </Alert>
      </div>
    )
  }

  // For now, return a simple admin interface - you can expand this
  return (
    <div className="min-h-screen bg-gray-50">
      <header className="bg-white shadow-sm border-b">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center h-16">
            <div className="flex items-center space-x-8">
              <div className="flex items-center">
                <Building2 className="h-8 w-8 text-blue-600" />
                <h1 className="ml-2 text-xl font-semibold text-gray-900">
                  Admin Dashboard
                </h1>
              </div>
            </div>
            <div className="flex items-center space-x-4">
              <Badge variant="secondary">{currentOrganization?.role}</Badge>
              <span className="text-sm text-gray-700">{currentOrganization?.organization_name}</span>
              <span className="text-sm text-gray-700">{user?.username}</span>
              <Button variant="outline" size="sm" onClick={() => {}}>
                <LogOut className="h-4 w-4 mr-2" />
                Logout
              </Button>
            </div>
          </div>
        </div>
      </header>
      <main className="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
        <Card>
          <CardHeader>
            <CardTitle>Multi-Organization Admin Dashboard</CardTitle>
            <CardDescription>
              Welcome to the enhanced admin dashboard with multi-organization support
            </CardDescription>
          </CardHeader>
          <CardContent>
            <p>Dashboard functionality will be implemented here...</p>
          </CardContent>
        </Card>
      </main>
    </div>
  )
}

export default App