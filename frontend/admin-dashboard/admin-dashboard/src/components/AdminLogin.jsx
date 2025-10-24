import React, { useState, useEffect } from 'react'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { Building2, User, Lock, RefreshCw } from 'lucide-react'
import { useTranslation } from 'react-i18next'
import axios from 'axios'

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || '/api'

const api = axios.create({
  baseURL: API_BASE_URL,
})

function AdminLogin({ onLogin }) {
  const { t } = useTranslation()
  const [credentials, setCredentials] = useState({
    username: '',
    password: '',
    organization_id: ''
  })
  const [organizations, setOrganizations] = useState([])
  const [loading, setLoading] = useState(false)
  const [loadingOrgs, setLoadingOrgs] = useState(false)
  const [error, setError] = useState('')
  const [step, setStep] = useState(1) // 1: username, 2: organization selection, 3: password

  const handleUsernameSubmit = async (e) => {
    e.preventDefault()
    if (!credentials.username.trim()) {
      setError(t('auth.required'))
      return
    }

    setLoadingOrgs(true)
    setError('')

    try {
      const response = await api.get(`/auth/admin-organizations/${credentials.username}`)
      const userOrganizations = response.data.organizations

      if (userOrganizations.length === 0) {
        setError(t('organizations.noAdminPrivileges'))
        setLoadingOrgs(false)
        return
      }

      if (userOrganizations.length === 1) {
        // If user is admin of only one organization, auto-select it and go to password step
        setCredentials(prev => ({ ...prev, organization_id: userOrganizations[0].id }))
        setOrganizations(userOrganizations)
        setStep(3)
      } else {
        // If user is admin of multiple organizations, show selection
        setOrganizations(userOrganizations)
        setStep(2)
      }
    } catch (error) {
      setError(error.response?.data?.error || t('organizations.failedToFetchOrgs'))
    } finally {
      setLoadingOrgs(false)
    }
  }

  const handleOrganizationSelect = (orgId) => {
    setCredentials(prev => ({ ...prev, organization_id: orgId }))
    setStep(3)
  }

  const handleFinalLogin = async (e) => {
    e.preventDefault()
    if (!credentials.password.trim()) {
      setError(t('auth.required'))
      return
    }

    setLoading(true)
    setError('')

    try {
      const response = await api.post('/auth/login', credentials)
      onLogin(response.data)
    } catch (error) {
      setError(error.response?.data?.error || t('auth.loginError'))
    } finally {
      setLoading(false)
    }
  }

  const resetForm = () => {
    setCredentials({ username: '', password: '', organization_id: '' })
    setOrganizations([])
    setError('')
    setStep(1)
  }

  const selectedOrganization = organizations.find(org => org.id === credentials.organization_id)

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
      <Card className="w-full max-w-md">
        <CardHeader className="space-y-1">
          <div className="flex items-center justify-center">
            <Building2 className="h-8 w-8 text-blue-600" />
          </div>
          <CardTitle className="text-2xl text-center">{t('dashboard.title')}</CardTitle>
          <CardDescription className="text-center">
            {step === 1 && t('auth.enterUsername')}
            {step === 2 && t('auth.selectOrganization')}
            {step === 3 && t('auth.signIn') + ` ${selectedOrganization?.name}`}
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          {error && (
            <Alert variant="destructive">
              <AlertDescription>{error}</AlertDescription>
            </Alert>
          )}

          {/* Step 1: Username */}
          {step === 1 && (
            <form onSubmit={handleUsernameSubmit} className="space-y-4">
              <div className="space-y-2">
                <Label htmlFor="username">{t('auth.usernameOrEmail')}</Label>
                <div className="relative">
                  <User className="absolute left-3 top-3 h-4 w-4 text-gray-400" />
                  <Input
                    id="username"
                    type="text"
                    placeholder={t('auth.enterUsernameOrEmail')}
                    value={credentials.username}
                    onChange={(e) => setCredentials(prev => ({ ...prev, username: e.target.value }))}
                    className="pl-10"
                    disabled={loadingOrgs}
                  />
                </div>
              </div>
              <Button 
                type="submit" 
                className="w-full" 
                disabled={loadingOrgs || !credentials.username.trim()}
              >
                {loadingOrgs ? (
                  <>
                    <RefreshCw className="mr-2 h-4 w-4 animate-spin" />
                    {t('auth.checkingOrganizations')}
                  </>
                ) : (
                  t('auth.continue')
                )}
              </Button>
            </form>
          )}

          {/* Step 2: Organization Selection */}
          {step === 2 && (
            <div className="space-y-4">
              <div className="space-y-2">
                <Label>{t('organizations.selectOrganization')}</Label>
                <p className="text-sm text-gray-600">
                  {t('organizations.youAreAdminOf')} {organizations.length} {organizations.length !== 1 ? t('organizations.organizations') : t('organizations.organization')}. 
                  {t('organizations.pleaseSelectManage')}
                </p>
              </div>
              <div className="space-y-2">
                {organizations.map((org) => (
                  <Card 
                    key={org.id} 
                    className="cursor-pointer hover:border-blue-500 transition-colors"
                    onClick={() => handleOrganizationSelect(org.id)}
                  >
                    <CardContent className="p-4">
                      <div className="flex items-center justify-between">
                        <div>
                          <h3 className="font-medium">{org.name}</h3>
                          {org.description && (
                            <p className="text-sm text-gray-600">{org.description}</p>
                          )}
                          <p className="text-xs text-gray-500 mt-1">
                            {org.member_count} {org.member_count !== 1 ? t('organizations.members') : t('organizations.member')}
                          </p>
                        </div>
                        <Building2 className="h-5 w-5 text-gray-400" />
                      </div>
                    </CardContent>
                  </Card>
                ))}
              </div>
              <Button 
                variant="outline" 
                className="w-full" 
                onClick={resetForm}
              >
                {t('organizations.backToUsername')}
              </Button>
            </div>
          )}

          {/* Step 3: Password */}
          {step === 3 && (
            <form onSubmit={handleFinalLogin} className="space-y-4">
              <div className="space-y-2">
                <Label>{t('organizations.organization')}</Label>
                <div className="p-3 bg-gray-50 rounded-md border">
                  <div className="flex items-center">
                    <Building2 className="h-4 w-4 text-gray-600 mr-2" />
                    <span className="font-medium">{selectedOrganization?.name}</span>
                  </div>
                  {selectedOrganization?.description && (
                    <p className="text-sm text-gray-600 mt-1">{selectedOrganization.description}</p>
                  )}
                </div>
              </div>
              <div className="space-y-2">
                <Label htmlFor="password">{t('auth.password')}</Label>
                <div className="relative">
                  <Lock className="absolute left-3 top-3 h-4 w-4 text-gray-400" />
                  <Input
                    id="password"
                    type="password"
                    placeholder={t('auth.enterPassword')}
                    value={credentials.password}
                    onChange={(e) => setCredentials(prev => ({ ...prev, password: e.target.value }))}
                    className="pl-10"
                    disabled={loading}
                  />
                </div>
              </div>
              <div className="space-y-2">
                <Button 
                  type="submit" 
                  className="w-full" 
                  disabled={loading || !credentials.password.trim()}
                >
                  {loading ? (
                    <>
                      <RefreshCw className="mr-2 h-4 w-4 animate-spin" />
                      {t('auth.signingIn')}
                    </>
                  ) : (
                    t('auth.signIn')
                  )}
                </Button>
                <Button 
                  variant="outline" 
                  className="w-full" 
                  onClick={() => setStep(organizations.length > 1 ? 2 : 1)}
                  disabled={loading}
                >
                  {t('auth.back')}
                </Button>
              </div>
            </form>
          )}
        </CardContent>
      </Card>
    </div>
  )
}

export default AdminLogin