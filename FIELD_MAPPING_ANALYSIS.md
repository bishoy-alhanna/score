# Database Schema vs Frontend Fields Comparison

## Summary
This document compares the fields expected by the Admin Dashboard and User Dashboard with the actual database schema to ensure compatibility.

---

## Database Schema (from `init_database.sql`)

### Users Table - All Available Fields

```sql
CREATE TABLE users (
    -- Core Identity
    id UUID PRIMARY KEY
    username VARCHAR(255) UNIQUE NOT NULL
    email VARCHAR(255) UNIQUE NOT NULL
    password_hash VARCHAR(255) NOT NULL
    
    -- Basic Personal Info
    first_name VARCHAR(255)
    last_name VARCHAR(255)
    profile_picture_url VARCHAR(500)
    
    -- Personal Information
    birthdate DATE
    phone_number VARCHAR(20)
    bio TEXT
    gender VARCHAR(20)
    
    -- Academic Information
    school_year VARCHAR(50)
    student_id VARCHAR(50)
    major VARCHAR(100)
    gpa FLOAT
    graduation_year INTEGER
    university_name VARCHAR(255)
    faculty_name VARCHAR(255)
    
    -- Contact Information
    address_line1 VARCHAR(255)
    address_line2 VARCHAR(255)
    city VARCHAR(100)
    state VARCHAR(50)
    postal_code VARCHAR(20)
    country VARCHAR(100)
    
    -- Emergency Contact
    emergency_contact_name VARCHAR(255)
    emergency_contact_phone VARCHAR(20)
    emergency_contact_relationship VARCHAR(50)
    
    -- Social Media & Links
    linkedin_url VARCHAR(500)
    github_url VARCHAR(500)
    personal_website VARCHAR(500)
    
    -- Preferences
    timezone VARCHAR(50) DEFAULT 'UTC'
    language VARCHAR(10) DEFAULT 'en'
    notification_preferences JSON
    
    -- System fields
    is_active BOOLEAN DEFAULT TRUE
    is_verified BOOLEAN DEFAULT FALSE
    email_verified_at TIMESTAMP WITH TIME ZONE
    last_login_at TIMESTAMP WITH TIME ZONE
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
    
    -- QR Code fields
    qr_code_token VARCHAR(255) UNIQUE
    qr_code_generated_at TIMESTAMP WITH TIME ZONE
    qr_code_expires_at TIMESTAMP WITH TIME ZONE
)
```

**Total Database Fields: 40+ fields**

---

## Admin Dashboard Fields

### User Registration/Invite Form
Located in: `frontend/admin-dashboard/admin-dashboard/src/App.jsx`

**Fields Used:**
- ✅ `username` - MATCHES DB
- ✅ `email` - MATCHES DB
- ✅ `password` - Converted to `password_hash` in backend
- ✅ `first_name` - MATCHES DB
- ✅ `last_name` - MATCHES DB
- ✅ `role` - Stored in `user_organizations` table, not users table

### User Edit Form
Located in: `frontend/admin-dashboard/admin-dashboard/src/App.jsx`

**Fields Used:**
- ✅ `username` - MATCHES DB
- ✅ `email` - MATCHES DB
- ✅ `first_name` - MATCHES DB
- ✅ `last_name` - MATCHES DB
- ✅ `is_active` - MATCHES DB

### User Profile Display (Leaderboard Management)
Located in: `frontend/admin-dashboard/admin-dashboard/src/App.jsx` (Line ~2739)

**Fields Displayed:**
- ✅ `username` - MATCHES DB
- ⚠️ `role` - From `user_organizations`, not users table
- ⚠️ `department` - NOT in users table (should be in user_organizations)
- ⚠️ `title` - NOT in users table (should be in user_organizations)
- ✅ `phone_number` - MATCHES DB (but called `phone` in display)
- ✅ `city` - MATCHES DB
- ✅ `major` - MATCHES DB
- ⚠️ `joined_at` - From `user_organizations`, not users table

