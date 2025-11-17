#!/bin/bash

# Export Current Database Schema from Production

echo "Exporting production database schema..."

ssh -o StrictHostKeyChecking=no bihannaroot@escore.al-hanna.com << 'ENDSSH'
docker exec score_postgres_prod psql -U postgres -d saas_platform << 'EOSQL'

\echo '=========================================='
\echo 'PRODUCTION DATABASE SCHEMA ANALYSIS'
\echo '=========================================='
\echo ''

\echo '1. ALL TABLES:'
\dt

\echo ''
\echo '2. USERS TABLE:'
\d users

\echo ''
\echo '3. ORGANIZATIONS TABLE:'
\d organizations

\echo ''
\echo '4. USER_ORGANIZATIONS TABLE:'
\d user_organizations

\echo ''
\echo '5. ORGANIZATION_JOIN_REQUESTS TABLE:'
\d organization_join_requests

\echo ''
\echo '6. ORGANIZATION_INVITATIONS TABLE:'
\d organization_invitations

\echo ''
\echo '7. GROUPS TABLE:'
\d groups

\echo ''
\echo '8. GROUP_MEMBERS TABLE:'
\d group_members

\echo ''
\echo '9. SCORE_CATEGORIES TABLE:'
\d score_categories

\echo ''
\echo '10. SCORES TABLE:'
\d scores

\echo ''
\echo '11. SCORE_AGGREGATES TABLE:'
\d score_aggregates

\echo ''
\echo '12. SUPER_ADMIN_CONFIG TABLE:'
\d super_admin_config

\echo ''
\echo '13. QR_SCAN_LOGS TABLE:'
\d qr_scan_logs

EOSQL
ENDSSH
