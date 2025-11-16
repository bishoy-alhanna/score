# Backend Profile Update Fix

## File to Update
`backend/user-service/user-service/src/routes/users.py`

## Current Code (Lines 251-280)

```python
@users_bp.route('/profile', methods=['PUT'])
def update_profile():
    """Update current user's profile"""
    try:
        user, error, status_code = verify_token_and_get_user()
        if error:
            return jsonify(error), status_code
        
        data = request.get_json()
        
        # Update allowed fields
        if 'first_name' in data:
            user.first_name = data['first_name']
        if 'last_name' in data:
            user.last_name = data['last_name']
        if 'department' in data:
            user.department = data['department']
        
        db.session.commit()
        
        return jsonify({
            'message': 'Profile updated successfully',
            'user': user.to_dict()
        }), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500
```

**Problem:** Only updates 3 fields, but frontend sends 30+ fields!

---

## Updated Code (Replace with this)

```python
@users_bp.route('/profile', methods=['PUT'])
def update_profile():
    """Update current user's profile"""
    try:
        user, error, status_code = verify_token_and_get_user()
        if error:
            return jsonify(error), status_code
        
        data = request.get_json()
        
        # Basic Personal Information
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
            # Validate GPA range
            try:
                gpa_value = float(data['gpa'])
                if 0.0 <= gpa_value <= 4.0:
                    user.gpa = gpa_value
            except (ValueError, TypeError):
                pass  # Invalid GPA, skip
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
        
        # Emergency Contact Information
        if 'emergency_contact_name' in data:
            user.emergency_contact_name = data['emergency_contact_name']
        if 'emergency_contact_phone' in data:
            user.emergency_contact_phone = data['emergency_contact_phone']
        if 'emergency_contact_relationship' in data:
            user.emergency_contact_relationship = data['emergency_contact_relationship']
        
        # Social Media & Links
        if 'linkedin_url' in data:
            user.linkedin_url = data['linkedin_url']
        if 'github_url' in data:
            user.github_url = data['github_url']
        if 'personal_website' in data:
            user.personal_website = data['personal_website']
        
        # User Preferences
        if 'timezone' in data:
            user.timezone = data['timezone']
        if 'language' in data:
            user.language = data['language']
        if 'notification_preferences' in data:
            user.notification_preferences = data['notification_preferences']
        
        db.session.commit()
        
        return jsonify({
            'message': 'Profile updated successfully',
            'user': user.to_dict()
        }), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500
```

---

## How to Apply the Fix

### Option 1: Manual Edit

1. Open the file:
   ```bash
   nano backend/user-service/user-service/src/routes/users.py
   ```

2. Find the `update_profile()` function (around line 251)

3. Replace the entire function with the updated code above

4. Save and exit

### Option 2: Using This Script

Save this as `fix-profile-update.sh`:

```bash
#!/bin/bash

# Backup the original file
cp backend/user-service/user-service/src/routes/users.py \
   backend/user-service/user-service/src/routes/users.py.backup

echo "Backup created: backend/user-service/user-service/src/routes/users.py.backup"
echo ""
echo "Please manually update the update_profile() function"
echo "See BACKEND_PROFILE_UPDATE_FIX.md for the code"
```

### After Making the Change

1. **Rebuild the user-service container:**
   ```bash
   docker-compose build user-service
   ```

2. **Restart the container:**
   ```bash
   docker-compose up -d user-service
   ```

3. **Test the changes:**
   - Go to user dashboard
   - Edit your profile (add academic info, contact info, etc.)
   - Click "Save Changes"
   - Refresh the page
   - Verify all fields are saved

---

## Testing Checklist

After applying the fix, test these profile sections:

### Personal Information
- [ ] First Name
- [ ] Last Name
- [ ] Birthdate
- [ ] Gender
- [ ] Phone Number
- [ ] Bio

### Academic Information
- [ ] University Name
- [ ] Faculty Name
- [ ] School Year
- [ ] Student ID
- [ ] Major
- [ ] GPA
- [ ] Graduation Year

### Contact Information
- [ ] Address Line 1
- [ ] Address Line 2
- [ ] City
- [ ] State/Province
- [ ] Postal Code
- [ ] Country

### Emergency Contact
- [ ] Emergency Contact Name
- [ ] Emergency Contact Phone
- [ ] Emergency Contact Relationship

### Social Links
- [ ] LinkedIn URL
- [ ] GitHub URL
- [ ] Personal Website

### Preferences
- [ ] Timezone
- [ ] Language

---

## What Changed

**Before:**
- Only 3 fields updated: first_name, last_name, department
- 27+ fields sent by frontend were ignored

**After:**
- All 30+ profile fields are now properly saved
- Added GPA validation (0.0 - 4.0 range)
- All user profile sections work correctly

---

## Impact

✅ **Users can now:**
- Save their complete academic information
- Save their complete contact information
- Save emergency contact details
- Save social media links
- Change their preferences (timezone, language)
- See their saved data persist after page refresh

❌ **Before this fix:**
- Only name changes were saved
- All other profile changes were lost
- Users would be frustrated filling out forms that didn't work

---

## Additional Notes

### Department Field
The `department` field is being removed from this endpoint because it should be managed through the `user_organizations` table, not the users table. User-organization relationships (role, department, title) are separate from personal profile information.

### Email Updates
Email is not updated through the profile endpoint for security reasons. Email changes should go through a separate verification process.

### Profile Picture
Profile picture updates are handled by a separate upload endpoint and are not included in this profile update.

---

**Created:** November 16, 2025  
**Priority:** HIGH - Users cannot save profile data without this fix  
**Effort:** 5 minutes to copy/paste the code  
**Impact:** Makes the entire user profile feature actually work
