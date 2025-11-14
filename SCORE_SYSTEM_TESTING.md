# Score System Testing Guide

## 🔍 Test Results Summary

### Schema Fixes Applied ✅
- Fixed `score_categories` table to include `max_score`, `created_by`, and `is_predefined` columns
- Fixed `scores` table: renamed `points` → `score_value`, added `group_id` support, added `category` field
- Fixed `score_aggregates` table: renamed `total_points` → `total_score`, added `score_count`, `average_score`, `group_id` support
- Removed `scored_at` column (using `created_at` instead)
- Added CHECK constraints to ensure either `user_id` OR `group_id` is set (not both)

### Demo Data Included ✅
- 3 organizations (Tech University, Business School, Arts Academy)
- 9 demo users (3 admins, 6 regular users)
- 10 score categories across all organizations
- 8 sample scores for testing
- All passwords: `password123`

---

## 📊 Test Cases

### 1. Database Schema Test

**Test**: Verify all tables exist with correct schema

```bash
# SSH to production server
ssh root@escore.al-hanna.com

# Run the reset script
cd /root/score
./scripts/reset-database.sh
# Type: DELETE ALL DATA

# Verify tables
docker exec saas_postgres psql -U postgres -d saas_platform -c "\dt"
```

**Expected Result**: Should show all tables including:
- organizations
- users
- user_organizations
- groups
- score_categories
- scores
- score_aggregates

**Check Scores Table Schema**:
```bash
docker exec saas_postgres psql -U postgres -d saas_platform -c "\d scores"
```

**Expected Columns**:
- id (UUID)
- user_id (UUID, nullable)
- group_id (UUID, nullable)
- organization_id (UUID, not null)
- category_id (UUID, nullable)
- category (VARCHAR, default 'general')
- score_value (INTEGER, not null)
- description (TEXT)
- assigned_by (UUID)
- created_at (TIMESTAMP)
- updated_at (TIMESTAMP)

---

### 2. Authentication Tests

**Test 2.1**: Login with Admin User

```bash
curl -X POST https://escore.al-hanna.com/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin",
    "password": "password123"
  }' | jq
```

**Expected Result**:
```json
{
  "message": "Login successful",
  "token": "eyJ...",
  "user": {
    "id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
    "username": "admin",
    "email": "admin@score.com",
    "organization_id": "11111111-1111-1111-1111-111111111111",
    "role": "ORG_ADMIN"
  }
}
```

**Test 2.2**: Login with Regular User

```bash
curl -X POST https://escore.al-hanna.com/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "john.doe",
    "password": "password123"
  }' | jq
```

**Expected Result**: Should return token and user object with role "USER"

---

### 3. Score Categories Tests

**Test 3.1**: Get Score Categories

```bash
# Get the token first
TOKEN=$(curl -s -X POST https://escore.al-hanna.com/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"password123"}' | jq -r '.token')

# Get categories
curl -X GET "https://escore.al-hanna.com/api/scores/categories" \
  -H "Authorization: Bearer $TOKEN" | jq
```

**Expected Result**:
```json
{
  "categories": [
    {
      "id": "cat11111-1111-1111-1111-111111111111",
      "name": "Attendance",
      "description": "Attendance points",
      "max_score": 100,
      "organization_id": "11111111-1111-1111-1111-111111111111",
      "is_predefined": true,
      "is_active": true
    },
    ...
  ]
}
```

**Test 3.2**: Create New Category (Admin Only)

```bash
TOKEN=$(curl -s -X POST https://escore.al-hanna.com/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"john.admin","password":"password123"}' | jq -r '.token')

curl -X POST https://escore.al-hanna.com/api/scores/categories \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test Category",
    "description": "Testing category creation",
    "max_score": 50
  }' | jq
```

**Expected Result**:
```json
{
  "message": "Score category created successfully",
  "category": {
    "id": "...",
    "name": "Test Category",
    "max_score": 50,
    ...
  }
}
```

**Test 3.3**: Try to Delete Predefined Category (Should Fail)

