import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { useTranslation } from 'react-i18next';
import OrganizationDetails from './OrganizationDetails';

const SuperAdminDashboard = ({ onLogout }) => {
  const { t } = useTranslation();
  const [stats, setStats] = useState({
    total_users: 0,
    total_organizations: 0,
    active_organizations: 0,
    pending_requests: 0
  });
  const [organizations, setOrganizations] = useState([]);
  const [pendingRequests, setPendingRequests] = useState([]);
  const [allUsers, setAllUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState('dashboard');
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [showUserDetailsModal, setShowUserDetailsModal] = useState(false);
  const [selectedUser, setSelectedUser] = useState(null);
  const [selectedOrganizationId, setSelectedOrganizationId] = useState(null);
  const [createForm, setCreateForm] = useState({
    name: '',
    description: '',
    admin_username: '',
    admin_email: '',
    admin_password: '',
    admin_first_name: '',
    admin_last_name: ''
  });
  const [creating, setCreating] = useState(false);
  const [error, setError] = useState('');
  const [deleteConfirmUser, setDeleteConfirmUser] = useState(null);

  // Export Settings State
  const [showExportSettings, setShowExportSettings] = useState(false);
  const [exportFilters, setExportFilters] = useState({
    organization: 'all', // 'all' or specific organization_id
    birthYear: 'all', // 'all' or specific year
    graduationYear: 'all' // 'all' or specific year
  });
  const [exportFields, setExportFields] = useState({
    // Basic Information
    fullName: true,
    firstName: true,
    lastName: true,
    email: true,
    username: true,
    phoneNumber: true,
    gender: false,
    birthDate: false,
    
    // Academic Information
    studentId: false,
    major: false,
    schoolYear: false,
    gpa: false,
    graduationYear: false,
    universityName: false,
    facultyName: false,
    
    // Address Information
    city: false,
    country: false,
    
    // Organization Information
    organizationName: true,
    organizationRole: true,
    
    // Status Information
    isActive: true,
    isVerified: false,
    
    // Dates
    joinedOrganization: true,
    accountCreated: false
  });

  // API configuration
  const api = axios.create({
    baseURL: '/api',
    headers: {
      'Authorization': `Bearer ${localStorage.getItem('superAdminToken')}`,
      'Content-Type': 'application/json'
    }
  });

  useEffect(() => {
    fetchDashboardData();
  }, []);

  useEffect(() => {
    if (activeTab === 'requests') {
      fetchPendingRequests();
    } else if (activeTab === 'users') {
      fetchAllUsers();
    }
  }, [activeTab]);

  const fetchDashboardData = async () => {
    try {
      setLoading(true);
      const [dashboardResponse, orgsResponse] = await Promise.all([
        api.get('/super-admin/dashboard'),
        api.get('/super-admin/organizations')
      ]);
      
      setStats(dashboardResponse.data.stats);
      setOrganizations(orgsResponse.data.organizations);
      setError('');
    } catch (error) {
      console.error('Error fetching dashboard data:', error);
      setError(t('superAdmin.failedToLoadDashboard'));
    } finally {
      setLoading(false);
    }
  };

  const fetchPendingRequests = async () => {
    try {
      const response = await api.get('/super-admin/join-requests?status=PENDING');
      setPendingRequests(response.data.requests);
      setError('');
    } catch (error) {
      console.error('Error fetching pending requests:', error);
      setError(t('superAdmin.failedToLoadRequests'));
    }
  };

  const fetchAllUsers = async () => {
    try {
      const response = await api.get('/super-admin/users');
      setAllUsers(response.data.users);
      setError('');
    } catch (error) {
      console.error('Error fetching users:', error);
      setError(t('superAdmin.failedToLoadUsers'));
    }
  };

  const handleApproveRequest = async (requestId) => {
    try {
      // Fix: Explicitly set Content-Type header for empty POST request
      await api.post(`/super-admin/join-requests/${requestId}/approve`, {}, {
        headers: {
          'Content-Type': 'application/json'
        }
      });
      // Refresh pending requests and stats
      await Promise.all([fetchPendingRequests(), fetchDashboardData()]);
      setError('');
    } catch (error) {
      console.error('Error approving request:', error);
      setError(error.response?.data?.error || t('superAdmin.failedToApproveRequest'));
    }
  };

  const handleRejectRequest = async (requestId, reason = '') => {
    try {
      await api.post(`/super-admin/join-requests/${requestId}/reject`, {
        reason: reason
      });
      // Refresh pending requests and stats
      await Promise.all([fetchPendingRequests(), fetchDashboardData()]);
      setError('');
    } catch (error) {
      console.error('Error rejecting request:', error);
      setError(error.response?.data?.error || 'Failed to reject request');
    }
  };

  const handleCreateOrganization = async (e) => {
    e.preventDefault();
    setCreating(true);
    setError('');

    try {
      await api.post('/super-admin/organizations', createForm);
      
      // Reset form and close modal
      setCreateForm({
        name: '',
        description: '',
        admin_username: '',
        admin_email: '',
        admin_password: '',
        admin_first_name: '',
        admin_last_name: ''
      });
      setShowCreateModal(false);
      
      // Refresh data
      await fetchDashboardData();
      
    } catch (error) {
      console.error('Error creating organization:', error);
      setError(error.response?.data?.error || 'Failed to create organization');
    } finally {
      setCreating(false);
    }
  };

  const toggleOrganizationStatus = async (organizationId) => {
    try {
      await api.post(`/super-admin/organizations/${organizationId}/toggle-status`, {}, {
        headers: {
          'Content-Type': 'application/json'
        }
      });
      await fetchDashboardData(); // Refresh data
      setError('');
    } catch (error) {
      console.error('Error toggling organization status:', error);
      setError(error.response?.data?.error || 'Failed to update organization status');
    }
  };

  const viewOrganizationDetails = (organizationId) => {
    setSelectedOrganizationId(organizationId);
  };

  const handleBackToList = () => {
    setSelectedOrganizationId(null);
    fetchDashboardData(); // Refresh data when coming back
  };

  const handleToggleUserStatus = async (userId, currentStatus) => {
    try {
      await api.put(`/super-admin/users/${userId}`, {
        is_active: !currentStatus
      });
      // Refresh users list
      await fetchAllUsers();
      
      // Update selected user if modal is open
      if (selectedUser && selectedUser.id === userId) {
        const updatedUser = allUsers.find(u => u.id === userId);
        if (updatedUser) {
          setSelectedUser({...updatedUser, is_active: !currentStatus});
        }
      }
      
      setError('');
    } catch (error) {
      console.error('Error toggling user status:', error);
      setError(error.response?.data?.error || 'Failed to update user status');
    }
  };

  // Export functionality
  const getFieldMapping = () => ({
    fullName: { 
      label: 'Full Name', 
      getValue: (user) => `${user.first_name || ''} ${user.last_name || ''}`.trim() 
    },
    firstName: { label: 'First Name', getValue: (user) => user.first_name || '' },
    lastName: { label: 'Last Name', getValue: (user) => user.last_name || '' },
    email: { label: 'Email', getValue: (user) => user.email || '' },
    username: { label: 'Username', getValue: (user) => user.username || '' },
    phoneNumber: { label: 'Phone Number', getValue: (user) => user.phone_number || '' },
    gender: { label: 'Gender', getValue: (user) => user.gender || '' },
    birthDate: { label: 'Birth Date', getValue: (user) => user.birthdate ? new Date(user.birthdate).toLocaleDateString() : '' },
    
    studentId: { label: 'Student ID', getValue: (user) => user.student_id || '' },
    major: { label: 'Major', getValue: (user) => user.major || '' },
    schoolYear: { label: 'School Year', getValue: (user) => user.school_year || '' },
    gpa: { label: 'GPA', getValue: (user) => user.gpa || '' },
    graduationYear: { label: 'Graduation Year', getValue: (user) => user.graduation_year || '' },
    universityName: { label: 'University', getValue: (user) => user.university_name || '' },
    facultyName: { label: 'Faculty', getValue: (user) => user.faculty_name || '' },
    
    city: { label: 'City', getValue: (user) => user.city || '' },
    country: { label: 'Country', getValue: (user) => user.country || '' },
    
    organizationName: { 
      label: 'Organization(s)', 
      getValue: (user) => user.organizations?.map(org => org.organization_name).join(', ') || '' 
    },
    organizationRole: { 
      label: 'Role(s)', 
      getValue: (user) => user.organizations?.map(org => org.role).join(', ') || '' 
    },
    
    isActive: { label: 'Active', getValue: (user) => user.is_active ? 'Yes' : 'No' },
    isVerified: { label: 'Verified', getValue: (user) => user.is_verified ? 'Yes' : 'No' },
    
    joinedOrganization: { 
      label: 'Joined Organization', 
      getValue: (user) => user.organizations?.[0]?.joined_at ? new Date(user.organizations[0].joined_at).toLocaleDateString() : '' 
    },
    accountCreated: { 
      label: 'Account Created', 
      getValue: (user) => user.created_at ? new Date(user.created_at).toLocaleDateString() : '' 
    }
  });

  const exportToExcel = async () => {
    try {
      // Filter users based on export filters
      let filteredUsers = [...allUsers];
      
      // Filter by organization
      if (exportFilters.organization !== 'all') {
        filteredUsers = filteredUsers.filter(user => 
          user.organizations?.some(org => org.organization_id === exportFilters.organization)
        );
      }
      
      // Filter by birth year
      if (exportFilters.birthYear !== 'all') {
        filteredUsers = filteredUsers.filter(user => {
          if (!user.birthdate) return false;
          const birthYear = new Date(user.birthdate).getFullYear();
          return birthYear.toString() === exportFilters.birthYear;
        });
      }
      
      // Filter by graduation year
      if (exportFilters.graduationYear !== 'all') {
        filteredUsers = filteredUsers.filter(user => 
          user.graduation_year && user.graduation_year.toString() === exportFilters.graduationYear
        );
      }
      
      if (filteredUsers.length === 0) {
        alert('No users match the selected filters.');
        return;
      }
      
      // Get only selected fields
      const fieldMapping = getFieldMapping();
      const selectedFields = Object.keys(exportFields).filter(field => exportFields[field]);
      
      if (selectedFields.length === 0) {
        alert('Please select at least one field to export.');
        return;
      }
      
      // Build headers and rows based on selected fields
      const csvHeaders = selectedFields.map(field => fieldMapping[field].label);
      const csvRows = filteredUsers.map(user => 
        selectedFields.map(field => fieldMapping[field].getValue(user))
      );
      
      const csvContent = [csvHeaders, ...csvRows]
        .map(row => row.map(field => `"${field}"`).join(','))
        .join('\n');
      
      // Create filename with filters
      let filename = 'users-export';
      if (exportFilters.organization !== 'all') {
        const org = organizations.find(o => o.id === exportFilters.organization);
        if (org) filename += `-${org.name.replace(/\s+/g, '-')}`;
      }
      if (exportFilters.birthYear !== 'all') {
        filename += `-birth-${exportFilters.birthYear}`;
      }
      if (exportFilters.graduationYear !== 'all') {
        filename += `-grad-${exportFilters.graduationYear}`;
      }
      filename += `-${new Date().toISOString().split('T')[0]}.csv`;
      
      // Create and download file
      const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
      const link = document.createElement('a');
      const url = URL.createObjectURL(blob);
      link.setAttribute('href', url);
      link.setAttribute('download', filename);
      link.style.visibility = 'hidden';
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      
      setShowExportSettings(false);
      
    } catch (error) {
      console.error('Error exporting users:', error);
      alert('Failed to export users. Please try again.');
    }
  };

  // Get unique birth years and graduation years from users
  const getAvailableYears = () => {
    const birthYears = new Set();
    const gradYears = new Set();
    
    allUsers.forEach(user => {
      if (user.birthdate) {
        birthYears.add(new Date(user.birthdate).getFullYear());
      }
      if (user.graduation_year) {
        gradYears.add(user.graduation_year);
      }
    });
    
    return {
      birthYears: Array.from(birthYears).sort((a, b) => b - a),
      graduationYears: Array.from(gradYears).sort((a, b) => b - a)
    };
  };

  const handleViewUserDetails = (userId) => {
    const user = allUsers.find(u => u.id === userId);
    if (user) {
      setSelectedUser(user);
      setShowUserDetailsModal(true);
    }
  };

  const handleDeleteUser = async () => {
    if (!deleteConfirmUser) return;
    
    try {
      await api.post(`/super-admin/users/${deleteConfirmUser.id}/delete`);
      setDeleteConfirmUser(null);
      await fetchAllUsers(); // Refresh the users list
      setError('');
    } catch (error) {
      console.error('Error deleting user:', error);
      
      // Handle authentication errors and non-JSON responses gracefully
      if (error.response?.status === 401) {
        setError('Authentication failed. Please log in again.');
        // Optionally clear token and redirect to login
        localStorage.removeItem('superAdminToken');
        window.location.href = '/admin-login';
      } else if (error.response?.status === 503) {
        setError('Service temporarily unavailable. Please try again later.');
      } else {
        // Try to extract error message, fallback for non-JSON responses
        let errorMessage = 'Failed to delete user';
        try {
          if (error.response?.data?.error) {
            errorMessage = error.response.data.error;
          } else if (error.response?.data && typeof error.response.data === 'string') {
            errorMessage = error.response.data;
          }
        } catch (parseError) {
          // If we can't parse the response, use the default message
          console.log('Could not parse error response:', parseError);
        }
        setError(errorMessage);
      }
    }
  };

  // If viewing organization details, show the details component
  if (selectedOrganizationId) {
    return (
      <OrganizationDetails 
        organizationId={selectedOrganizationId} 
        onBack={handleBackToList}
      />
    );
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto"></div>
          <p className="mt-4 text-gray-600">Loading dashboard...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50 p-6">
      <div className="flex items-center justify-between mb-8">
        <div>
          <h1 className="text-3xl font-bold text-gray-900">Super Admin Dashboard</h1>
          <p className="text-gray-600 mt-2">Manage the entire platform</p>
        </div>
        <button 
          onClick={onLogout}
          className="px-4 py-2 bg-gray-200 hover:bg-gray-300 rounded-md transition-colors"
        >
          Logout
        </button>
      </div>

      {error && (
        <div className="mb-6 bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded">
          {error}
        </div>
      )}

      {/* Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
        <div className="bg-white p-6 rounded-lg shadow">
          <h3 className="text-lg font-medium text-gray-900">Total Users</h3>
          <p className="text-3xl font-bold text-blue-600">{stats.total_users}</p>
        </div>

        <div className="bg-white p-6 rounded-lg shadow">
          <h3 className="text-lg font-medium text-gray-900">Total Organizations</h3>
          <p className="text-3xl font-bold text-green-600">{stats.total_organizations}</p>
        </div>

        <div className="bg-white p-6 rounded-lg shadow">
          <h3 className="text-lg font-medium text-gray-900">Active Organizations</h3>
          <p className="text-3xl font-bold text-purple-600">{stats.active_organizations}</p>
        </div>

        <div className="bg-white p-6 rounded-lg shadow">
          <h3 className="text-lg font-medium text-gray-900">Pending Requests</h3>
          <p className="text-3xl font-bold text-orange-600">{stats.pending_requests}</p>
        </div>
      </div>

      {/* Tabs Navigation */}
      <div className="bg-white rounded-lg shadow mb-6">
        <div className="border-b border-gray-200">
          <nav className="-mb-px flex space-x-8 px-6">
            <button
              onClick={() => setActiveTab('dashboard')}
              className={`py-4 px-1 border-b-2 font-medium text-sm ${
                activeTab === 'dashboard'
                  ? 'border-blue-500 text-blue-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
              }`}
            >
              Organizations
            </button>
            <button
              onClick={() => setActiveTab('requests')}
              className={`py-4 px-1 border-b-2 font-medium text-sm ${
                activeTab === 'requests'
                  ? 'border-blue-500 text-blue-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
              }`}
            >
              Pending Requests ({stats.pending_requests})
            </button>
            <button
              onClick={() => setActiveTab('users')}
              className={`py-4 px-1 border-b-2 font-medium text-sm ${
                activeTab === 'users'
                  ? 'border-blue-500 text-blue-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
              }`}
            >
              All Users ({stats.total_users})
            </button>
          </nav>
        </div>
      </div>

      {/* Tab Content */}
      {activeTab === 'dashboard' && (
        <div className="bg-white rounded-lg shadow">
          <div className="px-6 py-4 border-b border-gray-200 flex items-center justify-between">
            <div>
              <h3 className="text-lg font-medium text-gray-900">Organization Management</h3>
              <p className="text-sm text-gray-500">Manage all organizations in the platform</p>
            </div>
            <button 
              onClick={() => setShowCreateModal(true)}
              className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 transition-colors cursor-pointer"
            >
              Create Organization
          </button>
        </div>
        <div className="p-6">
          {organizations.length === 0 ? (
            <p className="text-gray-500 text-center py-8">
              No organizations found. Create your first organization to get started.
            </p>
          ) : (
            <div className="space-y-4">
              {organizations.map((org) => (
                <div key={org.id} className="border border-gray-200 rounded-lg p-4">
                  <div className="flex items-center justify-between">
                    <div>
                      <h4 className="text-lg font-medium text-gray-900">{org.name}</h4>
                      <p className="text-sm text-gray-500">{org.description}</p>
                      <p className="text-xs text-gray-400 mt-1">
                        Created: {new Date(org.created_at).toLocaleDateString()}
                      </p>
                    </div>
                    <div className="flex items-center space-x-4">
                      <div className="text-right">
                        <span className={`inline-flex px-2 py-1 text-xs font-semibold rounded-full ${
                          org.is_active ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'
                        }`}>
                          {org.is_active ? 'Active' : 'Inactive'}
                        </span>
                        <p className="text-sm text-gray-500 mt-1">
                          {org.member_count} member{org.member_count !== 1 ? 's' : ''}
                        </p>
                      </div>
                      <div className="flex flex-col space-y-2">
                        <button
                          onClick={() => viewOrganizationDetails(org.id)}
                          className="flex items-center px-3 py-1 bg-blue-600 text-white text-sm rounded hover:bg-blue-700 transition-colors"
                        >
                          <svg className="h-4 w-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                          </svg>
                          View Details
                        </button>
                        <button
                          onClick={() => toggleOrganizationStatus(org.id)}
                          className={`flex items-center px-3 py-1 text-sm rounded transition-colors ${
                            org.is_active 
                              ? 'bg-red-600 text-white hover:bg-red-700' 
                              : 'bg-green-600 text-white hover:bg-green-700'
                          }`}
                        >
                          {org.is_active ? (
                            <>
                              <svg className="h-4 w-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M18.364 18.364A9 9 0 005.636 5.636m12.728 12.728L5.636 5.636m12.728 12.728L5.636 5.636" />
                              </svg>
                              Disable
                            </>
                          ) : (
                            <>
                              <svg className="h-4 w-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                              </svg>
                              Enable
                            </>
                          )}
                        </button>
                      </div>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
      )}

      {/* Pending Requests Tab Content */}
      {activeTab === 'requests' && (
        <div className="bg-white rounded-lg shadow">
          <div className="px-6 py-4 border-b border-gray-200">
            <h3 className="text-lg font-medium text-gray-900">Pending Join Requests</h3>
            <p className="text-sm text-gray-500">Review and manage organization join requests</p>
          </div>
          <div className="p-6">
            {pendingRequests.length === 0 ? (
              <p className="text-gray-500 text-center py-8">
                No pending join requests found.
              </p>
            ) : (
              <div className="space-y-4">
                {pendingRequests.map((request) => (
                  <div key={request.id} className="border border-gray-200 rounded-lg p-4">
                    <div className="flex items-center justify-between">
                      <div className="flex-1">
                        <div className="flex items-center space-x-4">
                          <div>
                            <h4 className="text-lg font-medium text-gray-900">
                              {request.user?.first_name} {request.user?.last_name}
                            </h4>
                            <p className="text-sm text-gray-500">{request.user?.email}</p>
                            <p className="text-sm text-gray-600 mt-1">
                              Wants to join: <span className="font-medium">{request.organization_name}</span>
                            </p>
                            <p className="text-xs text-gray-400 mt-1">
                              Requested: {new Date(request.created_at).toLocaleDateString()}
                            </p>
                            {request.message && (
                              <p className="text-sm text-gray-600 mt-2 bg-gray-50 p-2 rounded">
                                <strong>Message:</strong> {request.message}
                              </p>
                            )}
                          </div>
                        </div>
                      </div>
                      <div className="flex space-x-2">
                        <button
                          onClick={() => handleApproveRequest(request.id)}
                          className="px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700 transition-colors"
                        >
                          Approve
                        </button>
                        <button
                          onClick={() => handleRejectRequest(request.id)}
                          className="px-4 py-2 bg-red-600 text-white rounded-md hover:bg-red-700 transition-colors"
                        >
                          Reject
                        </button>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      )}

      {/* Users Tab Content */}
      {activeTab === 'users' && (
        <div className="bg-white rounded-lg shadow">
          <div className="px-6 py-4 border-b border-gray-200 flex items-center justify-between">
            <div>
              <h3 className="text-lg font-medium text-gray-900">All Users</h3>
              <p className="text-sm text-gray-500">Manage all users across the platform</p>
            </div>
            <button
              onClick={() => setShowExportSettings(true)}
              className="px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700 transition-colors flex items-center space-x-2"
            >
              <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
              </svg>
              <span>Export Users</span>
            </button>
          </div>
          <div className="p-6">
            {allUsers.length === 0 ? (
              <p className="text-gray-500 text-center py-8">
                No users found.
              </p>
            ) : (
              <div className="space-y-4">
                {allUsers.map((user) => (
                  <div key={user.id} className="border border-gray-200 rounded-lg p-4">
                    <div className="flex items-center justify-between">
                      <div className="flex-1">
                        <div className="flex items-center space-x-4">
                          <div className={`w-10 h-10 rounded-full flex items-center justify-center ${
                            user.is_active ? 'bg-green-100' : 'bg-gray-100'
                          }`}>
                            <span className={`text-sm font-medium ${
                              user.is_active ? 'text-green-800' : 'text-gray-500'
                            }`}>
                              {user.first_name?.[0]}{user.last_name?.[0]}
                            </span>
                          </div>
                          <div>
                            <h4 className="text-lg font-medium text-gray-900">
                              {user.first_name} {user.last_name}
                            </h4>
                            <p className="text-sm text-gray-500">@{user.username}</p>
                            <p className="text-sm text-gray-500">{user.email}</p>
                            <div className="flex items-center space-x-2 mt-2">
                              <span className={`inline-flex px-2 py-1 text-xs font-semibold rounded-full ${
                                user.is_active ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'
                              }`}>
                                {user.is_active ? 'Active' : 'Inactive'}
                              </span>
                              {user.organizations && user.organizations.length > 0 && (
                                <span className="text-xs text-gray-500">
                                  {user.organizations.length} organization{user.organizations.length !== 1 ? 's' : ''}
                                </span>
                              )}
                            </div>
                          </div>
                        </div>
                        {user.organizations && user.organizations.length > 0 && (
                          <div className="mt-3 pl-14">
                            <h5 className="text-sm font-medium text-gray-700 mb-2">Organizations:</h5>
                            <div className="space-y-1">
                              {user.organizations.map((org, index) => (
                                <div key={index} className="flex items-center space-x-2">
                                  <span className="text-sm text-gray-600">{org.organization_name}</span>
                                  <span className={`px-2 py-1 text-xs rounded ${
                                    org.role === 'SUPER_ADMIN' ? 'bg-purple-100 text-purple-800' :
                                    org.role === 'ORG_ADMIN' ? 'bg-blue-100 text-blue-800' :
                                    'bg-gray-100 text-gray-800'
                                  }`}>
                                    {org.role}
                                  </span>
                                </div>
                              ))}
                            </div>
                          </div>
                        )}
                      </div>
                      <div className="flex space-x-2">
                        <button
                          onClick={() => handleToggleUserStatus(user.id, user.is_active)}
                          className={`px-4 py-2 rounded-md transition-colors ${
                            user.is_active 
                              ? 'bg-red-600 text-white hover:bg-red-700' 
                              : 'bg-green-600 text-white hover:bg-green-700'
                          }`}
                        >
                          {user.is_active ? 'Deactivate' : 'Activate'}
                        </button>
                        <button
                          onClick={() => handleViewUserDetails(user.id)}
                          className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 transition-colors"
                        >
                          View Details
                        </button>
                        <button
                          onClick={() => setDeleteConfirmUser(user)}
                          className="px-4 py-2 bg-red-600 text-white rounded-md hover:bg-red-700 transition-colors"
                        >
                          Delete
                        </button>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      )}

      {/* Create Organization Modal */}
      {showCreateModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-lg max-w-md w-full max-h-[90vh] overflow-y-auto">
            <div className="px-6 py-4 border-b border-gray-200">
              <h3 className="text-lg font-medium text-gray-900">Create New Organization</h3>
            </div>
            <form onSubmit={handleCreateOrganization} className="p-6 space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Organization Name
                </label>
                <input
                  type="text"
                  value={createForm.name}
                  onChange={(e) => setCreateForm({...createForm, name: e.target.value})}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                  required
                />
              </div>
              
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Description
                </label>
                <textarea
                  value={createForm.description}
                  onChange={(e) => setCreateForm({...createForm, description: e.target.value})}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                  rows="3"
                />
              </div>

              <div className="border-t pt-4">
                <h4 className="text-sm font-medium text-gray-900 mb-3">Admin User Details</h4>
                
                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      First Name
                    </label>
                    <input
                      type="text"
                      value={createForm.admin_first_name}
                      onChange={(e) => setCreateForm({...createForm, admin_first_name: e.target.value})}
                      className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                      required
                    />
                  </div>
                  
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      Last Name
                    </label>
                    <input
                      type="text"
                      value={createForm.admin_last_name}
                      onChange={(e) => setCreateForm({...createForm, admin_last_name: e.target.value})}
                      className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                      required
                    />
                  </div>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Username
                  </label>
                  <input
                    type="text"
                    value={createForm.admin_username}
                    onChange={(e) => setCreateForm({...createForm, admin_username: e.target.value})}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                    required
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Email
                  </label>
                  <input
                    type="email"
                    value={createForm.admin_email}
                    onChange={(e) => setCreateForm({...createForm, admin_email: e.target.value})}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                    required
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Password
                  </label>
                  <input
                    type="password"
                    value={createForm.admin_password}
                    onChange={(e) => setCreateForm({...createForm, admin_password: e.target.value})}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                    required
                    minLength="8"
                  />
                </div>
              </div>

              <div className="flex space-x-3 pt-4">
                <button
                  type="submit"
                  disabled={creating}
                  className="flex-1 px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                >
                  {creating ? 'Creating...' : 'Create Organization'}
                </button>
                <button
                  type="button"
                  onClick={() => setShowCreateModal(false)}
                  className="px-4 py-2 bg-gray-200 text-gray-800 rounded-md hover:bg-gray-300 transition-colors"
                >
                  Cancel
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* User Details Modal */}
      {showUserDetailsModal && selectedUser && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-lg max-w-2xl w-full max-h-[90vh] overflow-y-auto">
            <div className="px-6 py-4 border-b border-gray-200 flex items-center justify-between">
              <h3 className="text-lg font-medium text-gray-900">User Details</h3>
              <button
                onClick={() => setShowUserDetailsModal(false)}
                className="text-gray-400 hover:text-gray-600"
              >
                <svg className="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>
            <div className="p-6 space-y-6">
              {/* User Basic Information */}
              <div className="flex items-center space-x-4">
                <div className={`w-16 h-16 rounded-full flex items-center justify-center ${
                  selectedUser.is_active ? 'bg-green-100' : 'bg-gray-100'
                }`}>
                  <span className={`text-xl font-medium ${
                    selectedUser.is_active ? 'text-green-800' : 'text-gray-500'
                  }`}>
                    {selectedUser.first_name?.[0]}{selectedUser.last_name?.[0]}
                  </span>
                </div>
                <div>
                  <h4 className="text-xl font-medium text-gray-900">
                    {selectedUser.first_name} {selectedUser.last_name}
                  </h4>
                  <p className="text-gray-500">@{selectedUser.username}</p>
                  <p className="text-gray-500">{selectedUser.email}</p>
                  <span className={`inline-flex px-2 py-1 text-xs font-semibold rounded-full mt-2 ${
                    selectedUser.is_active ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'
                  }`}>
                    {selectedUser.is_active ? 'Active' : 'Inactive'}
                  </span>
                </div>
              </div>

              {/* User Statistics */}
              <div className="grid grid-cols-3 gap-4">
                <div className="bg-gray-50 p-4 rounded-lg text-center">
                  <div className="text-2xl font-bold text-gray-900">
                    {selectedUser.organizations?.length || 0}
                  </div>
                  <div className="text-sm text-gray-500">Organizations</div>
                </div>
                <div className="bg-gray-50 p-4 rounded-lg text-center">
                  <div className="text-2xl font-bold text-gray-900">
                    {selectedUser.created_at ? new Date(selectedUser.created_at).toLocaleDateString() : 'N/A'}
                  </div>
                  <div className="text-sm text-gray-500">Joined</div>
                </div>
                <div className="bg-gray-50 p-4 rounded-lg text-center">
                  <div className="text-2xl font-bold text-gray-900">
                    {selectedUser.updated_at ? new Date(selectedUser.updated_at).toLocaleDateString() : 'N/A'}
                  </div>
                  <div className="text-sm text-gray-500">Last Updated</div>
                </div>
              </div>

              {/* Organization Memberships */}
              <div>
                <h5 className="text-lg font-medium text-gray-900 mb-4">Organization Memberships</h5>
                {selectedUser.organizations && selectedUser.organizations.length > 0 ? (
                  <div className="space-y-3">
                    {selectedUser.organizations.map((org, index) => (
                      <div key={index} className="border border-gray-200 rounded-lg p-4">
                        <div className="flex items-center justify-between">
                          <div>
                            <h6 className="font-medium text-gray-900">{org.organization_name}</h6>
                            <p className="text-sm text-gray-500">
                              Joined: {org.created_at ? new Date(org.created_at).toLocaleDateString() : 'N/A'}
                            </p>
                          </div>
                          <div className="flex items-center space-x-2">
                            <span className={`px-3 py-1 text-xs rounded-full ${
                              org.role === 'SUPER_ADMIN' ? 'bg-purple-100 text-purple-800' :
                              org.role === 'ORG_ADMIN' ? 'bg-blue-100 text-blue-800' :
                              'bg-gray-100 text-gray-800'
                            }`}>
                              {org.role}
                            </span>
                            <span className={`px-2 py-1 text-xs rounded ${
                              org.is_active ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'
                            }`}>
                              {org.is_active ? 'Active' : 'Inactive'}
                            </span>
                          </div>
                        </div>
                      </div>
                    ))}
                  </div>
                ) : (
                  <p className="text-gray-500 text-center py-4">
                    User is not a member of any organizations
                  </p>
                )}
              </div>

              {/* Additional User Information */}
              <div>
                <h5 className="text-lg font-medium text-gray-900 mb-4">Additional Information</h5>
                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <label className="block text-sm font-medium text-gray-700">User ID</label>
                    <p className="text-sm text-gray-900 bg-gray-50 p-2 rounded">{selectedUser.id}</p>
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-gray-700">Account Status</label>
                    <p className="text-sm text-gray-900 bg-gray-50 p-2 rounded">
                      {selectedUser.is_active ? 'Active' : 'Inactive'}
                    </p>
                  </div>
                  {selectedUser.phone && (
                    <div>
                      <label className="block text-sm font-medium text-gray-700">Phone</label>
                      <p className="text-sm text-gray-900 bg-gray-50 p-2 rounded">{selectedUser.phone}</p>
                    </div>
                  )}
                  {selectedUser.address && (
                    <div>
                      <label className="block text-sm font-medium text-gray-700">Address</label>
                      <p className="text-sm text-gray-900 bg-gray-50 p-2 rounded">{selectedUser.address}</p>
                    </div>
                  )}
                </div>
              </div>

              {/* Action Buttons */}
              <div className="flex justify-end space-x-3 pt-4 border-t border-gray-200">
                <button
                  onClick={() => handleToggleUserStatus(selectedUser.id, selectedUser.is_active)}
                  className={`px-4 py-2 rounded-md transition-colors ${
                    selectedUser.is_active 
                      ? 'bg-red-600 text-white hover:bg-red-700' 
                      : 'bg-green-600 text-white hover:bg-green-700'
                  }`}
                >
                  {selectedUser.is_active ? 'Deactivate User' : 'Activate User'}
                </button>
                <button
                  onClick={() => setShowUserDetailsModal(false)}
                  className="px-4 py-2 bg-gray-200 text-gray-800 rounded-md hover:bg-gray-300 transition-colors"
                >
                  Close
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Delete Confirmation Modal */}
      {deleteConfirmUser && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-lg max-w-md w-full">
            <div className="px-6 py-4 border-b border-gray-200">
              <h3 className="text-lg font-medium text-gray-900">Confirm User Deletion</h3>
            </div>
            <div className="p-6">
              <p className="text-sm text-gray-600 mb-4">
                Are you sure you want to permanently delete the user <strong>{deleteConfirmUser.username}</strong>? 
                This action will:
              </p>
              <ul className="text-sm text-gray-600 mb-6 list-disc list-inside space-y-1">
                <li>Deactivate the user across the entire platform</li>
                <li>Remove them from all organizations</li>
                <li>This action cannot be undone</li>
              </ul>
              <div className="flex space-x-3 justify-end">
                <button
                  onClick={() => setDeleteConfirmUser(null)}
                  className="px-4 py-2 bg-gray-200 text-gray-800 rounded-md hover:bg-gray-300 transition-colors"
                >
                  Cancel
                </button>
                <button
                  onClick={handleDeleteUser}
                  className="px-4 py-2 bg-red-600 text-white rounded-md hover:bg-red-700 transition-colors"
                >
                  Delete User
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Export Settings Modal */}
      {showExportSettings && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-lg max-w-4xl w-full max-h-[90vh] overflow-y-auto">
            <div className="px-6 py-4 border-b border-gray-200">
              <h3 className="text-lg font-medium text-gray-900">Export Users</h3>
              <p className="text-sm text-gray-500 mt-1">Configure export filters and select fields</p>
            </div>
            
            <div className="p-6 space-y-6">
              {/* Filters Section */}
              <div className="border-b pb-6">
                <h4 className="text-md font-medium text-gray-900 mb-4">Filters</h4>
                <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                  {/* Organization Filter */}
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                      Organization
                    </label>
                    <select
                      value={exportFilters.organization}
                      onChange={(e) => setExportFilters({...exportFilters, organization: e.target.value})}
                      className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                    >
                      <option value="all">All Organizations</option>
                      {organizations.map(org => (
                        <option key={org.id} value={org.id}>{org.name}</option>
                      ))}
                    </select>
                  </div>

                  {/* Birth Year Filter */}
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                      Birth Year
                    </label>
                    <select
                      value={exportFilters.birthYear}
                      onChange={(e) => setExportFilters({...exportFilters, birthYear: e.target.value})}
                      className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                    >
                      <option value="all">All Birth Years</option>
                      {getAvailableYears().birthYears.map(year => (
                        <option key={year} value={year}>{year}</option>
                      ))}
                    </select>
                  </div>

                  {/* Graduation Year Filter */}
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                      Graduation Year
                    </label>
                    <select
                      value={exportFilters.graduationYear}
                      onChange={(e) => setExportFilters({...exportFilters, graduationYear: e.target.value})}
                      className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                    >
                      <option value="all">All Graduation Years</option>
                      {getAvailableYears().graduationYears.map(year => (
                        <option key={year} value={year}>{year}</option>
                      ))}
                    </select>
                  </div>
                </div>
              </div>

              {/* Fields Selection */}
              <div>
                <h4 className="text-md font-medium text-gray-900 mb-4">Export Fields</h4>
                
                {/* Basic Information */}
                <div className="mb-4">
                  <h5 className="text-sm font-medium text-gray-700 mb-2">Basic Information</h5>
                  <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
                    {['fullName', 'firstName', 'lastName', 'email', 'username', 'phoneNumber', 'gender', 'birthDate'].map(field => (
                      <label key={field} className="flex items-center space-x-2 cursor-pointer">
                        <input
                          type="checkbox"
                          checked={exportFields[field]}
                          onChange={(e) => setExportFields(prev => ({...prev, [field]: e.target.checked}))}
                          className="rounded border-gray-300"
                        />
                        <span className="text-sm text-gray-700 capitalize">
                          {field.replace(/([A-Z])/g, ' $1').trim()}
                        </span>
                      </label>
                    ))}
                  </div>
                </div>

                {/* Academic Information */}
                <div className="mb-4">
                  <h5 className="text-sm font-medium text-gray-700 mb-2">Academic Information</h5>
                  <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
                    {['studentId', 'major', 'schoolYear', 'gpa', 'graduationYear', 'universityName', 'facultyName'].map(field => (
                      <label key={field} className="flex items-center space-x-2 cursor-pointer">
                        <input
                          type="checkbox"
                          checked={exportFields[field]}
                          onChange={(e) => setExportFields(prev => ({...prev, [field]: e.target.checked}))}
                          className="rounded border-gray-300"
                        />
                        <span className="text-sm text-gray-700 capitalize">
                          {field.replace(/([A-Z])/g, ' $1').trim()}
                        </span>
                      </label>
                    ))}
                  </div>
                </div>

                {/* Location & Organization */}
                <div className="mb-4">
                  <h5 className="text-sm font-medium text-gray-700 mb-2">Location & Organization</h5>
                  <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
                    {['city', 'country', 'organizationName', 'organizationRole'].map(field => (
                      <label key={field} className="flex items-center space-x-2 cursor-pointer">
                        <input
                          type="checkbox"
                          checked={exportFields[field]}
                          onChange={(e) => setExportFields(prev => ({...prev, [field]: e.target.checked}))}
                          className="rounded border-gray-300"
                        />
                        <span className="text-sm text-gray-700 capitalize">
                          {field.replace(/([A-Z])/g, ' $1').trim()}
                        </span>
                      </label>
                    ))}
                  </div>
                </div>

                {/* Status & Dates */}
                <div className="mb-4">
                  <h5 className="text-sm font-medium text-gray-700 mb-2">Status & Dates</h5>
                  <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
                    {['isActive', 'isVerified', 'joinedOrganization', 'accountCreated'].map(field => (
                      <label key={field} className="flex items-center space-x-2 cursor-pointer">
                        <input
                          type="checkbox"
                          checked={exportFields[field]}
                          onChange={(e) => setExportFields(prev => ({...prev, [field]: e.target.checked}))}
                          className="rounded border-gray-300"
                        />
                        <span className="text-sm text-gray-700 capitalize">
                          {field.replace(/([A-Z])/g, ' $1').trim()}
                        </span>
                      </label>
                    ))}
                  </div>
                </div>
              </div>

              {/* Action Buttons */}
              <div className="flex justify-end space-x-3 pt-4 border-t border-gray-200">
                <button
                  onClick={() => setShowExportSettings(false)}
                  className="px-4 py-2 bg-gray-200 text-gray-800 rounded-md hover:bg-gray-300 transition-colors"
                >
                  Cancel
                </button>
                <button
                  onClick={exportToExcel}
                  className="px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700 transition-colors flex items-center space-x-2"
                >
                  <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                  </svg>
                  <span>Export to CSV</span>
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default SuperAdminDashboard;
