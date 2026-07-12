import React, { useState, useEffect, useRef } from 'react'
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
import { Checkbox } from '@/components/ui/checkbox'
import { 
  Users, UserPlus, Trophy, BarChart3, Settings, LogOut, Building2, 
  UserCheck, UserX, Clock, Plus, CheckCircle, XCircle, Shield,
  UsersIcon, Target, Award, Scan, TrendingUp, Tags, UserCog
} from 'lucide-react'
import axios from 'axios'
import ErrorBoundary from '@/components/ErrorBoundary'
import LoadingSpinner from '@/components/ui/loading-spinner'
import SuperAdminLogin from '@/components/SuperAdminLogin'
import SuperAdminDashboard from '@/components/SuperAdminDashboard'
import AdminLogin from '@/components/AdminLogin'
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

  console.log('AuthProvider mounted')

  useEffect(() => {
    const token = localStorage.getItem('authToken')
    console.log('Token from storage:', token ? 'exists' : 'null')
    if (token) {
      verifyToken(token)
    } else {
      // No token - show login immediately
      console.log('No token found - showing login page')
      setLoading(false)
    }
    
    // Failsafe: force show login after 2 seconds regardless
    const failsafe = setTimeout(() => {
      console.log('Failsafe timeout - forcing login page to show')
      setLoading(false)
    }, 2000)
    
    return () => clearTimeout(failsafe)
  }, [])

  const verifyToken = async (token) => {
    try {
      // Add timeout to prevent infinite loading
      const timeoutPromise = new Promise((_, reject) => 
        setTimeout(() => reject(new Error('Timeout')), 5000)
      )
      
      const response = await Promise.race([
        api.post('/auth/verify'),
        timeoutPromise
      ])
      
      setUser(response.data.user)
      if (response.data.current_organization_id) {
        const org = response.data.user.organizations?.find(
          org => org.organization_id === response.data.current_organization_id
        )
        setCurrentOrganization(org)
      }
    } catch (error) {
      console.log('Token verification failed:', error.message)
      localStorage.removeItem('authToken')
    } finally {
      setLoading(false)
    }
  }

  const login = async (loginData) => {
    // loginData is already the response from AdminLogin component's API call
    const { token, user, organization_id } = loginData
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
    
    return loginData
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

// Organization selection/creation component
function OrganizationSetup() {
  const { t } = useTranslation()
  const [showCreateForm, setShowCreateForm] = useState(false)
  const [availableOrgs, setAvailableOrgs] = useState([])
  const [orgData, setOrgData] = useState({ name: '', description: '' })
  const [joinRequestData, setJoinRequestData] = useState({
    organization_id: '',
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
      setError(error.response?.data?.error || t('organizations.failedToCreateOrg'))
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
      alert(t('organizations.joinRequestSubmitted'))
      setJoinRequestData({ organization_id: '', requested_role: 'USER', message: '' })
      fetchAvailableOrganizations()
    } catch (error) {
      setError(error.response?.data?.error || t('organizations.failedToSubmitRequest'))
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
                <TabsTrigger value="create">{t('organizations.createOrganization')}</TabsTrigger>
                <TabsTrigger value="join">{t('organizations.joinOrganization')}</TabsTrigger>
              </TabsList>
              
              <TabsContent value="create" className="space-y-4">
                <form onSubmit={handleCreateOrganization} className="space-y-4">
                  <div>
                    <Label htmlFor="org-name">{t('organizations.organizationName')}</Label>
                    <Input
                      id="org-name"
                      type="text"
                      value={orgData.name}
                      onChange={(e) => setOrgData({ ...orgData, name: e.target.value })}
                      required
                    />
                  </div>
                  <div>
                    <Label htmlFor="org-description">{t('organizations.description')}</Label>
                    <Input
                      id="org-description"
                      type="text"
                      value={orgData.description}
                      onChange={(e) => setOrgData({ ...orgData, description: e.target.value })}
                    />
                  </div>
                  <Button type="submit" disabled={loading}>
                    {loading ? t('organizations.creating') : t('organizations.createOrganization')}
                  </Button>
                </form>
              </TabsContent>
              
              <TabsContent value="join" className="space-y-4">
                <form onSubmit={handleJoinRequest} className="space-y-4">
                  <div>
                    <Label htmlFor="join-org-name">{t('organizations.organization')}</Label>
                    <Select 
                      value={joinRequestData.organization_id} 
                      onValueChange={(value) => setJoinRequestData({ 
                        ...joinRequestData, 
                        organization_id: value 
                      })}
                    >
                      <SelectTrigger>
                        <SelectValue placeholder={t('organizations.selectOrganization')} />
                      </SelectTrigger>
                      <SelectContent>
                        {availableOrgs
                          .filter(org => !org.is_member && !org.has_pending_request)
                          .map((org) => (
                            <SelectItem key={org.id} value={org.id}>
                              {org.name}
                            </SelectItem>
                          ))}
                      </SelectContent>
                    </Select>
                  </div>
                  <div>
                    <Label htmlFor="requested-role">{t('organizations.requestedRole')}</Label>
                    <Select 
                      value={joinRequestData.requested_role} 
                      onValueChange={(value) => setJoinRequestData({ 
                        ...joinRequestData, 
                        requested_role: value 
                      })}
                    >
                      <SelectTrigger>
                        <SelectValue placeholder={t('organizations.selectRole')} />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="USER">{t('organizations.user')}</SelectItem>
                        <SelectItem value="ORG_ADMIN">{t('organizations.admin')}</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                  <div>
                    <Label htmlFor="join-message">{t('organizations.optionalMessage')}</Label>
                    <Input
                      id="join-message"
                      type="text"
                      value={joinRequestData.message}
                      onChange={(e) => setJoinRequestData({ 
                        ...joinRequestData, 
                        message: e.target.value 
                      })}
                      placeholder={t('organizations.whyJoinQuestion')}
                    />
                  </div>
                  <Button type="submit" disabled={loading}>
                    {loading ? t('organizations.submitting') : t('organizations.submitJoinRequest')}
                  </Button>
                </form>

                {availableOrgs.length > 0 && (
                  <div className="mt-6">
                    <h3 className="text-lg font-semibold mb-4">{t('organizations.availableOrganizations')}</h3>
                    <div className="grid gap-4">
                      {availableOrgs.map((org) => (
                        <Card key={org.id}>
                          <CardContent className="p-4">
                            <div className="flex justify-between items-center">
                              <div>
                                <h4 className="font-medium">{org.name}</h4>
                                <p className="text-sm text-gray-600">{org.description}</p>
                                <p className="text-xs text-gray-500">{org.member_count} {t('organizations.members')}</p>
                              </div>
                              <div>
                                {org.is_member ? (
                                  <Badge variant="success">{t('organizations.member')}</Badge>
                                ) : org.has_pending_request ? (
                                  <Badge variant="secondary">
                                    <Clock className="h-3 w-3 mr-1" />
                                    {t('organizations.pending')}
                                  </Badge>
                                ) : (
                                  <Button
                                    size="sm"
                                    onClick={() => setJoinRequestData({
                                      ...joinRequestData,
                                      organization_name: org.name
                                    })}
                                  >
                                    {t('organizations.requestJoin')}
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
  console.log('App component rendering')
  const [superAdminMode, setSuperAdminMode] = useState(false)
  const [superAdmin, setSuperAdmin] = useState(null)

  useEffect(() => {
    console.log('App useEffect running')
    // Check if super admin is already logged in
    const superAdminToken = localStorage.getItem('superAdminToken')
    const superAdminData = localStorage.getItem('superAdminData')
    
    console.log('Super admin token:', superAdminToken ? 'exists' : 'null')
    
    if (superAdminToken && superAdminData) {
      setSuperAdmin(JSON.parse(superAdminData))
      setSuperAdminMode(true)
    }
  }, [])

  const handleSuperAdminLogin = (adminData) => {
    setSuperAdmin(adminData)
    setSuperAdminMode(true)
  }

  const handleSuperAdminLogout = () => {
    localStorage.removeItem('superAdminToken')
    localStorage.removeItem('superAdminData')
    setSuperAdmin(null)
    setSuperAdminMode(false)
  }

  const toggleAdminMode = () => {
    if (superAdminMode) {
      // Switch to regular admin mode
      setSuperAdminMode(false)
    } else {
      // Switch to super admin mode if logged in, otherwise show login
      if (superAdmin) {
        setSuperAdminMode(true)
      } else {
        // Show super admin login
        setSuperAdminMode(true)
      }
    }
  }

  if (superAdminMode) {
    if (!superAdmin) {
      return <SuperAdminLogin onLoginSuccess={handleSuperAdminLogin} />
    }
    return (
      <div>
        {/* Switch Mode Button */}
        <div className="fixed top-4 left-4 z-50">
          <Button
            variant="outline"
            size="sm"
            onClick={toggleAdminMode}
            className="bg-white border-gray-300"
          >
            <Building2 className="h-4 w-4 mr-2" />
            Switch to Org Admin
          </Button>
        </div>
        <SuperAdminDashboard onLogout={handleSuperAdminLogout} />
      </div>
    )
  }

  // Regular admin dashboard
  return (
    <ErrorBoundary>
      <TranslationWrapper>
        <AuthProvider>
          <Router basename="/">
            <div>
              {/* Switch Mode Button */}
              <div className="fixed top-4 left-4 z-50">
                <Button
                  variant="outline"
                  size="sm"
                  onClick={toggleAdminMode}
                  className="bg-white border-gray-300"
                >
                  <Shield className="h-4 w-4 mr-2" />
                  Super Admin
                </Button>
              </div>
              <AppContent />
            </div>
          </Router>
        </AuthProvider>
      </TranslationWrapper>
    </ErrorBoundary>
  )
}

function AppContent() {
  const { user, currentOrganization, loading, login, logout } = useAuth()
  const { t } = useTranslation()

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <LoadingSpinner size="xl" text={t('common.loading')} />
      </div>
    )
  }

  if (!user) {
    return <AdminLogin onLogin={login} />
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
                  {t('dashboard.title')}
                </h1>
              </div>
            </div>
            <div className="flex items-center gap-2 sm:gap-3 min-w-0">
              <LanguageSwitcher />
              <Badge variant="secondary" className="hidden sm:inline-flex shrink-0">{currentOrganization?.role}</Badge>
              <span className="text-sm text-gray-700 hidden md:block truncate max-w-[140px]">{currentOrganization?.organization_name}</span>
              <span className="text-sm text-gray-700 hidden lg:block truncate max-w-[100px]">{user?.username}</span>
              <Button variant="outline" size="sm" onClick={logout} className="shrink-0">
                <LogOut className="h-4 w-4 sm:mr-2" />
                <span className="hidden sm:inline">{t('auth.logout')}</span>
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
            <Tabs defaultValue={user?.role === 'SERVANT' ? 'groups' : 'join-requests'} className="w-full">
              <TabsList className={user?.role === 'SERVANT' ? 'grid w-full grid-cols-2' : 'grid w-full grid-cols-8'}>
                {user?.role !== 'SERVANT' && (
                  <>
                    <TabsTrigger value="join-requests">{t('navigation.joinRequests')}</TabsTrigger>
                    <TabsTrigger value="users">{t('navigation.users')}</TabsTrigger>
                    <TabsTrigger value="servants">Servants</TabsTrigger>
                  </>
                )}
                <TabsTrigger value="groups">{t('navigation.groups')}</TabsTrigger>
                <TabsTrigger value="scoring">{t('navigation.scoring')}</TabsTrigger>
                {user?.role !== 'SERVANT' && (
                  <>
                    <TabsTrigger value="user-scores">User Scores</TabsTrigger>
                    <TabsTrigger value="leaderboard">{t('navigation.leaderboards')}</TabsTrigger>
                    <TabsTrigger value="qr-scanner">{t('navigation.qrScanner')}</TabsTrigger>
                  </>
                )}
              </TabsList>
              
              {user?.role !== 'SERVANT' && (
                <>
                  <TabsContent value="join-requests" className="space-y-4">
                    <JoinRequestsManagement />
                  </TabsContent>
                  
                  <TabsContent value="users" className="space-y-4">
                    <UsersManagement />
                  </TabsContent>
                  
                  <TabsContent value="servants" className="space-y-4">
                    <ServantsManagement />
                  </TabsContent>
                </>
              )}
              
              <TabsContent value="groups" className="space-y-4">
                <GroupsManagement />
              </TabsContent>
              
              <TabsContent value="scoring" className="space-y-4">
                <ScoringManagement />
              </TabsContent>
              
              {user?.role !== 'SERVANT' && (
                <>
                  <TabsContent value="user-scores" className="space-y-4">
                    <UserScoresManagement />
                  </TabsContent>
                  
                  <TabsContent value="leaderboard" className="space-y-4">
                    <LeaderboardManagement />
                  </TabsContent>
                  
                  <TabsContent value="qr-scanner" className="space-y-4">
                    <QRScannerManagement />
                  </TabsContent>
                </>
              )}
            </Tabs>
          </CardContent>
        </Card>
      </main>
    </div>
  )
}

// Join Requests Management Component
function JoinRequestsManagement() {
  const { t } = useTranslation()
  const [joinRequests, setJoinRequests] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const { currentOrganization } = useAuth()

  useEffect(() => {
    if (currentOrganization?.organization_id) {
      fetchJoinRequests()
    }
  }, [currentOrganization])

  const fetchJoinRequests = async () => {
    try {
      const response = await api.get(`/auth/organizations/${currentOrganization.organization_id}/join-requests`)
      setJoinRequests(response.data.join_requests)
    } catch (error) {
      setError('Failed to fetch join requests')
      console.error('Error fetching join requests:', error)
    } finally {
      setLoading(false)
    }
  }

  const handleApprove = async (requestId) => {
    try {
      await api.post(`/auth/organizations/${currentOrganization.organization_id}/join-requests/${requestId}/approve`, {
        role: 'USER'
      })
      await fetchJoinRequests() // Refresh the list
    } catch (error) {
      setError('Failed to approve request')
      console.error('Error approving request:', error)
    }
  }

  const handleReject = async (requestId) => {
    try {
      await api.post(`/auth/organizations/${currentOrganization.organization_id}/join-requests/${requestId}/reject`, {
        message: 'Request rejected by admin'
      })
      await fetchJoinRequests() // Refresh the list
    } catch (error) {
      setError('Failed to reject request')
      console.error('Error rejecting request:', error)
    }
  }

  if (loading) {
    return <LoadingSpinner text="Loading join requests..." />
  }

  return (
    <div className="space-y-6">
      <div>
        <h3 className="text-lg font-medium text-gray-900">Organization Join Requests</h3>
        <p className="text-sm text-gray-500">
          Manage users requesting to join your organization
        </p>
      </div>

      {error && (
        <Alert variant="destructive">
          <AlertDescription>{error}</AlertDescription>
        </Alert>
      )}

      {joinRequests.length === 0 ? (
        <Card>
          <CardContent className="text-center py-8">
            <UserCheck className="h-12 w-12 text-gray-400 mx-auto mb-4" />
            <h3 className="text-lg font-medium text-gray-900 mb-2">No pending requests</h3>
            <p className="text-gray-500">
              All join requests have been processed or no new requests have been submitted.
            </p>
          </CardContent>
        </Card>
      ) : (
        <div className="space-y-4">
          {joinRequests.map((request) => (
            <Card key={request.id}>
              <CardContent className="p-6">
                <div className="flex items-center justify-between">
                  <div className="flex-1">
                    <div className="flex items-center space-x-3">
                      <div className="bg-blue-100 rounded-full p-2">
                        <UserPlus className="h-5 w-5 text-blue-600" />
                      </div>
                      <div>
                        <h4 className="text-lg font-medium text-gray-900">
                          {request.user?.first_name} {request.user?.last_name}
                        </h4>
                        <p className="text-sm text-gray-500">@{request.user?.username}</p>
                        <p className="text-sm text-gray-500">{request.user?.email}</p>
                      </div>
                    </div>
                    
                    <div className="mt-4 space-y-2">
                      <div className="flex items-center space-x-2">
                        <Badge variant="outline">
                          Requested Role: {request.requested_role}
                        </Badge>
                        <Badge variant="secondary">
                          <Clock className="h-3 w-3 mr-1" />
                          {new Date(request.created_at).toLocaleDateString()}
                        </Badge>
                      </div>
                      
                      {request.message && (
                        <div className="bg-gray-50 rounded-lg p-3 mt-3">
                          <p className="text-sm text-gray-700">
                            <strong>Message:</strong> {request.message}
                          </p>
                        </div>
                      )}
                    </div>
                  </div>
                  
                  <div className="flex items-center space-x-3 ml-6">
                    <Button
                      onClick={() => handleApprove(request.id)}
                      className="bg-green-600 hover:bg-green-700"
                    >
                      <CheckCircle className="h-4 w-4 mr-2" />
                      Approve
                    </Button>
                    <Button
                      variant="outline"
                      onClick={() => handleReject(request.id)}
                      className="border-red-300 text-red-700 hover:bg-red-50"
                    >
                      <XCircle className="h-4 w-4 mr-2" />
                      Reject
                    </Button>
                  </div>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      )}
    </div>
  )
}

// Users Management Component
function UsersManagement() {
  const { t } = useTranslation()
  const [users, setUsers] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [showInviteForm, setShowInviteForm] = useState(false)
  const [editingUser, setEditingUser] = useState(null)
  const [passwordResetUser, setPasswordResetUser] = useState(null)
  const [deleteConfirmUser, setDeleteConfirmUser] = useState(null)
  const { currentOrganization } = useAuth()

  const [inviteData, setInviteData] = useState({
    username: '',
    email: '',
    password: '',
    first_name: '',
    last_name: '',
    role: 'USER'
  })

  const [showBulkAddForm, setShowBulkAddForm] = useState(false)
  const [bulkUsers, setBulkUsers] = useState([
    { username: '', email: '', password: '', first_name: '', last_name: '', role: 'USER' }
  ])
  const [bulkAddResults, setBulkAddResults] = useState(null)

  const [editData, setEditData] = useState({
    username: '',
    email: '',
    first_name: '',
    last_name: '',
    is_active: true
  })

  const [passwordData, setPasswordData] = useState({
    new_password: '',
    confirm_password: ''
  })

  useEffect(() => {
    if (currentOrganization?.organization_id) {
      fetchUsers()
    }
  }, [currentOrganization])

  const fetchUsers = async () => {
    try {
      const response = await api.get(`/auth/organizations/${currentOrganization.organization_id}/users`)
      setUsers(response.data.users)
    } catch (error) {
      setError('Failed to fetch users')
      console.error('Error fetching users:', error)
    } finally {
      setLoading(false)
    }
  }

  const handleInviteUser = async (e) => {
    e.preventDefault()
    try {
      await api.post(`/auth/organizations/${currentOrganization.organization_id}/invite-user`, inviteData)
      setShowInviteForm(false)
      setInviteData({ username: '', email: '', password: '', first_name: '', last_name: '', role: 'USER' })
      await fetchUsers()
    } catch (error) {
      setError('Failed to invite user')
      console.error('Error inviting user:', error)
    }
  }

  const handleBulkAddUsers = async (e) => {
    e.preventDefault()
    setError('')
    setBulkAddResults(null)
    
    try {
      // Filter out empty rows
      const validUsers = bulkUsers.filter(user => 
        user.username.trim() && user.email.trim() && user.password.trim()
      )
      
      if (validUsers.length === 0) {
        setError('Please add at least one valid user')
        return
      }

      const response = await api.post(
        `/auth/organizations/${currentOrganization.organization_id}/bulk-add-users`,
        { users: validUsers }
      )
      
      setBulkAddResults(response.data)
      
      // If all succeeded, close form and refresh users
      if (response.data.errors.length === 0) {
        setTimeout(() => {
          setShowBulkAddForm(false)
          setBulkUsers([{ username: '', email: '', password: '', first_name: '', last_name: '', role: 'USER' }])
          setBulkAddResults(null)
          fetchUsers()
        }, 2000)
      }
    } catch (error) {
      setError('Failed to add users: ' + (error.response?.data?.error || error.message))
      console.error('Error adding bulk users:', error)
    }
  }

  const addBulkUserRow = () => {
    if (bulkUsers.length < 100) {
      setBulkUsers([...bulkUsers, { username: '', email: '', password: '', first_name: '', last_name: '', role: 'USER' }])
    }
  }

  const removeBulkUserRow = (index) => {
    if (bulkUsers.length > 1) {
      setBulkUsers(bulkUsers.filter((_, i) => i !== index))
    }
  }

  const updateBulkUser = (index, field, value) => {
    const updated = [...bulkUsers]
    updated[index][field] = value
    setBulkUsers(updated)
  }

  const handleEditUser = async (e) => {
    e.preventDefault()
    try {
      await api.put(`/auth/users/${editingUser.id}`, editData)
      setEditingUser(null)
      setEditData({ username: '', email: '', first_name: '', last_name: '', is_active: true })
      await fetchUsers()
    } catch (error) {
      setError('Failed to update user')
      console.error('Error updating user:', error)
    }
  }

  const handlePasswordReset = async (e) => {
    e.preventDefault()
    if (passwordData.new_password !== passwordData.confirm_password) {
      setError('Passwords do not match')
      return
    }
    if (passwordData.new_password.length < 6) {
      setError('Password must be at least 6 characters long')
      return
    }
    
    try {
      await api.put(`/auth/users/${passwordResetUser.id}/password`, {
        new_password: passwordData.new_password
      })
      setPasswordResetUser(null)
      setPasswordData({ new_password: '', confirm_password: '' })
      setError('')
    } catch (error) {
      setError('Failed to reset password')
      console.error('Error resetting password:', error)
    }
  }

  const handleToggleUserStatus = async (userId, currentStatus) => {
    try {
      await api.put(`/auth/users/${userId}`, { is_active: !currentStatus })
      await fetchUsers()
    } catch (error) {
      setError('Failed to update user status')
      console.error('Error updating user status:', error)
    }
  }

  const handleChangeRole = async (userId, newRole) => {
    try {
      await api.put(`/auth/organizations/${currentOrganization.organization_id}/users/${userId}/role`, {
        role: newRole
      })
      await fetchUsers()
    } catch (error) {
      setError('Failed to change user role')
      console.error('Error changing user role:', error)
    }
  }

  const handleDeleteUser = async () => {
    if (!deleteConfirmUser) return
    
    try {
      await api.delete(`/auth/organizations/${currentOrganization.organization_id}/users/${deleteConfirmUser.id}`)
      setDeleteConfirmUser(null)
      await fetchUsers()
    } catch (error) {
      console.error('Error removing user:', error)
      
      // Handle authentication errors and non-JSON responses gracefully
      if (error.response?.status === 401) {
        setError('Authentication failed. Please log in again.')
        // Optionally clear token and redirect to login
        localStorage.removeItem('adminToken')
        window.location.href = '/admin-login'
      } else if (error.response?.status === 503) {
        setError('Service temporarily unavailable. Please try again later.')
      } else {
        // Try to extract error message, fallback for non-JSON responses
        let errorMessage = 'Failed to remove user from organization'
        try {
          if (error.response?.data?.error) {
            errorMessage = error.response.data.error
          } else if (error.response?.data && typeof error.response.data === 'string') {
            errorMessage = error.response.data
          }
        } catch (parseError) {
          // If we can't parse the response, use the default message
          console.log('Could not parse error response:', parseError)
        }
        setError(errorMessage)
      }
    }
  }

  const startEdit = (user) => {
    setEditingUser(user)
    setEditData({
      username: user.username,
      email: user.email,
      first_name: user.first_name || '',
      last_name: user.last_name || '',
      is_active: user.is_active
    })
  }

  const startPasswordReset = (user) => {
    setPasswordResetUser(user)
    setPasswordData({ new_password: '', confirm_password: '' })
  }

  if (loading) {
    return <LoadingSpinner text="Loading users..." />
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:justify-between sm:items-center gap-3">
        <div>
          <h3 className="text-lg font-medium text-gray-900">Users Management</h3>
          <p className="text-sm text-gray-500">
            Manage users in your organization
          </p>
        </div>
        <div className="flex flex-wrap gap-2">
          <Button onClick={() => setShowBulkAddForm(true)} variant="outline">
            <Users className="h-4 w-4 mr-2" />
            Bulk Add Users
          </Button>
          <Button onClick={() => setShowInviteForm(true)}>
            <UserPlus className="h-4 w-4 mr-2" />
            Invite User
          </Button>
        </div>
      </div>

      {error && (
        <Alert variant="destructive">
          <AlertDescription>{error}</AlertDescription>
        </Alert>
      )}

      {/* Invite User Form */}
      {showInviteForm && (
        <Card>
          <CardHeader>
            <CardTitle>Invite New User</CardTitle>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleInviteUser} className="space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <Label htmlFor="username">Username</Label>
                  <Input
                    id="username"
                    value={inviteData.username}
                    onChange={(e) => setInviteData({ ...inviteData, username: e.target.value })}
                    required
                  />
                </div>
                <div>
                  <Label htmlFor="email">Email</Label>
                  <Input
                    id="email"
                    type="email"
                    value={inviteData.email}
                    onChange={(e) => setInviteData({ ...inviteData, email: e.target.value })}
                    required
                  />
                </div>
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <Label htmlFor="first_name">First Name</Label>
                  <Input
                    id="first_name"
                    value={inviteData.first_name}
                    onChange={(e) => setInviteData({ ...inviteData, first_name: e.target.value })}
                  />
                </div>
                <div>
                  <Label htmlFor="last_name">Last Name</Label>
                  <Input
                    id="last_name"
                    value={inviteData.last_name}
                    onChange={(e) => setInviteData({ ...inviteData, last_name: e.target.value })}
                  />
                </div>
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <Label htmlFor="password">Password</Label>
                  <Input
                    id="password"
                    type="password"
                    value={inviteData.password}
                    onChange={(e) => setInviteData({ ...inviteData, password: e.target.value })}
                    required
                  />
                </div>
                <div>
                  <Label htmlFor="role">Role</Label>
                  <Select value={inviteData.role} onValueChange={(value) => setInviteData({ ...inviteData, role: value })}>
                    <SelectTrigger>
                      <SelectValue placeholder={t('common.selectRole')} />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="USER">User</SelectItem>
                      <SelectItem value="ORG_ADMIN">Admin</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
              </div>
              <div className="flex space-x-2">
                <Button type="submit">Invite User</Button>
                <Button type="button" variant="outline" onClick={() => setShowInviteForm(false)}>
                  Cancel
                </Button>
              </div>
            </form>
          </CardContent>
        </Card>
      )}

      {/* Bulk Add Users Form */}
      {showBulkAddForm && (
        <Card>
          <CardHeader>
            <CardTitle>Bulk Add Users</CardTitle>
            <CardDescription>Add multiple users to your organization at once</CardDescription>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleBulkAddUsers} className="space-y-4">
              <div className="space-y-4">
                {bulkUsers.map((user, index) => (
                  <div key={index} className="border rounded-lg p-4 space-y-4 bg-gray-50">
                    <div className="flex justify-between items-center mb-2">
                      <h4 className="font-medium text-sm">User {index + 1}</h4>
                      {bulkUsers.length > 1 && (
                        <Button
                          type="button"
                          variant="ghost"
                          size="sm"
                          onClick={() => removeBulkUserRow(index)}
                        >
                          <XCircle className="h-4 w-4 text-red-500" />
                        </Button>
                      )}
                    </div>
                    <div className="grid grid-cols-2 gap-4">
                      <div>
                        <Label htmlFor={`username-${index}`}>Username *</Label>
                        <Input
                          id={`username-${index}`}
                          value={user.username}
                          onChange={(e) => updateBulkUser(index, 'username', e.target.value)}
                          required
                        />
                      </div>
                      <div>
                        <Label htmlFor={`email-${index}`}>Email *</Label>
                        <Input
                          id={`email-${index}`}
                          type="email"
                          value={user.email}
                          onChange={(e) => updateBulkUser(index, 'email', e.target.value)}
                          required
                        />
                      </div>
                    </div>
                    <div className="grid grid-cols-2 gap-4">
                      <div>
                        <Label htmlFor={`first_name-${index}`}>First Name</Label>
                        <Input
                          id={`first_name-${index}`}
                          value={user.first_name}
                          onChange={(e) => updateBulkUser(index, 'first_name', e.target.value)}
                        />
                      </div>
                      <div>
                        <Label htmlFor={`last_name-${index}`}>Last Name</Label>
                        <Input
                          id={`last_name-${index}`}
                          value={user.last_name}
                          onChange={(e) => updateBulkUser(index, 'last_name', e.target.value)}
                        />
                      </div>
                    </div>
                    <div className="grid grid-cols-2 gap-4">
                      <div>
                        <Label htmlFor={`password-${index}`}>Password *</Label>
                        <Input
                          id={`password-${index}`}
                          type="password"
                          value={user.password}
                          onChange={(e) => updateBulkUser(index, 'password', e.target.value)}
                          required
                        />
                      </div>
                      <div>
                        <Label htmlFor={`role-${index}`}>Role</Label>
                        <Select 
                          value={user.role} 
                          onValueChange={(value) => updateBulkUser(index, 'role', value)}
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
                    </div>
                  </div>
                ))}
              </div>
              
              <Button
                type="button"
                variant="outline"
                onClick={addBulkUserRow}
                className="w-full"
                disabled={bulkUsers.length >= 100}
              >
                <Plus className="h-4 w-4 mr-2" />
                Add Another User {bulkUsers.length >= 100 && '(Max 100 reached)'}
              </Button>

              {bulkAddResults && (
                <div className="space-y-2">
                  {bulkAddResults.summary.created > 0 && (
                    <Alert className="border-green-500 bg-green-50">
                      <CheckCircle className="h-4 w-4 text-green-600" />
                      <AlertDescription>
                        Successfully created {bulkAddResults.summary.created} user(s)
                      </AlertDescription>
                    </Alert>
                  )}
                  {bulkAddResults.summary.skipped > 0 && (
                    <Alert className="border-yellow-500 bg-yellow-50">
                      <Clock className="h-4 w-4 text-yellow-600" />
                      <AlertDescription>
                        Skipped {bulkAddResults.summary.skipped} user(s) - already exist
                      </AlertDescription>
                    </Alert>
                  )}
                  {bulkAddResults.summary.failed > 0 && (
                    <Alert variant="destructive">
                      <XCircle className="h-4 w-4" />
                      <AlertDescription>
                        Failed to create {bulkAddResults.summary.failed} user(s)
                        <ul className="mt-2 list-disc list-inside">
                          {bulkAddResults.errors.map((err, i) => (
                            <li key={i} className="text-sm">{err.email || err.username}: {err.error}</li>
                          ))}
                        </ul>
                      </AlertDescription>
                    </Alert>
                  )}
                </div>
              )}

              <div className="flex space-x-2">
                <Button type="submit">Add All Users</Button>
                <Button 
                  type="button" 
                  variant="outline" 
                  onClick={() => {
                    setShowBulkAddForm(false)
                    setBulkUsers([{ username: '', email: '', password: '', first_name: '', last_name: '', role: 'USER' }])
                    setBulkAddResults(null)
                  }}
                >
                  Cancel
                </Button>
              </div>
            </form>
          </CardContent>
        </Card>
      )}

      {/* Users List */}
      <Card>
        <CardHeader>
          <CardTitle>All Users ({users.length})</CardTitle>
          <CardDescription>Manage users in your organization</CardDescription>
        </CardHeader>
        <CardContent>
          {users.length === 0 ? (
            <div className="text-center py-8">
              <Users className="h-12 w-12 text-gray-400 mx-auto mb-4" />
              <h3 className="text-lg font-medium text-gray-900 mb-2">No users found</h3>
              <p className="text-gray-500">
                Start by inviting users to your organization.
              </p>
            </div>
          ) : (
            <div className="space-y-4">
              {users.map((user) => (
                <div key={user.id} className="flex flex-col sm:flex-row sm:items-center sm:justify-between p-4 border rounded-lg gap-3">
                  <div className="flex items-center space-x-3 min-w-0">
                    <div className="bg-blue-100 rounded-full p-2 shrink-0">
                      <Users className="h-5 w-5 text-blue-600" />
                    </div>
                    <div className="min-w-0">
                      <p className="font-medium truncate">{user.first_name} {user.last_name}</p>
                      <p className="text-sm text-gray-600 truncate">@{user.username}</p>
                      <p className="text-sm text-gray-500 truncate">{user.email}</p>
                    </div>
                  </div>

                  <div className="flex flex-wrap items-center gap-2 shrink-0">
                    {/* Role Selector */}
                    <Select
                      value={user.role}
                      onValueChange={(value) => handleChangeRole(user.id, value)}
                    >
                      <SelectTrigger className="w-28">
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="USER">User</SelectItem>
                        <SelectItem value="ORG_ADMIN">Admin</SelectItem>
                      </SelectContent>
                    </Select>

                    {/* Status Badge */}
                    <Badge variant={user.is_active ? 'default' : 'destructive'}>
                      {user.is_active ? 'Active' : 'Inactive'}
                    </Badge>

                    {/* Action Buttons */}
                    <Button size="sm" variant="outline" onClick={() => startEdit(user)}>Edit</Button>
                    <Button size="sm" variant="outline" onClick={() => startPasswordReset(user)}>Reset Pw</Button>
                    <Button
                      size="sm"
                      variant={user.is_active ? "destructive" : "default"}
                      onClick={() => handleToggleUserStatus(user.id, user.is_active)}
                    >
                      {user.is_active ? 'Disable' : 'Enable'}
                    </Button>
                    <Button size="sm" variant="destructive" onClick={() => setDeleteConfirmUser(user)}>Remove</Button>
                  </div>
                </div>
              ))}
            </div>
          )}
        </CardContent>
      </Card>

      {/* Edit User Dialog */}
      <Dialog open={!!editingUser} onOpenChange={() => setEditingUser(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Edit User</DialogTitle>
            <DialogDescription>
              Update user information
            </DialogDescription>
          </DialogHeader>
          <form onSubmit={handleEditUser} className="space-y-4">
            <div className="grid grid-cols-2 gap-4">
              <div>
                <Label htmlFor="edit_username">Username</Label>
                <Input
                  id="edit_username"
                  value={editData.username}
                  onChange={(e) => setEditData({ ...editData, username: e.target.value })}
                  required
                />
              </div>
              <div>
                <Label htmlFor="edit_email">Email</Label>
                <Input
                  id="edit_email"
                  type="email"
                  value={editData.email}
                  onChange={(e) => setEditData({ ...editData, email: e.target.value })}
                  required
                />
              </div>
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div>
                <Label htmlFor="edit_first_name">First Name</Label>
                <Input
                  id="edit_first_name"
                  value={editData.first_name}
                  onChange={(e) => setEditData({ ...editData, first_name: e.target.value })}
                />
              </div>
              <div>
                <Label htmlFor="edit_last_name">Last Name</Label>
                <Input
                  id="edit_last_name"
                  value={editData.last_name}
                  onChange={(e) => setEditData({ ...editData, last_name: e.target.value })}
                />
              </div>
            </div>
            <div className="flex space-x-2">
              <Button type="submit">Update User</Button>
              <Button type="button" variant="outline" onClick={() => setEditingUser(null)}>
                Cancel
              </Button>
            </div>
          </form>
        </DialogContent>
      </Dialog>

      {/* Password Reset Dialog */}
      <Dialog open={!!passwordResetUser} onOpenChange={() => setPasswordResetUser(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Reset Password</DialogTitle>
            <DialogDescription>
              Set a new password for {passwordResetUser?.username}
            </DialogDescription>
          </DialogHeader>
          <form onSubmit={handlePasswordReset} className="space-y-4">
            <div>
              <Label htmlFor="new_password">New Password</Label>
              <Input
                id="new_password"
                type="password"
                value={passwordData.new_password}
                onChange={(e) => setPasswordData({ ...passwordData, new_password: e.target.value })}
                required
                minLength={6}
              />
            </div>
            <div>
              <Label htmlFor="confirm_password">Confirm Password</Label>
              <Input
                id="confirm_password"
                type="password"
                value={passwordData.confirm_password}
                onChange={(e) => setPasswordData({ ...passwordData, confirm_password: e.target.value })}
                required
                minLength={6}
              />
            </div>
            <div className="flex space-x-2">
              <Button type="submit">Reset Password</Button>
              <Button type="button" variant="outline" onClick={() => setPasswordResetUser(null)}>
                Cancel
              </Button>
            </div>
          </form>
        </DialogContent>
      </Dialog>

      {/* Delete Confirmation Dialog */}
      <Dialog open={!!deleteConfirmUser} onOpenChange={() => setDeleteConfirmUser(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Remove User</DialogTitle>
            <DialogDescription>
              Are you sure you want to remove {deleteConfirmUser?.username} from this organization? 
              This action cannot be undone.
            </DialogDescription>
          </DialogHeader>
          <div className="flex space-x-2 justify-end">
            <Button variant="outline" onClick={() => setDeleteConfirmUser(null)}>
              Cancel
            </Button>
            <Button variant="destructive" onClick={handleDeleteUser}>
              Remove User
            </Button>
          </div>
        </DialogContent>
      </Dialog>
    </div>
  )
}

// Servants Management Component
function ServantsManagement() {
  const { t } = useTranslation()
  const [servants, setServants] = useState([])
  const [users, setUsers] = useState([])
  const [groups, setGroups] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [selectedServant, setSelectedServant] = useState(null)
  const [selectedGroup, setSelectedGroup] = useState('')
  const [showAssignDialog, setShowAssignDialog] = useState(false)
  const { currentOrganization } = useAuth()

  useEffect(() => {
    if (currentOrganization?.organization_id) {
      fetchServants()
      fetchUsers()
      fetchGroups()
    }
  }, [currentOrganization])

  const fetchServants = async () => {
    try {
      const response = await api.get(`/servants?organization_id=${currentOrganization.organization_id}`)
      setServants(response.data.servants || [])
      setError('')
    } catch (error) {
      setError('Failed to fetch servants')
      console.error('Error fetching servants:', error)
    } finally {
      setLoading(false)
    }
  }

  const fetchUsers = async () => {
    try {
      const response = await api.get(`/auth/organizations/${currentOrganization.organization_id}/users`)
      setUsers(response.data.users || [])
    } catch (error) {
      console.error('Error fetching users:', error)
    }
  }

  const fetchGroups = async () => {
    try {
      const response = await api.get(`/groups?organization_id=${currentOrganization.organization_id}`)
      setGroups(response.data.groups || [])
    } catch (error) {
      console.error('Error fetching groups:', error)
    }
  }

  const handlePromoteToServant = async (userId) => {
    try {
      await api.post(`/servants/users/${userId}/promote-to-servant`)
      await fetchServants()
      await fetchUsers()
      setError('')
    } catch (error) {
      setError('Failed to promote user to servant')
      console.error('Error promoting user:', error)
    }
  }

  const handleDemoteFromServant = async (userId) => {
    try {
      await api.post(`/servants/users/${userId}/demote-from-servant`)
      await fetchServants()
      await fetchUsers()
      setError('')
    } catch (error) {
      setError('Failed to demote servant')
      console.error('Error demoting servant:', error)
    }
  }

  const handleAssignToGroup = async () => {
    if (!selectedServant || !selectedGroup) return
    
    try {
      await api.post(`/servants/${selectedServant.id}/groups`, {
        group_id: selectedGroup
      })
      await fetchServants()
      setShowAssignDialog(false)
      setSelectedServant(null)
      setSelectedGroup('')
      setError('')
    } catch (error) {
      setError('Failed to assign servant to group')
      console.error('Error assigning servant:', error)
    }
  }

  const handleRemoveFromGroup = async (servantId, groupId) => {
    try {
      await api.delete(`/servants/${servantId}/groups/${groupId}`)
      await fetchServants()
      setError('')
    } catch (error) {
      setError('Failed to remove servant from group')
      console.error('Error removing servant from group:', error)
    }
  }

  if (loading) {
    return <LoadingSpinner />
  }

  const regularUsers = users.filter(user => user.role === 'USER')

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <div>
          <h2 className="text-2xl font-bold flex items-center gap-2">
            <UserCog className="h-6 w-6" />
            Servants Management
          </h2>
          <p className="text-gray-600 mt-1">
            Manage servants and their group assignments
          </p>
        </div>
      </div>

      {error && (
        <Alert variant="destructive">
          <AlertDescription>{error}</AlertDescription>
        </Alert>
      )}

      {/* Current Servants */}
      <Card>
        <CardHeader>
          <CardTitle>Current Servants ({servants.length})</CardTitle>
          <CardDescription>Users with SERVANT role</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-3">
            {servants.length === 0 ? (
              <p className="text-gray-500 text-center py-4">No servants yet</p>
            ) : (
              servants.map((servant) => (
                <div key={servant.id} className="border rounded-lg p-4">
                  <div className="flex flex-col sm:flex-row sm:justify-between sm:items-start gap-3">
                    <div className="flex-1 min-w-0">
                      <div className="flex flex-wrap items-center gap-2">
                        <h3 className="font-semibold">{servant.first_name} {servant.last_name}</h3>
                        <Badge variant="secondary">
                          <Shield className="h-3 w-3 mr-1" />
                          SERVANT
                        </Badge>
                      </div>
                      <p className="text-sm text-gray-600">{servant.username}</p>
                      <p className="text-sm text-gray-600">{servant.email}</p>

                      {/* Assigned Groups */}
                      {servant.assigned_groups && servant.assigned_groups.length > 0 && (
                        <div className="mt-2">
                          <p className="text-sm font-medium text-gray-700">Assigned Groups:</p>
                          <div className="flex flex-wrap gap-2 mt-1">
                            {servant.assigned_groups.map((group) => (
                              <Badge key={group.id} variant="outline" className="flex items-center gap-1">
                                {group.name}
                                <button
                                  onClick={() => handleRemoveFromGroup(servant.id, group.id)}
                                  className="ml-1 hover:text-red-600"
                                >
                                  <XCircle className="h-3 w-3" />
                                </button>
                              </Badge>
                            ))}
                          </div>
                        </div>
                      )}
                    </div>

                    <div className="flex flex-wrap gap-2 shrink-0">
                      <Button
                        size="sm"
                        variant="outline"
                        onClick={() => {
                          setSelectedServant(servant)
                          setShowAssignDialog(true)
                        }}
                      >
                        <Plus className="h-4 w-4 mr-1" />
                        Assign Group
                      </Button>
                      <Button
                        size="sm"
                        variant="destructive"
                        onClick={() => handleDemoteFromServant(servant.id)}
                      >
                        <UserX className="h-4 w-4 mr-1" />
                        Demote
                      </Button>
                    </div>
                  </div>
                </div>
              ))
            )}
          </div>
        </CardContent>
      </Card>

      {/* Regular Users to Promote */}
      <Card>
        <CardHeader>
          <CardTitle>Promote Users to Servant</CardTitle>
          <CardDescription>Regular users who can be promoted to SERVANT role</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-2">
            {regularUsers.length === 0 ? (
              <p className="text-gray-500 text-center py-4">No regular users available</p>
            ) : (
              regularUsers.map((user) => (
                <div key={user.id} className="flex justify-between items-center border rounded-lg p-3">
                  <div>
                    <p className="font-medium">{user.first_name} {user.last_name}</p>
                    <p className="text-sm text-gray-600">{user.username} • {user.email}</p>
                  </div>
                  <Button
                    size="sm"
                    onClick={() => handlePromoteToServant(user.id)}
                  >
                    <UserCheck className="h-4 w-4 mr-1" />
                    Promote to Servant
                  </Button>
                </div>
              ))
            )}
          </div>
        </CardContent>
      </Card>

      {/* Assign to Group Dialog */}
      <Dialog open={showAssignDialog} onOpenChange={setShowAssignDialog}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Assign Servant to Group</DialogTitle>
            <DialogDescription>
              Select a group to assign {selectedServant?.first_name} {selectedServant?.last_name}
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4">
            <div>
              <Label>Select Group</Label>
              <Select value={selectedGroup} onValueChange={setSelectedGroup}>
                <SelectTrigger>
                  <SelectValue placeholder="Choose a group" />
                </SelectTrigger>
                <SelectContent>
                  {groups.map((group) => (
                    <SelectItem key={group.id} value={group.id}>
                      {group.name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="flex justify-end gap-2">
              <Button variant="outline" onClick={() => setShowAssignDialog(false)}>
                Cancel
              </Button>
              <Button onClick={handleAssignToGroup} disabled={!selectedGroup}>
                Assign
              </Button>
            </div>
          </div>
        </DialogContent>
      </Dialog>
    </div>
  )
}

// Groups Management Component
function GroupsManagement() {
  const { t } = useTranslation()
  const [groups, setGroups] = useState([])
  const [users, setUsers] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState('')
  const { currentOrganization, user } = useAuth()

  // Group creation state
  const [showCreateGroup, setShowCreateGroup] = useState(false)
  const [newGroup, setNewGroup] = useState({
    name: '',
    description: ''
  })

  // Group editing state
  const [editingGroup, setEditingGroup] = useState(null)
  const [selectedGroup, setSelectedGroup] = useState(null)
  const [groupUsers, setGroupUsers] = useState([])
  
  const isServant = user?.role === 'SERVANT'

  useEffect(() => {
    if (currentOrganization?.organization_id) {
      fetchGroups()
      fetchUsers()
    }
  }, [currentOrganization])

  const fetchGroups = async () => {
    try {
      if (isServant) {
        // Servants only see their assigned groups
        const response = await api.get(`/servants/${user.id}/groups`)
        // Extract group details from assignments
        const servantGroups = response.data.assignments?.map(assignment => assignment.group).filter(Boolean) || []
        setGroups(servantGroups)
      } else {
        // Admins see all groups
        const response = await api.get(`/groups?organization_id=${currentOrganization.organization_id}`)
        setGroups(response.data.groups || [])
      }
    } catch (error) {
      setError('Failed to fetch groups')
    }
  }

  const fetchUsers = async () => {
    try {
      const response = await api.get(`/organizations/users`)
      setUsers(response.data.users || [])
    } catch (error) {
      setError('Failed to fetch users')
    } finally {
      setLoading(false)
    }
  }

  const fetchGroupUsers = async (groupId) => {
    try {
      const response = await api.get(`/groups/${groupId}/members`)
      setGroupUsers(response.data.members || [])
    } catch (error) {
      setError('Failed to fetch group members')
    }
  }

  const handleCreateGroup = async (e) => {
    e.preventDefault()
    try {
      const response = await api.post('/groups', {
        ...newGroup,
        organization_id: currentOrganization.organization_id
      })
      setGroups([...groups, response.data.group])
      setNewGroup({ name: '', description: '' })
      setShowCreateGroup(false)
      setSuccess('Group created successfully!')
    } catch (error) {
      setError('Failed to create group')
    }
  }

  const handleUpdateGroup = async (e) => {
    e.preventDefault()
    try {
      const response = await api.put(`/groups/${editingGroup.id}`, editingGroup)
      setGroups(groups.map(g => g.id === editingGroup.id ? response.data.group : g))
      setEditingGroup(null)
      setSuccess('Group updated successfully!')
    } catch (error) {
      setError('Failed to update group')
    }
  }

  const handleDeleteGroup = async (groupId) => {
    if (!confirm('Are you sure you want to delete this group?')) return
    
    try {
      await api.delete(`/groups/${groupId}`)
      setGroups(groups.filter(g => g.id !== groupId))
      setSuccess('Group deleted successfully!')
    } catch (error) {
      setError('Failed to delete group')
    }
  }

  const handleAddUserToGroup = async (groupId, userId) => {
    try {
      await api.post(`/groups/${groupId}/members`, { user_id: userId })
      fetchGroupUsers(groupId)
      setSuccess('User added to group successfully!')
    } catch (error) {
      setError('Failed to add user to group')
    }
  }

  const handleRemoveUserFromGroup = async (groupId, userId) => {
    try {
      await api.delete(`/groups/${groupId}/members/${userId}`)
      fetchGroupUsers(groupId)
      setSuccess('User removed from group successfully!')
    } catch (error) {
      setError('Failed to remove user from group')
    }
  }

  if (loading) return <LoadingSpinner />

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h3 className="text-lg font-semibold flex items-center gap-2">
          <UsersIcon className="h-5 w-5" />
          {t('sections.groupsManagement')}
          {isServant && <Badge variant="secondary">My Assigned Groups</Badge>}
        </h3>
        {!isServant && (
          <Button onClick={() => setShowCreateGroup(true)}>
            <Plus className="h-4 w-4 mr-2" />
            Create Group
          </Button>
        )}
      </div>

      {error && (
        <Alert variant="destructive">
          <AlertDescription>{error}</AlertDescription>
        </Alert>
      )}

      {success && (
        <Alert className="border-green-200 bg-green-50">
          <AlertDescription className="text-green-800">{success}</AlertDescription>
        </Alert>
      )}
      
      {isServant && groups.length === 0 && (
        <Alert>
          <AlertDescription>
            You are not assigned to any groups yet. Please contact your administrator.
          </AlertDescription>
        </Alert>
      )}

      {/* Groups Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {groups.map((group) => (
          <Card key={group.id}>
            <CardHeader className="pb-2">
              <CardTitle className="text-base leading-snug">{group.name}</CardTitle>
              <CardDescription>{group.description}</CardDescription>
            </CardHeader>
            <CardContent>
              <p className="text-sm text-gray-600 mb-3">{group.member_count || 0} members</p>
              <div className="flex flex-wrap gap-2">
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => {
                    setSelectedGroup(group)
                    fetchGroupUsers(group.id)
                  }}
                >
                  Manage
                </Button>
                {!isServant && (
                  <>
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => setEditingGroup(group)}
                    >
                      Edit
                    </Button>
                    <Button
                      variant="destructive"
                      size="sm"
                      onClick={() => handleDeleteGroup(group.id)}
                    >
                      Delete
                    </Button>
                  </>
                )}
              </div>
            </CardContent>
          </Card>
        ))}
      </div>

      {/* Create Group Dialog */}
      {showCreateGroup && (
        <Dialog open={showCreateGroup} onOpenChange={setShowCreateGroup}>
          <DialogContent>
            <DialogHeader>
              <DialogTitle>Create New Group</DialogTitle>
              <DialogDescription>
                Create a new group for your organization
              </DialogDescription>
            </DialogHeader>
            <form onSubmit={handleCreateGroup} className="space-y-4">
              <div>
                <Label htmlFor="group_name">Group Name</Label>
                <Input
                  id="group_name"
                  value={newGroup.name}
                  onChange={(e) => setNewGroup({ ...newGroup, name: e.target.value })}
                  required
                />
              </div>
              <div>
                <Label htmlFor="group_description">Description</Label>
                <Input
                  id="group_description"
                  value={newGroup.description}
                  onChange={(e) => setNewGroup({ ...newGroup, description: e.target.value })}
                />
              </div>
              <div className="flex space-x-2">
                <Button type="submit">Create Group</Button>
                <Button type="button" variant="outline" onClick={() => setShowCreateGroup(false)}>
                  Cancel
                </Button>
              </div>
            </form>
          </DialogContent>
        </Dialog>
      )}

      {/* Edit Group Dialog */}
      {editingGroup && (
        <Dialog open={!!editingGroup} onOpenChange={() => setEditingGroup(null)}>
          <DialogContent>
            <DialogHeader>
              <DialogTitle>Edit Group</DialogTitle>
              <DialogDescription>
                Update group information
              </DialogDescription>
            </DialogHeader>
            <form onSubmit={handleUpdateGroup} className="space-y-4">
              <div>
                <Label htmlFor="edit_group_name">Group Name</Label>
                <Input
                  id="edit_group_name"
                  value={editingGroup.name}
                  onChange={(e) => setEditingGroup({ ...editingGroup, name: e.target.value })}
                  required
                />
              </div>
              <div>
                <Label htmlFor="edit_group_description">Description</Label>
                <Input
                  id="edit_group_description"
                  value={editingGroup.description}
                  onChange={(e) => setEditingGroup({ ...editingGroup, description: e.target.value })}
                />
              </div>
              <div className="flex space-x-2">
                <Button type="submit">Update Group</Button>
                <Button type="button" variant="outline" onClick={() => setEditingGroup(null)}>
                  Cancel
                </Button>
              </div>
            </form>
          </DialogContent>
        </Dialog>
      )}

      {/* Group Members Management Dialog */}
      {selectedGroup && (
        <Dialog open={!!selectedGroup} onOpenChange={() => setSelectedGroup(null)}>
          <DialogContent className="max-w-4xl">
            <DialogHeader>
              <DialogTitle>Manage Group: {selectedGroup.name}</DialogTitle>
              <DialogDescription>
                Add or remove members from this group
              </DialogDescription>
            </DialogHeader>
            
            <div className="grid grid-cols-2 gap-6">
              {/* Available Users */}
              <div>
                <h4 className="font-medium mb-2">Available Users</h4>
                <div className="space-y-2 max-h-60 overflow-y-auto">
                  {users.filter(user => !groupUsers.find(gu => gu.id === user.id)).map((user) => (
                    <div key={user.id} className="flex justify-between items-center p-2 border rounded">
                      <span>{user.first_name} {user.last_name} ({user.username})</span>
                      <Button
                        size="sm"
                        onClick={() => handleAddUserToGroup(selectedGroup.id, user.id)}
                      >
                        Add
                      </Button>
                    </div>
                  ))}
                </div>
              </div>

              {/* Group Members */}
              <div>
                <h4 className="font-medium mb-2">Group Members</h4>
                <div className="space-y-2 max-h-60 overflow-y-auto">
                  {groupUsers.map((member) => (
                    <div key={member.id} className="flex justify-between items-center p-2 border rounded">
                      <span>
                        {member.user?.full_name || `${member.user?.first_name || ''} ${member.user?.last_name || ''}`.trim() || member.user?.username || 'Unknown User'}
                        {member.user?.username && ` (${member.user.username})`}
                        {member.role === 'ADMIN' && <span className="ml-2 text-xs bg-blue-100 text-blue-800 px-2 py-1 rounded">Admin</span>}
                      </span>
                      <Button
                        size="sm"
                        variant="destructive"
                        onClick={() => handleRemoveUserFromGroup(selectedGroup.id, member.id)}
                      >
                        Remove
                      </Button>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </DialogContent>
        </Dialog>
      )}
    </div>
  )
}

// Scoring Management Component
function ScoringManagement() {
  const { t } = useTranslation()
  const [scoreCategories, setScoreCategories] = useState([])
  const [users, setUsers] = useState([])
  const [groups, setGroups] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState('')
  const { currentOrganization } = useAuth()

  // Category management state
  const [showCreateCategory, setShowCreateCategory] = useState(false)
  const [editingCategory, setEditingCategory] = useState(null)
  const [newCategory, setNewCategory] = useState({
    name: '',
    description: '',
    max_score: 100
  })

  // Score assignment state
  const [scoreAssignment, setScoreAssignment] = useState({
    target_type: 'user', // 'user' or 'group'
    target_id: '',
    category_id: '',
    score: 0,
    reason: ''
  })

  useEffect(() => {
    if (currentOrganization?.organization_id) {
      fetchScoreCategories()
      fetchUsers()
      fetchGroups()
    }
  }, [currentOrganization])

  const fetchScoreCategories = async () => {
    try {
      const response = await api.get(`/scores/categories?organization_id=${currentOrganization.organization_id}`)
      setScoreCategories(response.data.categories || [])
    } catch (error) {
      setError('Failed to fetch score categories')
    }
  }

  const fetchUsers = async () => {
    try {
      const response = await api.get(`/organizations/users`)
      setUsers(response.data.users || [])
    } catch (error) {
      setError('Failed to fetch users')
    }
  }

  const fetchGroups = async () => {
    try {
      const response = await api.get(`/groups?organization_id=${currentOrganization.organization_id}`)
      setGroups(response.data.groups || [])
    } catch (error) {
      setError('Failed to fetch groups')
    } finally {
      setLoading(false)
    }
  }

  const handleCreateCategory = async (e) => {
    e.preventDefault()
    try {
      const response = await api.post('/scores/categories', {
        ...newCategory,
        organization_id: currentOrganization.organization_id
      })
      setScoreCategories([...scoreCategories, response.data.category])
      setNewCategory({ name: '', description: '', max_score: 100 })
      setShowCreateCategory(false)
      setSuccess('Score category created successfully!')
    } catch (error) {
      setError('Failed to create score category')
    }
  }

  const handleUpdateCategory = async (e) => {
    e.preventDefault()
    try {
      const response = await api.put(`/scores/categories/${editingCategory.id}`, {
        name: editingCategory.name,
        description: editingCategory.description,
        max_score: editingCategory.max_score,
        is_predefined: editingCategory.is_predefined || false
      })
      setScoreCategories(scoreCategories.map(cat => 
        cat.id === editingCategory.id ? response.data.category : cat
      ))
      setEditingCategory(null)
      setSuccess('Category updated successfully!')
    } catch (error) {
      setError('Failed to update category')
    }
  }

  const handleDeleteCategory = async (categoryId, categoryName, isPredefined) => {
    if (isPredefined) {
      setError('Cannot delete predefined categories')
      return
    }
    
    if (!confirm(`Are you sure you want to delete the category "${categoryName}"?`)) {
      return
    }
    
    try {
      await api.delete(`/scores/categories/${categoryId}`)
      setScoreCategories(scoreCategories.filter(cat => cat.id !== categoryId))
      setSuccess('Category deleted successfully!')
    } catch (error) {
      setError(error.response?.data?.error || 'Failed to delete category')
    }
  }

  const handleAssignScore = async (e) => {
    e.preventDefault()
    try {
      const payload = {
        organization_id: currentOrganization.organization_id,
        category_id: scoreAssignment.category_id,
        score_value: scoreAssignment.score, // Rename to score_value for backend
        description: scoreAssignment.reason
      }
      
      // Add either user_id or group_id based on target_type
      if (scoreAssignment.target_type === 'user') {
        payload.user_id = scoreAssignment.target_id
      } else if (scoreAssignment.target_type === 'group') {
        payload.group_id = scoreAssignment.target_id
      }
      
      await api.post('/scores', payload)
      setScoreAssignment({
        target_type: 'user',
        target_id: '',
        category_id: '',
        score: 0,
        reason: ''
      })
      setSuccess('Score assigned successfully!')
    } catch (error) {
      setError(t('scoring.failedToAssignScore'))
    }
  }

  if (loading) return <LoadingSpinner />

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h3 className="text-lg font-semibold flex items-center gap-2">
          <Target className="h-5 w-5" />
          {t('sections.scoringManagement')}
        </h3>
        <Button onClick={() => setShowCreateCategory(true)}>
          <Plus className="h-4 w-4 mr-2" />
          Create Category
        </Button>
      </div>

      {error && (
        <Alert variant="destructive">
          <AlertDescription>{error}</AlertDescription>
        </Alert>
      )}

      {success && (
        <Alert className="border-green-200 bg-green-50">
          <AlertDescription className="text-green-800">{success}</AlertDescription>
        </Alert>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Score Categories */}
        <Card>
          <CardHeader>
            <CardTitle>Score Categories</CardTitle>
            <CardDescription>Manage scoring categories for your organization</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="space-y-2">
              {scoreCategories.map((category) => (
                <div key={category.id} className="flex flex-col sm:flex-row sm:justify-between sm:items-center p-3 border rounded gap-2">
                  <div className="min-w-0">
                    <h4 className="font-medium flex flex-wrap items-center gap-2">
                      {category.name}
                      {category.is_predefined && (
                        <span className="text-xs bg-blue-100 text-blue-800 px-2 py-1 rounded">
                          Predefined
                        </span>
                      )}
                    </h4>
                    <p className="text-sm text-gray-600">{category.description}</p>
                    <p className="text-sm text-gray-500">Max Score: {category.max_score}</p>
                  </div>
                  <div className="flex flex-wrap items-center gap-2 shrink-0">
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => setEditingCategory(category)}
                    >
                      Edit
                    </Button>
                    {!category.is_predefined && (
                      <Button
                        variant="destructive"
                        size="sm"
                        onClick={() => handleDeleteCategory(category.id, category.name, category.is_predefined)}
                      >
                        Delete
                      </Button>
                    )}
                  </div>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>

        {/* Score Assignment */}
        <Card>
          <CardHeader>
            <CardTitle>{t('scoring.assignScore')}</CardTitle>
            <CardDescription>{t('scoring.assignScoresToUsers')}</CardDescription>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleAssignScore} className="space-y-4">
              <div>
                <Label htmlFor="target_type">Target Type</Label>
                <Select
                  value={scoreAssignment.target_type}
                  onValueChange={(value) => setScoreAssignment({ ...scoreAssignment, target_type: value, target_id: '' })}
                >
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="user">User</SelectItem>
                    <SelectItem value="group">Group</SelectItem>
                  </SelectContent>
                </Select>
              </div>

              <div>
                <Label htmlFor="target_id">
                  {scoreAssignment.target_type === 'user' ? 'Select User' : 'Select Group'}
                </Label>
                <Select
                  value={scoreAssignment.target_id}
                  onValueChange={(value) => setScoreAssignment({ ...scoreAssignment, target_id: value })}
                >
                  <SelectTrigger>
                    <SelectValue placeholder={`Select ${scoreAssignment.target_type}`} />
                  </SelectTrigger>
                  <SelectContent>
                    {(scoreAssignment.target_type === 'user' ? users : groups).map((item) => (
                      <SelectItem key={item.id} value={item.id}>
                        {scoreAssignment.target_type === 'user' 
                          ? `${item.first_name} ${item.last_name} (${item.username})`
                          : item.name
                        }
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>

              <div>
                <Label htmlFor="category_id">Score Category</Label>
                <Select
                  value={scoreAssignment.category_id}
                  onValueChange={(value) => setScoreAssignment({ ...scoreAssignment, category_id: value })}
                >
                  <SelectTrigger>
                    <SelectValue placeholder={t('common.selectCategory')} />
                  </SelectTrigger>
                  <SelectContent>
                    {scoreCategories.map((category) => (
                      <SelectItem key={category.id} value={category.id}>
                        {category.name} (Max: {category.max_score})
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>

              <div>
                <Label htmlFor="score">{t('scoring.score')}</Label>
                <Input
                  id="score"
                  type="number"
                  value={scoreAssignment.score}
                  onChange={(e) => setScoreAssignment({ ...scoreAssignment, score: parseInt(e.target.value) || 0 })}
                  required
                />
              </div>

              <div>
                <Label htmlFor="reason">{t('scoring.reason')}</Label>
                <Input
                  id="reason"
                  value={scoreAssignment.reason}
                  onChange={(e) => setScoreAssignment({ ...scoreAssignment, reason: e.target.value })}
                  placeholder={t('common.reasonForScore')}
                />
              </div>

              <Button type="submit" className="w-full">
                {t('scoring.assignScore')}
              </Button>
            </form>
          </CardContent>
        </Card>
      </div>

      {/* Create Category Dialog */}
      {showCreateCategory && (
        <Dialog open={showCreateCategory} onOpenChange={setShowCreateCategory}>
          <DialogContent>
            <DialogHeader>
              <DialogTitle>Create Score Category</DialogTitle>
              <DialogDescription>
                Create a new scoring category for your organization
              </DialogDescription>
            </DialogHeader>
            <form onSubmit={handleCreateCategory} className="space-y-4">
              <div>
                <Label htmlFor="category_name">Category Name</Label>
                <Input
                  id="category_name"
                  value={newCategory.name}
                  onChange={(e) => setNewCategory({ ...newCategory, name: e.target.value })}
                  required
                />
              </div>
              <div>
                <Label htmlFor="category_description">Description</Label>
                <Input
                  id="category_description"
                  value={newCategory.description}
                  onChange={(e) => setNewCategory({ ...newCategory, description: e.target.value })}
                />
              </div>
              <div>
                <Label htmlFor="max_score">Maximum Score</Label>
                <Input
                  id="max_score"
                  type="number"
                  value={newCategory.max_score}
                  onChange={(e) => setNewCategory({ ...newCategory, max_score: parseInt(e.target.value) || 100 })}
                  required
                />
              </div>
              <div className="flex space-x-2">
                <Button type="submit">Create Category</Button>
                <Button type="button" variant="outline" onClick={() => setShowCreateCategory(false)}>
                  Cancel
                </Button>
              </div>
            </form>
          </DialogContent>
        </Dialog>
      )}

      {/* Edit Category Dialog */}
      {editingCategory && (
        <Dialog open={!!editingCategory} onOpenChange={() => setEditingCategory(null)}>
          <DialogContent>
            <DialogHeader>
              <DialogTitle>Edit Score Category</DialogTitle>
              <DialogDescription>
                Update the category information
              </DialogDescription>
            </DialogHeader>
            <form onSubmit={handleUpdateCategory} className="space-y-4">
              <div>
                <Label htmlFor="edit_category_name">Category Name</Label>
                <Input
                  id="edit_category_name"
                  value={editingCategory.name}
                  onChange={(e) => setEditingCategory({ ...editingCategory, name: e.target.value })}
                  required
                />
              </div>
              <div>
                <Label htmlFor="edit_category_description">Description</Label>
                <Input
                  id="edit_category_description"
                  value={editingCategory.description}
                  onChange={(e) => setEditingCategory({ ...editingCategory, description: e.target.value })}
                />
              </div>
              <div>
                <Label htmlFor="edit_max_score">Maximum Score</Label>
                <Input
                  id="edit_max_score"
                  type="number"
                  value={editingCategory.max_score}
                  onChange={(e) => setEditingCategory({ ...editingCategory, max_score: parseInt(e.target.value) || 100 })}
                  required
                />
              </div>
              <div className="flex items-center space-x-2">
                <Checkbox
                  id="edit_is_predefined"
                  checked={editingCategory.is_predefined || false}
                  onCheckedChange={(checked) => setEditingCategory({ ...editingCategory, is_predefined: checked })}
                />
                <Label htmlFor="edit_is_predefined" className="cursor-pointer">
                  Mark as Predefined Category
                </Label>
              </div>
              <div className="flex space-x-2">
                <Button type="submit">Update Category</Button>
                <Button type="button" variant="outline" onClick={() => setEditingCategory(null)}>
                  Cancel
                </Button>
              </div>
            </form>
          </DialogContent>
        </Dialog>
      )}
    </div>
  )
}

// User Scores Management Component
function UserScoresManagement() {
  const { t } = useTranslation()
  const [scores, setScores] = useState([])
  const [users, setUsers] = useState([])
  const [scoreCategories, setScoreCategories] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState('')
  const { currentOrganization } = useAuth()
  const [editingScore, setEditingScore] = useState(null)
  const [showEditDialog, setShowEditDialog] = useState(false)

  // Pagination
  const [currentPage, setCurrentPage] = useState(1)
  const [totalPages, setTotalPages] = useState(1)
  const [totalScores, setTotalScores] = useState(0)

  // Filters
  const [filterUserId, setFilterUserId] = useState('')
  const [filterCategory, setFilterCategory] = useState('')

  useEffect(() => {
    if (currentOrganization?.organization_id) {
      fetchScores()
      fetchUsers()
      fetchScoreCategories()
    }
  }, [currentOrganization, currentPage, filterUserId, filterCategory])

  const fetchScores = async () => {
    try {
      setLoading(true)
      const params = new URLSearchParams({
        page: currentPage.toString(),
        per_page: '20'
      })
      
      if (filterUserId) params.append('user_id', filterUserId)
      if (filterCategory) params.append('category', filterCategory)
      
      const response = await api.get(`/scores?${params}`)
      setScores(response.data.scores || [])
      setTotalPages(response.data.pagination?.pages || 1)
      setTotalScores(response.data.pagination?.total || 0)
    } catch (error) {
      setError('Failed to fetch scores')
      console.error('Error fetching scores:', error)
    } finally {
      setLoading(false)
    }
  }

  const fetchUsers = async () => {
    try {
      const response = await api.get(`/organizations/users`)
      setUsers(response.data.users || [])
    } catch (error) {
      console.error('Error fetching users:', error)
    }
  }

  const fetchScoreCategories = async () => {
    try {
      const response = await api.get('/scores/categories')
      setScoreCategories(response.data.categories || [])
    } catch (error) {
      console.error('Error fetching score categories:', error)
    }
  }

  const handleEditScore = (score) => {
    setEditingScore({
      ...score,
      score_value: score.score_value,
      category_id: score.category_id || ''
    })
    setShowEditDialog(true)
  }

  const handleUpdateScore = async (e) => {
    e.preventDefault()
    try {
      const payload = {
        score_value: editingScore.score_value,
        description: editingScore.description
      }
      if (editingScore.category_id) {
        payload.category_id = editingScore.category_id
      }
      await api.put(`/scores/${editingScore.id}`, payload)
      setSuccess('Score updated successfully!')
      setShowEditDialog(false)
      setEditingScore(null)
      fetchScores()
    } catch (error) {
      setError('Failed to update score')
    }
  }

  const handleDeleteScore = async (scoreId) => {
    if (!confirm('Are you sure you want to delete this score?')) {
      return
    }
    
    try {
      await api.delete(`/scores/${scoreId}`)
      setSuccess('Score deleted successfully!')
      fetchScores()
    } catch (error) {
      setError('Failed to delete score')
    }
  }

  const getUserName = (userId) => {
    const user = users.find(u => u.id === userId)
    if (!user) return `User ${userId?.slice(0, 8)}`
    return user.display_name || `${user.first_name || ''} ${user.last_name || ''}`.trim() || user.username || `User ${userId?.slice(0, 8)}`
  }

  if (!currentOrganization) {
    return (
      <div className="flex justify-center items-center py-8">
        <div className="text-gray-500">Please select an organization</div>
      </div>
    )
  }

  if (loading && scores.length === 0) return <LoadingSpinner />

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h3 className="text-lg font-semibold flex items-center gap-2">
          <Target className="h-5 w-5" />
          User Scores Management
        </h3>
        <div className="text-sm text-gray-600">
          Total Scores: {totalScores}
        </div>
      </div>

      {error && (
        <Alert variant="destructive">
          <AlertDescription>{error}</AlertDescription>
        </Alert>
      )}

      {success && (
        <Alert className="border-green-200 bg-green-50">
          <AlertDescription className="text-green-800">{success}</AlertDescription>
        </Alert>
      )}

      {/* Filters */}
      <Card>
        <CardHeader>
          <CardTitle>Filters</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <Label htmlFor="filterUser">Filter by User</Label>
              <Select value={filterUserId || "all"} onValueChange={(value) => {
                setFilterUserId(value === "all" ? "" : value)
                setCurrentPage(1)
              }}>
                <SelectTrigger>
                  <SelectValue placeholder="All Users" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">All Users</SelectItem>
                  {users.map((user) => (
                    <SelectItem key={user.id} value={user.id}>
                      {getUserName(user.id)}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div>
              <Label htmlFor="filterCategory">Filter by Category</Label>
              <Input
                id="filterCategory"
                value={filterCategory}
                onChange={(e) => {
                  setFilterCategory(e.target.value)
                  setCurrentPage(1)
                }}
                placeholder="Enter category"
              />
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Scores Table */}
      <Card>
        <CardHeader>
          <CardTitle>All Scores</CardTitle>
          <CardDescription>Review, edit, or delete scores assigned to users</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="overflow-x-auto">
            <table className="w-full border-collapse">
              <thead>
                <tr className="border-b">
                  <th className="text-left p-3 font-medium">User</th>
                  <th className="text-left p-3 font-medium">Category</th>
                  <th className="text-left p-3 font-medium">Score</th>
                  <th className="text-left p-3 font-medium">Description</th>
                  <th className="text-left p-3 font-medium">Date</th>
                  <th className="text-left p-3 font-medium">Actions</th>
                </tr>
              </thead>
              <tbody>
                {scores.map((score) => (
                  <tr key={score.id} className="border-b hover:bg-gray-50">
                    <td className="p-3">{getUserName(score.user_id)}</td>
                    <td className="p-3">
                      <span className="px-2 py-1 bg-blue-100 text-blue-800 rounded text-sm">
                        {score.category || 'general'}
                      </span>
                    </td>
                    <td className="p-3">
                      <span className="font-bold text-lg">{score.score_value}</span>
                    </td>
                    <td className="p-3 max-w-xs truncate">
                      {score.description || '-'}
                    </td>
                    <td className="p-3 text-sm text-gray-600">
                      {new Date(score.created_at).toLocaleDateString()}
                    </td>
                    <td className="p-3">
                      <div className="flex gap-2">
                        <Button
                          variant="outline"
                          size="sm"
                          onClick={() => handleEditScore(score)}
                        >
                          Edit
                        </Button>
                        <Button
                          variant="destructive"
                          size="sm"
                          onClick={() => handleDeleteScore(score.id)}
                        >
                          Delete
                        </Button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {scores.length === 0 && !loading && (
            <div className="text-center py-8 text-gray-500">
              No scores found
            </div>
          )}

          {/* Pagination */}
          {totalPages > 1 && (
            <div className="flex justify-center items-center gap-4 mt-6">
              <Button
                variant="outline"
                onClick={() => setCurrentPage(p => Math.max(1, p - 1))}
                disabled={currentPage === 1}
              >
                Previous
              </Button>
              <span className="text-sm">
                Page {currentPage} of {totalPages}
              </span>
              <Button
                variant="outline"
                onClick={() => setCurrentPage(p => Math.min(totalPages, p + 1))}
                disabled={currentPage === totalPages}
              >
                Next
              </Button>
            </div>
          )}
        </CardContent>
      </Card>

      {/* Edit Score Dialog */}
      {editingScore && (
        <Dialog open={showEditDialog} onOpenChange={setShowEditDialog}>
          <DialogContent>
            <DialogHeader>
              <DialogTitle>Edit Score</DialogTitle>
              <DialogDescription>
                Update the score value, category, or description
              </DialogDescription>
            </DialogHeader>
            <form onSubmit={handleUpdateScore} className="space-y-4">
              <div>
                <Label htmlFor="edit_score_value">Score Value</Label>
                <Input
                  id="edit_score_value"
                  type="number"
                  value={editingScore.score_value}
                  onChange={(e) => setEditingScore({
                    ...editingScore,
                    score_value: parseInt(e.target.value) || 0
                  })}
                  required
                />
              </div>
              <div>
                <Label htmlFor="edit_category">Category</Label>
                <Select
                  value={editingScore.category_id}
                  onValueChange={(value) => setEditingScore({ ...editingScore, category_id: value })}
                >
                  <SelectTrigger id="edit_category">
                    <SelectValue placeholder="Select category" />
                  </SelectTrigger>
                  <SelectContent>
                    {scoreCategories.map((cat) => (
                      <SelectItem key={cat.id} value={cat.id}>
                        {cat.name} (Max: {cat.max_score})
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              <div>
                <Label htmlFor="edit_description">Description</Label>
                <Input
                  id="edit_description"
                  value={editingScore.description || ''}
                  onChange={(e) => setEditingScore({
                    ...editingScore,
                    description: e.target.value
                  })}
                  placeholder="Optional description"
                />
              </div>
              <div className="flex gap-2 justify-end">
                <Button
                  type="button"
                  variant="outline"
                  onClick={() => {
                    setShowEditDialog(false)
                    setEditingScore(null)
                  }}
                >
                  Cancel
                </Button>
                <Button type="submit">
                  Save Changes
                </Button>
              </div>
            </form>
          </DialogContent>
        </Dialog>
      )}
    </div>
  )
}

// Leaderboard Management Component
function LeaderboardManagement() {
  const { t } = useTranslation()
  const [userLeaderboard, setUserLeaderboard] = useState([])
  const [groupLeaderboard, setGroupLeaderboard] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [activeTab, setActiveTab] = useState('users')
  const [categories, setCategories] = useState([])
  const [selectedCategory, setSelectedCategory] = useState('all')

  // Date filter state
  const [filterByDate, setFilterByDate] = useState(false)
  const [startDate, setStartDate] = useState('')
  const [endDate, setEndDate] = useState('')
  const [filterSaveSuccess, setFilterSaveSuccess] = useState('')
  const [filterSaveError, setFilterSaveError] = useState('')
  
  // User Profiles Management State
  const [userProfiles, setUserProfiles] = useState([])
  const [userProfilesLoading, setUserProfilesLoading] = useState(false)
  const [userProfilesError, setUserProfilesError] = useState('')
  const [searchTerm, setSearchTerm] = useState('')
  const [currentPage, setCurrentPage] = useState(1)
  const [totalPages, setTotalPages] = useState(1)
  const [totalUsers, setTotalUsers] = useState(0)
  
  // Export Settings State
  const [showExportSettings, setShowExportSettings] = useState(false)
  const [exportFields, setExportFields] = useState({
    // Basic Information - default enabled
    fullName: true,
    firstName: true,
    lastName: true,
    email: true,
    username: true,
    role: true,
    department: false,
    title: false,
    phoneNumber: true,
    gender: false,
    birthDate: false,
    bio: false,
    
    // Academic Information - default disabled
    studentId: false,
    major: false,
    schoolYear: false,
    gpa: false,
    graduationYear: false,
    
    // Address Information - default disabled
    addressLine1: false,
    addressLine2: false,
    city: false,
    state: false,
    postalCode: false,
    country: false,
    
    // Emergency Contact - default disabled
    emergencyContactName: false,
    emergencyContactPhone: false,
    emergencyContactRelationship: false,
    
    // Social Links - default disabled
    linkedinUrl: false,
    githubUrl: false,
    personalWebsite: false,
    
    // System Information - default disabled
    language: false,
    timezone: false,
    notificationPreferences: false,
    
    // Status Information - default enabled
    isVerified: true,
    isActive: true,
    emailVerified: false,
    hasQrCode: false,
    lastLogin: false,
    
    // Dates - default enabled
    joinedOrganization: true,
    accountCreated: false,
    lastUpdated: false
  })
  
  const { currentOrganization } = useAuth()

  useEffect(() => {
    if (currentOrganization?.organization_id) {
      fetchCategories()
      loadOrganizationFilterSettings()
      fetchLeaderboards()
    }
  }, [currentOrganization])

  useEffect(() => {
    if (currentOrganization?.organization_id && selectedCategory) {
      fetchLeaderboards()
    }
  }, [selectedCategory])

  // Fetch user profiles when tab is active or dependencies change
  useEffect(() => {
    if (currentOrganization?.organization_id && activeTab === 'users') {
      fetchUserProfiles()
    }
  }, [currentOrganization, activeTab, currentPage, searchTerm])

  const fetchCategories = async () => {
    try {
      const response = await api.get(`/leaderboards/categories?organization_id=${currentOrganization.organization_id}`)
      const availableCategories = response.data.categories || ['all', 'general']
      setCategories(availableCategories)
      
      // Set default category if current selection isn't available
      if (!availableCategories.includes(selectedCategory)) {
        setSelectedCategory(availableCategories[0] || 'all')
      }
    } catch (error) {
      console.error('Failed to fetch categories:', error)
      setCategories(['all', 'general'])
    }
  }

  const loadOrganizationFilterSettings = async () => {
    try {
      const response = await api.get('/organizations/')
      const org = response.data.organization
      if (org) {
        setFilterByDate(org.filter_enabled || false)
        setStartDate(org.filter_start_date || '')
        setEndDate(org.filter_end_date || '')
      }
    } catch (error) {
      console.error('Failed to load organization filter settings:', error)
    }
  }

  const saveOrganizationFilterSettings = async () => {
    setFilterSaveError('')
    setFilterSaveSuccess('')

    if (filterByDate) {
      if (!startDate || !endDate) {
        setFilterSaveError('Both start date and end date are required.')
        return
      }
      if (new Date(startDate) >= new Date(endDate)) {
        setFilterSaveError('Start date must be before end date.')
        return
      }
    }

    try {
      await api.put('/organizations/filter-settings', {
        filter_enabled: filterByDate,
        filter_start_date: filterByDate ? startDate : null,
        filter_end_date: filterByDate ? endDate : null,
      })
      setFilterSaveSuccess('Date filter settings saved successfully.')
      setTimeout(() => setFilterSaveSuccess(''), 3000)
      fetchLeaderboards()
    } catch (error) {
      const msg = error.response?.data?.error || 'Failed to save filter settings.'
      setFilterSaveError(msg)
      setTimeout(() => setFilterSaveError(''), 4000)
    }
  }

  const fetchLeaderboards = async () => {
    try {
      setLoading(true)
      const params = new URLSearchParams({
        organization_id: currentOrganization.organization_id,
        category: selectedCategory,
      })
      if (filterByDate && startDate) params.append('start_date', startDate)
      if (filterByDate && endDate) params.append('end_date', endDate)

      const [usersResponse, groupsResponse] = await Promise.all([
        api.get(`/leaderboards/users?${params}`),
        api.get(`/leaderboards/groups?${params}`)
      ])

      setUserLeaderboard(usersResponse.data.leaderboard || [])
      setGroupLeaderboard(groupsResponse.data.leaderboard || [])
    } catch (error) {
      setError('Failed to fetch leaderboards')
    } finally {
      setLoading(false)
    }
  }

  const fetchUserProfiles = async () => {
    try {
      setUserProfilesLoading(true)
      setUserProfilesError('')
      
      const params = new URLSearchParams({
        page: currentPage.toString(),
        per_page: '10'
      })
      
      if (searchTerm.trim()) {
        params.append('search', searchTerm.trim())
      }
      
      const response = await api.get(`/profile/organization-users?${params}&organization_id=${currentOrganization.organization_id}`)
      
      console.log('User profiles response:', response.data)
      setUserProfiles(response.data.users || [])
      setTotalUsers(response.data.pagination?.total || response.data.total || 0)
      setTotalPages(response.data.pagination?.pages || response.data.pages || 1)
    } catch (error) {
      setUserProfilesError('Failed to fetch user profiles')
      console.error('Error fetching user profiles:', error)
    } finally {
      setUserProfilesLoading(false)
    }
  }

  // Helper function to get field mappings
  const getFieldMapping = () => ({
    fullName: { 
      label: 'Full Name', 
      getValue: (user) => user.display_name || `${user.first_name || ''} ${user.last_name || ''}`.trim() || user.username || `User ${user.user_id?.slice(0, 8)}` 
    },
    firstName: { label: 'First Name', getValue: (user) => user.first_name || '' },
    lastName: { label: 'Last Name', getValue: (user) => user.last_name || '' },
    email: { label: 'Email', getValue: (user) => user.email || '' },
    username: { label: 'Username', getValue: (user) => user.username || '' },
    role: { label: 'Role', getValue: (user) => user.role || '' },
    department: { label: 'Department', getValue: (user) => user.department || '' },
    title: { label: 'Title', getValue: (user) => user.title || '' },
    phoneNumber: { label: 'Phone Number', getValue: (user) => user.phone_number || '' },
    gender: { label: 'Gender', getValue: (user) => user.gender || '' },
    birthDate: { label: 'Birth Date', getValue: (user) => user.birthdate ? new Date(user.birthdate).toLocaleDateString() : '' },
    bio: { label: 'Bio', getValue: (user) => user.bio || '' },
    
    studentId: { label: 'Student ID', getValue: (user) => user.student_id || '' },
    major: { label: 'Major', getValue: (user) => user.major || '' },
    schoolYear: { label: 'School Year', getValue: (user) => user.school_year || '' },
    gpa: { label: 'GPA', getValue: (user) => user.gpa || '' },
    graduationYear: { label: 'Graduation Year', getValue: (user) => user.graduation_year || '' },
    
    addressLine1: { label: 'Address Line 1', getValue: (user) => user.address_line1 || '' },
    addressLine2: { label: 'Address Line 2', getValue: (user) => user.address_line2 || '' },
    city: { label: 'City', getValue: (user) => user.city || '' },
    state: { label: 'State', getValue: (user) => user.state || '' },
    postalCode: { label: 'Postal Code', getValue: (user) => user.postal_code || '' },
    country: { label: 'Country', getValue: (user) => user.country || '' },
    
    emergencyContactName: { label: 'Emergency Contact Name', getValue: (user) => user.emergency_contact_name || '' },
    emergencyContactPhone: { label: 'Emergency Contact Phone', getValue: (user) => user.emergency_contact_phone || '' },
    emergencyContactRelationship: { label: 'Emergency Contact Relationship', getValue: (user) => user.emergency_contact_relationship || '' },
    
    linkedinUrl: { label: 'LinkedIn URL', getValue: (user) => user.linkedin_url || '' },
    githubUrl: { label: 'GitHub URL', getValue: (user) => user.github_url || '' },
    personalWebsite: { label: 'Personal Website', getValue: (user) => user.personal_website || '' },
    
    language: { label: 'Language', getValue: (user) => user.language || '' },
    timezone: { label: 'Timezone', getValue: (user) => user.timezone || '' },
    notificationPreferences: { label: 'Notification Preferences', getValue: (user) => user.notification_preferences ? JSON.stringify(user.notification_preferences) : '' },
    
    isVerified: { label: 'Is Verified', getValue: (user) => user.is_verified ? 'Yes' : 'No' },
    isActive: { label: 'Is Active', getValue: (user) => user.is_active ? 'Yes' : 'No' },
    emailVerified: { label: 'Email Verified', getValue: (user) => user.email_verified_at ? 'Yes' : 'No' },
    hasQrCode: { label: 'Has QR Code', getValue: (user) => user.has_qr_code ? 'Yes' : 'No' },
    lastLogin: { label: 'Last Login', getValue: (user) => user.last_login_at ? new Date(user.last_login_at).toLocaleDateString() : '' },
    
    joinedOrganization: { label: 'Joined Organization', getValue: (user) => user.joined_at ? new Date(user.joined_at).toLocaleDateString() : '' },
    accountCreated: { label: 'Account Created', getValue: (user) => user.created_at ? new Date(user.created_at).toLocaleDateString() : '' },
    lastUpdated: { label: 'Last Updated', getValue: (user) => user.updated_at ? new Date(user.updated_at).toLocaleDateString() : '' }
  })

  const exportToExcel = async () => {
    try {
      // First, fetch ALL users (not just current page) for export
      const params = new URLSearchParams({
        page: '1',
        per_page: totalUsers.toString() // Get all users
      })
      
      if (searchTerm.trim()) {
        params.append('search', searchTerm.trim())
      }
      
      const response = await api.get(`/profile/organization-users?${params}&organization_id=${currentOrganization.organization_id}`)
      const allUsers = response.data.users || []
      
      // Get only selected fields
      const fieldMapping = getFieldMapping()
      const selectedFields = Object.keys(exportFields).filter(field => exportFields[field])
      
      if (selectedFields.length === 0) {
        alert('Please select at least one field to export.')
        return
      }
      
      // Build headers and rows based on selected fields
      const csvHeaders = selectedFields.map(field => fieldMapping[field].label)
      const csvRows = allUsers.map(user => 
        selectedFields.map(field => fieldMapping[field].getValue(user))
      )
      
      const csvContent = [csvHeaders, ...csvRows]
        .map(row => row.map(field => `"${field}"`).join(','))
        .join('\n')
      
      // Create and download file
      const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' })
      const link = document.createElement('a')
      const url = URL.createObjectURL(blob)
      link.setAttribute('href', url)
      link.setAttribute('download', `user-profiles-${currentOrganization?.name || 'org'}-${new Date().toISOString().split('T')[0]}.csv`)
      link.style.visibility = 'hidden'
      document.body.appendChild(link)
      link.click()
      document.body.removeChild(link)
      
    } catch (error) {
      console.error('Error exporting user profiles:', error)
      alert('Failed to export user profiles. Please try again.')
    }
  }

  if (loading) return <LoadingSpinner />

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:justify-between sm:items-center gap-3">
        <h3 className="text-lg font-semibold flex items-center gap-2">
          <TrendingUp className="h-5 w-5" />
          {t('sections.leaderboards')}
        </h3>
        <div className="flex flex-wrap items-center gap-2">
          <label htmlFor="category-select" className="text-sm font-medium">{t('leaderboards.category')}:</label>
          <Select value={selectedCategory} onValueChange={setSelectedCategory}>
            <SelectTrigger className="w-[140px]">
              <SelectValue placeholder={t('common.selectCategory')} />
            </SelectTrigger>
            <SelectContent>
              {categories.map((category) => (
                <SelectItem key={category} value={category}>
                  {category === 'all' ? t('leaderboards.allCategories') : category.charAt(0).toUpperCase() + category.slice(1)}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
          <Button onClick={fetchLeaderboards} variant="outline" size="sm">
            {t('common.refresh')}
          </Button>
        </div>
      </div>

      {error && (
        <Alert variant="destructive">
          <AlertDescription>{error}</AlertDescription>
        </Alert>
      )}

      {/* Date Filter Card */}
      <Card>
        <CardContent className="pt-4 pb-4">
          <div className="flex flex-wrap items-center gap-3">
            <div className="flex items-center gap-2">
              <input
                type="checkbox"
                id="filterByDate"
                checked={filterByDate}
                onChange={e => setFilterByDate(e.target.checked)}
                className="h-4 w-4 cursor-pointer"
              />
              <label htmlFor="filterByDate" className="text-sm font-medium cursor-pointer">Filter by Date</label>
            </div>
            {filterByDate && (
              <>
                <div className="flex items-center gap-2">
                  <label className="text-sm font-medium text-gray-600">From:</label>
                  <input
                    type="date"
                    value={startDate}
                    onChange={e => setStartDate(e.target.value)}
                    className="border rounded px-2 py-1 text-sm w-full sm:w-auto"
                  />
                </div>
                <div className="flex items-center gap-2">
                  <label className="text-sm font-medium text-gray-600">To:</label>
                  <input
                    type="date"
                    value={endDate}
                    onChange={e => setEndDate(e.target.value)}
                    className="border rounded px-2 py-1 text-sm w-full sm:w-auto"
                  />
                </div>
              </>
            )}
            <Button size="sm" onClick={saveOrganizationFilterSettings} variant="secondary">
              {filterByDate ? 'Save as Default' : 'Save (No Filter)'}
            </Button>
          </div>
          {filterSaveSuccess && <p className="text-green-600 text-sm mt-2">{filterSaveSuccess}</p>}
          {filterSaveError && <p className="text-red-600 text-sm mt-2">{filterSaveError}</p>}
        </CardContent>
      </Card>

      <Tabs value={activeTab} onValueChange={setActiveTab}>
        <TabsList>
          <TabsTrigger value="users">{t('leaderboards.userLeaderboard')}</TabsTrigger>
          <TabsTrigger value="groups">{t('leaderboards.groupLeaderboard')}</TabsTrigger>
          <TabsTrigger value="user-profiles">User Profiles</TabsTrigger>
        </TabsList>

        <TabsContent value="users">
          <Card>
            <CardHeader>
              <CardTitle>{t('leaderboards.userLeaderboard')} - {selectedCategory === 'all' ? t('leaderboards.allCategories') : selectedCategory.charAt(0).toUpperCase() + selectedCategory.slice(1)}</CardTitle>
              <CardDescription>{t('leaderboards.topUsersRanked')} {selectedCategory === 'all' ? t('leaderboards.acrossAllCategories') : `${t('leaderboards.inCategory')} ${selectedCategory}`}</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-3">
                {userLeaderboard.map((user, index) => (
                  <div key={user.user_id} className="flex items-center justify-between p-3 border rounded">
                    <div className="flex items-center gap-3">
                      <div className="flex items-center justify-center w-8 h-8 rounded-full bg-primary text-primary-foreground font-bold">
                        {user.rank || index + 1}
                      </div>
                      <div>
                        <h4 className="font-medium">{user.display_name || `${user.first_name || ''} ${user.last_name || ''}`.trim() || user.username || `User ${user.user_id?.slice(0, 8)}`}</h4>
                        <p className="text-sm text-gray-600">@{user.username || 'unknown'}</p>
                      </div>
                    </div>
                    <div className="text-right">
                      <div className="font-bold text-lg">{user.total_score || 0}</div>
                      <div className="text-sm text-gray-600">{user.score_count || 0} {t('leaderboards.scores')}</div>
                    </div>
                  </div>
                ))}
                {userLeaderboard.length === 0 && (
                  <p className="text-center text-gray-500 py-8">{t('leaderboards.noUsersFound')}</p>
                )}
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="groups">
          <Card>
            <CardHeader>
              <CardTitle>{t('leaderboards.groupLeaderboard')} - {selectedCategory === 'all' ? t('leaderboards.allCategories') : selectedCategory.charAt(0).toUpperCase() + selectedCategory.slice(1)}</CardTitle>
              <CardDescription>{t('leaderboards.topGroupsRanked')} {selectedCategory === 'all' ? t('leaderboards.acrossAllCategories') : `${t('leaderboards.inCategory')} ${selectedCategory}`}</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-3">
                {groupLeaderboard.map((group, index) => (
                  <div key={group.id} className="flex items-center justify-between p-3 border rounded">
                    <div className="flex items-center gap-3">
                      <div className="flex items-center justify-center w-8 h-8 rounded-full bg-primary text-primary-foreground font-bold">
                        {index + 1}
                      </div>
                      <div>
                        <h4 className="font-medium">{group.name}</h4>
                        <p className="text-sm text-gray-600">{group.member_count || 0} {t('leaderboards.members')}</p>
                      </div>
                    </div>
                    <div className="text-right">
                      <div className="font-bold text-lg">{group.total_score || 0}</div>
                      <div className="text-sm text-gray-600">{group.score_count || 0} {t('leaderboards.scores')}</div>
                    </div>
                  </div>
                ))}
                {groupLeaderboard.length === 0 && (
                  <p className="text-center text-gray-500 py-8">{t('leaderboards.noGroupsFound')}</p>
                )}
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="user-profiles">
          <Card>
            <CardHeader>
              <div className="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-3">
                <div>
                  <CardTitle>Organization User Profiles</CardTitle>
                </div>
                <div className="flex flex-wrap gap-2 shrink-0">
                  <Dialog open={showExportSettings} onOpenChange={setShowExportSettings}>
                    <DialogTrigger asChild>
                      <Button variant="outline" size="sm">
                        <Settings className="h-4 w-4 mr-2" />
                        Export Settings
                      </Button>
                    </DialogTrigger>
                    <DialogContent className="max-w-4xl max-h-[80vh] overflow-y-auto">
                      <DialogHeader>
                        <DialogTitle>Export Field Settings</DialogTitle>
                        <DialogDescription>
                          Select which fields to include in the CSV export. Changes are saved automatically.
                        </DialogDescription>
                      </DialogHeader>
                      
                      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 py-4">
                        
                        {/* Basic Information */}
                        <div className="space-y-3">
                          <h4 className="font-medium text-sm text-gray-900">Basic Information</h4>
                          <div className="space-y-2">
                            <div className="flex items-center space-x-2">
                              <Checkbox 
                                id="fullName"
                                checked={exportFields.fullName}
                                onCheckedChange={(checked) => setExportFields(prev => ({...prev, fullName: checked}))}
                              />
                              <Label htmlFor="fullName" className="text-sm">Full Name</Label>
                            </div>
                            <div className="flex items-center space-x-2">
                              <Checkbox 
                                id="firstName"
                                checked={exportFields.firstName}
                                onCheckedChange={(checked) => setExportFields(prev => ({...prev, firstName: checked}))}
                              />
                              <Label htmlFor="firstName" className="text-sm">First Name</Label>
                            </div>
                            <div className="flex items-center space-x-2">
                              <Checkbox 
                                id="lastName"
                                checked={exportFields.lastName}
                                onCheckedChange={(checked) => setExportFields(prev => ({...prev, lastName: checked}))}
                              />
                              <Label htmlFor="lastName" className="text-sm">Last Name</Label>
                            </div>
                            <div className="flex items-center space-x-2">
                              <Checkbox 
                                id="email"
                                checked={exportFields.email}
                                onCheckedChange={(checked) => setExportFields(prev => ({...prev, email: checked}))}
                              />
                              <Label htmlFor="email" className="text-sm">Email</Label>
                            </div>
                            <div className="flex items-center space-x-2">
                              <Checkbox 
                                id="username"
                                checked={exportFields.username}
                                onCheckedChange={(checked) => setExportFields(prev => ({...prev, username: checked}))}
                              />
                              <Label htmlFor="username" className="text-sm">Username</Label>
                            </div>
                            <div className="flex items-center space-x-2">
                              <Checkbox 
                                id="role"
                                checked={exportFields.role}
                                onCheckedChange={(checked) => setExportFields(prev => ({...prev, role: checked}))}
                              />
                              <Label htmlFor="role" className="text-sm">Role</Label>
                            </div>
                            <div className="flex items-center space-x-2">
                              <Checkbox 
                                id="department"
                                checked={exportFields.department}
                                onCheckedChange={(checked) => setExportFields(prev => ({...prev, department: checked}))}
                              />
                              <Label htmlFor="department" className="text-sm">Department</Label>
                            </div>
                            <div className="flex items-center space-x-2">
                              <Checkbox 
                                id="title"
                                checked={exportFields.title}
                                onCheckedChange={(checked) => setExportFields(prev => ({...prev, title: checked}))}
                              />
                              <Label htmlFor="title" className="text-sm">Title</Label>
                            </div>
                            <div className="flex items-center space-x-2">
                              <Checkbox 
                                id="phoneNumber"
                                checked={exportFields.phoneNumber}
                                onCheckedChange={(checked) => setExportFields(prev => ({...prev, phoneNumber: checked}))}
                              />
                              <Label htmlFor="phoneNumber" className="text-sm">Phone Number</Label>
                            </div>
                            <div className="flex items-center space-x-2">
                              <Checkbox 
                                id="gender"
                                checked={exportFields.gender}
                                onCheckedChange={(checked) => setExportFields(prev => ({...prev, gender: checked}))}
                              />
                              <Label htmlFor="gender" className="text-sm">Gender</Label>
                            </div>
                            <div className="flex items-center space-x-2">
                              <Checkbox 
                                id="birthDate"
                                checked={exportFields.birthDate}
                                onCheckedChange={(checked) => setExportFields(prev => ({...prev, birthDate: checked}))}
                              />
                              <Label htmlFor="birthDate" className="text-sm">Birth Date</Label>
                            </div>
                            <div className="flex items-center space-x-2">
                              <Checkbox 
                                id="bio"
                                checked={exportFields.bio}
                                onCheckedChange={(checked) => setExportFields(prev => ({...prev, bio: checked}))}
                              />
                              <Label htmlFor="bio" className="text-sm">Bio</Label>
                            </div>
                          </div>
                        </div>

                        {/* Academic Information */}
                        <div className="space-y-3">
                          <h4 className="font-medium text-sm text-gray-900">Academic Information</h4>
                          <div className="space-y-2">
                            <div className="flex items-center space-x-2">
                              <Checkbox 
                                id="studentId"
                                checked={exportFields.studentId}
                                onCheckedChange={(checked) => setExportFields(prev => ({...prev, studentId: checked}))}
                              />
                              <Label htmlFor="studentId" className="text-sm">Student ID</Label>
                            </div>
                            <div className="flex items-center space-x-2">
                              <Checkbox 
                                id="major"
                                checked={exportFields.major}
                                onCheckedChange={(checked) => setExportFields(prev => ({...prev, major: checked}))}
                              />
                              <Label htmlFor="major" className="text-sm">Major</Label>
                            </div>
                            <div className="flex items-center space-x-2">
                              <Checkbox 
                                id="schoolYear"
                                checked={exportFields.schoolYear}
                                onCheckedChange={(checked) => setExportFields(prev => ({...prev, schoolYear: checked}))}
                              />
                              <Label htmlFor="schoolYear" className="text-sm">School Year</Label>
                            </div>
                            <div className="flex items-center space-x-2">
                              <Checkbox 
                                id="gpa"
                                checked={exportFields.gpa}
                                onCheckedChange={(checked) => setExportFields(prev => ({...prev, gpa: checked}))}
                              />
                              <Label htmlFor="gpa" className="text-sm">GPA</Label>
                            </div>
                            <div className="flex items-center space-x-2">
                              <Checkbox 
                                id="graduationYear"
                                checked={exportFields.graduationYear}
                                onCheckedChange={(checked) => setExportFields(prev => ({...prev, graduationYear: checked}))}
                              />
                              <Label htmlFor="graduationYear" className="text-sm">Graduation Year</Label>
                            </div>
                          </div>
                        </div>

                        {/* Address Information */}
                        <div className="space-y-3">
                          <h4 className="font-medium text-sm text-gray-900">Address Information</h4>
                          <div className="space-y-2">
                            <div className="flex items-center space-x-2">
                              <Checkbox 
                                id="addressLine1"
                                checked={exportFields.addressLine1}
                                onCheckedChange={(checked) => setExportFields(prev => ({...prev, addressLine1: checked}))}
                              />
                              <Label htmlFor="addressLine1" className="text-sm">Address Line 1</Label>
                            </div>
                            <div className="flex items-center space-x-2">
                              <Checkbox 
                                id="addressLine2"
                                checked={exportFields.addressLine2}
                                onCheckedChange={(checked) => setExportFields(prev => ({...prev, addressLine2: checked}))}
                              />
                              <Label htmlFor="addressLine2" className="text-sm">Address Line 2</Label>
                            </div>
                            <div className="flex items-center space-x-2">
                              <Checkbox 
                                id="city"
                                checked={exportFields.city}
                                onCheckedChange={(checked) => setExportFields(prev => ({...prev, city: checked}))}
                              />
                              <Label htmlFor="city" className="text-sm">City</Label>
                            </div>
                            <div className="flex items-center space-x-2">
                              <Checkbox 
                                id="state"
                                checked={exportFields.state}
                                onCheckedChange={(checked) => setExportFields(prev => ({...prev, state: checked}))}
                              />
                              <Label htmlFor="state" className="text-sm">State</Label>
                            </div>
                            <div className="flex items-center space-x-2">
                              <Checkbox 
                                id="postalCode"
                                checked={exportFields.postalCode}
                                onCheckedChange={(checked) => setExportFields(prev => ({...prev, postalCode: checked}))}
                              />
                              <Label htmlFor="postalCode" className="text-sm">Postal Code</Label>
                            </div>
                            <div className="flex items-center space-x-2">
                              <Checkbox 
                                id="country"
                                checked={exportFields.country}
                                onCheckedChange={(checked) => setExportFields(prev => ({...prev, country: checked}))}
                              />
                              <Label htmlFor="country" className="text-sm">Country</Label>
                            </div>
                          </div>
                        </div>
                      </div>
                      
                      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 py-4 border-t">
                        
                        {/* Emergency Contact */}
                        <div className="space-y-3">
                          <h4 className="font-medium text-sm text-gray-900">Emergency Contact</h4>
                          <div className="space-y-2">
                            <div className="flex items-center space-x-2">
                              <Checkbox 
                                id="emergencyContactName"
                                checked={exportFields.emergencyContactName}
                                onCheckedChange={(checked) => setExportFields(prev => ({...prev, emergencyContactName: checked}))}
                              />
                              <Label htmlFor="emergencyContactName" className="text-sm">Emergency Contact Name</Label>
                            </div>
                            <div className="flex items-center space-x-2">
                              <Checkbox 
                                id="emergencyContactPhone"
                                checked={exportFields.emergencyContactPhone}
                                onCheckedChange={(checked) => setExportFields(prev => ({...prev, emergencyContactPhone: checked}))}
                              />
                              <Label htmlFor="emergencyContactPhone" className="text-sm">Emergency Contact Phone</Label>
                            </div>
                            <div className="flex items-center space-x-2">
                              <Checkbox 
                                id="emergencyContactRelationship"
                                checked={exportFields.emergencyContactRelationship}
                                onCheckedChange={(checked) => setExportFields(prev => ({...prev, emergencyContactRelationship: checked}))}
                              />
                              <Label htmlFor="emergencyContactRelationship" className="text-sm">Emergency Contact Relationship</Label>
                            </div>
                          </div>
                        </div>

                        {/* Social Links */}
                        <div className="space-y-3">
                          <h4 className="font-medium text-sm text-gray-900">Social Links</h4>
                          <div className="space-y-2">
                            <div className="flex items-center space-x-2">
                              <Checkbox 
                                id="linkedinUrl"
                                checked={exportFields.linkedinUrl}
                                onCheckedChange={(checked) => setExportFields(prev => ({...prev, linkedinUrl: checked}))}
                              />
                              <Label htmlFor="linkedinUrl" className="text-sm">LinkedIn URL</Label>
                            </div>
                            <div className="flex items-center space-x-2">
                              <Checkbox 
                                id="githubUrl"
                                checked={exportFields.githubUrl}
                                onCheckedChange={(checked) => setExportFields(prev => ({...prev, githubUrl: checked}))}
                              />
                              <Label htmlFor="githubUrl" className="text-sm">GitHub URL</Label>
                            </div>
                            <div className="flex items-center space-x-2">
                              <Checkbox 
                                id="personalWebsite"
                                checked={exportFields.personalWebsite}
                                onCheckedChange={(checked) => setExportFields(prev => ({...prev, personalWebsite: checked}))}
                              />
                              <Label htmlFor="personalWebsite" className="text-sm">Personal Website</Label>
                            </div>
                          </div>
                        </div>

                        {/* Status & Dates */}
                        <div className="space-y-3">
                          <h4 className="font-medium text-sm text-gray-900">Status & Dates</h4>
                          <div className="space-y-2">
                            <div className="flex items-center space-x-2">
                              <Checkbox 
                                id="isVerified"
                                checked={exportFields.isVerified}
                                onCheckedChange={(checked) => setExportFields(prev => ({...prev, isVerified: checked}))}
                              />
                              <Label htmlFor="isVerified" className="text-sm">Is Verified</Label>
                            </div>
                            <div className="flex items-center space-x-2">
                              <Checkbox 
                                id="isActive"
                                checked={exportFields.isActive}
                                onCheckedChange={(checked) => setExportFields(prev => ({...prev, isActive: checked}))}
                              />
                              <Label htmlFor="isActive" className="text-sm">Is Active</Label>
                            </div>
                            <div className="flex items-center space-x-2">
                              <Checkbox 
                                id="emailVerified"
                                checked={exportFields.emailVerified}
                                onCheckedChange={(checked) => setExportFields(prev => ({...prev, emailVerified: checked}))}
                              />
                              <Label htmlFor="emailVerified" className="text-sm">Email Verified</Label>
                            </div>
                            <div className="flex items-center space-x-2">
                              <Checkbox 
                                id="hasQrCode"
                                checked={exportFields.hasQrCode}
                                onCheckedChange={(checked) => setExportFields(prev => ({...prev, hasQrCode: checked}))}
                              />
                              <Label htmlFor="hasQrCode" className="text-sm">Has QR Code</Label>
                            </div>
                            <div className="flex items-center space-x-2">
                              <Checkbox 
                                id="lastLogin"
                                checked={exportFields.lastLogin}
                                onCheckedChange={(checked) => setExportFields(prev => ({...prev, lastLogin: checked}))}
                              />
                              <Label htmlFor="lastLogin" className="text-sm">Last Login</Label>
                            </div>
                            <div className="flex items-center space-x-2">
                              <Checkbox 
                                id="joinedOrganization"
                                checked={exportFields.joinedOrganization}
                                onCheckedChange={(checked) => setExportFields(prev => ({...prev, joinedOrganization: checked}))}
                              />
                              <Label htmlFor="joinedOrganization" className="text-sm">Joined Organization</Label>
                            </div>
                            <div className="flex items-center space-x-2">
                              <Checkbox 
                                id="accountCreated"
                                checked={exportFields.accountCreated}
                                onCheckedChange={(checked) => setExportFields(prev => ({...prev, accountCreated: checked}))}
                              />
                              <Label htmlFor="accountCreated" className="text-sm">Account Created</Label>
                            </div>
                            <div className="flex items-center space-x-2">
                              <Checkbox 
                                id="lastUpdated"
                                checked={exportFields.lastUpdated}
                                onCheckedChange={(checked) => setExportFields(prev => ({...prev, lastUpdated: checked}))}
                              />
                              <Label htmlFor="lastUpdated" className="text-sm">Last Updated</Label>
                            </div>
                          </div>
                        </div>
                      </div>

                      <div className="flex justify-between items-center pt-4 border-t">
                        <div className="flex gap-2">
                          <Button 
                            variant="outline" 
                            size="sm"
                            onClick={() => {
                              // Select All
                              setExportFields(prev => Object.keys(prev).reduce((acc, key) => ({...acc, [key]: true}), {}))
                            }}
                          >
                            Select All
                          </Button>
                          <Button 
                            variant="outline" 
                            size="sm"
                            onClick={() => {
                              // Select None
                              setExportFields(prev => Object.keys(prev).reduce((acc, key) => ({...acc, [key]: false}), {}))
                            }}
                          >
                            Select None
                          </Button>
                        </div>
                        <Button onClick={() => setShowExportSettings(false)}>
                          Done
                        </Button>
                      </div>
                    </DialogContent>
                  </Dialog>
                  
                  <Button
                    onClick={exportToExcel}
                    variant="outline"
                    size="sm"
                    disabled={userProfiles.length === 0}
                  >
                    Export CSV ({Object.values(exportFields).filter(Boolean).length} fields)
                  </Button>
                </div>
              </div>
              <CardDescription className="mt-1">
                View and manage all user profiles in your organization ({totalUsers} total users)
              </CardDescription>
              <div className="flex flex-col sm:flex-row sm:items-center gap-2 mt-4">
                <Input
                  placeholder="Search by name, email, or username..."
                  value={searchTerm}
                  onChange={(e) => {
                    setSearchTerm(e.target.value)
                    setCurrentPage(1)
                  }}
                  className="flex-1"
                />
                <Button onClick={fetchUserProfiles} variant="outline" size="sm" className="shrink-0">
                  Refresh
                </Button>
              </div>
            </CardHeader>
            <CardContent>
              {userProfilesError && (
                <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-4">
                  {userProfilesError}
                </div>
              )}
              
              {userProfilesLoading ? (
                <div className="flex justify-center items-center py-8">
                  <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-gray-900"></div>
                  <span className="ml-2">Loading user profiles...</span>
                </div>
              ) : (
                <>
                  <div className="overflow-x-auto">
                    <table className="w-full border-collapse border border-gray-200">
                      <thead>
                        <tr className="bg-gray-50">
                          <th className="border border-gray-200 px-4 py-2 text-left">Name</th>
                          <th className="border border-gray-200 px-4 py-2 text-left">Email</th>
                          <th className="border border-gray-200 px-4 py-2 text-left">Username</th>
                          <th className="border border-gray-200 px-4 py-2 text-left">Role</th>
                          <th className="border border-gray-200 px-4 py-2 text-left">Department</th>
                          <th className="border border-gray-200 px-4 py-2 text-left">Title</th>
                          <th className="border border-gray-200 px-4 py-2 text-left">Phone</th>
                          <th className="border border-gray-200 px-4 py-2 text-left">City</th>
                          <th className="border border-gray-200 px-4 py-2 text-left">Major</th>
                          <th className="border border-gray-200 px-4 py-2 text-left">Joined</th>
                        </tr>
                      </thead>
                      <tbody>
                        {userProfiles.map((user) => (
                          <tr key={user.user_id} className="hover:bg-gray-50">
                            <td className="border border-gray-200 px-4 py-2">
                              <div className="flex items-center gap-2">
                                <img
                                  src={(() => {
                                    if (!user.profile_picture_url || user.profile_picture_url.trim() === '') return '/default-profile.png';
                                    if (user.profile_picture_url.startsWith('http')) return user.profile_picture_url;
                                    // Use relative URL so it works on both admin and main domains
                                    return user.profile_picture_url;
                                  })()}
                                  alt="Profile"
                                  className="w-8 h-8 rounded-full object-cover border border-gray-300 bg-gray-100"
                                  onError={e => { e.target.onerror = null; e.target.src = '/default-profile.png'; }}
                                />
                                <span>
                                  {user.display_name ||
                                    `${user.first_name || ''} ${user.last_name || ''}`.trim() ||
                                    user.username ||
                                    `User ${user.user_id?.slice(0, 8)}`}
                                </span>
                              </div>
                            </td>
                            <td className="border border-gray-200 px-4 py-2">{user.email || 'N/A'}</td>
                            <td className="border border-gray-200 px-4 py-2">{user.username || 'N/A'}</td>
                            <td className="border border-gray-200 px-4 py-2">
                              <span className={`px-2 py-1 rounded-full text-xs font-medium ${
                                user.role === 'ORG_ADMIN' ? 'bg-purple-100 text-purple-800' :
                                user.role === 'MEMBER' ? 'bg-blue-100 text-blue-800' :
                                'bg-gray-100 text-gray-800'
                              }`}>
                                {user.role || 'N/A'}
                              </span>
                            </td>
                            <td className="border border-gray-200 px-4 py-2">{user.department || 'N/A'}</td>
                            <td className="border border-gray-200 px-4 py-2">{user.title || 'N/A'}</td>
                            <td className="border border-gray-200 px-4 py-2">{user.phone_number || 'N/A'}</td>
                            <td className="border border-gray-200 px-4 py-2">{user.city || 'N/A'}</td>
                            <td className="border border-gray-200 px-4 py-2">{user.major || 'N/A'}</td>
                            <td className="border border-gray-200 px-4 py-2">
                              {user.joined_at ? new Date(user.joined_at).toLocaleDateString() : 'N/A'}
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                  
                  {userProfiles.length === 0 && !userProfilesLoading && (
                    <p className="text-center text-gray-500 py-8">
                      {searchTerm ? 'No users found matching your search.' : 'No users found in this organization.'}
                    </p>
                  )}
                  
                  {totalPages > 1 && (
                    <div className="flex flex-col sm:flex-row sm:justify-between sm:items-center gap-2 mt-6">
                      <div className="text-sm text-gray-600">
                        Page {currentPage} of {totalPages} ({totalUsers} total users)
                      </div>
                      <div className="flex gap-2">
                        <Button
                          onClick={() => setCurrentPage(prev => Math.max(1, prev - 1))}
                          disabled={currentPage === 1}
                          variant="outline"
                          size="sm"
                        >
                          Previous
                        </Button>
                        <Button
                          onClick={() => setCurrentPage(prev => Math.min(totalPages, prev + 1))}
                          disabled={currentPage === totalPages}
                          variant="outline"
                          size="sm"
                        >
                          Next
                        </Button>
                      </div>
                    </div>
                  )}
                </>
              )}
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>
    </div>
  )
}

// QR Scanner Management Component
function QRScannerManagement() {
  const { t } = useTranslation()
  const [scoreCategories, setScoreCategories] = useState([])
  const [orgUsers, setOrgUsers] = useState([])
  const [isScanning, setIsScanning] = useState(false)
  const [cameraError, setCameraError] = useState('')
  const [scannedUser, setScannedUser] = useState(null)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState('')
  const { currentOrganization } = useAuth()
  const videoRef = useRef(null)
  const canvasRef = useRef(null)
  const scanIntervalRef = useRef(null)

  const [quickScore, setQuickScore] = useState({ category_id: '', score_value: 1, description: 'Attendance' })

  useEffect(() => {
    if (currentOrganization?.organization_id) {
      fetchScoreCategories()
      fetchOrgUsers()
    }
    return () => stopCamera()
  }, [currentOrganization])

  const fetchScoreCategories = async () => {
    try {
      const response = await api.get('/scores/categories')
      setScoreCategories(response.data.categories || [])
    } catch {
      setError('Failed to fetch score categories')
    }
  }

  const fetchOrgUsers = async () => {
    try {
      const response = await api.get('/organizations/users')
      setOrgUsers(response.data.users || [])
    } catch {
      // non-fatal
    }
  }

  const startCamera = async () => {
    setCameraError('')
    setError('')
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: 'environment', width: { ideal: 1280 }, height: { ideal: 720 } }
      })
      if (videoRef.current) {
        videoRef.current.srcObject = stream
        videoRef.current.play()
      }
      setIsScanning(true)
      scanIntervalRef.current = setInterval(scanFrame, 250)
    } catch (err) {
      setCameraError('Camera access denied. Grant camera permission or use manual entry below.')
    }
  }

  const stopCamera = () => {
    if (scanIntervalRef.current) { clearInterval(scanIntervalRef.current); scanIntervalRef.current = null }
    if (videoRef.current?.srcObject) {
      videoRef.current.srcObject.getTracks().forEach(t => t.stop())
      videoRef.current.srcObject = null
    }
    setIsScanning(false)
  }

  const scanFrame = () => {
    const video = videoRef.current
    const canvas = canvasRef.current
    if (!video || !canvas || video.readyState < video.HAVE_ENOUGH_DATA) return
    canvas.width = video.videoWidth
    canvas.height = video.videoHeight
    const ctx = canvas.getContext('2d')
    ctx.drawImage(video, 0, 0)
    const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height)
    import('jsqr').then(({ default: jsQR }) => {
      const code = jsQR(imageData.data, imageData.width, imageData.height, { inversionAttempts: 'dontInvert' })
      if (code?.data) processQRData(code.data)
    })
  }

  const processQRData = (raw) => {
    try {
      const parsed = JSON.parse(raw)
      if (parsed.type !== 'score' || !parsed.user_id) {
        setError('Invalid QR code — not an attendance code')
        return
      }
      const user = orgUsers.find(u => u.id === parsed.user_id)
      if (!user) {
        setError('User not found in this organization')
        return
      }
      stopCamera()
      setScannedUser(user)
      setError('')
      setSuccess(`Identified: ${user.first_name} ${user.last_name}`)
    } catch {
      setError('Could not read QR code data')
    }
  }

  const handleManualEntry = (e) => {
    if (e.key === 'Enter' && e.target.value.trim()) {
      processQRData(e.target.value.trim())
      e.target.value = ''
    }
  }

  const handleQuickScoreAssignment = async (e) => {
    e.preventDefault()
    if (!scannedUser || !quickScore.category_id) return
    try {
      await api.post('/scores', {
        user_id: scannedUser.id,
        category_id: quickScore.category_id,
        score_value: quickScore.score_value,
        description: quickScore.description,
        organization_id: currentOrganization.organization_id
      })
      setSuccess(`Attendance recorded for ${scannedUser.first_name} ${scannedUser.last_name}!`)
      setQuickScore({ category_id: quickScore.category_id, score_value: 1, description: 'Attendance' })
      setScannedUser(null)
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to assign score')
    }
  }

  const resetScanner = () => {
    setScannedUser(null)
    setError('')
    setSuccess('')
  }

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h3 className="text-lg font-semibold flex items-center gap-2">
          <Scan className="h-5 w-5" />
          {t('sections.qrScannerQuickScoring')}
        </h3>
      </div>

      {error && (
        <Alert variant="destructive">
          <AlertDescription>{error}</AlertDescription>
        </Alert>
      )}
      {success && (
        <Alert className="border-green-200 bg-green-50">
          <AlertDescription className="text-green-800">{success}</AlertDescription>
        </Alert>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Camera Scanner */}
        <Card>
          <CardHeader>
            <CardTitle>QR Code Scanner</CardTitle>
            <CardDescription>Scan a user's attendance QR code from their profile</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            {/* Video feed */}
            <div className={`relative rounded-lg overflow-hidden bg-black ${isScanning ? 'block' : 'hidden'}`} style={{ aspectRatio: '4/3' }}>
              <video ref={videoRef} className="w-full h-full object-cover" playsInline muted />
              {/* Scan overlay */}
              <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
                <div className="w-48 h-48 border-2 border-white rounded-lg opacity-70">
                  <div className="absolute top-0 left-0 w-6 h-6 border-t-4 border-l-4 border-blue-400 rounded-tl" />
                  <div className="absolute top-0 right-0 w-6 h-6 border-t-4 border-r-4 border-blue-400 rounded-tr" />
                  <div className="absolute bottom-0 left-0 w-6 h-6 border-b-4 border-l-4 border-blue-400 rounded-bl" />
                  <div className="absolute bottom-0 right-0 w-6 h-6 border-b-4 border-r-4 border-blue-400 rounded-br" />
                </div>
              </div>
            </div>
            <canvas ref={canvasRef} className="hidden" />

            {!isScanning && !scannedUser && (
              <div className="space-y-3">
                <Button onClick={startCamera} className="w-full gap-2">
                  <Scan className="h-4 w-4" />
                  Start Camera
                </Button>
                {cameraError && <p className="text-sm text-amber-600">{cameraError}</p>}
              </div>
            )}

            {isScanning && (
              <Button variant="outline" onClick={stopCamera} className="w-full">
                Stop Camera
              </Button>
            )}

            {scannedUser && (
              <div className="border rounded-lg p-4 bg-green-50 space-y-2">
                <p className="font-semibold text-green-800">{scannedUser.first_name} {scannedUser.last_name}</p>
                <p className="text-sm text-green-600">@{scannedUser.username}</p>
                <Button variant="outline" size="sm" onClick={resetScanner}>Scan Another</Button>
              </div>
            )}

            {/* Manual fallback */}
            <div className="space-y-1 pt-2 border-t">
              <Label className="text-xs text-gray-500">Manual entry (paste QR data + Enter)</Label>
              <Input placeholder="Paste QR code data and press Enter" onKeyDown={handleManualEntry} />
            </div>
          </CardContent>
        </Card>

        {/* Quick Score Assignment */}
        <Card>
          <CardHeader>
            <CardTitle>Record Attendance</CardTitle>
            <CardDescription>
              {scannedUser
                ? `Assigning score to ${scannedUser.first_name} ${scannedUser.last_name}`
                : 'Scan a QR code first'}
            </CardDescription>
          </CardHeader>
          <CardContent>
            {scannedUser ? (
              <form onSubmit={handleQuickScoreAssignment} className="space-y-4">
                <div>
                  <Label>Category</Label>
                  <Select
                    value={quickScore.category_id}
                    onValueChange={(v) => setQuickScore({ ...quickScore, category_id: v })}
                  >
                    <SelectTrigger>
                      <SelectValue placeholder="Select attendance category" />
                    </SelectTrigger>
                    <SelectContent>
                      {scoreCategories.map((cat) => (
                        <SelectItem key={cat.id} value={cat.id}>
                          {cat.name} (Max: {cat.max_score})
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <div>
                  <Label>Score Value</Label>
                  <Input
                    type="number"
                    min="1"
                    value={quickScore.score_value}
                    onChange={(e) => setQuickScore({ ...quickScore, score_value: parseInt(e.target.value) || 1 })}
                    required
                  />
                </div>
                <div>
                  <Label>Note (optional)</Label>
                  <Input
                    value={quickScore.description}
                    onChange={(e) => setQuickScore({ ...quickScore, description: e.target.value })}
                    placeholder="e.g. Sunday service attendance"
                  />
                </div>
                <Button type="submit" className="w-full" disabled={!quickScore.category_id}>
                  Record Attendance Score
                </Button>
              </form>
            ) : (
              <div className="text-center py-10 text-gray-400">
                <Scan className="h-14 w-14 mx-auto mb-3 text-gray-300" />
                <p className="text-sm">Scan a user&apos;s QR code to begin</p>
              </div>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  )
}

export default App