### User Profiles Export Fields
Located in: `frontend/admin-dashboard/admin-dashboard/src/App.jsx` (Line ~2069)

**Available Export Fields:**
- ✅ `first_name` - MATCHES DB
- ✅ `last_name` - MATCHES DB
- ✅ `email` - MATCHES DB
- ✅ `username` - MATCHES DB
- ✅ `phone_number` - MATCHES DB
- ✅ `birthdate` - MATCHES DB
- ✅ `gender` - MATCHES DB
- ✅ `bio` - MATCHES DB
- ✅ `student_id` - MATCHES DB
- ✅ `school_year` - MATCHES DB
- ✅ `major` - MATCHES DB
- ✅ `gpa` - MATCHES DB
- ✅ `graduation_year` - MATCHES DB
- ✅ `university_name` - MATCHES DB
- ✅ `faculty_name` - MATCHES DB
- ✅ `address_line1` - MATCHES DB
- ✅ `address_line2` - MATCHES DB
- ✅ `city` - MATCHES DB
- ✅ `state` - MATCHES DB
- ✅ `postal_code` - MATCHES DB
- ✅ `country` - MATCHES DB
- ✅ `linkedin_url` - MATCHES DB
- ✅ `github_url` - MATCHES DB
- ✅ `personal_website` - MATCHES DB

