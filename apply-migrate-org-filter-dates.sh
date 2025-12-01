#!/bin/bash
# Apply organization filter date migration on production server

set -e

# Copy migration file to remote server
scp migrate_org_filter_dates.sql bihannaroot@escore.al-hanna.com:/home/bihannaroot/score/

# SSH and apply migration
ssh bihannaroot@escore.al-hanna.com << 'EOF'
cd /home/bihannaroot/score

docker-compose -f docker-compose.prod.yml exec -T postgres \
  psql -U postgres -d saas_platform < migrate_org_filter_dates.sql
EOF

echo "Migration applied successfully."
