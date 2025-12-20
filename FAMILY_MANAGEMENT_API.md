# Family Management API Documentation

## Overview
The Family Management API allows administrators to create and manage families within an organization, add family members, and link existing users to families using their National ID.

## Base URL
All endpoints are prefixed with `/api/families`

## Authentication
All endpoints require a valid JWT token in the Authorization header:
```
Authorization: Bearer <token>
```

## Endpoints

### 1. Create Family
**POST** `/api/families`

Create a new family in an organization.

**Required Permission:** ORG_ADMIN or SUPER_ADMIN

**Request Body:**
```json
{
  "organization_id": "uuid",
  "family_name": "Smith Family",
  "head_of_family_id": "uuid (optional)",
  "contact_info": {
    "phone": "+1234567890",
    "email": "smith@example.com"
  }
}
```

**Response (201):**
```json
{
  "message": "Family created successfully",
  "family": {
    "id": "uuid",
    "family_name": "Smith Family",
    "head_of_family_id": "uuid",
    "head_of_family_name": "John Smith",
    "contact_info": { ... },
    "organization_id": "uuid",
    "is_active": true,
    "created_at": "2024-01-01T00:00:00",
    "updated_at": "2024-01-01T00:00:00",
    "member_count": 0
  }
}
```

### 2. List Families
**GET** `/api/families`

Get a list of all families in an organization.

**Query Parameters:**
- `organization_id` (required): UUID of the organization
- `page` (optional): Page number (default: 1)
- `per_page` (optional): Results per page (default: 20, max: 100)
- `search` (optional): Search term for family name
- `include_members` (optional): Include member details (default: false)

**Response (200):**
```json
{
  "families": [
    {
      "id": "uuid",
      "family_name": "Smith Family",
      "head_of_family_id": "uuid",
      "head_of_family_name": "John Smith",
      "contact_info": { ... },
      "organization_id": "uuid",
      "is_active": true,
      "created_at": "2024-01-01T00:00:00",
      "updated_at": "2024-01-01T00:00:00",
      "member_count": 3,
      "members": [...]  // If include_members=true
    }
  ],
  "pagination": {
    "page": 1,
    "per_page": 20,
    "total": 50,
    "pages": 3,
    "has_next": true,
    "has_prev": false
  }
}
```

### 3. Get Family Details
**GET** `/api/families/{family_id}`

Get details of a specific family.

**Query Parameters:**
- `organization_id` (required): UUID of the organization
- `include_members` (optional): Include member details (default: true)

**Response (200):**
```json
{
  "id": "uuid",
  "family_name": "Smith Family",
  "head_of_family_id": "uuid",
  "head_of_family_name": "John Smith",
  "contact_info": {
    "phone": "+1234567890",
    "email": "smith@example.com"
  },
  "organization_id": "uuid",
  "is_active": true,
  "created_at": "2024-01-01T00:00:00",
  "updated_at": "2024-01-01T00:00:00",
  "member_count": 3,
  "members": [
    {
      "id": "uuid",
      "username": "jsmith",
      "first_name": "John",
      "last_name": "Smith",
      "email": "john@example.com",
      "national_id": "123456789",
      "church_role": "Elder",
      "gender": "Male",
      "birthdate": "1980-01-01",
      "phone_number": "+1234567890",
      "is_active": true
    }
  ]
}
```

### 4. Update Family
**PUT** `/api/families/{family_id}`

Update family details.

**Required Permission:** ORG_ADMIN or SUPER_ADMIN

**Request Body:**
```json
{
  "organization_id": "uuid",
  "family_name": "Updated Family Name",
  "head_of_family_id": "uuid",
  "contact_info": {
    "phone": "+9876543210",
    "email": "updated@example.com"
  }
}
```

**Response (200):**
```json
{
  "message": "Family updated successfully",
  "family": { ... }
}
```

### 5. Add Family Member
**POST** `/api/families/{family_id}/members`

Add a new member to a family or link an existing member by National ID.

**Required Permission:** ORG_ADMIN or SUPER_ADMIN

