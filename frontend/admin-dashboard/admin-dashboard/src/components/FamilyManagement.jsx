import React, { useState, useEffect } from 'react'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Badge } from '@/components/ui/badge'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle, DialogTrigger, DialogFooter } from '@/components/ui/dialog'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Users, Plus, Search, UserPlus, Trash2, Edit, AlertCircle, CheckCircle } from 'lucide-react'
import axios from 'axios'

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || '/api'

const api = axios.create({
  baseURL: API_BASE_URL,
})

api.interceptors.request.use((config) => {
  const token = localStorage.getItem('authToken')
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

function FamilyManagement({ organizationId }) {
  const [families, setFamilies] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [searchTerm, setSearchTerm] = useState('')
  const [selectedFamily, setSelectedFamily] = useState(null)
  const [showFamilyDialog, setShowFamilyDialog] = useState(false)
  const [showMemberDialog, setShowMemberDialog] = useState(false)
  const [nationalIdSearch, setNationalIdSearch] = useState('')
  const [existingMember, setExistingMember] = useState(null)
  const [successMessage, setSuccessMessage] = useState('')

  // Form states
  const [familyForm, setFamilyForm] = useState({
    family_name: '',
    contact_info: { phone: '', email: '' }
  })

  const [memberForm, setMemberForm] = useState({
    first_name: '',
    last_name: '',
    national_id: '',
    email: '',
    gender: '',
    birthdate: '',
    phone_number: '',
    church_role: ''
  })

  useEffect(() => {
    if (organizationId) {
      fetchFamilies()
    }
  }, [organizationId])

  const fetchFamilies = async () => {
    try {
      setLoading(true)
      setError(null)
      const response = await api.get('/families', {
        params: { 
          organization_id: organizationId,
          include_members: true,
          per_page: 100
        }
      })
      setFamilies(response.data.families || [])
    } catch (err) {
      console.error('Error fetching families:', err)
      setError(err.response?.data?.error || 'Failed to load families')
    } finally {
      setLoading(false)
    }
  }

  const searchByNationalId = async () => {
    if (!nationalIdSearch.trim()) {
      setError('Please enter a national ID')
      return
    }

    try {
      setError(null)
      const response = await api.get('/families/search-by-national-id', {
        params: {
          national_id: nationalIdSearch,
          organization_id: organizationId
        }
      })
      
      if (response.data.found) {
        setExistingMember(response.data)
        setMemberForm({
          ...memberForm,
          national_id: nationalIdSearch,
          first_name: response.data.user.first_name || '',
          last_name: response.data.user.last_name || '',
          email: response.data.user.email || '',
          gender: response.data.user.gender || '',
          birthdate: response.data.user.birthdate || '',
          phone_number: response.data.user.phone_number || '',
          church_role: response.data.user.church_role || ''
        })
      } else {
        setExistingMember({ found: false })
        setMemberForm({ ...memberForm, national_id: nationalIdSearch })
      }
    } catch (err) {
      console.error('Error searching national ID:', err)
      setError(err.response?.data?.error || 'Failed to search national ID')
    }
  }

  const createFamily = async (e) => {
    e.preventDefault()
    try {
      setError(null)
      await api.post('/families', {
        ...familyForm,
        organization_id: organizationId
      })
      setSuccessMessage('Family created successfully!')
      setShowFamilyDialog(false)
      setFamilyForm({ family_name: '', contact_info: { phone: '', email: '' } })
      fetchFamilies()
      setTimeout(() => setSuccessMessage(''), 3000)
    } catch (err) {
      console.error('Error creating family:', err)
      setError(err.response?.data?.error || 'Failed to create family')
    }
  }

  const addFamilyMember = async (e) => {
    e.preventDefault()
    if (!selectedFamily) return

    try {
      setError(null)
      const response = await api.post(`/families/${selectedFamily.id}/members`, {
        ...memberForm,
        organization_id: organizationId
      })
      
      const message = response.data.linked_existing 
        ? 'Existing member linked to family successfully!' 
        : 'New family member created successfully!'
      
      setSuccessMessage(message)
      setShowMemberDialog(false)
      setMemberForm({
        first_name: '',
        last_name: '',
        national_id: '',
        email: '',
        gender: '',
        birthdate: '',
        phone_number: '',
        church_role: ''
      })
      setNationalIdSearch('')
      setExistingMember(null)
      fetchFamilies()
      setTimeout(() => setSuccessMessage(''), 3000)
    } catch (err) {
      console.error('Error adding family member:', err)
      setError(err.response?.data?.error || 'Failed to add family member')
    }
  }

  const removeFamilyMember = async (familyId, memberId) => {
    if (!confirm('Are you sure you want to remove this member from the family?')) return

    try {
      setError(null)
      await api.delete(`/families/${familyId}/members/${memberId}`, {
        params: { organization_id: organizationId }
      })
      setSuccessMessage('Member removed from family successfully!')
      fetchFamilies()
      setTimeout(() => setSuccessMessage(''), 3000)
    } catch (err) {
      console.error('Error removing family member:', err)
      setError(err.response?.data?.error || 'Failed to remove family member')
    }
  }

  const deleteFamily = async (familyId) => {
    if (!confirm('Are you sure you want to delete this family? All members will be unlinked.')) return

    try {
      setError(null)
      await api.delete(`/families/${familyId}`, {
        params: { organization_id: organizationId }
      })
      setSuccessMessage('Family deleted successfully!')
      fetchFamilies()
      setTimeout(() => setSuccessMessage(''), 3000)
    } catch (err) {
      console.error('Error deleting family:', err)
      setError(err.response?.data?.error || 'Failed to delete family')
    }
  }

  const filteredFamilies = families.filter(family =>
    family.family_name.toLowerCase().includes(searchTerm.toLowerCase())
  )

  if (loading) {
    return (
      <div className="flex items-center justify-center p-8">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto"></div>
          <p className="mt-4 text-gray-600">Loading families...</p>
        </div>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex justify-between items-center">
        <div>
          <h2 className="text-3xl font-bold tracking-tight">Family Management</h2>
          <p className="text-gray-600 mt-1">Manage families and their members</p>
        </div>
        <Dialog open={showFamilyDialog} onOpenChange={setShowFamilyDialog}>
          <DialogTrigger asChild>
            <Button>
              <Plus className="mr-2 h-4 w-4" />
              Create Family
            </Button>
          </DialogTrigger>
          <DialogContent>
            <DialogHeader>
              <DialogTitle>Create New Family</DialogTitle>
              <DialogDescription>
                Add a new family to the organization
              </DialogDescription>
            </DialogHeader>
            <form onSubmit={createFamily} className="space-y-4">
              <div>
                <Label htmlFor="family_name">Family Name *</Label>
                <Input
                  id="family_name"
                  value={familyForm.family_name}
                  onChange={(e) => setFamilyForm({ ...familyForm, family_name: e.target.value })}
                  placeholder="Enter family name"
                  required
                />
              </div>
              <div>
                <Label htmlFor="contact_phone">Contact Phone</Label>
                <Input
                  id="contact_phone"
                  value={familyForm.contact_info?.phone || ''}
                  onChange={(e) => setFamilyForm({ 
                    ...familyForm, 
                    contact_info: { ...familyForm.contact_info, phone: e.target.value }
                  })}
                  placeholder="Family contact phone"
                />
              </div>
              <div>
                <Label htmlFor="contact_email">Contact Email</Label>
                <Input
                  id="contact_email"
                  type="email"
                  value={familyForm.contact_info?.email || ''}
                  onChange={(e) => setFamilyForm({ 
                    ...familyForm, 
                    contact_info: { ...familyForm.contact_info, email: e.target.value }
                  })}
                  placeholder="Family contact email"
                />
              </div>
              <DialogFooter>
                <Button type="button" variant="outline" onClick={() => setShowFamilyDialog(false)}>
                  Cancel
                </Button>
                <Button type="submit">Create Family</Button>
              </DialogFooter>
            </form>
          </DialogContent>
        </Dialog>
      </div>

      {/* Success Message */}
      {successMessage && (
        <Alert className="bg-green-50 border-green-200">
          <CheckCircle className="h-4 w-4 text-green-600" />
          <AlertDescription className="text-green-800">
            {successMessage}
          </AlertDescription>
        </Alert>
      )}

      {/* Error Message */}
      {error && (
        <Alert variant="destructive">
          <AlertCircle className="h-4 w-4" />
          <AlertDescription>{error}</AlertDescription>
        </Alert>
      )}

      {/* Search */}
      <div className="flex gap-2">
        <div className="relative flex-1">
          <Search className="absolute left-3 top-3 h-4 w-4 text-gray-400" />
          <Input
            placeholder="Search families..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="pl-9"
          />
        </div>
      </div>

      {/* Families List */}
      <div className="grid gap-4">
        {filteredFamilies.length === 0 ? (
          <Card>
            <CardContent className="p-12 text-center">
              <Users className="h-12 w-12 text-gray-400 mx-auto mb-4" />
              <p className="text-gray-600">No families found</p>
              <p className="text-sm text-gray-500 mt-1">Create a family to get started</p>
            </CardContent>
          </Card>
        ) : (
          filteredFamilies.map((family) => (
            <Card key={family.id}>
              <CardHeader>
                <div className="flex justify-between items-start">
                  <div>
                    <CardTitle className="flex items-center gap-2">
                      <Users className="h-5 w-5" />
                      {family.family_name}
                    </CardTitle>
                    <CardDescription>
                      {family.head_of_family_name ? `Head: ${family.head_of_family_name}` : 'No head of family assigned'} · {family.member_count} member{family.member_count !== 1 ? 's' : ''}
                    </CardDescription>
                  </div>
                  <div className="flex gap-2">
                    <Dialog>
                      <DialogTrigger asChild>
                        <Button 
                          variant="outline" 
                          size="sm"
                          onClick={() => setSelectedFamily(family)}
                        >
                          <UserPlus className="h-4 w-4 mr-1" />
                          Add Member
                        </Button>
                      </DialogTrigger>
                      <DialogContent className="max-w-2xl">
                        <DialogHeader>
                          <DialogTitle>Add Family Member</DialogTitle>
                          <DialogDescription>
                            Add a new member to {family.family_name}
                          </DialogDescription>
                        </DialogHeader>
                        
                        {/* National ID Search */}
                        <div className="space-y-4 border-b pb-4">
                          <Label>Search by National ID</Label>
                          <div className="flex gap-2">
                            <Input
                              placeholder="Enter National ID"
                              value={nationalIdSearch}
                              onChange={(e) => setNationalIdSearch(e.target.value)}
                            />
                            <Button type="button" onClick={searchByNationalId}>
                              <Search className="h-4 w-4" />
                            </Button>
                          </div>
                          {existingMember && existingMember.found && (
                            <Alert className="bg-blue-50 border-blue-200">
                              <AlertCircle className="h-4 w-4 text-blue-600" />
                              <AlertDescription className="text-blue-800">
                                Found existing member: {existingMember.user.first_name} {existingMember.user.last_name}
                                {existingMember.has_family && ' (Already in a family)'}
                              </AlertDescription>
                            </Alert>
                          )}
                          {existingMember && !existingMember.found && (
                            <Alert className="bg-yellow-50 border-yellow-200">
                              <AlertCircle className="h-4 w-4 text-yellow-600" />
                              <AlertDescription className="text-yellow-800">
                                No existing member found. A new member will be created.
                              </AlertDescription>
                            </Alert>
                          )}
                        </div>

                        <form onSubmit={addFamilyMember} className="space-y-4">
                          <div className="grid grid-cols-2 gap-4">
                            <div>
                              <Label htmlFor="first_name">First Name *</Label>
                              <Input
                                id="first_name"
                                value={memberForm.first_name}
                                onChange={(e) => setMemberForm({ ...memberForm, first_name: e.target.value })}
                                required
                                disabled={existingMember?.found}
                              />
                            </div>
                            <div>
                              <Label htmlFor="last_name">Last Name *</Label>
                              <Input
                                id="last_name"
                                value={memberForm.last_name}
                                onChange={(e) => setMemberForm({ ...memberForm, last_name: e.target.value })}
                                required
                                disabled={existingMember?.found}
                              />
                            </div>
                          </div>

                          <div>
                            <Label htmlFor="national_id">National ID</Label>
                            <Input
                              id="national_id"
                              value={memberForm.national_id}
                              onChange={(e) => setMemberForm({ ...memberForm, national_id: e.target.value })}
                              disabled
                            />
                          </div>

                          <div className="grid grid-cols-2 gap-4">
                            <div>
                              <Label htmlFor="email">Email</Label>
                              <Input
                                id="email"
                                type="email"
                                value={memberForm.email}
                                onChange={(e) => setMemberForm({ ...memberForm, email: e.target.value })}
                                disabled={existingMember?.found}
                              />
                            </div>
                            <div>
                              <Label htmlFor="phone_number">Phone Number</Label>
                              <Input
                                id="phone_number"
                                value={memberForm.phone_number}
                                onChange={(e) => setMemberForm({ ...memberForm, phone_number: e.target.value })}
                                disabled={existingMember?.found}
                              />
                            </div>
                          </div>

                          <div className="grid grid-cols-2 gap-4">
                            <div>
                              <Label htmlFor="gender">Gender</Label>
                              <Select 
                                value={memberForm.gender} 
                                onValueChange={(value) => setMemberForm({ ...memberForm, gender: value })}
                                disabled={existingMember?.found}
                              >
                                <SelectTrigger>
                                  <SelectValue placeholder="Select gender" />
                                </SelectTrigger>
                                <SelectContent>
                                  <SelectItem value="Male">Male</SelectItem>
                                  <SelectItem value="Female">Female</SelectItem>
                                  <SelectItem value="Other">Other</SelectItem>
                                </SelectContent>
                              </Select>
                            </div>
                            <div>
                              <Label htmlFor="birthdate">Birthdate</Label>
                              <Input
                                id="birthdate"
                                type="date"
                                value={memberForm.birthdate}
                                onChange={(e) => setMemberForm({ ...memberForm, birthdate: e.target.value })}
                                disabled={existingMember?.found}
                              />
                            </div>
                          </div>

                          <div>
                            <Label htmlFor="church_role">Church Role</Label>
                            <Input
                              id="church_role"
                              value={memberForm.church_role}
                              onChange={(e) => setMemberForm({ ...memberForm, church_role: e.target.value })}
                              placeholder="e.g., Member, Deacon, Elder"
                              disabled={existingMember?.found}
                            />
                          </div>

                          <DialogFooter>
                            <Button type="button" variant="outline" onClick={() => {
                              setShowMemberDialog(false)
                              setMemberForm({
                                first_name: '',
                                last_name: '',
                                national_id: '',
                                email: '',
                                gender: '',
                                birthdate: '',
                                phone_number: '',
                                church_role: ''
                              })
                              setNationalIdSearch('')
                              setExistingMember(null)
                            }}>
                              Cancel
                            </Button>
                            <Button type="submit">
                              {existingMember?.found ? 'Link Member' : 'Create & Add Member'}
                            </Button>
                          </DialogFooter>
                        </form>
                      </DialogContent>
                    </Dialog>
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => deleteFamily(family.id)}
                    >
                      <Trash2 className="h-4 w-4" />
                    </Button>
                  </div>
                </div>
              </CardHeader>
              {family.members && family.members.length > 0 && (
                <CardContent>
                  <Table>
                    <TableHeader>
                      <TableRow>
                        <TableHead>Name</TableHead>
                        <TableHead>National ID</TableHead>
                        <TableHead>Gender</TableHead>
                        <TableHead>Phone</TableHead>
                        <TableHead>Church Role</TableHead>
                        <TableHead className="text-right">Actions</TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      {family.members.map((member) => (
                        <TableRow key={member.id}>
                          <TableCell className="font-medium">
                            {member.first_name} {member.last_name}
                          </TableCell>
                          <TableCell>{member.national_id || '-'}</TableCell>
                          <TableCell>{member.gender || '-'}</TableCell>
                          <TableCell>{member.phone_number || '-'}</TableCell>
                          <TableCell>{member.church_role || '-'}</TableCell>
                          <TableCell className="text-right">
                            <Button
                              variant="ghost"
                              size="sm"
                              onClick={() => removeFamilyMember(family.id, member.id)}
                            >
                              <Trash2 className="h-4 w-4 text-red-600" />
                            </Button>
                          </TableCell>
                        </TableRow>
                      ))}
                    </TableBody>
                  </Table>
                </CardContent>
              )}
            </Card>
          ))
        )}
      </div>
    </div>
  )
}

export default FamilyManagement
