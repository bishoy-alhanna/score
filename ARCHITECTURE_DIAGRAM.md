# Family Management Feature - Architecture Diagram

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Frontend (React)                             │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │          OrganizationDetails Component                       │  │
│  │  ┌────────────┐  ┌──────────────────────────────────────┐   │  │
│  │  │  Members   │  │  Families (FamilyManagement)         │   │  │
│  │  │    Tab     │  │  - List Families                     │   │  │
│  │  └────────────┘  │  - Create Family                     │   │  │
│  │                  │  - Add/Remove Members                │   │  │
│  │                  │  - Search by National ID             │   │  │
│  │                  └──────────────────────────────────────┘   │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                       │
└───────────────────────────────┬─────────────────────────────────────┘
                                │ REST API Calls
                                │ (JWT Auth)
┌───────────────────────────────┴─────────────────────────────────────┐
│                         Backend (Flask)                              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │              Family Routes (/api/families)                    │  │
│  │  - POST /families (Create)                                    │  │
│  │  - GET /families (List with pagination)                       │  │
│  │  - GET /families/{id} (Get details)                           │  │
│  │  - PUT /families/{id} (Update)                                │  │
│  │  - DELETE /families/{id} (Soft delete)                        │  │
│  │  - POST /families/{id}/members (Add/Link member)              │  │
│  │  - DELETE /families/{id}/members/{id} (Remove member)         │  │
│  │  - GET /families/search-by-national-id (Search)               │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                │                                     │
│                                │ SQLAlchemy ORM                      │
└────────────────────────────────┴─────────────────────────────────────┘
                                │
┌───────────────────────────────┴─────────────────────────────────────┐
│                     Database (PostgreSQL)                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  ┌──────────────────┐           ┌──────────────────────────────┐   │
│  │  Organizations   │           │          Families            │   │
│  │  - id (UUID)     │           │  - id (UUID)                 │   │
│  │  - name          │◄──────────│  - family_name               │   │
│  │  - is_active     │           │  - head_of_family_id (FK)    │   │
│  └──────────────────┘           │  - organization_id (FK)      │   │
│                                  │  - contact_info (JSON)       │   │
│                                  │  - is_active                 │   │
│                                  └──────────────┬───────────────┘   │
│                                                 │                    │
│  ┌──────────────────────────────────────────────┘                   │
│  │                                                                   │
│  │  ┌──────────────────────────────────────────────────────────┐   │
│  │  │                        Users                              │   │
│  │  │  - id (UUID)                                              │   │
│  │  │  - username, email, password_hash                         │   │
│  │  │  - first_name, last_name                                  │   │
│  │  │  - national_id (Unique) ◄─── NEW FIELD                   │   │
│  │  │  - church_role         ◄─── NEW FIELD                    │   │
│  │  │  - family_id (FK)      ◄─── NEW FIELD                    │   │
│  │  │  - organization relationships                             │   │
│  │  │  - birthdate, gender, phone, etc.                         │   │
│  │  └──────────────────────────────────────────────────────────┘   │
│  │                                                                   │
│  └───────────────────────────────────────────────────────────────┘ │
│                                                                       │
└─────────────────────────────────────────────────────────────────────┘
```

## Data Flow: Adding a Family Member

```
┌─────────────┐
│    Admin    │
│  Dashboard  │
└──────┬──────┘
       │ 1. Enter National ID
       │
       ▼
┌─────────────────────┐
│  Search by          │
│  National ID        │
└──────┬──────────────┘
       │
       │ 2. API Call: GET /families/search-by-national-id
       │
       ▼
┌─────────────────────┐
│   Backend checks    │
│   if user exists    │
└──────┬──────────────┘
       │
       ├─────────────┐
       │             │
       │ Found       │ Not Found
       │             │
       ▼             ▼
┌──────────────┐  ┌──────────────┐
│ Show user    │  │ Show new     │
│ details      │  │ member form  │
│ (read-only)  │  │ (editable)   │
└──────┬───────┘  └──────┬───────┘
       │                 │
       │ 3. Admin confirms
       │                 │
       ▼                 ▼
┌─────────────────────────────────┐
│ POST /families/{id}/members     │
└────────────┬────────────────────┘
             │
             ├─────────────┐
             │             │
     Existing User    New User
             │             │
             ▼             ▼
┌────────────────┐  ┌──────────────┐
│ Link to family │  │ Create user  │
│ family_id = X  │  │ + Link       │
└────────────────┘  │ Return temp  │
                    │ password     │
                    └──────────────┘
             │
             ▼
┌────────────────────────┐
│   Success Message      │
│   Family updated       │
└────────────────────────┘
```

## Key Relationships

```
Organization
    │
    ├── Has Many ──► Families
    │                   │
    │                   └── Has Many ──► Users (via family_id)
    │
    └── Has Many ──► Users (via UserOrganization)
                         │
                         └── May Belong To ──► Family (via family_id)
```

## Security Layers

```
┌────────────────────────────────┐
│   1. JWT Authentication        │  ◄── All requests must have valid token
└────────────────┬───────────────┘
                 │
┌────────────────▼───────────────┐
│   2. Role Authorization        │  ◄── Only ORG_ADMIN or SUPER_ADMIN
└────────────────┬───────────────┘
                 │
┌────────────────▼───────────────┐
│   3. Organization Scope        │  ◄── Can only access own org's data
└────────────────┬───────────────┘
                 │
┌────────────────▼───────────────┐
│   4. Input Validation          │  ◄── Validate all inputs
└────────────────┬───────────────┘
                 │
┌────────────────▼───────────────┐
│   5. Database Constraints      │  ◄── Enforce data integrity
└────────────────────────────────┘
```

## State Management (Frontend)

```
FamilyManagement Component
    │
    ├── families (array)          ◄── List of all families
    ├── loading (boolean)         ◄── Loading state
    ├── error (string)            ◄── Error messages
    ├── searchTerm (string)       ◄── Search input
    ├── selectedFamily (object)   ◄── Currently selected family
    ├── showFamilyDialog (bool)   ◄── Show create dialog
    ├── showMemberDialog (bool)   ◄── Show add member dialog
    ├── nationalIdSearch (string) ◄── National ID search input
    ├── existingMember (object)   ◄── Found member data
    ├── successMessage (string)   ◄── Success feedback
    ├── deleteConfirm (object)    ◄── Confirmation dialog state
    ├── familyForm (object)       ◄── Family form data
    └── memberForm (object)       ◄── Member form data
```

## API Response Flow

```
Request with JWT
    │
    ▼
┌─────────────────┐
│ Verify Token    │
└────────┬────────┘
         │ Valid
         ▼
┌─────────────────┐
│ Check Role      │
└────────┬────────┘
         │ Authorized
         ▼
┌─────────────────┐
│ Validate Input  │
└────────┬────────┘
         │ Valid
         ▼
┌─────────────────┐
│ Execute Query   │
└────────┬────────┘
         │ Success
         ▼
┌─────────────────┐
│ Format Response │
└────────┬────────┘
         │
         ▼
    JSON Response
```

## Backward Compatibility Strategy

```
Existing Users (Before Feature)
    │
    ├── national_id: NULL    ◄── Optional field
    ├── church_role: NULL    ◄── Optional field
    └── family_id: NULL      ◄── Optional field
    
    All existing functionality continues to work!
    
New Users (After Feature)
    │
    ├── national_id: "123"   ◄── Can be set
    ├── church_role: "Elder" ◄── Can be set
    └── family_id: UUID      ◄── Can be linked to family
    
    Plus all existing fields and functionality!
```
