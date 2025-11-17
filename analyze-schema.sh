#!/bin/bash

# Comprehensive Database Schema Analysis and Migration Generator

OUTPUT_FILE="database-migration-analysis.sql"

echo "-- =========================================="  > $OUTPUT_FILE
echo "-- DATABASE SCHEMA ANALYSIS AND MIGRATION" >> $OUTPUT_FILE
echo "-- Generated: $(date)" >> $OUTPUT_FILE
echo "-- =========================================="  >> $OUTPUT_FILE
echo "" >> $OUTPUT_FILE

echo "Analyzing database schema..."

# Export current schema from production
echo "Fetching production schema..."
ssh -o StrictHostKeyChecking=no bihannaroot@escore.al-hanna.com << 'ENDSSH' >> $OUTPUT_FILE

docker exec score_postgres_prod psql -U postgres -d saas_platform << 'EOSQL'

\echo ''
\echo '-- =========================================='
\echo '-- CURRENT PRODUCTION SCHEMA'
\echo '-- =========================================='
\echo ''

-- List all tables
\echo '-- ALL TABLES:'
SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename;

\echo ''
\echo '-- USERS TABLE STRUCTURE:'
SELECT column_name, data_type, character_maximum_length, is_nullable, column_default
FROM information_schema.columns 
WHERE table_name = 'users' 
ORDER BY ordinal_position;

\echo ''
\echo '-- ORGANIZATIONS TABLE STRUCTURE:'
SELECT column_name, data_type, character_maximum_length, is_nullable, column_default
FROM information_schema.columns 
WHERE table_name = 'organizations' 
ORDER BY ordinal_position;

\echo ''
\echo '-- USER_ORGANIZATIONS TABLE STRUCTURE:'
SELECT column_name, data_type, character_maximum_length, is_nullable, column_default
FROM information_schema.columns 
WHERE table_name = 'user_organizations' 
ORDER BY ordinal_position;

\echo ''
\echo '-- SCORE_CATEGORIES TABLE STRUCTURE:'
SELECT column_name, data_type, character_maximum_length, is_nullable, column_default
FROM information_schema.columns 
WHERE table_name = 'score_categories' 
ORDER BY ordinal_position;

\echo ''
\echo '-- SCORES TABLE STRUCTURE:'
SELECT column_name, data_type, character_maximum_length, is_nullable, column_default
FROM information_schema.columns 
WHERE table_name = 'scores' 
ORDER BY ordinal_position;

\echo ''
\echo '-- GROUPS TABLE STRUCTURE:'
SELECT column_name, data_type, character_maximum_length, is_nullable, column_default
FROM information_schema.columns 
WHERE table_name = 'groups' 
ORDER BY ordinal_position;

\echo ''
\echo '-- GROUP_MEMBERS TABLE STRUCTURE:'
SELECT column_name, data_type, character_maximum_length, is_nullable, column_default
FROM information_schema.columns 
WHERE table_name = 'group_members' 
ORDER BY ordinal_position;

\echo ''
\echo '-- ORGANIZATION_JOIN_REQUESTS TABLE STRUCTURE:'
SELECT column_name, data_type, character_maximum_length, is_nullable, column_default
FROM information_schema.columns 
WHERE table_name = 'organization_join_requests' 
ORDER BY ordinal_position;

\echo ''
\echo '-- ORGANIZATION_INVITATIONS TABLE STRUCTURE:'
SELECT column_name, data_type, character_maximum_length, is_nullable, column_default
FROM information_schema.columns 
WHERE table_name = 'organization_invitations' 
ORDER BY ordinal_position;

\echo ''
\echo '-- SCORE_AGGREGATES TABLE STRUCTURE:'
SELECT column_name, data_type, character_maximum_length, is_nullable, column_default
FROM information_schema.columns 
WHERE table_name = 'score_aggregates' 
ORDER BY ordinal_position;

\echo ''
\echo '-- SUPER_ADMIN_CONFIG TABLE STRUCTURE:'
SELECT column_name, data_type, character_maximum_length, is_nullable, column_default
FROM information_schema.columns 
WHERE table_name = 'super_admin_config' 
ORDER BY ordinal_position;

\echo ''
\echo '-- QR_SCAN_LOGS TABLE STRUCTURE:'
SELECT column_name, data_type, character_maximum_length, is_nullable, column_default
FROM information_schema.columns 
WHERE table_name = 'qr_scan_logs' 
ORDER BY ordinal_position;

\echo ''
\echo '-- ALL INDEXES:'
SELECT 
    tablename,
    indexname,
    indexdef
FROM pg_indexes 
WHERE schemaname = 'public' 
ORDER BY tablename, indexname;

\echo ''
\echo '-- ALL FOREIGN KEYS:'
SELECT
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc 
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
ORDER BY tc.table_name;

EOSQL
ENDSSH

echo ""
echo "Schema analysis saved to: $OUTPUT_FILE"
echo ""
echo "Now analyzing model files for expected schema..."
