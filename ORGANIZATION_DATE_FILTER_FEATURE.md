# Organization-Wide Date Filter Feature

## Overview
Implemented a global organization setting that allows administrators to set a date range filter for leaderboards. This filter persists in the database and automatically applies to all users in the organization.

## Implementation Details

### Database Changes
**File:** `backend/migrations/add_organization_filter_settings.sql`

Added three new columns to the `organizations` table:
- `filter_start_date` (DATE, nullable) - Start date for leaderboard filtering
- `filter_end_date` (DATE, nullable) - End date for leaderboard filtering  
- `filter_enabled` (BOOLEAN, default FALSE) - Toggle to enable/disable the filter

### Backend Changes

#### 1. Auth Service - Organization Model
**Files:**
- `backend/auth-service/auth-service/src/models/database_multi_org.py`

Added filter settings fields to the Organization model and updated `to_dict()` to include them in API responses.

#### 2. Auth Service - Organization Routes
**File:** `backend/auth-service/auth-service/src/routes/organization.py`

Added new endpoint:
- **PUT /organizations/filter-settings**
  - Requires ORG_ADMIN role
  - Accepts: `filter_enabled`, `filter_start_date`, `filter_end_date`
  - Parses dates from YYYY-MM-DD format
  - Updates organization record
  - Returns updated organization with filter settings

#### 3. Leaderboard Service
**File:** `backend/leaderboard-service/leaderboard-service/src/routes/leaderboards.py`

Added:
- `fetch_organization_settings()` function to retrieve organization filter settings from auth service
- Updated `get_user_leaderboard()` to check organization filter settings when no explicit dates are provided
- Updated `get_group_leaderboard()` to check organization filter settings when no explicit dates are provided

Logic flow:
1. If explicit `start_date`/`end_date` parameters provided → use those
2. If no explicit dates → fetch organization settings
3. If organization has `filter_enabled=true` → use organization's start/end dates
4. Otherwise → use default aggregates without filtering

### Frontend Changes

#### 1. Admin Dashboard
**File:** `frontend/admin-dashboard/admin-dashboard/src/App.jsx`

Added in LeaderboardManagement component:
- `loadOrganizationFilterSettings()` - Fetches and applies saved organization filter settings on component mount
- `saveOrganizationFilterSettings()` - Saves current date filter settings to organization
- "Save as Default" button - Appears when date filtering is enabled, calls the save endpoint
- Auto-loads organization settings when component mounts

#### 2. User Dashboard
**File:** `frontend/user-dashboard/user-dashboard/src/App.jsx`

Added in Dashboard component:
- `orgFilterSettings` state to track organization filter settings
- `fetchOrganizationFilterSettings()` - Fetches organization settings on mount
- Visual indicator in leaderboard card showing active date filter range
- Automatically uses organization filter settings (via backend)

## User Flow

### Admin Flow:
1. Admin opens Leaderboard Management in admin dashboard
2. Admin checks "Filter by Date" checkbox
3. Admin selects start and end dates
4. Admin clicks "Save as Default" button
5. Settings are saved to organization in database
6. Success message confirms save

### User Flow:
1. User logs into user dashboard
2. Dashboard automatically fetches organization filter settings
3. If filter is enabled, leaderboard shows filtered data
4. Visual indicator displays the active date range: "📅 Filtered: YYYY-MM-DD to YYYY-MM-DD"
5. All leaderboard API calls automatically use organization filter settings

## API Endpoints

### Save Organization Filter Settings
```
PUT /organizations/filter-settings
Authorization: Bearer <token>
Content-Type: application/json

{
  "filter_enabled": true,
  "filter_start_date": "2024-01-01",
  "filter_end_date": "2024-12-31"
}

Response:
{
  "message": "Filter settings updated successfully",
  "organization": {
    "id": "...",
    "name": "...",
    "filter_enabled": true,
    "filter_start_date": "2024-01-01",
    "filter_end_date": "2024-12-31",
    ...
  }
}
```

### Get Organization (includes filter settings)
```
GET /organizations
Authorization: Bearer <token>

Response:
{
  "id": "...",
  "name": "...",
  "filter_enabled": true,
  "filter_start_date": "2024-01-01",
  "filter_end_date": "2024-12-31",
  ...
}
```

### Get Leaderboard (automatically uses org filter)
```
GET /leaderboards/users?category=all&organization_id=<org_id>
Authorization: Bearer <token>

# If organization has filter_enabled=true, backend automatically applies dates
# Can also override with explicit dates:
GET /leaderboards/users?category=all&organization_id=<org_id>&start_date=2024-01-01&end_date=2024-12-31
```

## Testing

### Test Admin Save Flow:
1. Login as ORG_ADMIN
2. Navigate to Leaderboards section
3. Enable date filter checkbox
4. Select dates (e.g., 2024-01-01 to 2024-12-31)
5. Click "Save as Default"
6. Verify success message
7. Refresh page
8. Verify dates are pre-populated

### Test User Dashboard Flow:
1. As admin, set and save organization date filter
2. Login as regular user
3. View user dashboard
4. Verify leaderboard shows "📅 Filtered: ..." indicator
5. Verify leaderboard data matches filtered date range

### Test Disable Filter:
1. As admin, uncheck "Filter by Date"
2. Click "Save as Default"
3. Login as user
4. Verify no date filter indicator shown
5. Verify leaderboard shows all-time data

## Database Migration Applied
```sql
ALTER TABLE organizations 
ADD COLUMN IF NOT EXISTS filter_start_date DATE,
ADD COLUMN IF NOT EXISTS filter_end_date DATE,
ADD COLUMN IF NOT EXISTS filter_enabled BOOLEAN DEFAULT FALSE;

UPDATE organizations SET filter_enabled = FALSE WHERE filter_enabled IS NULL;
```

## Services Rebuilt
- ✅ auth-service (new model fields and API endpoint)
- ✅ leaderboard-service (organization filter logic)
- ✅ admin-dashboard (save/load UI)
- ✅ user-dashboard (visual indicator)

## Benefits
1. **Centralized Control**: Admins can control date filtering for entire organization
2. **Persistence**: Settings survive page refreshes and user sessions
3. **Transparency**: Users can see when a filter is active
4. **Flexibility**: Admins can enable/disable without losing date values
5. **Override Capability**: API still accepts explicit dates for manual queries
6. **Automatic Application**: No code changes needed in user dashboard - backend handles it

## Future Enhancements
- Add category-specific date filters
- Add preset date ranges (This Week, This Month, This Year)
- Add audit log of filter changes
- Add user-level date filter overrides (if admin allows)
- Add filter history/versioning
