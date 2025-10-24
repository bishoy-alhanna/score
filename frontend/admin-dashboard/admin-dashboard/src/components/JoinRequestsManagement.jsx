import React, { useState, useEffect } from 'react'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle, DialogTrigger } from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Textarea } from '@/components/ui/textarea'
import { CheckCircle, XCircle, Clock, User, Mail, MessageSquare } from 'lucide-react'
import LoadingSpinner from '@/components/ui/loading-spinner'

function JoinRequestsManagement({ organizationId, api }) {
  const [requests, setRequests] = useState([])
  const [loading, setLoading] = useState(true)
  const [processing, setProcessing] = useState(null)
  const [selectedRequest, setSelectedRequest] = useState(null)
  const [reviewData, setReviewData] = useState({
    role: '',
    department: '',
    title: '',
    message: ''
  })

  useEffect(() => {
    if (organizationId) {
      fetchJoinRequests()
    }
  }, [organizationId])

  const fetchJoinRequests = async () => {
    try {
      setLoading(true)
      const response = await api.get(`/auth/organizations/${organizationId}/join-requests`)
      setRequests(response.data.requests)
    } catch (error) {
      console.error('Failed to fetch join requests:', error)
    } finally {
      setLoading(false)
    }
  }

  const handleApprove = async () => {
    if (!selectedRequest) return

    try {
      setProcessing('approve')
      await api.post(
        `/auth/organizations/${organizationId}/join-requests/${selectedRequest.id}/approve`,
        reviewData
      )
      
      // Remove approved request from list
      setRequests(requests.filter(req => req.id !== selectedRequest.id))
      setSelectedRequest(null)
      setReviewData({ role: '', department: '', title: '', message: '' })
      
      alert('Join request approved successfully!')
    } catch (error) {
      console.error('Failed to approve request:', error)
      alert('Failed to approve request: ' + (error.response?.data?.error || 'Unknown error'))
    } finally {
      setProcessing(null)
    }
  }

  const handleReject = async () => {
    if (!selectedRequest) return

    try {
      setProcessing('reject')
      await api.post(
        `/auth/organizations/${organizationId}/join-requests/${selectedRequest.id}/reject`,
        { message: reviewData.message }
      )
      
      // Remove rejected request from list
      setRequests(requests.filter(req => req.id !== selectedRequest.id))
      setSelectedRequest(null)
      setReviewData({ role: '', department: '', title: '', message: '' })
      
      alert('Join request rejected')
    } catch (error) {
      console.error('Failed to reject request:', error)
      alert('Failed to reject request: ' + (error.response?.data?.error || 'Unknown error'))
    } finally {
      setProcessing(null)
    }
  }

  const openReviewDialog = (request) => {
    setSelectedRequest(request)
    setReviewData({
      role: request.requested_role,
      department: '',
      title: '',
      message: ''
    })
  }

  if (loading) {
    return (
      <Card>
        <CardHeader>
          <CardTitle>Join Requests</CardTitle>
        </CardHeader>
        <CardContent>
          <LoadingSpinner text="Loading join requests..." />
        </CardContent>
      </Card>
    )
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center">
          <Clock className="h-5 w-5 mr-2" />
          Pending Join Requests
        </CardTitle>
        <CardDescription>
          Review and manage requests to join your organization
        </CardDescription>
      </CardHeader>
      <CardContent>
        {requests.length === 0 ? (
          <div className="text-center py-8 text-gray-500">
            <Clock className="h-12 w-12 mx-auto mb-4 text-gray-300" />
            <p>No pending join requests</p>
          </div>
        ) : (
          <div className="space-y-4">
            {requests.map((request) => (
              <Card key={request.id} className="border-l-4 border-l-blue-500">
                <CardContent className="p-4">
                  <div className="flex justify-between items-start">
                    <div className="space-y-2">
                      <div className="flex items-center space-x-2">
                        <User className="h-4 w-4" />
                        <span className="font-medium">{request.user.username}</span>
                        <Badge variant="secondary">{request.requested_role}</Badge>
                      </div>
                      
                      <div className="flex items-center space-x-2 text-sm text-gray-600">
                        <Mail className="h-3 w-3" />
                        <span>{request.user.email}</span>
                      </div>
                      
                      {request.user.first_name && (
                        <div className="text-sm text-gray-600">
                          <strong>Name:</strong> {request.user.first_name} {request.user.last_name}
                        </div>
                      )}
                      
                      {request.message && (
                        <div className="flex items-start space-x-2 text-sm">
                          <MessageSquare className="h-3 w-3 mt-0.5 text-gray-400" />
                          <div>
                            <strong>Message:</strong>
                            <p className="text-gray-600 mt-1">{request.message}</p>
                          </div>
                        </div>
                      )}
                      
                      <div className="text-xs text-gray-500">
                        Requested: {new Date(request.created_at).toLocaleDateString()}
                      </div>
                    </div>
                    
                    <div className="flex space-x-2">
                      <Dialog>
                        <DialogTrigger asChild>
                          <Button 
                            size="sm" 
                            onClick={() => openReviewDialog(request)}
                          >
                            <CheckCircle className="h-4 w-4 mr-1" />
                            Review
                          </Button>
                        </DialogTrigger>
                        <DialogContent>
                          <DialogHeader>
                            <DialogTitle>Review Join Request</DialogTitle>
                            <DialogDescription>
                              Review and approve/reject {request.user.username}'s request to join your organization
                            </DialogDescription>
                          </DialogHeader>
                          
                          <div className="space-y-4">
                            <div className="bg-gray-50 p-4 rounded-lg">
                              <h4 className="font-medium mb-2">User Information</h4>
                              <div className="space-y-1 text-sm">
                                <p><strong>Username:</strong> {request.user.username}</p>
                                <p><strong>Email:</strong> {request.user.email}</p>
                                {request.user.first_name && (
                                  <p><strong>Name:</strong> {request.user.first_name} {request.user.last_name}</p>
                                )}
                                <p><strong>Requested Role:</strong> {request.requested_role}</p>
                                {request.message && (
                                  <p><strong>Message:</strong> {request.message}</p>
                                )}
                              </div>
                            </div>
                            
                            <div className="grid grid-cols-2 gap-4">
                              <div>
                                <Label htmlFor="review-role">Assign Role</Label>
                                <Select 
                                  value={reviewData.role} 
                                  onValueChange={(value) => setReviewData({ ...reviewData, role: value })}
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
                                <Label htmlFor="review-department">Department</Label>
                                <Input
                                  id="review-department"
                                  value={reviewData.department}
                                  onChange={(e) => setReviewData({ ...reviewData, department: e.target.value })}
                                  placeholder="e.g., Engineering"
                                />
                              </div>
                            </div>
                            
                            <div>
                              <Label htmlFor="review-title">Job Title</Label>
                              <Input
                                id="review-title"
                                value={reviewData.title}
                                onChange={(e) => setReviewData({ ...reviewData, title: e.target.value })}
                                placeholder="e.g., Software Developer"
                              />
                            </div>
                            
                            <div>
                              <Label htmlFor="review-message">Review Message (Optional)</Label>
                              <Textarea
                                id="review-message"
                                value={reviewData.message}
                                onChange={(e) => setReviewData({ ...reviewData, message: e.target.value })}
                                placeholder="Welcome message or rejection reason..."
                                rows={3}
                              />
                            </div>
                            
                            <div className="flex space-x-2">
                              <Button 
                                onClick={handleApprove}
                                disabled={processing === 'approve' || !reviewData.role}
                                className="flex-1"
                              >
                                {processing === 'approve' ? (
                                  <>
                                    <LoadingSpinner size="sm" />
                                    Approving...
                                  </>
                                ) : (
                                  <>
                                    <CheckCircle className="h-4 w-4 mr-1" />
                                    Approve
                                  </>
                                )}
                              </Button>
                              
                              <Button 
                                variant="destructive"
                                onClick={handleReject}
                                disabled={processing === 'reject'}
                                className="flex-1"
                              >
                                {processing === 'reject' ? (
                                  <>
                                    <LoadingSpinner size="sm" />
                                    Rejecting...
                                  </>
                                ) : (
                                  <>
                                    <XCircle className="h-4 w-4 mr-1" />
                                    Reject
                                  </>
                                )}
                              </Button>
                            </div>
                          </div>
                        </DialogContent>
                      </Dialog>
                    </div>
                  </div>
                </CardContent>
              </Card>
            ))}
          </div>
        )}
      </CardContent>
    </Card>
  )
}

export default JoinRequestsManagement