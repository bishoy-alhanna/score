# Testing the Group Member Score Aggregation Feature

## ✅ Status: Feature is NOW DEPLOYED and RUNNING!

The updated code has been deployed to the production containers:
- ✅ Group Service updated with `manual_score` field
- ✅ Scoring Service updated with member score aggregation logic
- ✅ Database migration applied
- ✅ All services healthy and running

## How It Works Now

**Total Group Score = Manual Score + Sum of All Member Scores + Direct Group Scores**

### Example:
- Group "فريق الخدمة" (ID: `7d800f80-95f3-4398-8c4a-ec410f095447`)
- Has 5 members
- Member "Kerosvictor" has 40 points total (20 in "التناول" + 20 in "القداس")
- When you query the group aggregate, it will include all member scores

## Quick Test Instructions

### 1. Login and Get Token
```bash
curl -X POST http://localhost/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "YOUR_ADMIN_USERNAME",
    "password": "YOUR_PASSWORD"
  }'
```

Save the token from the response.

### 2. Set Manual Score for Group
```bash
curl -X PUT "http://localhost/api/groups/7d800f80-95f3-4398-8c4a-ec410f095447/manual-score" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"manual_score": 100}'
```

### 3. Assign Score to a Member (to trigger aggregation)
```bash
curl -X POST http://localhost/api/scores \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "fd0444af-6d38-469f-8355-cb87f441eafa",
    "score_value": 30,
    "category": "general",
    "description": "Test score"
  }'
```

### 4. Check Group Total Score with Breakdown
```bash
curl -X GET "http://localhost/api/scores/group/7d800f80-95f3-4398-8c4a-ec410f095447/total?category=general" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

**Expected Response:**
```json
{
  "group_id": "7d800f80-95f3-4398-8c4a-ec410f095447",
  "category": "general",
  "total_score": 180,
  "breakdown": {
    "direct_group_scores": 50,
    "manual_score": 100,
    "members_score_sum": 30
  }
}
```

### 5. View in Leaderboard
```bash
curl -X GET "http://localhost/api/leaderboards/groups?category=general" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

The leaderboard will show the total combined score (manual + members + direct).

## What's Automatic

✅ **When a member receives a score**, the group's total is automatically recalculated  
✅ **When you set a manual score**, it's added to the group total  
✅ **When you query the group score**, you get a detailed breakdown  

## Testing from Admin Dashboard

If you're using the admin dashboard at `http://admin.escore.al-hanna.com`:

1. **Go to Groups section**
2. **Select "فريق الخدمة"**
3. **Assign scores to members**
4. **View group leaderboard** - you'll see the combined total!

## Database Verification

You can also check directly in the database:

```bash
# Check group manual score
docker exec -it score_postgres_prod psql -U postgres -d saas_platform -c \
  "SELECT id, name, manual_score FROM groups WHERE id = '7d800f80-95f3-4398-8c4a-ec410f095447';"

# Check member scores
docker exec -it score_postgres_prod psql -U postgres -d saas_platform -c \
  "SELECT u.username, SUM(s.score_value) as total_score 
   FROM scores s 
   JOIN users u ON s.user_id = u.id 
   WHERE s.user_id IN (SELECT user_id FROM group_members WHERE group_id = '7d800f80-95f3-4398-8c4a-ec410f095447')
   AND s.category = 'general'
   GROUP BY u.username;"

# Check group aggregate
docker exec -it score_postgres_prod psql -U postgres -d saas_platform -c \
  "SELECT * FROM score_aggregates WHERE group_id = '7d800f80-95f3-4398-8c4a-ec410f095447' AND category = 'general';"
```

## Features Now Working

✅ Set manual score for groups (admin only)  
✅ Automatic aggregation of all member scores  
✅ Detailed breakdown showing each component  
✅ Real-time updates when scores change  
✅ Works across all categories  
✅ Displays correctly in leaderboards  

## Notes

- **Manual scores** can be set using the `/groups/{id}/manual-score` endpoint
- **Member scores** are automatically summed when calculating group totals
- **Categories matter**: Scores are grouped by category ("general", "القداس", "التناول", etc.)
- **Organization isolation**: Groups only see scores within their organization

## Troubleshooting

If aggregates aren't updating:
```bash
# Manually trigger recalculation
curl -X POST "http://localhost/api/scores/group/7d800f80-95f3-4398-8c4a-ec410f095447/recalculate?category=general" \
  -H "Authorization: Bearer YOUR_ADMIN_TOKEN"
```

---

**The feature is LIVE and ready to use!** 🎉

Test it now and let me know if you see the member scores aggregating to the group total!
