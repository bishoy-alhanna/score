# Cities and States Management Feature

## Overview
Convert city and state fields from text input to dropdown lists managed by super admin.

## Changes Made

### 1. Database Migration ✅
**File:** `database/add_cities_states_tables.sql`

Created two new tables:
- **`states`** - Contains governorates/states (26 Egyptian governorates pre-populated)
- **`cities`** - Contains cities belonging to states (sample Cairo cities included)

Added to `users` table:
- `city_id` (UUID, foreign key to cities)
- `state_id` (UUID, foreign key to states)

**Note:** Old text fields `city` and `state` are kept for backward compatibility.

### 2. Backend API Routes ✅
**File:** `backend/auth-service/auth-service/src/routes/locations.py`

New endpoints created:

#### States Management
- `GET /api/locations/states` - Get all states (public, anyone can access)
- `POST /api/locations/states` - Create new state (super admin only)
- `PUT /api/locations/states/<id>` - Update state (super admin only)
- `DELETE /api/locations/states/<id>` - Soft delete state (super admin only)

#### Cities Management
- `GET /api/locations/cities` - Get all cities (public)
- `GET /api/locations/cities?state_id=<id>` - Get cities filtered by state (public)
- `POST /api/locations/cities` - Create new city (super admin only)
- `PUT /api/locations/cities/<id>` - Update city (super admin only)
- `DELETE /api/locations/cities/<id>` - Soft delete city (super admin only)

#### Authentication
- Super admin endpoints require `is_super_admin = true` in JWT token
- Public GET endpoints accessible to all authenticated users

### 3. Profile API Updated ✅
**File:** `backend/auth-service/auth-service/src/routes/profile.py`

Updated `PUT /api/profile/me` to accept:
- `city_id` - UUID of selected city
- `state_id` - UUID of selected state

Old fields (`city`, `state`) still work for backward compatibility.

### 4. Service Registration ✅
**File:** `backend/auth-service/auth-service/src/main.py`

Registered new locations blueprint with prefix `/api/locations`.

## Next Steps - Frontend Changes Needed

### User Dashboard Changes
**File:** `frontend/user-dashboard/user-dashboard/src/App.jsx`

Need to update the profile form:

1. **Add state management:**
```jsx
const [states, setStates] = useState([])
const [cities, setCities] = useState([])
const [selectedStateId, setSelectedStateId] = useState(null)
```

2. **Fetch states on component mount:**
```jsx
useEffect(() => {
  fetchStates()
}, [])

const fetchStates = async () => {
  try {
    const response = await api.get('/auth/locations/states')
    setStates(response.data.states || [])
  } catch (error) {
    console.error('Failed to fetch states:', error)
  }
}
```

3. **Fetch cities when state selected:**
```jsx
const fetchCitiesByState = async (stateId) => {
  try {
    const response = await api.get(`/auth/locations/cities?state_id=${stateId}`)
    setCities(response.data.cities || [])
  } catch (error) {
    console.error('Failed to fetch cities:', error)
  }
}
```

4. **Replace text inputs with dropdowns in profile form:**
```jsx
{/* State Dropdown */}
<div>
  <label>المحافظة (State)</label>
  <select 
    value={profile.state_id || ''} 
    onChange={(e) => {
      setProfile({...profile, state_id: e.target.value})
      setSelectedStateId(e.target.value)
      fetchCitiesByState(e.target.value)
    }}
  >
    <option value="">اختر المحافظة</option>
    {states.map(state => (
      <option key={state.id} value={state.id}>
        {state.name_ar || state.name}
      </option>
    ))}
  </select>
</div>

{/* City Dropdown */}
<div>
  <label>المدينة (City)</label>
  <select 
    value={profile.city_id || ''} 
    onChange={(e) => setProfile({...profile, city_id: e.target.value})}
    disabled={!selectedStateId}
  >
    <option value="">اختر المدينة</option>
    {cities.map(city => (
      <option key={city.id} value={city.id}>
        {city.name_ar || city.name}
      </option>
    ))}
  </select>
</div>
```

5. **Update profile submission:**
```jsx
const handleProfileUpdate = async () => {
  try {
    const response = await api.put('/auth/profile/me', {
      ...profile,
      state_id: profile.state_id,
      city_id: profile.city_id
    })
    // Success handling
  } catch (error) {
    // Error handling
  }
}
```

### Admin Dashboard - Super Admin Panel
**File:** `frontend/admin-dashboard/admin-dashboard/src/*` (new component needed)

Create a new page for super admin to manage cities and states:

1. **Create component:** `src/components/LocationsManagement.jsx`
2. **Add routes:** States CRUD + Cities CRUD
3. **Features needed:**
   - List all states with edit/delete actions
   - Add new state form
   - List cities by state with edit/delete actions
   - Add new city form (select state first)
   - Toggle active/inactive status

## Pre-populated Data

### States (26 Egyptian Governorates)
- القاهرة (Cairo)
- الإسكندرية (Alexandria)
- الجيزة (Giza)
- القليوبية (Qalyubia)
- And 22 more...

### Sample Cities (Cairo)
- مدينة نصر (Nasr City)
- مصر الجديدة (Heliopolis)
- المعادي (Maadi)
- الزمالك (Zamalek)
- And 4 more...

## Deployment

Run the deployment script:
```bash
chmod +x deploy-cities-states-feature.sh
./deploy-cities-states-feature.sh
```

This will:
1. Apply database migration
2. Rebuild and deploy auth service
3. Verify service health

## Testing

### Test API Endpoints (using curl or Postman):

```bash
# Get all states (no auth required for GET)
curl https://escore.al-hanna.com/api/locations/states

# Get cities for a specific state
curl https://escore.al-hanna.com/api/locations/cities?state_id=<STATE_UUID>

# Create new state (super admin only)
curl -X POST https://escore.al-hanna.com/api/locations/states \
  -H "Authorization: Bearer <SUPER_ADMIN_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"name": "Test State", "name_ar": "محافظة تجريبية"}'

# Create new city (super admin only)
curl -X POST https://escore.al-hanna.com/api/locations/cities \
  -H "Authorization: Bearer <SUPER_ADMIN_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"name": "Test City", "name_ar": "مدينة تجريبية", "state_id": "<STATE_UUID>"}'
```

## Migration Strategy for Existing Data

If you want to migrate existing text-based city/state data to the new system:

```sql
-- Example: Find users with city="Cairo" and set city_id
UPDATE users u
SET city_id = c.id
FROM cities c
WHERE LOWER(u.city) LIKE '%cairo%' 
  AND c.name = 'Nasr City'
  AND c.is_active = true;
```

## Backward Compatibility

- Old text fields `city` and `state` are kept in the database
- APIs still accept and return both formats
- Gradual migration: Users can continue using old format until they update their profile with new dropdowns
- Once `city_id` and `state_id` are set, display those values instead of text fields

## Security

- Super admin check: `@super_admin_required` decorator
- Only users with `is_super_admin = true` can manage cities/states
- Soft deletes: Locations are marked as `is_active = false` instead of hard deletion
- Foreign key constraints prevent orphaned data

## Future Enhancements

1. Add more countries (not just Egypt)
2. Add postal codes to cities
3. Add coordinates (lat/lng) for mapping
4. Add city population data
5. Multi-language support (English + Arabic completed)
6. Import/export cities and states via CSV
