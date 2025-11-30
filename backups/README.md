# Database Backups

This directory contains PostgreSQL database backups for the Score Platform.

## Available Backups

- `backup_20251123_214617.sql` - Database backup from November 23, 2025
- `saas_platform_20251128_141410.sql.gz` - Compressed backup from November 28, 2025 (includes membership filter updates)

## Restore a Backup

### Using the restore script (Recommended)

```bash
# Restore compressed backup
bash restore-database.sh backups/saas_platform_20251128_141410.sql.gz

# Restore uncompressed backup
bash restore-database.sh backups/backup_20251123_214617.sql
```

### Manual restore

**Compressed backup (.sql.gz):**
```bash
gunzip -c backups/saas_platform_20251128_141410.sql.gz | docker exec -i score_postgres_prod psql -U postgres saas_platform
```

**Uncompressed backup (.sql):**
```bash
docker exec -i score_postgres_prod psql -U postgres saas_platform < backups/backup_20251123_214617.sql
```

## Create New Backup

### Quick backup
```bash
docker exec score_postgres_prod pg_dump -U postgres saas_platform > backups/backup_$(date +%Y%m%d_%H%M%S).sql
```

### Compressed backup
```bash
docker exec score_postgres_prod pg_dump -U postgres saas_platform | gzip > backups/saas_platform_$(date +%Y%m%d_%H%M%S).sql.gz
```

## Backup Schedule Recommendations

### Development
- Manual backups before major changes
- Before database migrations
- Before production deployments

### Production
- **Daily:** Automated backups at 2 AM
- **Weekly:** Full backup retention for 4 weeks
- **Monthly:** Archive backup for 12 months

## Automated Backups (Production)

Add to crontab:

```bash
# Daily backup at 2 AM
0 2 * * * cd /path/to/score && docker exec score_postgres_prod pg_dump -U postgres saas_platform | gzip > backups/daily_$(date +\%Y\%m\%d_\%H\%M\%S).sql.gz

# Weekly backup on Sunday at 3 AM
0 3 * * 0 cd /path/to/score && docker exec score_postgres_prod pg_dump -U postgres saas_platform | gzip > backups/weekly_$(date +\%Y\%m\%d).sql.gz

# Cleanup old backups (keep last 30 days)
0 4 * * * find /path/to/score/backups -name "daily_*.sql.gz" -mtime +30 -delete
```

## Backup File Naming Convention

- **Format:** `[prefix]_YYYYMMDD_HHMMSS.sql[.gz]`
- **Examples:**
  - `backup_20251123_214617.sql` - Manual backup
  - `saas_platform_20251128_141410.sql.gz` - Compressed backup
  - `daily_20251128_020000.sql.gz` - Automated daily backup
  - `weekly_20251124.sql.gz` - Weekly backup

## Important Notes

⚠️ **Security:**
- Database backups may contain sensitive data
- Do not commit backups to public repositories
- Encrypt backups before transferring to external storage
- Store backups in secure, access-controlled locations

⚠️ **Storage:**
- Compressed backups save ~70-90% disk space
- Monitor backup directory size
- Implement backup rotation to prevent disk full issues

⚠️ **Testing:**
- Regularly test backup restoration
- Verify backup integrity
- Keep at least 3 generations of backups

## Backup Contents

Each backup includes:
- All database schemas
- All tables and data
- Indexes and constraints
- Sequences and views
- Stored procedures and functions

**Excluded from backups:**
- Docker volumes (handled separately)
- Log files
- Temporary files
- Application code

## Restore Safety

The `restore-database.sh` script includes safety features:
- Confirmation prompt before restore
- Stops backend services during restore
- Terminates active database connections
- Drops and recreates database
- Restarts services after restore

## Troubleshooting

### Restore fails with "permission denied"
```bash
# Check file permissions
ls -l backups/backup_file.sql

# Fix permissions
chmod 644 backups/backup_file.sql
```

### Restore fails with "database is being accessed"
```bash
# Manually stop services
docker-compose -f docker-compose.prod.yml stop auth-service user-service group-service scoring-service leaderboard-service

# Try restore again
bash restore-database.sh backups/backup_file.sql
```

### Backup file too large for git
```bash
# Compress if not already compressed
gzip backups/large_backup.sql

# Or exclude from git
echo "backups/*.sql" >> .gitignore
echo "backups/*.sql.gz" >> .gitignore
```

---

**Last Updated:** November 28, 2025
