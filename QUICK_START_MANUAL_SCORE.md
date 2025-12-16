# Quick Start Guide - Group Manual Score Feature

## What's Been Implemented

✅ **Manual Score Field** - Added to groups table  
✅ **Set Manual Score Endpoint** - PUT `/groups/{id}/manual-score`  
✅ **Member Score Summation** - Automatically sums all member scores  
✅ **Combined Total** - Group score = manual_score + member_scores_sum + direct_scores  
✅ **Score Breakdown Endpoint** - GET `/scores/group/{id}/total` with detailed breakdown  
✅ **Recalculation Endpoint** - POST `/scores/group/{id}/recalculate`  

## Setup Instructions

### 1. Start the Services
```bash
cd /Users/bhanna/Projects/Score/score
docker-compose up -d
```

### 2. Apply Database Migration
```bash
./apply-manual-score-migration.sh
```

This will add the `manual_score` field to the groups table.

### 3. Restart Services (Optional but Recommended)
```bash
docker-compose restart group-service scoring-service
```

## Testing the Feature

### Step 1: Login as Admin
Get your admin token first.

### Step 2: Create or Get a Group
```bash
# Create a new group
curl -X POST http://localhost/api/groups \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test Team",
    "description": "Testing manual scores"
  }'
```

### Step 3: Add Members to the Group
```bash
curl -X POST http://localhost/api/groups/{GROUP_ID}/members \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "USER_ID_HERE"
  }'
```

### Step 4: Set Manual Score
```bash
curl -X PUT http://localhost/api/groups/{GROUP_ID}/manual-score \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "manual_score": 100
  }'
```

Expected response:
```json
{
  "message": "Manual score updated successfully",
  "group": {
    "id": "...",
    "name": "Test Team",
    "manual_score": 100,
    ...
  }
}
```

### Step 5: Assign Scores to Members
```bash
curl -X POST http://localhost/api/scores \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "MEMBER_USER_ID",
    "score_value": 50,
    "category": "general",
    "description": "Good work"
  }'
```

### Step 6: Check Group Total Score
```bash
curl -X GET "http://localhost/api/scores/group/{GROUP_ID}/total?category=general" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

Expected response:
```json
{
  "group_id": "...",
  "category": "general",
  "total_score": 150,
  "breakdown": {
    "direct_group_scores": 0,
    "manual_score": 100,
    "members_score_sum": 50
  },
  "score_count": 0,
  "average_score": 0
}
```

### Step 7: View in Leaderboard
The group leaderboard will now show the total score (manual + members):
```bash
curl -X GET "http://localhost/api/leaderboards/groups?category=general" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

## API Endpoints Summary

### Group Service (Port 5003)

#### Set Manual Score
- **Endpoint**: `PUT /groups/{group_id}/manual-score`
- **Auth**: ORG_ADMIN only
- **Body**: `{"manual_score": 100}`

### Scoring Service (Port 5004)

#### Get Group Total with Breakdown
- **Endpoint**: `GET /scores/group/{group_id}/total`
- **Query**: `?category=general` (optional)
- **Auth**: Any authenticated user
- **Response**: Includes breakdown of manual_score, member scores, and direct scores

#### Recalculate Group Scores
- **Endpoint**: `POST /scores/group/{group_id}/recalculate`
- **Query**: `?category=general` (optional)
- **Auth**: ORG_ADMIN only

## How Scoring Works

### Example Scenario:
1. **Group "Alpha Team"** is created
2. **Admin sets manual_score = 50**
3. **Three members join:**
   - Member A receives: 30 points
   - Member B receives: 20 points
   - Member C receives: 10 points
4. **Total Member Scores = 60**
5. **Group also receives direct score = 15**
6. **Total Group Score = 50 + 60 + 15 = 125**

### Score Calculation Formula:
```
Total Group Score = Manual Score + Sum(Member Scores) + Direct Group Scores
```

## Troubleshooting

### Migration Fails
If the migration script fails:
```bash
# Check if database is running
docker-compose ps postgres

# Apply manually
docker-compose exec postgres psql -U postgres -d saas_platform -f /path/to/add_manual_score_to_groups.sql
```

### Manual Score Not Showing
1. Check that migration was applied:
```bash
docker-compose exec postgres psql -U postgres -d saas_platform -c "\d groups"
```

2. Verify you're calling the right endpoint with ORG_ADMIN token

### Member Scores Not Summing
1. Ensure members are properly added to the group
2. Trigger recalculation:
```bash
curl -X POST http://localhost/api/scores/group/{GROUP_ID}/recalculate \
  -H "Authorization: Bearer YOUR_ADMIN_TOKEN"
```

## Development Notes

### Code Locations
- **Migration**: `database/add_manual_score_to_groups.sql`
- **Group Model**: `backend/group-service/group-service/src/models/database.py`
- **Group Routes**: `backend/group-service/group-service/src/routes/groups.py`
- **Scoring Logic**: `backend/scoring-service/scoring-service/src/routes/scores.py`

### Environment Variables
Make sure `GROUP_SERVICE_URL` is set in scoring-service:
```yaml
scoring-service:
  environment:
    - GROUP_SERVICE_URL=http://group-service:5003
```

## Next Steps

1. ✅ Apply the migration
2. ✅ Test the endpoints
3. 🔲 Add UI for setting manual scores in admin dashboard
4. 🔲 Display score breakdown in group details view
5. 🔲 Add validation/limits on manual score values
6. 🔲 Create audit log for manual score changes

## Support

For issues or questions:
1. Check the main documentation: `GROUP_SCORE_MANUAL_FEATURE.md`
2. Review the service logs:
   ```bash
   docker-compose logs group-service
   docker-compose logs scoring-service
   ```

## Summary

This feature gives you flexibility to:
- **Reward groups directly** via manual scores
- **Automatically aggregate** individual member contributions
- **Track everything** with detailed breakdowns
- **Keep it fair** with transparent calculations

Perfect for scenarios where groups need bonus points, team achievements, or manual adjustments while still tracking individual contributions! 🎯
