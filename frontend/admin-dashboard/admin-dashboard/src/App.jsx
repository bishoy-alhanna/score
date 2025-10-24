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
  UserCheck, UserX, Clock, Plus, CheckCircle, XCircle, Shield,
  UsersIcon, Target, Award, Scan, TrendingUp, Tags
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
  const [superAdminMode, setSuperAdminMode] = useState(false)
  const [superAdmin, setSuperAdmin] = useState(null)

  useEffect(() => {
    // Check if super admin is already logged in
    const superAdminToken = localStorage.getItem('superAdminToken')
    const superAdminData = localStorage.getItem('superAdminData')
    
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
          <Router>
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
            <div className="flex items-center space-x-4">
              <LanguageSwitcher />
              <Badge variant="secondary">{currentOrganization?.role}</Badge>
              <span className="text-sm text-gray-700">{currentOrganization?.organization_name}</span>
              <span className="text-sm text-gray-700">{user?.username}</span>
              <Button variant="outline" size="sm" onClick={logout}>
                <LogOut className="h-4 w-4 mr-2" />
                {t('auth.logout')}
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
            <Tabs defaultValue="join-requests" className="w-full">
              <TabsList className="grid w-full grid-cols-6">
                <TabsTrigger value="join-requests">{t('navigation.joinRequests')}</TabsTrigger>
                <TabsTrigger value="users">{t('navigation.users')}</TabsTrigger>
                <TabsTrigger value="groups">{t('navigation.groups')}</TabsTrigger>
                <TabsTrigger value="scoring">{t('navigation.scoring')}</TabsTrigger>
                <TabsTrigger value="leaderboard">{t('navigation.leaderboards')}</TabsTrigger>
                <TabsTrigger value="qr-scanner">{t('navigation.qrScanner')}</TabsTrigger>
              </TabsList>
              
              <TabsContent value="join-requests" className="space-y-4">
                <JoinRequestsManagement />
              </TabsContent>
              
              <TabsContent value="users" className="space-y-4">
                <UsersManagement />
              </TabsContent>
              
              <TabsContent value="groups" className="space-y-4">
                <GroupsManagement />
              </TabsContent>
              
              <TabsContent value="scoring" className="space-y-4">
                <ScoringManagement />
              </TabsContent>
              
              <TabsContent value="leaderboard" className="space-y-4">
                <LeaderboardManagement />
              </TabsContent>
              
              <TabsContent value="qr-scanner" className="space-y-4">
                <QRScannerManagement />
              </TabsContent>
            </Tabs>
          </CardContent>
        </Card>
      </main>
    </div>
  )
}