**Behavior:**
- If `national_id` is provided and exists in the system, the existing user will be linked to the family
- If `national_id` is not found or not provided, a new user will be created
- Newly created users receive a temporary password

**Request Body:**
```json
{
  "organization_id": "uuid",
  "national_id": "123456789",
  "first_name": "Jane",
  "last_name": "Smith",
  "email": "jane@example.com",
  "gender": "Female",
  "birthdate": "1985-05-15",
  "phone_number": "+1234567890",
  "church_role": "Member",
  "username": "janesmith"  // Optional, auto-generated if not provided
}
```

**Response (200 or 201):**
```json
{
  "message": "Existing member linked to family successfully",
  "member": { ... },
  "linked_existing": true
}
```

Or for new members:
```json
{
  "message": "New family member created successfully",
  "member": { ... },
  "linked_existing": false,
  "temporary_password": "generated-password"
}
```

### 6. Remove Family Member
**DELETE** `/api/families/{family_id}/members/{member_id}`

Remove a member from a family (unlinks only, does not delete the user).

**Required Permission:** ORG_ADMIN or SUPER_ADMIN

**Query Parameters:**
- `organization_id` (required): UUID of the organization

**Response (200):**
```json
{
  "message": "Member removed from family successfully"
}
```

### 7. Delete Family
**DELETE** `/api/families/{family_id}`

Soft delete a family (marks as inactive and unlinks all members).

**Required Permission:** ORG_ADMIN or SUPER_ADMIN

**Query Parameters:**
- `organization_id` (required): UUID of the organization

**Response (200):**
```json
{
  "message": "Family deleted successfully"
}
```

### 8. Search by National ID
**GET** `/api/families/search-by-national-id`

Search for a user by their National ID.

**Required Permission:** ORG_ADMIN or SUPER_ADMIN

**Query Parameters:**
- `national_id` (required): National ID to search for
- `organization_id` (required): UUID of the organization

**Response (200):**

If user found:
```json
{
  "found": true,
  "user": {
    "id": "uuid",
    "username": "jsmith",
    "first_name": "John",
    "last_name": "Smith",
    "email": "john@example.com",
    "national_id": "123456789",
    "church_role": "Elder",
    ...
  },
  "has_family": true,
  "family_id": "uuid"
}
```

If user not found:
```json
{
  "found": false,
  "message": "No user found with this national ID"
}
```

## Database Models

### Family Model
- `id`: UUID (Primary Key)
- `family_name`: String(255) (Required)
- `head_of_family_id`: UUID (Foreign Key to User, Optional)
- `contact_info`: JSON (Optional)
- `organization_id`: UUID (Foreign Key to Organization, Required)
- `is_active`: Boolean (Default: true)
- `created_at`: DateTime
- `updated_at`: DateTime

### User Model - New Fields
- `national_id`: String(50), Unique (Optional) - Unique identifier for family member linking
- `church_role`: String(100) (Optional) - Role in the church (e.g., Member, Deacon, Elder)
- `family_id`: UUID (Foreign Key to Family, Optional)

## Error Responses

**400 Bad Request:**
```json
{
  "error": "Family name is required"
}
```

**401 Unauthorized:**
```json
{
  "error": "Authentication required"
}
```

**403 Forbidden:**
```json
{
  "error": "Admin access required"
}
```

**404 Not Found:**
```json
{
  "error": "Family not found"
}
```

**500 Internal Server Error:**
```json
{
  "error": "Failed to create family"
}
```

## Backward Compatibility

All new fields are nullable to maintain backward compatibility:
- Existing users without `national_id`, `church_role`, or `family_id` will continue to work
- The system can operate without any families defined
- Existing API endpoints are not affected by these changes

## Security Considerations

1. **Authentication:** All endpoints require valid JWT authentication
2. **Authorization:** Only ORG_ADMIN and SUPER_ADMIN roles can manage families
3. **Data Isolation:** Families are scoped to organizations
4. **National ID Uniqueness:** National IDs are unique across the entire system
5. **Soft Delete:** Families are soft-deleted to preserve data integrity