```bash
curl -X DELETE "https://escore.al-hanna.com/api/scores/categories/cat11111-1111-1111-1111-111111111111" \
  -H "Authorization: Bearer $TOKEN" | jq
```

**Expected Result**:
```json
{
  "error": "Cannot delete predefined categories"
}
```

---

### 4. Assign Score Tests

**Test 4.1**: Admin Assigns Score to User

```bash
# Login as admin
TOKEN=$(curl -s -X POST https://escore.al-hanna.com/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"john.admin","password":"password123"}' | jq -r '.token')

# Assign score
curl -X POST https://escore.al-hanna.com/api/scores \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "dddddddd-dddd-dddd-dddd-dddddddddddd",
    "category_id": "cat11111-1111-1111-1111-111111111111",
    "score_value": 75,
    "description": "Test score assignment"
  }' | jq
```

**Expected Result**:
```json
{
  "message": "Score assigned successfully",
  "score": {
    "id": "...",
    "user_id": "dddddddd-dddd-dddd-dddd-dddddddddddd",
    "score_value": 75,
    "category_name": "Attendance",
    ...
  }
}
```

**Test 4.2**: Regular User Tries to Assign Score (Should Fail)

```bash
# Login as regular user
TOKEN=$(curl -s -X POST https://escore.al-hanna.com/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"john.doe","password":"password123"}' | jq -r '.token')

# Try to assign score
curl -X POST https://escore.al-hanna.com/api/scores \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee",
    "category_id": "cat11111-1111-1111-1111-111111111111",
    "score_value": 75
  }' | jq
```

**Expected Result**:
```json
{
  "error": "Only organization admins can assign scores"
}
```

**Test 4.3**: Score Exceeds Max (Should Fail)

```bash
TOKEN=$(curl -s -X POST https://escore.al-hanna.com/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"john.admin","password":"password123"}' | jq -r '.token')

curl -X POST https://escore.al-hanna.com/api/scores \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "dddddddd-dddd-dddd-dddd-dddddddddddd",
    "category_id": "cat11111-1111-1111-1111-111111111111",
    "score_value": 150
  }' | jq
```

**Expected Result**:
```json
{
  "error": "Score value cannot exceed maximum of 100 for this category"
}
```

---

### 5. Get Scores Tests

**Test 5.1**: Get All Scores for User

```bash
TOKEN=$(curl -s -X POST https://escore.al-hanna.com/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"john.doe","password":"password123"}' | jq -r '.token')

curl -X GET "https://escore.al-hanna.com/api/scores?user_id=dddddddd-dddd-dddd-dddd-dddddddddddd" \
  -H "Authorization: Bearer $TOKEN" | jq
```

**Expected Result**:
```json
{
  "scores": [
    {
      "id": "...",
      "user_id": "dddddddd-dddd-dddd-dddd-dddddddddddd",
      "score_value": 85,
      "category_name": "Attendance",
      "description": "Great attendance record",
      ...
    },
    {
      "id": "...",
      "score_value": 90,
      "category_name": "Participation",
      ...
    }
  ],
  "total": 2,
  "page": 1,
  "per_page": 20
}
```

**Test 5.2**: Get User Total Score

```bash
curl -X GET "https://escore.al-hanna.com/api/scores/user/dddddddd-dddd-dddd-dddd-dddddddddddd/total" \
  -H "Authorization: Bearer $TOKEN" | jq
```

**Expected Result**:
```json
{
  "user_id": "dddddddd-dddd-dddd-dddd-dddddddddddd",
  "total_score": 175,
  "score_count": 2,
  "average_score": 87.5
}
```

---

### 6. Leaderboard Tests

**Test 6.1**: Get User Leaderboard

```bash
TOKEN=$(curl -s -X POST https://escore.al-hanna.com/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"john.doe","password":"password123"}' | jq -r '.token')

curl -X GET "https://escore.al-hanna.com/api/leaderboards/users" \
  -H "Authorization: Bearer $TOKEN" | jq
```

