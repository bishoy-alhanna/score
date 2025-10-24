# Multi-Organization API Documentation

## Base URL
- Development: `http://localhost:5000/api`
- Production: `/api`

## Authentication
All protected endpoints require a JWT token in the Authorization header:
```
Authorization: Bearer <token>
```

## Response Format
All responses follow this format:
```json
{
  "message": "Success message",
  "data": {...},
  "error": "Error message (if error)"
}
```

## Authentication Endpoints

### Register User
```http
POST /auth/register
Content-Type: application/json

{
  "username": "string",
  "email": "string", 
  "password": "string",
  "first_name": "string",
  "last_name": "string"
}
```

### Login
```http
POST /auth/login
Content-Type: application/json

{
  "username": "string",
  "password": "string"
}
```

### Verify Token
```http
POST /auth/verify
Authorization: Bearer <token>
```

### Create Organization
```http
POST /auth/create-organization
Authorization: Bearer <token>
Content-Type: application/json

{
  "name": "string",
  "description": "string"
}
```

### Request to Join Organization
```http
POST /auth/request-join-organization
Authorization: Bearer <token>
Content-Type: application/json

{
  "organization_name": "string",
  "requested_role": "USER",
  "message": "string"
}
```

### Switch Organization Context
```http
POST /auth/switch-organization
Authorization: Bearer <token>
Content-Type: application/json

{
  "organization_id": "uuid"
}
```

### List Organizations
```http
GET /auth/organizations
Authorization: Bearer <token> (optional)
```

## Organization Management Endpoints

### Get Join Requests
```http
GET /auth/organizations/{org_id}/join-requests
Authorization: Bearer <token>
```

### Approve Join Request
```http
POST /auth/organizations/{org_id}/join-requests/{request_id}/approve
Authorization: Bearer <token>
Content-Type: application/json

{
  "role": "USER"
}
```

### Reject Join Request
```http
POST /auth/organizations/{org_id}/join-requests/{request_id}/reject
Authorization: Bearer <token>
Content-Type: application/json

{
  "message": "string"
}
```

## Super Admin Endpoints

### Super Admin Login
```http
POST /super-admin/login
Content-Type: application/json

{
  "username": "superadmin",
  "password": "SuperAdmin123!"
}
```

### Super Admin Dashboard
```http
GET /super-admin/dashboard
Authorization: Bearer <super_admin_token>
```

### Get All Organizations
```http
GET /super-admin/organizations
Authorization: Bearer <super_admin_token>
```

### Toggle Organization Status
```http
POST /super-admin/organizations/{org_id}/toggle-status
Authorization: Bearer <super_admin_token>
```

### Get All Users
```http
GET /super-admin/users?page=1&per_page=50
Authorization: Bearer <super_admin_token>
```

### Toggle User Status
```http
POST /super-admin/users/{user_id}/toggle-status
Authorization: Bearer <super_admin_token>
```

### Get All Join Requests
```http
GET /super-admin/join-requests?status=PENDING&page=1&per_page=50
Authorization: Bearer <super_admin_token>
```

## Organization Endpoints

### Get Organization Details
```http
GET /organizations/
Authorization: Bearer <token>
```

### Update Organization
```http
PUT /organizations/
Authorization: Bearer <token>
Content-Type: application/json

{
  "name": "string",
  "description": "string"
}
```

### Get Organization Users
```http
GET /organizations/users
Authorization: Bearer <token>
```

### Get Organization Statistics
```http
GET /organizations/stats
Authorization: Bearer <token>
```

## Error Codes

| Code | Description |
|------|-------------|
| 400 | Bad Request - Invalid input data |
| 401 | Unauthorized - Invalid or missing token |
| 403 | Forbidden - Insufficient permissions |
| 404 | Not Found - Resource doesn't exist |
| 422 | Unprocessable Entity - Validation errors |
| 500 | Internal Server Error |

## Rate Limiting
- 100 requests per minute per IP address
- 1000 requests per hour per authenticated user

## Data Models

### User
```json
{
  "id": "uuid",
  "username": "string",
  "email": "string",
  "first_name": "string",
  "last_name": "string",
  "is_active": "boolean",
  "created_at": "iso_datetime",
  "organizations": [
    {
      "organization_id": "uuid",
      "organization_name": "string",
      "role": "USER|ORG_ADMIN|SUPER_ADMIN",
      "department": "string",
      "title": "string",
      "is_active": "boolean",
      "joined_at": "iso_datetime"
    }
  ]
}
```

### Organization
```json
{
  "id": "uuid",
  "name": "string",
  "description": "string",
  "is_active": "boolean",
  "created_at": "iso_datetime",
  "updated_at": "iso_datetime",
  "member_count": "integer"
}
```

### Join Request
```json
{
  "id": "uuid",
  "user_id": "uuid",
  "organization_id": "uuid",
  "requested_role": "string",
  "message": "string",
  "status": "PENDING|APPROVED|REJECTED",
  "reviewed_by": "uuid",
  "reviewed_at": "iso_datetime",
  "review_message": "string",
  "created_at": "iso_datetime",
  "user": {
    "username": "string",
    "email": "string",
    "first_name": "string",
    "last_name": "string"
  }
}
```

## JWT Token Structure

### Regular User Token
```json
{
  "user_id": "uuid",
  "username": "string",
  "organization_id": "uuid",
  "role": "USER|ORG_ADMIN",
  "exp": "timestamp",
  "iat": "timestamp"
}
```

### Super Admin Token
```json
{
  "admin_id": "uuid",
  "username": "superadmin",
  "type": "super_admin",
  "exp": "timestamp",
  "iat": "timestamp"
}
```