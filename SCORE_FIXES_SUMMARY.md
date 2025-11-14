# Score System Fixes - Complete Summary

## 🔧 Issues Fixed

### 1. Database Schema Mismatches ✅

**Problem**: The database schema (`init_database.sql`) didn't match the scoring service models

**Fixed Tables**:

#### `score_categories` Table
- ✅ Added `max_score INTEGER DEFAULT 100`
- ✅ Added `created_by UUID REFERENCES users(id)`
- ✅ Added `is_predefined BOOLEAN DEFAULT FALSE`
- ✅ Increased `name` field size from `VARCHAR(100)` to `VARCHAR(255)`

#### `scores` Table  
- ✅ Renamed `points` column to `score_value`
- ✅ Removed `scored_at` column (using `created_at` instead)
- ✅ Renamed `reason` to `description`
- ✅ Renamed `awarded_by` to `assigned_by`
- ✅ Added `group_id UUID` for group score support
- ✅ Added `category VARCHAR(255)` for backward compatibility
- ✅ Made `user_id` nullable (since groups can have scores too)
- ✅ Added CHECK constraint: either `user_id` OR `group_id` must be set (not both)
- ✅ Added `updated_at` column with trigger

#### `score_aggregates` Table
- ✅ Renamed `total_points` to `total_score`
- ✅ Added `score_count INTEGER DEFAULT 0`
- ✅ Added `average_score NUMERIC(10, 2) DEFAULT 0.0`
- ✅ Added `group_id UUID` for group aggregates
- ✅ Removed `category_id` foreign key
- ✅ Added `category VARCHAR(255)` string field instead
- ✅ Made `user_id` nullable
- ✅ Added CHECK constraint for user_id/group_id
- ✅ Updated UNIQUE constraints for new structure

### 2. Demo Data Added ✅

**Organizations** (3):
- Tech University (ID: 11111111-1111-1111-1111-111111111111)
- Business School (ID: 22222222-2222-2222-2222-222222222222)
- Arts Academy (ID: 33333333-3333-3333-3333-333333333333)

**Users** (9):
- 3 Admin users (admin, john.admin, sarah.admin)
- 6 Regular users (john.doe, jane.smith, bob.wilson, alice.brown, charlie.davis, emma.taylor)
- All passwords: `password123`

**Score Categories** (10):
- 5 for Tech University (Attendance, Participation, Leadership, Academic Excellence, Community Service)
- 3 for Business School (Attendance, Participation, Leadership)  
- 2 for Arts Academy (Attendance, Creative Works)

**Sample Scores** (8):
- 4 scores for Tech University users
- 2 scores for Business School users
- 2 scores for Arts Academy users

### 3. Scripts Updated ✅

#### `reset-database.sh`
- ✅ Now terminates all database connections before dropping
- ✅ Uses `-d postgres` when dropping/creating database
- ✅ Better error handling
- ✅ Shows step-by-step progress

#### `init_database.sql`
- ✅ Complete schema aligned with service models
- ✅ Includes demo data for immediate testing
- ✅ Triggers for `updated_at` on all tables
- ✅ Proper indexes for performance

---

## 📋 Files Modified

1. `/database/init_database.sql` - Complete rewrite with fixed schema
2. `/scripts/reset-database.sh` - Updated with better DB dropping logic
3. `/SCORE_SYSTEM_TESTING.md` - NEW: Comprehensive testing guide

---

## 🚀 How to Apply Fixes

### On Production Server:

```bash
# 1. SSH to server
ssh root@escore.al-hanna.com

# 2. Go to project directory
cd /root/score

# 3. Pull latest changes
git pull

# 4. Reset database with new schema
./scripts/reset-database.sh
# Type: DELETE ALL DATA when prompted

# 5. Restart services
docker-compose restart

# 6. Clear browser cache
# In browser console: localStorage.clear(); location.reload()
```

### Expected Output:

```
✅ Database reset successfully!

📊 Demo Users:
  Admin: admin / password123
  Users: john.doe, jane.smith, etc.

📝 Score Categories: 10 categories created
🎯 Sample Scores: 8 scores assigned
```

---

## ✅ Verification Steps

### 1. Test Authentication
```bash
curl -X POST https://escore.al-hanna.com/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"password123"}' | jq
```

### 2. Test Get Categories
```bash
TOKEN="<your-token-here>"
curl -X GET "https://escore.al-hanna.com/api/scores/categories" \
  -H "Authorization: Bearer $TOKEN" | jq
```

### 3. Test Get Scores
```bash
curl -X GET "https://escore.al-hanna.com/api/scores?user_id=dddddddd-dddd-dddd-dddd-dddddddddddd" \
  -H "Authorization: Bearer $TOKEN" | jq
```

### 4. Test Assign Score
```bash
curl -X POST https://escore.al-hanna.com/api/scores \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "dddddddd-dddd-dddd-dddd-dddddddddddd",
    "category_id": "cat11111-1111-1111-1111-111111111111",
    "score_value": 75,
    "description": "Test score"
  }' | jq
```

See `SCORE_SYSTEM_TESTING.md` for complete test suite.

---

## 🎯 What Works Now

✅ Database schema matches Python models exactly
✅ Score categories with max_score validation
✅ Score assignment to users and groups
✅ Predefined categories that can't be deleted
✅ Role-based permissions (ORG_ADMIN can assign scores)
✅ Score aggregates for leaderboards
✅ Demo data for immediate testing
✅ Complete test suite with examples

---

## 🔒 Security Notes

⚠️ **IMPORTANT**: Change all default passwords after testing!

Default password for ALL demo users: `password123`

Update passwords for production:
```sql
-- In production, update admin password
UPDATE users SET password_hash = crypt('YOUR_SECURE_PASSWORD', gen_salt('bf'))
WHERE username = 'admin';
```

---

## 📚 Documentation

- **Testing Guide**: `SCORE_SYSTEM_TESTING.md`
- **Production Guide**: `QUICK_START_PRODUCTION.md`
- **API Documentation**: `API_DOCUMENTATION.md`
- **Deployment**: `DEPLOYMENT.md`

---

## 🐛 Troubleshooting

### Problem: Can't assign scores
**Solution**: Make sure you're logged in as ORG_ADMIN role user

### Problem: Score exceeds max
**Solution**: Each category has a max_score (default 100)

### Problem: Can't delete category
**Solution**: Predefined categories (`is_predefined=true`) cannot be deleted

### Problem: Foreign key error
**Solution**: Ensure user_id and category_id exist before assigning scores

---

## 📞 Support

If issues persist after applying fixes:

1. Check Docker logs: `docker-compose logs -f scoring-service`
2. Check database: `docker exec saas_postgres psql -U postgres -d saas_platform`
3. Verify schema: `\d scores` and `\d score_categories`
4. Run full test suite from `SCORE_SYSTEM_TESTING.md`