**Expected Result**:
```json
{
  "leaderboard": [
    {
      "rank": 1,
      "user_id": "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee",
      "username": "jane.smith",
      "total_score": 183,
      "score_count": 2
    },
    {
      "rank": 2,
      "user_id": "dddddddd-dddd-dddd-dddd-dddddddddddd",
      "username": "john.doe",
      "total_score": 175,
      "score_count": 2
    }
  ]
}
```

**Test 6.2**: Get User Rank

```bash
curl -X GET "https://escore.al-hanna.com/api/leaderboards/user/dddddddd-dddd-dddd-dddd-dddddddddddd/rank" \
  -H "Authorization: Bearer $TOKEN" | jq
```

**Expected Result**:
```json
{
  "user_id": "dddddddd-dddd-dddd-dddd-dddddddddddd",
  "rank": 2,
  "total_score": 175,
  "percentile": 50.0
}
```

---

### 7. Update Score Tests

**Test 7.1**: Admin Updates Score

```bash
TOKEN=$(curl -s -X POST https://escore.al-hanna.com/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"john.admin","password":"password123"}' | jq -r '.token')

# Get score ID first
SCORE_ID=$(curl -s -X GET "https://escore.al-hanna.com/api/scores?user_id=dddddddd-dddd-dddd-dddd-dddddddddddd" \
  -H "Authorization: Bearer $TOKEN" | jq -r '.scores[0].id')

# Update the score
curl -X PUT "https://escore.al-hanna.com/api/scores/$SCORE_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "score_value": 95,
    "description": "Updated score"
  }' | jq
```

**Expected Result**:
```json
{
  "message": "Score updated successfully",
  "score": {
    "id": "...",
    "score_value": 95,
    "description": "Updated score",
    ...
  }
}
```

---

### 8. Delete Score Tests

**Test 8.1**: Admin Deletes Score

```bash
TOKEN=$(curl -s -X POST https://escore.al-hanna.com/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"john.admin","password":"password123"}' | jq -r '.token')

SCORE_ID=$(curl -s -X GET "https://escore.al-hanna.com/api/scores?user_id=dddddddd-dddd-dddd-dddd-dddddddddddd" \
  -H "Authorization: Bearer $TOKEN" | jq -r '.scores[0].id')

curl -X DELETE "https://escore.al-hanna.com/api/scores/$SCORE_ID" \
  -H "Authorization: Bearer $TOKEN" | jq
```

**Expected Result**:
```json
{
  "message": "Score deleted successfully"
}
```

---

## 🐛 Common Issues & Solutions

### Issue 1: "database saas_platform already exists"
**Solution**: Use the updated `reset-database.sh` script which terminates connections before dropping

### Issue 2: Column `score_value` does not exist
**Solution**: Database needs to be reset with new schema. Run `./scripts/reset-database.sh`

### Issue 3: "Only organization admins can assign scores"
**Solution**: Make sure you're logged in as an admin user (john.admin, sarah.admin, or admin)

### Issue 4: Token expired or invalid
**Solution**: Get a new token using the login endpoint

### Issue 5: Foreign key violation when assigning scores
**Solution**: Ensure user_id and category_id exist in their respective tables

---

## 🎯 Success Criteria

✅ All tests pass without errors
✅ Admins can create/update/delete scores
✅ Users can view their own scores
✅ Leaderboards show correct rankings
✅ Score categories work correctly
✅ Max score validation works
✅ Role-based permissions enforced

---

## 📝 Test Credentials

| Username | Password | Role | Organization |
|----------|----------|------|--------------|
| admin | password123 | ORG_ADMIN | Tech University |
| john.admin | password123 | ORG_ADMIN | Tech University |
| sarah.admin | password123 | ORG_ADMIN | Business School |
| john.doe | password123 | USER | Tech University |
| jane.smith | password123 | USER | Tech University |
| bob.wilson | password123 | USER | Business School |

---

## 🔄 Reset Database

If you need to start fresh:

```bash
cd /root/score
./scripts/reset-database.sh
# Type: DELETE ALL DATA
```

This will:
1. Drop the existing database
2. Create a new database
3. Load schema and demo data
4. Create all demo users and scores
