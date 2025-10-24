# Multi-Organization Implementation Guide

## Overview

This implementation transforms the Score platform from a single-organization system to a comprehensive multi-organization platform where:

- Users can be members of multiple organizations with different roles
- Users can request to join organizations
- Organization admins can approve/reject join requests
- Users can register independently and then join organizations
- Complete role-based access control across organizations

## Key Features Implemented

### 🏢 **Multi-Organization Support**
- Users are no longer tied to a single organization
- Global user accounts with organization-specific memberships
- Organization switching functionality
- Role isolation per organization

### 📝 **Join Request System**
- Users can request to join any organization
- Admins receive join requests with user details
- Approve/reject workflow with messages
- Role assignment during approval

### 👥 **Enhanced User Management**
- Global user registration (no organization required)
- Organization creation by users
- User can be admin in one org and regular user in another
- Comprehensive user profiles

### 🔐 **Advanced Authentication**
- JWT tokens with organization context
- Organization switching without re-login
- Role-based access per organization
- Secure token verification

## Database Schema Changes

### New Tables Created

#### `users` (Updated)
- Removed `organization_id` constraint
- Global users not tied to specific organizations
- Enhanced profile fields

#### `user_organizations` (New)
- Many-to-many relationship between users and organizations
- Role per organization (USER, ORG_ADMIN, SUPER_ADMIN)
- Department and title fields
- Active status per membership

#### `organization_join_requests` (New)
- User requests to join organizations
- Requested role and message
- Approval workflow (PENDING, APPROVED, REJECTED)
- Review tracking

#### `organization_invitations` (New)
- Admin invitations to users
- Token-based invitation system
- Expiration handling
- Acceptance tracking

## API Endpoints

### Authentication Endpoints

```
POST /api/auth/register
- Register new user (no organization required)

POST /api/auth/login
- Login with username/password
- Optional organization context

POST /api/auth/create-organization
- Create new organization and become admin

POST /api/auth/request-join-organization
- Request to join an organization

POST /api/auth/switch-organization
- Switch active organization context

GET /api/auth/organizations
- List available organizations

POST /api/auth/verify
- Verify JWT token and get user info
```

### Organization Management Endpoints

```
GET /api/auth/organizations/{org_id}/join-requests
- Get pending join requests (admin only)

POST /api/auth/organizations/{org_id}/join-requests/{req_id}/approve
- Approve join request (admin only)

POST /api/auth/organizations/{org_id}/join-requests/{req_id}/reject
- Reject join request (admin only)
```

## Frontend Implementation

### Updated Components

#### `App_multi_org.jsx`
- Enhanced authentication flow
- Organization setup for new users
- Multi-organization context management

#### `JoinRequestsManagement.jsx`
- Complete join request management interface
- Approve/reject workflow
- User details and role assignment

### Key Features

1. **Registration Flow**
   - Simple user registration
   - Organization creation or join request

2. **Login Flow**
   - Global user login
   - Organization selection if multiple memberships

3. **Admin Dashboard**
   - Join request management
   - Organization member management
   - Role-based access control

4. **User Dashboard**
   - Organization switching
   - Join request status
   - Multi-organization view

## User Workflows

### New User Registration
1. User registers with username, email, password
2. User can either:
   - Create a new organization (becomes admin)
   - Request to join existing organization
3. If joining existing org, admin must approve request

### Join Organization Process
1. User searches for organization by name
2. User submits join request with message
3. Organization admin receives notification
4. Admin reviews request and approves/rejects
5. If approved, user becomes member with assigned role

### Organization Admin Workflow
1. Admin logs in and sees pending join requests
2. Admin reviews user details and request message
3. Admin assigns role, department, and title
4. Admin approves or rejects with optional message
5. User is notified of decision

## Security Considerations

### Role-Based Access Control
- Strict role checking per organization
- JWT tokens include organization context
- Admin actions limited to their organizations

### Data Isolation
- Users only see data from their organizations
- Scores and groups isolated by organization
- Join requests visible only to relevant admins

### Token Management
- Organization context in JWT tokens
- Secure token switching
- Proper token validation

## Migration Strategy

### From Current System
1. Run new schema creation script
2. Execute migration script to move existing data
3. Update backend to use new models
4. Deploy new frontend with multi-org support
5. Verify all existing functionality works

### Database Migration Steps
```sql
-- 1. Create new schema tables
\i schema_multi_org.sql

-- 2. Migrate existing data
\i migration_to_multi_org.sql

-- 3. Verify migration
SELECT * FROM user_organization_details;
```

## Testing Scenarios

### Test Cases to Verify

1. **User Registration**
   - New user registration works
   - User can create organization
   - User can request to join organization

2. **Join Request Flow**
   - User can submit join request
   - Admin can see pending requests
   - Admin can approve/reject requests
   - User gets proper role assignment

3. **Multi-Organization Access**
   - User can switch between organizations
   - Roles are properly isolated
   - Data access is organization-specific

4. **Admin Functions**
   - Only admins can see join requests
   - Role assignment works correctly
   - User management functions properly

## Future Enhancements

### Planned Features
- Email notifications for join requests
- Organization invitation system via email
- Bulk user management
- Organization settings and branding
- Advanced role hierarchies
- Organization analytics

### API Extensions
- Invitation management endpoints
- Bulk operations APIs
- Organization statistics APIs
- User activity tracking
- Advanced search and filtering

## Deployment Notes

### Environment Variables
```
DATABASE_URL=postgresql://user:pass@host:port/db
JWT_SECRET_KEY=your-secret-key
SECRET_KEY=your-flask-secret-key
```

### Database Requirements
- PostgreSQL with UUID support
- Proper indexing for performance
- Regular backup strategy

### Security Recommendations
- Use strong JWT secret keys
- Implement rate limiting
- Monitor for suspicious activities
- Regular security audits

This implementation provides a robust foundation for multi-organization functionality while maintaining backward compatibility and ensuring data security.