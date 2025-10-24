import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { ArrowLeft, Users, UserPlus, Search, Shield, UserMinus, Edit } from 'lucide-react';

const OrganizationDetails = ({ organizationId, onBack }) => {
  const [organization, setOrganization] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [showAddMember, setShowAddMember] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [searchResults, setSearchResults] = useState([]);
  const [searchLoading, setSearchLoading] = useState(false);
  const [selectedRole, setSelectedRole] = useState('USER');

  // API configuration
  const api = axios.create({
    baseURL: '/api',
    headers: {
      'Authorization': `Bearer ${localStorage.getItem('superAdminToken')}`,
      'Content-Type': 'application/json'
    }
  });

  useEffect(() => {
    fetchOrganizationDetails();
  }, [organizationId]);

  const fetchOrganizationDetails = async () => {
    try {
      setLoading(true);
      const response = await api.get(`/super-admin/organizations/${organizationId}/details`);
      setOrganization(response.data.organization);
      setError('');
    } catch (error) {
      console.error('Error fetching organization details:', error);
      setError('Failed to load organization details');
    } finally {
      setLoading(false);
    }
  };

  const toggleOrganizationStatus = async () => {
    try {
      await api.post(`/super-admin/organizations/${organizationId}/toggle-status`);
      await fetchOrganizationDetails(); // Refresh data
      setError('');
    } catch (error) {
      console.error('Error toggling organization status:', error);
      setError('Failed to update organization status');
    }
  };

  const searchUsers = async (query) => {
    if (query.length < 2) {
      setSearchResults([]);
      return;
    }

    try {
      setSearchLoading(true);
      const response = await api.get(`/super-admin/users/search?q=${encodeURIComponent(query)}&organization_id=${organizationId}`);
      setSearchResults(response.data.users);
    } catch (error) {
      console.error('Error searching users:', error);
      setSearchResults([]);
    } finally {
      setSearchLoading(false);
    }
  };

  const addMember = async (userId) => {
    try {
      await api.post(`/super-admin/organizations/${organizationId}/members`, {
        user_id: userId,
        role: selectedRole
      });
      await fetchOrganizationDetails(); // Refresh data
      setShowAddMember(false);
      setSearchQuery('');
      setSearchResults([]);
      setError('');
    } catch (error) {
      console.error('Error adding member:', error);
      setError(error.response?.data?.error || 'Failed to add member');
    }
  };

  const removeMember = async (userId) => {
    if (!confirm('Are you sure you want to remove this member from the organization?')) {
      return;
    }

    try {
      await api.delete(`/super-admin/organizations/${organizationId}/members/${userId}`);
      await fetchOrganizationDetails(); // Refresh data
      setError('');
    } catch (error) {
      console.error('Error removing member:', error);
      setError(error.response?.data?.error || 'Failed to remove member');
    }
  };

  const updateMemberRole = async (userId, newRole) => {
    try {
      await api.put(`/super-admin/organizations/${organizationId}/members/${userId}/role`, {
        role: newRole
      });
      await fetchOrganizationDetails(); // Refresh data
      setError('');
    } catch (error) {
      console.error('Error updating member role:', error);
      setError(error.response?.data?.error || 'Failed to update member role');
    }
  };

  useEffect(() => {
    const timeoutId = setTimeout(() => {
      if (searchQuery) {
        searchUsers(searchQuery);
      }
    }, 300);

    return () => clearTimeout(timeoutId);
  }, [searchQuery]);

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto"></div>
          <p className="mt-4 text-gray-600">Loading organization details...</p>
        </div>
      </div>
    );
  }

  if (!organization) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center">
          <p className="text-gray-600">Organization not found</p>
          <button
            onClick={onBack}
            className="mt-4 px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700"
          >
            Go Back
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50 p-6">
      {/* Header */}
      <div className="mb-8">
        <button
          onClick={onBack}
          className="flex items-center text-blue-600 hover:text-blue-800 mb-4"
        >
          <ArrowLeft className="h-4 w-4 mr-2" />
          Back to Organizations
        </button>
        
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-bold text-gray-900 flex items-center">
              {organization.name}
              <span className={`ml-3 inline-flex px-3 py-1 text-sm font-semibold rounded-full ${
                organization.is_active 
                  ? 'bg-green-100 text-green-800' 
                  : 'bg-red-100 text-red-800'
              }`}>
                {organization.is_active ? 'Active' : 'Inactive'}
              </span>
            </h1>
            <p className="text-gray-600 mt-2">{organization.description}</p>
            <p className="text-sm text-gray-500 mt-1">
              Created: {new Date(organization.created_at).toLocaleDateString()}
            </p>
          </div>
          
          <div className="flex space-x-3">
            <button
              onClick={() => setShowAddMember(true)}
              className="flex items-center px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 transition-colors"
            >
              <UserPlus className="h-4 w-4 mr-2" />
              Add Member
            </button>
            <button
              onClick={toggleOrganizationStatus}
              className={`px-4 py-2 rounded-md transition-colors ${
                organization.is_active
                  ? 'bg-red-600 text-white hover:bg-red-700'
                  : 'bg-green-600 text-white hover:bg-green-700'
              }`}
            >
              {organization.is_active ? 'Disable' : 'Enable'} Organization
            </button>
          </div>
        </div>
      </div>

      {/* Error Display */}
      {error && (
        <div className="mb-6 bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded">
          {error}
        </div>
      )}

      {/* Organization Stats */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
        <div className="bg-white p-6 rounded-lg shadow">
          <div className="flex items-center">
            <Users className="h-8 w-8 text-blue-600" />
            <div className="ml-4">
              <h3 className="text-lg font-medium text-gray-900">Total Members</h3>
              <p className="text-3xl font-bold text-blue-600">{organization.member_count}</p>
            </div>
          </div>
        </div>
        
        <div className="bg-white p-6 rounded-lg shadow">
          <div className="flex items-center">
            <Shield className="h-8 w-8 text-purple-600" />
            <div className="ml-4">
              <h3 className="text-lg font-medium text-gray-900">Admins</h3>
              <p className="text-3xl font-bold text-purple-600">
                {organization.members.filter(m => m.role === 'ORG_ADMIN').length}
              </p>
            </div>
          </div>
        </div>
        
        <div className="bg-white p-6 rounded-lg shadow">
          <div className="flex items-center">
            <Users className="h-8 w-8 text-green-600" />
            <div className="ml-4">
              <h3 className="text-lg font-medium text-gray-900">Regular Users</h3>
              <p className="text-3xl font-bold text-green-600">
                {organization.members.filter(m => m.role === 'USER').length}
              </p>
            </div>
          </div>
        </div>
      </div>

      {/* Members List */}
      <div className="bg-white rounded-lg shadow">
        <div className="px-6 py-4 border-b border-gray-200">
          <h3 className="text-lg font-medium text-gray-900">Organization Members</h3>
          <p className="text-sm text-gray-500">Manage users in this organization</p>
        </div>
        
        <div className="p-6">
          {organization.members.length === 0 ? (
            <div className="text-center py-8">
              <Users className="h-12 w-12 text-gray-400 mx-auto mb-4" />
              <h3 className="text-lg font-medium text-gray-900 mb-2">No members yet</h3>
              <p className="text-gray-500 mb-4">Add users to this organization to get started.</p>
              <button
                onClick={() => setShowAddMember(true)}
                className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700"
              >
                Add First Member
              </button>
            </div>
          ) : (
            <div className="space-y-4">
              {organization.members.map((member) => (
                <div key={member.id} className="border border-gray-200 rounded-lg p-4">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center space-x-4">
                      <div className="bg-blue-100 rounded-full p-3">
                        <Users className="h-5 w-5 text-blue-600" />
                      </div>
                      <div>
                        <h4 className="text-lg font-medium text-gray-900">
                          {member.first_name} {member.last_name}
                        </h4>
                        <p className="text-sm text-gray-500">@{member.username}</p>
                        <p className="text-sm text-gray-500">{member.email}</p>
                        <div className="flex items-center space-x-2 mt-1">
                          <span className={`inline-flex px-2 py-1 text-xs font-semibold rounded-full ${
                            member.role === 'ORG_ADMIN' 
                              ? 'bg-purple-100 text-purple-800' 
                              : 'bg-blue-100 text-blue-800'
                          }`}>
                            {member.role === 'ORG_ADMIN' ? 'Admin' : 'User'}
                          </span>
                          <span className={`inline-flex px-2 py-1 text-xs font-semibold rounded-full ${
                            member.is_active 
                              ? 'bg-green-100 text-green-800' 
                              : 'bg-red-100 text-red-800'
                          }`}>
                            {member.is_active ? 'Active' : 'Inactive'}
                          </span>
                          <span className="text-xs text-gray-400">
                            Joined: {new Date(member.joined_at).toLocaleDateString()}
                          </span>
                        </div>
                      </div>
                    </div>
                    
                    <div className="flex items-center space-x-2">
                      <select
                        value={member.role}
                        onChange={(e) => updateMemberRole(member.id, e.target.value)}
                        className="px-3 py-1 border border-gray-300 rounded text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                      >
                        <option value="USER">User</option>
                        <option value="ORG_ADMIN">Admin</option>
                      </select>
                      <button
                        onClick={() => removeMember(member.id)}
                        className="p-2 text-red-600 hover:bg-red-50 rounded transition-colors"
                        title="Remove member"
                      >
                        <UserMinus className="h-4 w-4" />
                      </button>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* Add Member Modal */}
      {showAddMember && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-lg max-w-md w-full">
            <div className="px-6 py-4 border-b border-gray-200">
              <h3 className="text-lg font-medium text-gray-900">Add Member to Organization</h3>
            </div>
            
            <div className="p-6 space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Search Users
                </label>
                <div className="relative">
                  <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
                  <input
                    type="text"
                    value={searchQuery}
                    onChange={(e) => setSearchQuery(e.target.value)}
                    placeholder="Search by name, username, or email..."
                    className="w-full pl-10 pr-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                  />
                </div>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Role
                </label>
                <select
                  value={selectedRole}
                  onChange={(e) => setSelectedRole(e.target.value)}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                >
                  <option value="USER">User</option>
                  <option value="ORG_ADMIN">Admin</option>
                </select>
              </div>

              {/* Search Results */}
              {searchLoading && (
                <div className="text-center py-4">
                  <div className="animate-spin rounded-full h-6 w-6 border-b-2 border-blue-600 mx-auto"></div>
                  <p className="text-sm text-gray-600 mt-2">Searching...</p>
                </div>
              )}

              {searchResults.length > 0 && (
                <div className="max-h-64 overflow-y-auto border border-gray-200 rounded-md">
                  {searchResults.map((user) => (
                    <div
                      key={user.id}
                      className="p-3 border-b border-gray-100 last:border-b-0 hover:bg-gray-50 cursor-pointer"
                      onClick={() => addMember(user.id)}
                    >
                      <div className="flex items-center justify-between">
                        <div>
                          <p className="font-medium text-gray-900">{user.full_name}</p>
                          <p className="text-sm text-gray-500">@{user.username}</p>
                          <p className="text-sm text-gray-500">{user.email}</p>
                        </div>
                        <UserPlus className="h-4 w-4 text-blue-600" />
                      </div>
                    </div>
                  ))}
                </div>
              )}

              {searchQuery.length >= 2 && !searchLoading && searchResults.length === 0 && (
                <p className="text-center text-gray-500 py-4">No users found</p>
              )}
            </div>
            
            <div className="px-6 py-4 border-t border-gray-200 flex space-x-3">
              <button
                onClick={() => {
                  setShowAddMember(false);
                  setSearchQuery('');
                  setSearchResults([]);
                }}
                className="flex-1 px-4 py-2 bg-gray-200 text-gray-800 rounded-md hover:bg-gray-300 transition-colors"
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default OrganizationDetails;