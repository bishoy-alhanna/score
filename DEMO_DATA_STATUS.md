# Demo Data Setup - Summary

## Current Status

✅ **Demo Organization Created**: "Demo Organization"  
✅ **Demo Users Created**:
- demoadmin (Admin) - Password: Demo@123
- john.demo (User) - Password: Demo@123
- jane.demo (User) - Password: Demo@123
- mike.demo (User) - Password: Demo@123

⚠️ **Predefined Categories**: Need to be created
⚠️ **Sample Scores**: Need to be added

## What's Available Now

You can login to the system with:
- **URL**: http://score.al-hanna.com
- **Organization**: Demo Organization
- **Username**: demoadmin
- **Password**: Demo@123

## To Complete Demo Data Setup

Run this command to add predefined categories and scores:

```bash
docker exec saas_postgres psql -U postgres -d saas_platform << 'EOF'
-- Get demo org ID
WITH demo_org AS (
  SELECT id::varchar as org_id FROM organizations WHERE name = 'Demo Organization'
),
demo_admin AS (
  SELECT u.id::varchar as admin_id 
  FROM users u, demo_org o
  WHERE u.organization_id::varchar = o.org_id AND u.role = 'ADMIN' LIMIT 1
)
-- Create categories
INSERT INTO score_categories (id, organization_id, name, description, max_score, created_by, is_active, is_predefined, created_at, updated_at)
SELECT 
    replace(gen_random_uuid()::varchar, '-', ''),
    demo_org.org_id,
    cat.name,
    cat.description,
    100,
    demo_admin.admin_id,
    true,
    true,
    NOW(),
    NOW()
FROM demo_org, demo_admin,
(VALUES 
    ('القداس', 'حضور القداس الإلهي'),
    ('التناول', 'تناول القربان المقدس'),
    ('الاعتراف', 'سر الاعتراف'),
    ('خدمة', 'الخدمة الكنسية'),
    ('حفظ الكتاب المقدس', 'حفظ آيات من الكتاب المقدس')
) AS cat(name, description)
ON CONFLICT (name, organization_id) DO NOTHING;

SELECT 'Categories created: ' || COUNT(*) FROM score_categories WHERE is_predefined = true;
EOF
```

## Super Admin Delete Feature

The API endpoint `/api/super-admin/demo/delete` has been created to allow super admins to delete all demo data after exploring the platform.

### API Endpoints:
- `GET /api/super-admin/demo/check` - Check if demo data exists
- `DELETE /api/super-admin/demo/delete` - Delete all demo data  
- `POST /api/super-admin/demo/recreate` - Recreate demo data

## Files Created

1. `/database/seed_demo_data.sql` - Demo data seed script (needs fixing for VARCHAR/UUID compatibility)
2. `/backend/api-gateway/api-gateway/src/routes/demo_data.py` - Demo data management API
3. Updated `/backend/api-gateway/api-gateway/src/main.py` - Registered demo routes

## Next Steps

1. ✅ Demo organization and users are ready to use
2. ⏭️ Add predefined categories (run the SQL above)
3. ⏭️ Add sample scores
4. ⏭️ Test login with demo accounts
5. ⏭️ Rebuild containers to include new API routes

## Rebuild Command

```bash
cd /Users/bhanna/Projects/Score/score
docker-compose down
docker-compose up -d --build
```

---

**You can now login and use the platform with the demo account!** 🎉
