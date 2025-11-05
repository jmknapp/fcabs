#!/bin/bash
# Daily update script for Franklin County absentee ballot data (HISTORICAL VERSION)
# This version keeps all historical records - multiple entries per voter
# Usage: ./update_fcabs_history.sh <new_csv_file>

# Load environment variables from .env file
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
else
    echo "Error: .env file not found"
    echo "Please copy .env.example to .env and configure your database credentials."
    exit 1
fi

CSV_FILE="$1"
DB_USER="${DB_USER}"
DB_PASS="${DB_PASS}"
DB_NAME="${DB_NAME}"
TABLE_NAME="${TABLE_NAME}"
TEMP_TABLE="${TABLE_NAME}_temp"

if [ -z "$CSV_FILE" ]; then
    echo "Usage: $0 <csv_file>"
    exit 1
fi

if [ ! -f "$CSV_FILE" ]; then
    echo "Error: File $CSV_FILE not found"
    exit 1
fi

echo "Starting update process (HISTORICAL MODE)..."
echo "CSV file: $CSV_FILE"
echo "Date: $(date)"

# Step 1: Add unique constraint if not exists (local_id + date_requested combination)
mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" << 'EOF'
-- Check and add unique index on local_id + date_requested
ALTER TABLE fcabs1004 ADD UNIQUE INDEX idx_voter_request (local_id, date_requested);
EOF

echo "✓ Unique index verified"

# Step 2: Load data with ON DUPLICATE KEY UPDATE
# This will update existing combinations and insert new ones
mysql -u "$DB_USER" -p"$DB_PASS" --local-infile=1 "$DB_NAME" << EOF
LOAD DATA LOCAL INFILE '$CSV_FILE'
INTO TABLE $TABLE_NAME
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(precinct_name, precinct_code, precinct_code_with_split, city_or_village, 
 school_district, township, house_district, senate_district, congress_district,
 police_district, road_district, fire_district, park_district, 
 court_appeals_name, board_of_ed_name, party, @date_mailed, @date_registered,
 local_id, year_of_birth, first_name, middle_name, last_name, suffix_name,
 address_line_1, address_line_2, address_line_3, address_line_4, city, state,
 zip, zip_plus_4, mailed, @date_requested, @date_returned, ballot_style, status)
SET
 date_mailed = STR_TO_DATE(SUBSTRING_INDEX(@date_mailed, ' ', 1), '%m/%d/%Y'),
 date_registered = STR_TO_DATE(SUBSTRING_INDEX(@date_registered, ' ', 1), '%m/%d/%Y'),
 date_requested = STR_TO_DATE(SUBSTRING_INDEX(@date_requested, ' ', 1), '%m/%d/%Y'),
 date_returned = STR_TO_DATE(SUBSTRING_INDEX(@date_returned, ' ', 1), '%m/%d/%Y')
ON DUPLICATE KEY UPDATE
    precinct_name = VALUES(precinct_name),
    precinct_code = VALUES(precinct_code),
    precinct_code_with_split = VALUES(precinct_code_with_split),
    city_or_village = VALUES(city_or_village),
    school_district = VALUES(school_district),
    township = VALUES(township),
    house_district = VALUES(house_district),
    senate_district = VALUES(senate_district),
    congress_district = VALUES(congress_district),
    police_district = VALUES(police_district),
    road_district = VALUES(road_district),
    fire_district = VALUES(fire_district),
    park_district = VALUES(park_district),
    court_appeals_name = VALUES(court_appeals_name),
    board_of_ed_name = VALUES(board_of_ed_name),
    party = VALUES(party),
    date_mailed = VALUES(date_mailed),
    date_registered = VALUES(date_registered),
    year_of_birth = VALUES(year_of_birth),
    first_name = VALUES(first_name),
    middle_name = VALUES(middle_name),
    last_name = VALUES(last_name),
    suffix_name = VALUES(suffix_name),
    address_line_1 = VALUES(address_line_1),
    address_line_2 = VALUES(address_line_2),
    address_line_3 = VALUES(address_line_3),
    address_line_4 = VALUES(address_line_4),
    city = VALUES(city),
    state = VALUES(state),
    zip = VALUES(zip),
    zip_plus_4 = VALUES(zip_plus_4),
    mailed = VALUES(mailed),
    date_returned = VALUES(date_returned),
    ballot_style = VALUES(ballot_style),
    status = VALUES(status);

-- Show statistics
SELECT 
    'Total records in table' as metric, 
    COUNT(*) as count 
FROM fcabs1004
UNION ALL
SELECT 
    'Unique voters', 
    COUNT(DISTINCT local_id) 
FROM fcabs1004;
EOF

echo "✓ Data loaded with duplicate handling"
echo "Update finished successfully at $(date)"

