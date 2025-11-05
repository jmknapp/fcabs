#!/bin/bash
# One-time cleanup script to remove duplicate local_id records
# Keeps the most recent record (by date_requested) for each voter

# Load environment variables from .env file
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
else
    echo "Error: .env file not found"
    echo "Please copy .env.example to .env and configure your database credentials."
    exit 1
fi

DB_USER="${DB_USER}"
DB_PASS="${DB_PASS}"
DB_NAME="${DB_NAME}"
TABLE_NAME="${TABLE_NAME}"

echo "Cleaning up duplicate records..."
echo "This will keep only the most recent ballot request per voter"
echo ""

# Show current duplicates
echo "Current duplicates:"
mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" << 'EOF'
SELECT local_id, COUNT(*) as count, 
       GROUP_CONCAT(CONCAT(first_name, ' ', last_name) SEPARATOR '; ') as voters,
       GROUP_CONCAT(date_requested ORDER BY date_requested) as request_dates
FROM fcabs1004 
GROUP BY local_id 
HAVING COUNT(*) > 1;
EOF

echo ""
read -p "Do you want to proceed with cleanup? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Cleanup cancelled"
    exit 0
fi

# Remove duplicates, keeping the latest request
mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" << 'EOF'
-- Delete older duplicate records, keeping the one with the latest date_requested
DELETE f1 FROM fcabs1004 f1
INNER JOIN fcabs1004 f2 
WHERE f1.local_id = f2.local_id
  AND (
    f1.date_requested < f2.date_requested 
    OR (f1.date_requested = f2.date_requested AND f1.id < f2.id)
  );

-- Show results
SELECT 'Records after cleanup' as status, COUNT(*) as count FROM fcabs1004;
SELECT 'Unique voters' as status, COUNT(DISTINCT local_id) as count FROM fcabs1004;
EOF

echo ""
echo "✓ Cleanup complete!"
echo "You can now use update_fcabs.sh for daily updates"