// Join Requests Management Component
function JoinRequestsManagement() {
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
      <div className="flex justify-between items-center">
        <div>
          <h3 className="text-lg font-medium text-gray-900">Users Management</h3>
          <p className="text-sm text-gray-500">
            Manage users in your organization
          </p>
        </div>
        <Button onClick={() => setShowInviteForm(true)}>
          <UserPlus className="h-4 w-4 mr-2" />
          Invite User
        </Button>
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
                <div key={user.id} className="flex items-center justify-between p-4 border rounded-lg">
                  <div className="flex-1">
                    <div className="flex items-center space-x-3">
                      <div className="bg-blue-100 rounded-full p-2">
                        <Users className="h-5 w-5 text-blue-600" />
                      </div>
                      <div>
                        <p className="font-medium">{user.first_name} {user.last_name}</p>
                        <p className="text-sm text-gray-600">@{user.username}</p>
                        <p className="text-sm text-gray-500">{user.email}</p>
                      </div>
                    </div>
                  </div>
                  
                  <div className="flex items-center space-x-3">
                    {/* Role Selector */}
                    <Select 
                      value={user.role} 
                      onValueChange={(value) => handleChangeRole(user.id, value)}
                    >
                      <SelectTrigger className="w-32">
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
                    <div className="flex items-center space-x-2">
                      <Button
                        size="sm"
                        variant="outline"
                        onClick={() => startEdit(user)}
                      >
                        Edit
                      </Button>
                      <Button
                        size="sm"
                        variant="outline"
                        onClick={() => startPasswordReset(user)}
                      >
                        Reset Password
                      </Button>
                      <Button
                        size="sm"
                        variant={user.is_active ? "destructive" : "default"}
                        onClick={() => handleToggleUserStatus(user.id, user.is_active)}
                      >
                        {user.is_active ? 'Disable' : 'Enable'}
                      </Button>
                      <Button
                        size="sm"
                        variant="destructive"
                        onClick={() => setDeleteConfirmUser(user)}
                      >
                        Remove
                      </Button>
                    </div>
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

// Groups Management Component
function GroupsManagement() {
  const [groups, setGroups] = useState([])
  const [users, setUsers] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState('')
  const { currentOrganization } = useAuth()

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

  useEffect(() => {
    if (currentOrganization?.organization_id) {
      fetchGroups()
      fetchUsers()
    }
  }, [currentOrganization])

  const fetchGroups = async () => {
    try {
      const response = await api.get(`/groups?organization_id=${currentOrganization.organization_id}`)
      setGroups(response.data.groups || [])
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
        </h3>
        <Button onClick={() => setShowCreateGroup(true)}>
          <Plus className="h-4 w-4 mr-2" />
          Create Group
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

      {/* Groups Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {groups.map((group) => (
          <Card key={group.id}>
            <CardHeader>
              <CardTitle className="flex justify-between items-center">
                <span>{group.name}</span>
                <div className="flex gap-2">
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
                </div>
              </CardTitle>
              <CardDescription>{group.description}</CardDescription>
            </CardHeader>
            <CardContent>
              <p className="text-sm text-gray-600">
                {group.member_count || 0} members
              </p>
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
                  {groupUsers.map((user) => (
                    <div key={user.id} className="flex justify-between items-center p-2 border rounded">
                      <span>{user.first_name} {user.last_name} ({user.username})</span>
                      <Button
                        size="sm"
                        variant="destructive"
                        onClick={() => handleRemoveUserFromGroup(selectedGroup.id, user.id)}
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
                <div key={category.id} className="flex justify-between items-center p-3 border rounded">
                  <div>
                    <h4 className="font-medium">{category.name}</h4>
                    <p className="text-sm text-gray-600">{category.description}</p>
                    <p className="text-sm text-gray-500">Max Score: {category.max_score}</p>
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
  const { currentOrganization } = useAuth()

  useEffect(() => {
    if (currentOrganization?.organization_id) {
      fetchCategories()
      fetchLeaderboards()
    }
  }, [currentOrganization])

  useEffect(() => {
    if (currentOrganization?.organization_id && selectedCategory) {
      fetchLeaderboards()
    }
  }, [selectedCategory])

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

  const fetchLeaderboards = async () => {
    try {
      setLoading(true)
      const [usersResponse, groupsResponse] = await Promise.all([
        api.get(`/leaderboards/users?organization_id=${currentOrganization.organization_id}&category=${selectedCategory}`),
        api.get(`/leaderboards/groups?organization_id=${currentOrganization.organization_id}&category=${selectedCategory}`)
      ])
      
      setUserLeaderboard(usersResponse.data.leaderboard || [])
      setGroupLeaderboard(groupsResponse.data.leaderboard || [])
    } catch (error) {
      setError('Failed to fetch leaderboards')
    } finally {
      setLoading(false)
    }
  }

  if (loading) return <LoadingSpinner />

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h3 className="text-lg font-semibold flex items-center gap-2">
          <TrendingUp className="h-5 w-5" />
          {t('sections.leaderboards')}
        </h3>
        <div className="flex items-center gap-3">
          <div className="flex items-center gap-2">
            <label htmlFor="category-select" className="text-sm font-medium">{t('leaderboards.category')}:</label>
            <Select value={selectedCategory} onValueChange={setSelectedCategory}>
              <SelectTrigger className="w-[160px]">
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
          </div>
          <Button onClick={fetchLeaderboards} variant="outline">
            {t('common.refresh')}
          </Button>
        </div>
      </div>

      {error && (
        <Alert variant="destructive">
          <AlertDescription>{error}</AlertDescription>
        </Alert>
      )}

      <Tabs value={activeTab} onValueChange={setActiveTab}>
        <TabsList>
          <TabsTrigger value="users">{t('leaderboards.userLeaderboard')}</TabsTrigger>
          <TabsTrigger value="groups">{t('leaderboards.groupLeaderboard')}</TabsTrigger>
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
      </Tabs>
    </div>
  )
}

// QR Scanner Management Component
function QRScannerManagement() {
  const [scoreCategories, setScoreCategories] = useState([])
  const [isScanning, setIsScanning] = useState(false)
  const [scannedUser, setScannedUser] = useState(null)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState('')
  const { currentOrganization } = useAuth()

  // Quick score assignment state
  const [quickScore, setQuickScore] = useState({
    category_id: '',
    score: 0,
    reason: ''
  })

  useEffect(() => {
    if (currentOrganization?.organization_id) {
      fetchScoreCategories()
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

  const handleQRScan = async (qrData) => {
    try {
      // Parse QR code data to get user information
      const response = await api.post('/auth/verify-qr', { qr_token: qrData })
      setScannedUser(response.data.user)
      setIsScanning(false)
      setSuccess(`User scanned: ${response.data.user.first_name} ${response.data.user.last_name}`)
    } catch (error) {
      setError('Invalid QR code or user not found')
      setIsScanning(false)
    }
  }

  const handleQuickScoreAssignment = async (e) => {
    e.preventDefault()
    if (!scannedUser) return

    try {
      await api.post('/scores', {
        target_type: 'user',
        target_id: scannedUser.id,
        category_id: quickScore.category_id,
        score: quickScore.score,
        reason: quickScore.reason,
        organization_id: currentOrganization.organization_id
      })
      
      setQuickScore({ category_id: '', score: 0, reason: '' })
      setScannedUser(null)
      setSuccess('Score assigned successfully!')
    } catch (error) {
      setError('Failed to assign score')
    }
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
        {/* QR Scanner */}
        <Card>
          <CardHeader>
            <CardTitle>QR Code Scanner</CardTitle>
            <CardDescription>Scan user QR codes to quickly identify users</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            {!isScanning && !scannedUser && (
              <Button 
                onClick={() => setIsScanning(true)}
                className="w-full"
              >
                <Scan className="h-4 w-4 mr-2" />
                Start Scanning
              </Button>
            )}

            {isScanning && (
              <div className="space-y-4">
                <div className="border-2 border-dashed border-gray-300 rounded-lg p-8 text-center">
                  <Scan className="h-12 w-12 mx-auto mb-4 text-gray-400" />
                  <p className="text-gray-600">
                    Point your camera at a user's QR code
                  </p>
                  <p className="text-sm text-gray-500 mt-2">
                    Or manually enter QR code data below
                  </p>
                </div>
                
                <div className="space-y-2">
                  <Label htmlFor="manual_qr">Manual QR Code Entry</Label>
                  <div className="flex gap-2">
                    <Input
                      id="manual_qr"
                      placeholder="Enter QR code data"
                      onKeyPress={(e) => {
                        if (e.key === 'Enter') {
                          handleQRScan(e.target.value)
                          e.target.value = ''
                        }
                      }}
                    />
                    <Button
                      variant="outline"
                      onClick={() => setIsScanning(false)}
                    >
                      Cancel
                    </Button>
                  </div>
                </div>
              </div>
            )}

            {scannedUser && (
              <div className="border rounded-lg p-4 bg-green-50">
                <h4 className="font-medium text-green-800">User Identified</h4>
                <p className="text-green-700">
                  {scannedUser.first_name} {scannedUser.last_name}
                </p>
                <p className="text-sm text-green-600">@{scannedUser.username}</p>
                <Button
                  variant="outline"
                  size="sm"
                  className="mt-2"
                  onClick={() => setScannedUser(null)}
                >
                  Clear
                </Button>
              </div>
            )}
          </CardContent>
        </Card>

        {/* Quick Score Assignment */}
        <Card>
          <CardHeader>
            <CardTitle>Quick Score Assignment</CardTitle>
            <CardDescription>
              {scannedUser 
                ? `Assign score to ${scannedUser.first_name} ${scannedUser.last_name}`
                : 'Scan a user first to assign scores'
              }
            </CardDescription>
          </CardHeader>
          <CardContent>
            {scannedUser ? (
              <form onSubmit={handleQuickScoreAssignment} className="space-y-4">
                <div>
                  <Label htmlFor="quick_category">{t('scoring.scoreCategory')}</Label>
                  <Select
                    value={quickScore.category_id}
                    onValueChange={(value) => setQuickScore({ ...quickScore, category_id: value })}
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
                  <Label htmlFor="quick_score">Score</Label>
                  <Input
                    id="quick_score"
                    type="number"
                    value={quickScore.score}
                    onChange={(e) => setQuickScore({ ...quickScore, score: parseInt(e.target.value) || 0 })}
                    required
                  />
                </div>

                <div>
                  <Label htmlFor="quick_reason">Reason</Label>
                  <Input
                    id="quick_reason"
                    value={quickScore.reason}
                    onChange={(e) => setQuickScore({ ...quickScore, reason: e.target.value })}
                    placeholder="Reason for this score"
                  />
                </div>

                <Button type="submit" className="w-full">
                  Assign Score
                </Button>
              </form>
            ) : (
              <div className="text-center py-8 text-gray-500">
                <Scan className="h-12 w-12 mx-auto mb-4 text-gray-300" />
                <p>Scan a user's QR code first</p>
              </div>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  )
}

export default App