import { useState, useEffect } from 'react'
import { useTranslation } from 'react-i18next'
import axios from 'axios'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { 
  Table, 
  TableBody, 
  TableCell, 
  TableHead, 
  TableHeader, 
  TableRow 
} from '@/components/ui/table'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import { 
  Search, 
  Edit, 
  Trash2, 
  Save, 
  X, 
  Plus, 
  User,
  Trophy,
  Calendar,
  Tag
} from 'lucide-react'
import { Badge } from '@/components/ui/badge'
import { Textarea } from '@/components/ui/textarea'

// Create API instance
const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:5000'
const api = axios.create({
  baseURL: `${API_URL}/api`,
  headers: {
    'Content-Type': 'application/json',
  },
})

// Add auth token to all requests
api.interceptors.request.use((config) => {
  const token = localStorage.getItem('token')
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

export default function UserScoresManagement() {
  const { t } = useTranslation()
  const [users, setUsers] = useState([])
  const [selectedUser, setSelectedUser] = useState(null)
  const [userScores, setUserScores] = useState([])
  const [categories, setCategories] = useState([])
  const [searchTerm, setSearchTerm] = useState('')
  const [loading, setLoading] = useState(false)
  const [editingScore, setEditingScore] = useState(null)
  const [showEditDialog, setShowEditDialog] = useState(false)
  const [showAddDialog, setShowAddDialog] = useState(false)
  const [editForm, setEditForm] = useState({
    score_value: '',
    category: '',
    description: '',
    score_date: ''
  })

  useEffect(() => {
    fetchUsers()
    fetchCategories()
  }, [])

  useEffect(() => {
    if (selectedUser) {
      fetchUserScores(selectedUser.id)
    }
  }, [selectedUser])

  const fetchUsers = async () => {
    try {
      const response = await api.get('/users')
      setUsers(response.data.users || [])
    } catch (error) {
      console.error('Failed to fetch users:', error)
    }
  }

  const fetchCategories = async () => {
    try {
      const response = await api.get('/scores/categories')
      setCategories(response.data.categories || [])
    } catch (error) {
      console.error('Failed to fetch categories:', error)
    }
  }

  const fetchUserScores = async (userId) => {
    setLoading(true)
    try {
      const response = await api.get(`/scores/user/${userId}`)
      setUserScores(response.data.scores || [])
    } catch (error) {
      console.error('Failed to fetch user scores:', error)
      setUserScores([])
    } finally {
      setLoading(false)
    }
  }

  const handleEditScore = (score) => {
    setEditingScore(score)
    setEditForm({
      score_value: score.score_value,
      category: score.category,
      description: score.description || '',
      score_date: score.score_date || new Date().toISOString().split('T')[0]
    })
    setShowEditDialog(true)
  }

  const handleAddScore = () => {
    setEditingScore(null)
    setEditForm({
      score_value: '',
      category: categories[0]?.name || '',
      description: '',
      score_date: new Date().toISOString().split('T')[0]
    })
    setShowAddDialog(true)
  }

  const handleSaveScore = async () => {
    try {
      if (editingScore) {
        // Update existing score
        await api.put(`/scores/${editingScore.id}`, {
          score_value: parseInt(editForm.score_value),
          category: editForm.category,
          description: editForm.description,
          score_date: editForm.score_date
        })
      } else {
        // Create new score
        await api.post('/scores', {
          user_id: selectedUser.id,
          score_value: parseInt(editForm.score_value),
          category: editForm.category,
          description: editForm.description,
          score_date: editForm.score_date
        })
      }
      
      // Refresh scores
      fetchUserScores(selectedUser.id)
      setShowEditDialog(false)
      setShowAddDialog(false)
      setEditingScore(null)
    } catch (error) {
      console.error('Failed to save score:', error)
      alert(t('common.error') || 'Failed to save score')
    }
  }

  const handleDeleteScore = async (scoreId) => {
    if (!confirm(t('scores.confirmDelete') || 'Are you sure you want to delete this score?')) {
      return
    }

    try {
      await api.delete(`/scores/${scoreId}`)
      fetchUserScores(selectedUser.id)
    } catch (error) {
      console.error('Failed to delete score:', error)
      alert(t('common.error') || 'Failed to delete score')
    }
  }

  const filteredUsers = users.filter(user => 
    user.first_name?.toLowerCase().includes(searchTerm.toLowerCase()) ||
    user.last_name?.toLowerCase().includes(searchTerm.toLowerCase()) ||
    user.username?.toLowerCase().includes(searchTerm.toLowerCase()) ||
    user.email?.toLowerCase().includes(searchTerm.toLowerCase())
  )

  const totalScore = userScores.reduce((sum, score) => sum + (score.score_value || 0), 0)
  const averageScore = userScores.length > 0 ? (totalScore / userScores.length).toFixed(2) : 0

  return (
    <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
      {/* Users List */}
      <Card className="lg:col-span-1">
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <User className="h-5 w-5" />
            {t('navigation.users') || 'Users'}
          </CardTitle>
          <CardDescription>{t('scores.selectUser') || 'Select a user to view and manage their scores'}</CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="relative">
            <Search className="absolute left-3 top-3 h-4 w-4 text-muted-foreground" />
            <Input
              placeholder={t('users.search') || 'Search users...'}
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="pl-10"
            />
          </div>

          <div className="space-y-2 max-h-[600px] overflow-y-auto">
            {filteredUsers.map(user => (
              <Button
                key={user.id}
                variant={selectedUser?.id === user.id ? 'default' : 'outline'}
                className="w-full justify-start text-left"
                onClick={() => setSelectedUser(user)}
              >
                <div className="flex flex-col items-start w-full">
                  <div className="font-medium">
                    {user.first_name} {user.last_name}
                  </div>
                  <div className="text-xs text-muted-foreground">
                    @{user.username}
                  </div>
                </div>
              </Button>
            ))}
          </div>
        </CardContent>
      </Card>

      {/* Scores Management */}
      <Card className="lg:col-span-2">
        <CardHeader>
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <Trophy className="h-5 w-5" />
              <CardTitle>
                {selectedUser 
                  ? `${selectedUser.first_name} ${selectedUser.last_name}'s ${t('navigation.scores') || 'Scores'}`
                  : t('scores.selectUserFirst') || 'Select a user to view scores'}
              </CardTitle>
            </div>
            {selectedUser && (
              <Button onClick={handleAddScore}>
                <Plus className="h-4 w-4 mr-2" />
                {t('scores.addScore') || 'Add Score'}
              </Button>
            )}
          </div>
          {selectedUser && (
            <CardDescription>
              <div className="flex gap-4 mt-2">
                <Badge variant="secondary">
                  Total: {totalScore} {t('common.points') || 'points'}
                </Badge>
                <Badge variant="outline">
                  Average: {averageScore}
                </Badge>
                <Badge variant="outline">
                  Count: {userScores.length}
                </Badge>
              </div>
            </CardDescription>
          )}
        </CardHeader>
        <CardContent>
          {!selectedUser ? (
            <div className="text-center text-muted-foreground py-12">
              <User className="h-12 w-12 mx-auto mb-4 opacity-50" />
              <p>{t('scores.selectUserPrompt') || 'Please select a user from the list to view and manage their scores'}</p>
            </div>
          ) : loading ? (
            <div className="text-center py-12">
              <p>{t('common.loading') || 'Loading...'}</p>
            </div>
          ) : userScores.length === 0 ? (
            <div className="text-center text-muted-foreground py-12">
              <Trophy className="h-12 w-12 mx-auto mb-4 opacity-50" />
              <p>{t('scores.noScores') || 'No scores found for this user'}</p>
              <Button onClick={handleAddScore} className="mt-4">
                <Plus className="h-4 w-4 mr-2" />
                {t('scores.addFirstScore') || 'Add First Score'}
              </Button>
            </div>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead><Tag className="h-4 w-4 inline mr-2" />{t('scores.category') || 'Category'}</TableHead>
                  <TableHead>{t('scores.value') || 'Value'}</TableHead>
                  <TableHead><Calendar className="h-4 w-4 inline mr-2" />{t('scores.date') || 'Date'}</TableHead>
                  <TableHead>{t('scores.description') || 'Description'}</TableHead>
                  <TableHead className="text-right">{t('common.actions') || 'Actions'}</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {userScores.map(score => (
                  <TableRow key={score.id}>
                    <TableCell>
                      <Badge>{score.category}</Badge>
                    </TableCell>
                    <TableCell className="font-medium">{score.score_value}</TableCell>
                    <TableCell className="text-sm text-muted-foreground">
                      {score.score_date ? new Date(score.score_date).toLocaleDateString() : 
                       score.created_at ? new Date(score.created_at).toLocaleDateString() : '-'}
                    </TableCell>
                    <TableCell className="max-w-xs truncate text-sm text-muted-foreground">
                      {score.description || '-'}
                    </TableCell>
                    <TableCell className="text-right">
                      <div className="flex justify-end gap-2">
                        <Button
                          variant="ghost"
                          size="sm"
                          onClick={() => handleEditScore(score)}
                        >
                          <Edit className="h-4 w-4" />
                        </Button>
                        <Button
                          variant="ghost"
                          size="sm"
                          onClick={() => handleDeleteScore(score.id)}
                        >
                          <Trash2 className="h-4 w-4 text-destructive" />
                        </Button>
                      </div>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>

      {/* Edit Score Dialog */}
      <Dialog open={showEditDialog} onOpenChange={setShowEditDialog}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>
              {t('scores.editScore') || 'Edit Score'}
            </DialogTitle>
            <DialogDescription>
              {t('scores.editScoreDescription') || 'Update the score details below'}
            </DialogDescription>
          </DialogHeader>
          
          <div className="space-y-4 py-4">
            <div className="space-y-2">
              <Label htmlFor="score_value">{t('scores.value') || 'Score Value'}</Label>
              <Input
                id="score_value"
                type="number"
                value={editForm.score_value}
                onChange={(e) => setEditForm({ ...editForm, score_value: e.target.value })}
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="category">{t('scores.category') || 'Category'}</Label>
              <Select value={editForm.category} onValueChange={(value) => setEditForm({ ...editForm, category: value })}>
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {categories.map(cat => (
                    <SelectItem key={cat.id} value={cat.name}>
                      {cat.name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            <div className="space-y-2">
              <Label htmlFor="score_date">{t('scores.date') || 'Date'}</Label>
              <Input
                id="score_date"
                type="date"
                value={editForm.score_date}
                onChange={(e) => setEditForm({ ...editForm, score_date: e.target.value })}
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="description">{t('scores.description') || 'Description'}</Label>
              <Textarea
                id="description"
                value={editForm.description}
                onChange={(e) => setEditForm({ ...editForm, description: e.target.value })}
                placeholder={t('scores.descriptionPlaceholder') || 'Enter description...'}
              />
            </div>
          </div>

          <DialogFooter>
            <Button variant="outline" onClick={() => setShowEditDialog(false)}>
              <X className="h-4 w-4 mr-2" />
              {t('common.cancel') || 'Cancel'}
            </Button>
            <Button onClick={handleSaveScore}>
              <Save className="h-4 w-4 mr-2" />
              {t('common.save') || 'Save'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Add Score Dialog */}
      <Dialog open={showAddDialog} onOpenChange={setShowAddDialog}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>
              {t('scores.addScore') || 'Add New Score'}
            </DialogTitle>
            <DialogDescription>
              {t('scores.addScoreDescription') || 'Add a new score for this user'}
            </DialogDescription>
          </DialogHeader>
          
          <div className="space-y-4 py-4">
            <div className="space-y-2">
              <Label htmlFor="new_score_value">{t('scores.value') || 'Score Value'}</Label>
              <Input
                id="new_score_value"
                type="number"
                value={editForm.score_value}
                onChange={(e) => setEditForm({ ...editForm, score_value: e.target.value })}
                placeholder="100"
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="new_category">{t('scores.category') || 'Category'}</Label>
              <Select value={editForm.category} onValueChange={(value) => setEditForm({ ...editForm, category: value })}>
                <SelectTrigger>
                  <SelectValue placeholder={t('scores.selectCategory') || 'Select category'} />
                </SelectTrigger>
                <SelectContent>
                  {categories.map(cat => (
                    <SelectItem key={cat.id} value={cat.name}>
                      {cat.name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            <div className="space-y-2">
              <Label htmlFor="new_score_date">{t('scores.date') || 'Date'}</Label>
              <Input
                id="new_score_date"
                type="date"
                value={editForm.score_date}
                onChange={(e) => setEditForm({ ...editForm, score_date: e.target.value })}
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="new_description">{t('scores.description') || 'Description'}</Label>
              <Textarea
                id="new_description"
                value={editForm.description}
                onChange={(e) => setEditForm({ ...editForm, description: e.target.value })}
                placeholder={t('scores.descriptionPlaceholder') || 'Enter description...'}
              />
            </div>
          </div>

          <DialogFooter>
            <Button variant="outline" onClick={() => setShowAddDialog(false)}>
              <X className="h-4 w-4 mr-2" />
              {t('common.cancel') || 'Cancel'}
            </Button>
            <Button onClick={handleSaveScore}>
              <Plus className="h-4 w-4 mr-2" />
              {t('scores.addScore') || 'Add Score'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
