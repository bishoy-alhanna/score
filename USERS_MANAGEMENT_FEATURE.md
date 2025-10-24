# Users Management Feature Documentation

## Overview
The Admin Dashboard now includes comprehensive Users Management functionality available in both Organization Admin and Super Admin interfaces.

## Features Implemented

### 1. Organization Admin - Users Tab
- Added a new "Users" tab alongside the existing "Join Requests" tab
- Displays all users within the current organization
- Shows user status (Active/Inactive), role, and join date

### 2. Super Admin - Users Tab
- Added a new "All Users" tab in the Super Admin dashboard
- Displays all users across the entire platform
- Shows user organizations and roles across multiple organizations
- Cross-organization user management capabilities

### 3. User Management Functionality

#### Enable/Disable Users
- Toggle user status between Active and Inactive
- Visual indicators show current status (green for active, gray for inactive)
- Immediate status update with API call
- Available in both Organization Admin and Super Admin interfaces

#### Edit User Information (Organization Admin)
- Edit basic user information:
  - Username
  - Email address
  - First name
  - Last name
  - Active status
- Form validation to prevent duplicate usernames/emails
- Modal dialog interface for editing

#### Reset Password (Organization Admin)
- Admin can reset any user's password
- Minimum 6-character password requirement
- Secure password update through dedicated API endpoint
- Success notification upon completion

#### Change User Roles (Organization Admin)
- Dropdown selection for user roles:
  - User (basic access)
  - Org Admin (organization administrator)
  - Super Admin (system-wide administrator)
- Immediate role changes with API integration
- Role changes are organization-specific

#### Super Admin User Management
- View all users across all organizations
- See user's organization memberships and roles
- Activate/Deactivate users platform-wide
- View detailed user information
- Enhanced user cards showing organization relationships

### 4. Backend API Endpoints

#### Organization Admin Endpoints
```
GET /api/auth/organizations/{organization_id}/users
PUT /api/auth/users/{user_id}
PUT /api/auth/users/{user_id}/password
PUT /api/auth/organizations/{organization_id}/users/{user_id}/role
```

#### Super Admin Endpoints
```
GET /api/super-admin/users
PUT /api/super-admin/users/{user_id}
POST /api/super-admin/users/{user_id}/toggle-status
```

### 5. User Interface Enhancements

#### Organization Admin Interface
- Clean, intuitive tabbed interface (Join Requests | Users)
- Responsive design with card-based layout
- Color-coded status indicators
- Modal dialogs for editing operations
- Real-time status updates
- Error handling with user-friendly messages

#### Super Admin Interface
- Three-tab layout (Organizations | Pending Requests | All Users)
- Enhanced user cards showing cross-organization relationships
- Role badges with color coding (Super Admin: purple, Org Admin: blue, User: gray)
- Platform-wide user management capabilities
- User count in tab header
- Organization membership display for each user

### 6. Security Features
- All endpoints require valid JWT authentication
- Role-based access control (Organization Admin vs Super Admin)
- Organization-scoped permissions for regular admins
- Platform-wide permissions for super admins
- Input validation and sanitization
- Unique constraint validation for usernames and emails

## Usage Instructions

### Organization Admin Users Management
1. Log into the Admin Dashboard as an Organization Admin
2. Click on the "Users" tab
3. View all users in your organization with their current status and roles
4. **Edit User**: Click the "Edit" button to modify user information
5. **Reset Password**: Click "Reset Password" to set a new password
6. **Change Role**: Use the role dropdown to change user permissions
7. **Enable/Disable**: Click the "Enable" or "Disable" button to toggle user status

### Super Admin Users Management
1. Access the Super Admin Dashboard (Shield icon in top-left)
2. Click on the "All Users" tab
3. View all platform users with their organization memberships
4. **View Details**: Click "View Details" to see user information
5. **Activate/Deactivate**: Toggle user status across the entire platform
6. See user's role in each organization they belong to

### Role Permissions
- **User**: Basic access to the platform
- **Org Admin**: Can manage organization users and settings
- **Super Admin**: System-wide administrative access

## Technical Implementation
- Frontend: React with shadcn/ui components
- Backend: Flask with SQLAlchemy ORM
- Database: PostgreSQL with multi-organization support
- Authentication: JWT-based with role-based access control
- API: RESTful endpoints with proper error handling

## Multi-Level Access Control
- **Organization Admins**: Can only manage users within their organization
- **Super Admins**: Can manage all users across all organizations
- **Cross-Organization Visibility**: Super admins see user memberships across multiple organizations
- **Scoped Permissions**: Each interface respects appropriate access levels

This comprehensive user management system provides both organization-level and platform-level administration capabilities while maintaining proper security boundaries and user experience.