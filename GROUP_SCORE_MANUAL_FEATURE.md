# Group Score Feature - Manual + Members Sum

## Overview
Implemented a feature where group scores can be:
1. **Set manually** by organization admins
2. **Automatically calculated** as the sum of all member scores
3. **Combined** to show total group score = manual_score + sum(member_scores) + direct_group_scores

## Database Changes

### Schema Migration
**File**: `database/add_manual_score_to_groups.sql`

Added `manual_score` column to the `groups` table:
```sql
ALTER TABLE groups ADD COLUMN IF NOT EXISTS manual_score INTEGER DEFAULT 0;
CREATE INDEX IF NOT EXISTS idx_groups_manual_score ON groups(manual_score);
```

To apply the migration:
```bash
psql -U postgres -d score_db -f database/add_manual_score_to_groups.sql
```

## Backend Changes

### 1. Group Service Updates

#### Model Change (`backend/group-service/group-service/src/models/database.py`)
- Added `manual_score` field to `Group` model
- Updated `to_dict()` method to include `manual_score`

```python
manual_score = db.Column(db.Integer, default=0)
```

#### New Endpoint (`backend/group-service/group-service/src/routes/groups.py`)

**PUT** `/groups/<group_id>/manual-score`
- **Description**: Set manual score for a group
- **Authorization**: ORG_ADMIN only
- **Request Body**:
  ```json
  {
    "manual_score": 100
  }
  ```
- **Response**:
  ```json
  {
    "message": "Manual score updated successfully",
    "group": {
      "id": "...",
      "name": "Team Alpha",
      "manual_score": 100,
      ...
    }
  }
  ```

### 2. Scoring Service Updates

#### Helper Functions (`backend/scoring-service/scoring-service/src/routes/scores.py`)

1. **`get_group_manual_score(group_id)`**
   - Fetches manual score from group-service
   - Returns 0 if unavailable

2. **`calculate_group_members_score_sum(group_id, category, organization_id)`**
   - Fetches all members of the group
   - Calculates sum of scores for all members in the specified category
   - Returns total member scores

#### Updated Function: `update_score_aggregate()`
Modified to calculate group scores as:
```
Total Group Score = Direct Group Scores + Manual Score + Sum of Member Scores
```

**Logic**:
- Direct scores: Scores assigned directly to the group entity
- Manual score: Score set by admin via PUT endpoint
- Member scores: Sum of all individual member scores in the category

#### Enhanced Endpoint: `GET /scores/group/<group_id>/total`
Now includes detailed breakdown:

**Query Parameters**:
- `category` (optional, default: "general")

**Response**:
```json
{
  "group_id": "abc-123",
  "category": "general",
  "total_score": 350,
  "breakdown": {
    "direct_group_scores": 50,
    "manual_score": 100,
    "members_score_sum": 200
  },
  "score_count": 5,
  "average_score": 10
}
```

#### New Endpoint: `POST /scores/group/<group_id>/recalculate`
- **Description**: Manually trigger recalculation of group aggregates
- **Authorization**: ORG_ADMIN only
- **Query Parameters**: `category` (optional)
- **Response**: Updated aggregate data

## API Usage Examples

### 1. Set Manual Score for a Group
```bash
curl -X PUT http://localhost:5003/groups/{group_id}/manual-score \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{"manual_score": 150}'
```

### 2. Get Group Total Score with Breakdown
```bash
curl -X GET "http://localhost:5004/scores/group/{group_id}/total?category=general" \
  -H "Authorization: Bearer {token}"
```

### 3. Recalculate Group Scores
```bash
curl -X POST "http://localhost:5004/scores/group/{group_id}/recalculate?category=general" \
  -H "Authorization: Bearer {token}"
```

### 4. Assign Score to Individual Member (Automatically updates group)
```bash
curl -X POST http://localhost:5004/scores/ \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "member-123",
    "score_value": 50,
    "category": "general",
    "description": "Completed task"
  }'
```

## How It Works

### Score Calculation Flow

1. **Admin Sets Manual Score**
   - Admin calls PUT `/groups/{id}/manual-score` with score value
   - Score is stored in `groups.manual_score` field

2. **Members Receive Individual Scores**
   - When a member receives a score, it's stored in `scores` table
   - `update_score_aggregate()` is triggered for both user AND group

3. **Group Aggregate Calculation**
   - Fetches manual score from groups table
   - Queries all group members from group-service
   - Calculates sum of all member scores for the category
   - Adds direct group scores
   - Stores total in `score_aggregates` table

4. **Leaderboard Display**
   - Leaderboards use `score_aggregates` table
   - Group rankings based on `total_score` which includes:
     - Manual score set by admin
     - Sum of all member scores
     - Any direct scores assigned to group

## Benefits

1. **Flexibility**: Admins can manually boost or adjust group scores
2. **Automatic Calculation**: Member contributions automatically count toward group
3. **Transparency**: Breakdown shows where score comes from
4. **Real-time Updates**: Member scores immediately affect group totals
5. **Category Support**: Works with all score categories

## Testing

### Test Scenario 1: Manual Score Only
```
1. Create group "Team A"
2. Set manual_score = 100
3. Verify group total = 100
```

### Test Scenario 2: Member Scores Only
```
1. Create group "Team B"
2. Add 3 members
3. Assign scores: Member1=50, Member2=30, Member3=20
4. Verify group total = 100 (sum of member scores)
```

### Test Scenario 3: Combined
```
1. Create group "Team C"
2. Set manual_score = 50
3. Add 2 members with scores: Member1=30, Member2=20
4. Verify group total = 100 (50 + 30 + 20)
```

### Test Scenario 4: Direct Group Score
```
1. Create group "Team D"
2. Set manual_score = 50
3. Add 2 members with scores: 30, 20
4. Assign direct group score = 25
5. Verify group total = 125 (50 + 50 + 25)
```

## Environment Variables

Ensure these are set in scoring-service:
```env
GROUP_SERVICE_URL=http://group-service:5003
```

## Deployment Steps

1. **Apply Database Migration**
   ```bash
   psql -U postgres -d score_db -f database/add_manual_score_to_groups.sql
   ```

2. **Restart Services**
   ```bash
   docker-compose restart group-service scoring-service
   ```

3. **Verify**
   - Test manual score endpoint
   - Assign member scores and verify group total updates
   - Check leaderboard shows correct totals

## Future Enhancements

- [ ] Add UI for admins to set manual scores
- [ ] Show score breakdown in group detail view
- [ ] Add history/audit log for manual score changes
- [ ] Support manual score per category (currently single value)
- [ ] Add validation/limits on manual score values
- [ ] Batch recalculate all groups endpoint
- [ ] Real-time notifications when group score changes

## Notes

- Manual scores are organization-wide (not per category)
- Member score calculation happens per category
- Recalculation is automatic when member scores change
- Manual recalculation endpoint available for troubleshooting
- Only ORG_ADMIN users can set manual scores

## Files Changed

1. `database/add_manual_score_to_groups.sql` (NEW)
2. `backend/group-service/group-service/src/models/database.py` (MODIFIED)
3. `backend/group-service/group-service/src/routes/groups.py` (MODIFIED)
4. `backend/scoring-service/scoring-service/src/routes/scores.py` (MODIFIED)
5. `GROUP_SCORE_MANUAL_FEATURE.md` (NEW - this file)