**Admin Dashboard Status: ✅ MOSTLY COMPATIBLE**
- All user table fields are correctly mapped
- Issue: `department` and `title` are shown but not in users table (they're in user_organizations)

---

## User Dashboard Fields

### User Registration Form
Located in: `frontend/user-dashboard/user-dashboard/src/App.jsx`

**Fields Used:**
- ✅ `first_name` - MATCHES DB
- ✅ `last_name` - MATCHES DB
- ✅ `username` - MATCHES DB
- ✅ `email` - MATCHES DB
- ✅ `password` - Converted to `password_hash` in backend
- ✅ `organization_name` - For organization lookup (not stored in users)

### User Profile Component (Full Profile Management)
Located in: `frontend/user-dashboard/user-dashboard/src/components/UserProfile.jsx`

**Personal Information Tab:**
- ✅ `first_name` - MATCHES DB
- ✅ `last_name` - MATCHES DB
- ✅ `birthdate` - MATCHES DB
- ✅ `gender` - MATCHES DB
- ✅ `email` - MATCHES DB (read-only)
- ✅ `phone_number` - MATCHES DB
- ✅ `bio` - MATCHES DB

**Academic Information Tab:**
- ✅ `university_name` - MATCHES DB
- ✅ `faculty_name` - MATCHES DB
- ✅ `school_year` - MATCHES DB
- ✅ `student_id` - MATCHES DB
- ✅ `major` - MATCHES DB
- ✅ `gpa` - MATCHES DB
- ✅ `graduation_year` - MATCHES DB

**Contact Information Tab:**
- ✅ `address_line1` - MATCHES DB
- ✅ `address_line2` - MATCHES DB
- ✅ `city` - MATCHES DB
- ✅ `state` - MATCHES DB
- ✅ `postal_code` - MATCHES DB
- ✅ `country` - MATCHES DB

**Emergency Contact:**
- ✅ `emergency_contact_name` - MATCHES DB
- ✅ `emergency_contact_phone` - MATCHES DB
- ✅ `emergency_contact_relationship` - MATCHES DB

**Social Links Tab:**
- ✅ `linkedin_url` - MATCHES DB
- ✅ `github_url` - MATCHES DB
- ✅ `personal_website` - MATCHES DB

**Preferences Tab:**
- ✅ `timezone` - MATCHES DB
- ✅ `language` - MATCHES DB

**Profile Picture:**
- ✅ `profile_picture_url` - MATCHES DB (handled via upload endpoint)

**User Dashboard Status: ✅ FULLY COMPATIBLE**
- All fields used by the user dashboard match the database schema perfectly

---

## Backend API Field Handling

### Auth Service - User Registration
Located in: `backend/auth-service/auth-service/src/routes/auth_multi_org.py`

**Required Fields:**
- ✅ `username`
- ✅ `email`
- ✅ `password`
- ✅ `first_name`
- ✅ `last_name`

**Created Fields:**
- All above fields are used when creating a new user
- Password is hashed before storage

### Auth Service - User Update
Located in: `backend/auth-service/auth-service/src/routes/auth_multi_org.py` (Line ~618)

**Updatable Fields:**
- ✅ `first_name`
- ✅ `last_name`

### User Service - Profile Update
Located in: `backend/user-service/user-service/src/routes/users.py` (Line ~262)

**Updatable Fields:**
- ✅ `first_name`
- ✅ `last_name`
- ⚠️ **MISSING:** Most profile fields are NOT handled in the backend update endpoint!

---

## Issues Found

### ❌ **CRITICAL ISSUE: Backend API Limited Field Support**

The backend user service only updates `first_name` and `last_name`, but the frontend sends many more fields:

**Frontend Sends (from UserProfile.jsx):**
- Personal: birthdate, phone_number, bio, gender
- Academic: university_name, faculty_name, school_year, student_id, major, gpa, graduation_year
- Contact: address_line1, address_line2, city, state, postal_code, country
- Emergency: emergency_contact_name, emergency_contact_phone, emergency_contact_relationship
- Social: linkedin_url, github_url, personal_website
- Preferences: timezone, language

**Backend Actually Updates (from users.py):**
- ✅ first_name
- ✅ last_name
- ❌ All other fields are IGNORED!

### ⚠️ **ISSUE: Department and Title Fields**

Admin dashboard displays `department` and `title` from user profiles, but these fields:
- Are NOT in the users table
- Should be in `user_organizations` table
- Currently may be NULL or missing

---

## Recommendations

### 1. **Update User Service Backend** (HIGH PRIORITY)

File: `backend/user-service/user-service/src/routes/users.py`

The profile update endpoint needs to handle ALL profile fields that the frontend can send:

```python
@users_bp.route('/profile', methods=['PUT'])
def update_profile():
    """Update current user's profile"""
    user, error, status_code = verify_token_and_get_user()
    if error:
        return jsonify(error), status_code
    
    data = request.get_json()
    
    # Basic Personal Info
    if 'first_name' in data:
        user.first_name = data['first_name']
    if 'last_name' in data:
        user.last_name = data['last_name']
    if 'birthdate' in data:
        user.birthdate = data['birthdate']
    if 'phone_number' in data:
        user.phone_number = data['phone_number']
    if 'bio' in data:
        user.bio = data['bio']
    if 'gender' in data:
        user.gender = data['gender']
    
    # Academic Information
    if 'university_name' in data:
        user.university_name = data['university_name']
    if 'faculty_name' in data:
        user.faculty_name = data['faculty_name']
    if 'school_year' in data:
        user.school_year = data['school_year']
    if 'student_id' in data:
        user.student_id = data['student_id']
    if 'major' in data:
        user.major = data['major']
    if 'gpa' in data:
        user.gpa = data['gpa']
    if 'graduation_year' in data:
        user.graduation_year = data['graduation_year']
    
    # Contact Information
    if 'address_line1' in data:
        user.address_line1 = data['address_line1']
    if 'address_line2' in data:
        user.address_line2 = data['address_line2']
    if 'city' in data:
        user.city = data['city']
    if 'state' in data:
        user.state = data['state']
    if 'postal_code' in data:
        user.postal_code = data['postal_code']
    if 'country' in data:
        user.country = data['country']
    
    # Emergency Contact
    if 'emergency_contact_name' in data:
        user.emergency_contact_name = data['emergency_contact_name']
    if 'emergency_contact_phone' in data:
        user.emergency_contact_phone = data['emergency_contact_phone']
    if 'emergency_contact_relationship' in data:
        user.emergency_contact_relationship = data['emergency_contact_relationship']
    
    # Social Links
    if 'linkedin_url' in data:
        user.linkedin_url = data['linkedin_url']
    if 'github_url' in data:
        user.github_url = data['github_url']
    if 'personal_website' in data:
        user.personal_website = data['personal_website']
    
    # Preferences
    if 'timezone' in data:
        user.timezone = data['timezone']
    if 'language' in data:
        user.language = data['language']
    
    db.session.commit()
    
    return jsonify({
        'message': 'Profile updated successfully',
        'user': user.to_dict()
    }), 200
```

### 2. **Fix Department and Title Display** (MEDIUM PRIORITY)

Admin dashboard should fetch these from `user_organizations` table, not users table.

### 3. **Add Field Validation** (MEDIUM PRIORITY)

Add validation for:
- Email format
- Phone number format
- URL formats (linkedin, github, personal website)
- Date formats (birthdate)
- GPA range (0.0 - 4.0)

### 4. **Frontend Field Consistency** (LOW PRIORITY)

Ensure all frontends use consistent field names:
- Use `phone_number` (not `phone`)
- Use snake_case consistently for API calls

---

## Field Mapping Summary

| Category | Frontend Field | DB Column | Status |
|----------|---------------|-----------|---------|
| **Core Identity** | | | |
| | username | username | ✅ Match |
| | email | email | ✅ Match |
| | password | password_hash | ✅ Match (converted) |
| **Basic Info** | | | |
| | first_name | first_name | ✅ Match |
| | last_name | last_name | ✅ Match |
| | birthdate | birthdate | ✅ Match |
| | gender | gender | ✅ Match |
| | phone_number | phone_number | ✅ Match |
| | bio | bio | ✅ Match |
| | profile_picture_url | profile_picture_url | ✅ Match |
| **Academic** | | | |
| | university_name | university_name | ✅ Match |
| | faculty_name | faculty_name | ✅ Match |
| | school_year | school_year | ✅ Match |
| | student_id | student_id | ✅ Match |
| | major | major | ✅ Match |
| | gpa | gpa | ✅ Match |
| | graduation_year | graduation_year | ✅ Match |
| **Contact** | | | |
| | address_line1 | address_line1 | ✅ Match |
| | address_line2 | address_line2 | ✅ Match |
| | city | city | ✅ Match |
| | state | state | ✅ Match |
| | postal_code | postal_code | ✅ Match |
| | country | country | ✅ Match |
| **Emergency** | | | |
| | emergency_contact_name | emergency_contact_name | ✅ Match |
| | emergency_contact_phone | emergency_contact_phone | ✅ Match |
| | emergency_contact_relationship | emergency_contact_relationship | ✅ Match |
| **Social** | | | |
| | linkedin_url | linkedin_url | ✅ Match |
| | github_url | github_url | ✅ Match |
| | personal_website | personal_website | ✅ Match |
| **Preferences** | | | |
| | timezone | timezone | ✅ Match |
| | language | language | ✅ Match |
| **System** | | | |
| | is_active | is_active | ✅ Match |
| | is_verified | is_verified | ✅ Match |
| **Organization** | | | |
| | role | user_organizations.role | ⚠️ Different table |
| | department | user_organizations.department | ⚠️ Different table |
| | title | user_organizations.title | ⚠️ Different table |

---

## Conclusion

✅ **Database Schema:** Complete with all 40+ fields  
✅ **User Dashboard Frontend:** Fully compatible with DB schema  
✅ **Admin Dashboard Frontend:** Mostly compatible (minor org fields issue)  
❌ **Backend API:** **INCOMPLETE - Only updates 2 fields instead of 30+**

**Action Required:** Update the backend user service to handle all profile fields that the frontend can send.

---

**Generated:** November 16, 2025  
**Version:** 1.0
