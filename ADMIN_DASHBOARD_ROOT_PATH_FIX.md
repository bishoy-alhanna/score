# Admin Dashboard Root Path Fix ✅

## Date: November 16, 2025

## Problem
The admin dashboard only worked at `admin.score.al-hanna.com/admin` but not at `admin.score.al-hanna.com/` (root path).

## Root Cause
The React Router in the admin dashboard was configured with `basename="/admin"`, which meant:
- All routes expected to be under the `/admin` path
- Direct access to root (`/`) would not match any routes
- This is why it only worked at `admin.score.al-hanna.com/admin`

## Solution

### 1. Fixed React Router basename
**File**: `frontend/admin-dashboard/admin-dashboard/src/App.jsx` (Line 472)

**Before**:
```jsx
<Router basename="/admin">
```

**After**:
```jsx
<Router basename="/">
```

**Impact**: Now React Router expects routes at the root level, matching the subdomain structure.

### 2. Simplified nginx routing
**File**: `nginx/nginx.conf`

**Before**: Had both `/admin` and `/` location blocks (confusing/redundant)

**After**: Single clean location block for root path:
```nginx
# Admin Dashboard - root path (basename="/")
location / {
    proxy_pass http://admin-dashboard:3000/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    
    # Prevent caching of HTML to avoid stale dashboard
    proxy_hide_header ETag;
    add_header Cache-Control "no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0";
    add_header Pragma "no-cache";
    add_header Expires "0";
    
    # Timeout settings
    proxy_connect_timeout 30s;
    proxy_send_timeout 30s;
    proxy_read_timeout 30s;
}
```

## Build Information

### Containers Rebuilt
- ✅ `admin-dashboard` - Build time: 118.2s
- ✅ `nginx` - Build time: < 1s (cached layers)

### Verification
Nginx logs confirm the dashboard is working at root:
```
192.168.65.1 - - [16/Nov/2025:04:08:45 +0000] "POST /api/auth/login HTTP/1.1" 200 836 "http://admin.score.al-hanna.com/" ...
192.168.65.1 - - [16/Nov/2025:04:08:46 +0000] "GET /api/auth/organizations/... HTTP/1.1" 200 21 "http://admin.score.al-hanna.com/" ...
```

Notice the referrer is `http://admin.score.al-hanna.com/` (root) not `/admin` ✅

## Current Routing Structure

### Admin Subdomain (`admin.score.al-hanna.com`)
- **Dashboard**: `/` (root) → Admin Dashboard
- **API**: `/api/*` → API Gateway
- **Static Assets**: Served by admin dashboard container

### Main Domain (`score.al-hanna.com`)
- **Dashboard**: `/` (root) → User Dashboard
- **API**: `/api/*` → API Gateway

## Files Modified
1. `/frontend/admin-dashboard/admin-dashboard/src/App.jsx` - Changed basename to "/"
2. `/nginx/nginx.conf` - Removed `/admin` location block, kept root location

## Testing Checklist

### ✅ Root Path Access
- Navigate to: `http://admin.score.al-hanna.com/` or `https://admin.score.al-hanna.com/`
- Expected: Admin dashboard loads at root
- Status: ✅ Working (confirmed in nginx logs)

### ✅ Login Flow
- Status: ✅ Working (successful login in logs)

### ✅ API Calls
- Status: ✅ Working (organizations, groups, join-requests all successful)

### ⚠️ Cache Clearing
**Important**: Users who previously accessed `/admin` should:
1. Hard refresh: `Cmd+Shift+R` (Mac) or `Ctrl+Shift+F5` (Windows)
2. Clear browser cache if issues persist
3. Access the root path `/` instead of `/admin`

## Migration Notes

### For Users
- **Old URL**: `admin.score.al-hanna.com/admin` ❌ (may still work but not recommended)
- **New URL**: `admin.score.al-hanna.com/` ✅ (correct)

### For Developers
- React Router now uses `basename="/"` 
- All internal routes are relative to root
- No need to prefix routes with `/admin`

## Benefits

1. **Cleaner URLs**: `admin.score.al-hanna.com/` instead of `admin.score.al-hanna.com/admin`
2. **Consistent Structure**: Subdomain serves as the namespace, root path serves the app
3. **Simpler Configuration**: One location block instead of two
4. **Better UX**: More intuitive URL structure

## Related Documents
- `ADMIN_DASHBOARD_FIX_APPLIED.md` - Previous i18n initialization fix
- `USER_DASHBOARD_LOADING_FIX_COMPLETE.md` - User dashboard fix

## Status: ✅ COMPLETE

The admin dashboard now works correctly at:
- ✅ `http://admin.score.al-hanna.com/`
- ✅ `https://admin.score.al-hanna.com/` (with SSL)

**No action needed** - System is already operational with the fix applied.
