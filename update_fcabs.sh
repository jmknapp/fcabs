#!/bin/bash
# Daily update script for Franklin County absentee ballot data
# Usage: ./update_fcabs.sh <new_csv_file>

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

echo "Starting update process..."
echo "CSV file: $CSV_FILE"
echo "Date: $(date)"

# Step 1: Create temporary table with same structure
mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" << EOF
DROP TABLE IF EXISTS $TEMP_TABLE;
CREATE TABLE $TEMP_TABLE LIKE $TABLE_NAME;

-- Remove auto-increment from temp table
ALTER TABLE $TEMP_TABLE MODIFY id INT;
EOF

echo "✓ Temporary table created"

# Step 2: Load new data into temporary table
mysql -u "$DB_USER" -p"$DB_PASS" --local-infile=1 "$DB_NAME" << EOF
LOAD DATA LOCAL INFILE '$CSV_FILE'
INTO TABLE $TEMP_TABLE
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
 date_returned = STR_TO_DATE(SUBSTRING_INDEX(@date_returned, ' ', 1), '%m/%d/%Y');
EOF

echo "✓ Data loaded into temporary table"

# Step 3: Update existing records and insert new ones
mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" << 'EOF'
-- Update existing records (based on local_id)
UPDATE fcabs2025 f
INNER JOIN fcabs2025_temp t ON f.local_id = t.local_id
SET 
    f.precinct_name = t.precinct_name,
    f.precinct_code = t.precinct_code,
    f.precinct_code_with_split = t.precinct_code_with_split,
    f.city_or_village = t.city_or_village,
    f.school_district = t.school_district,
    f.township = t.township,
    f.house_district = t.house_district,
    f.senate_district = t.senate_district,
    f.congress_district = t.congress_district,
    f.police_district = t.police_district,
    f.road_district = t.road_district,
    f.fire_district = t.fire_district,
    f.park_district = t.park_district,
    f.court_appeals_name = t.court_appeals_name,
    f.board_of_ed_name = t.board_of_ed_name,
    f.party = t.party,
    f.date_mailed = t.date_mailed,
    f.date_registered = t.date_registered,
    f.year_of_birth = t.year_of_birth,
    f.first_name = t.first_name,
    f.middle_name = t.middle_name,
    f.last_name = t.last_name,
    f.suffix_name = t.suffix_name,
    f.address_line_1 = t.address_line_1,
    f.address_line_2 = t.address_line_2,
    f.address_line_3 = t.address_line_3,
    f.address_line_4 = t.address_line_4,
    f.city = t.city,
    f.state = t.state,
    f.zip = t.zip,
    f.zip_plus_4 = t.zip_plus_4,
    f.mailed = t.mailed,
    f.date_requested = t.date_requested,
    f.date_returned = t.date_returned,
    f.ballot_style = t.ballot_style,
    f.status = t.status;

-- Insert new records (that don't exist in main table)
INSERT INTO fcabs2025 (
    precinct_name, precinct_code, precinct_code_with_split, city_or_village,
    school_district, township, house_district, senate_district, congress_district,
    police_district, road_district, fire_district, park_district,
    court_appeals_name, board_of_ed_name, party, date_mailed, date_registered,
    local_id, year_of_birth, first_name, middle_name, last_name, suffix_name,
    address_line_1, address_line_2, address_line_3, address_line_4, city, state,
    zip, zip_plus_4, mailed, date_requested, date_returned, ballot_style, status
)
SELECT 
    t.precinct_name, t.precinct_code, t.precinct_code_with_split, t.city_or_village,
    t.school_district, t.township, t.house_district, t.senate_district, t.congress_district,
    t.police_district, t.road_district, t.fire_district, t.park_district,
    t.court_appeals_name, t.board_of_ed_name, t.party, t.date_mailed, t.date_registered,
    t.local_id, t.year_of_birth, t.first_name, t.middle_name, t.last_name, t.suffix_name,
    t.address_line_1, t.address_line_2, t.address_line_3, t.address_line_4, t.city, t.state,
    t.zip, t.zip_plus_4, t.mailed, t.date_requested, t.date_returned, t.ballot_style, t.status
FROM fcabs2025_temp t
LEFT JOIN fcabs2025 f ON t.local_id = f.local_id
WHERE f.local_id IS NULL;

-- Get statistics
SELECT 
    'Records in temp table' as metric, 
    COUNT(*) as count 
FROM fcabs2025_temp
UNION ALL
SELECT 
    'Records in main table after update', 
    COUNT(*) 
FROM fcabs2025;
EOF

echo "✓ Records updated and new records inserted"

# Step 4: Cleanup
mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" << EOF
DROP TABLE IF EXISTS $TEMP_TABLE;
EOF

echo "✓ Cleanup complete"
echo "Update finished successfully at $(date)"
echo ""
echo "================================================"
echo "📅 REMINDER: Update the 'Data as of' date"
echo "================================================"
echo "Run: ./update_data_date.sh \"Month DD, YYYY\""
echo "Example: ./update_data_date.sh \"October 5, 2025\""
echo "================================================"

