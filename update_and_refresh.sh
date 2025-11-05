#!/bin/bash

# Script to update fcabs database and refresh the "Data as of" date
# Usage: ./update_and_refresh.sh <csv_file>

set -e  # Exit on any error

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Database configuration
DB_USER="root"
DB_PASS="R_250108_z"
DB_NAME="ohsosvoterfiles"
TABLE_NAME="fcabs2025"

# Check if CSV file argument provided
if [ -z "$1" ]; then
    echo -e "${RED}Error: No CSV file specified${NC}"
    echo "Usage: $0 <csv_file>"
    echo "Example: $0 fcabs1105.csv"
    exit 1
fi

CSV_FILE="$1"

# Check if file exists
if [ ! -f "$CSV_FILE" ]; then
    echo -e "${RED}Error: File '$CSV_FILE' not found${NC}"
    exit 1
fi

# Extract date from filename (e.g., fcabs1105.csv -> 11/05)
FILENAME=$(basename "$CSV_FILE")
if [[ $FILENAME =~ fcabs([0-9]{2})([0-9]{2})\.csv ]]; then
    MONTH="${BASH_REMATCH[1]}"
    DAY="${BASH_REMATCH[2]}"
    
    # Convert month number to name
    case $MONTH in
        01) MONTH_NAME="January" ;;
        02) MONTH_NAME="February" ;;
        03) MONTH_NAME="March" ;;
        04) MONTH_NAME="April" ;;
        05) MONTH_NAME="May" ;;
        06) MONTH_NAME="June" ;;
        07) MONTH_NAME="July" ;;
        08) MONTH_NAME="August" ;;
        09) MONTH_NAME="September" ;;
        10) MONTH_NAME="October" ;;
        11) MONTH_NAME="November" ;;
        12) MONTH_NAME="December" ;;
        *) MONTH_NAME="" ;;
    esac
    
    # Remove leading zero from day
    DAY=$((10#$DAY))
    
    NEW_DATE="${MONTH_NAME} ${DAY}, 2025"
else
    echo -e "${YELLOW}Warning: Could not extract date from filename${NC}"
    echo -n "Enter the data date (e.g., November 5, 2025): "
    read NEW_DATE
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Franklin County Voter Data Update${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "CSV File: $CSV_FILE"
echo "Data Date: $NEW_DATE"
echo "Database: $DB_NAME"
echo "Table: $TABLE_NAME"
echo ""

# Confirm before proceeding
read -p "Proceed with update? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Update cancelled${NC}"
    exit 0
fi

# Step 1: Load data into temporary table
echo ""
echo -e "${GREEN}Step 1: Loading CSV data into temporary table...${NC}"

mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" << EOF
-- Drop temporary table if exists
DROP TABLE IF EXISTS fcabs_temp;

-- Create temporary table with same structure
CREATE TABLE fcabs_temp LIKE $TABLE_NAME;

-- Disable keys for faster loading
ALTER TABLE fcabs_temp DISABLE KEYS;

-- Load data from CSV
LOAD DATA LOCAL INFILE '$CSV_FILE'
INTO TABLE fcabs_temp
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(@local_id, @voter_status, @county_number, @county_id, @last_name, @first_name,
 @middle_name, @suffix, @date_of_birth, @registration_date, @voter_status2,
 @party_affiliation, @residential_address1, @residential_address2,
 @residential_city, @residential_state, @residential_zip, @residential_zip_plus4,
 @residential_country, @residential_postalcode, @mailing_address1, @mailing_address2,
 @mailing_address3, @mailing_city, @mailing_state, @mailing_zip, @mailing_zip_plus4,
 @mailing_country, @mailing_postal_code, @career_center, @city, @city_school_district,
 @county_court_district, @congressional_district, @court_of_appeals, @edu_service_center_district,
 @exempted_vill_school_district, @library, @local_school_district, @municipal_court_district,
 @precinct_name, @precinct_code, @state_board_of_education, @state_representative_district,
 @state_senate_district, @township, @village, @ward, @primary_date, @primary_party,
 @absentee_type, @date_application_received, @application_type, @ballot_mailed_date,
 @ballot_returned_date, @ballot_status, @ballot_spoiled_reason)
SET
    local_id = NULLIF(@local_id, ''),
    voter_status = NULLIF(@voter_status, ''),
    county_number = NULLIF(@county_number, ''),
    county_id = NULLIF(@county_id, ''),
    last_name = NULLIF(@last_name, ''),
    first_name = NULLIF(@first_name, ''),
    middle_name = NULLIF(@middle_name, ''),
    suffix = NULLIF(@suffix, ''),
    date_of_birth = STR_TO_DATE(NULLIF(@date_of_birth, ''), '%m/%d/%Y'),
    registration_date = STR_TO_DATE(NULLIF(@registration_date, ''), '%m/%d/%Y %H:%i'),
    voter_status2 = NULLIF(@voter_status2, ''),
    party_affiliation = NULLIF(@party_affiliation, ''),
    residential_address1 = NULLIF(@residential_address1, ''),
    residential_address2 = NULLIF(@residential_address2, ''),
    residential_city = NULLIF(@residential_city, ''),
    residential_state = NULLIF(@residential_state, ''),
    residential_zip = NULLIF(@residential_zip, ''),
    residential_zip_plus4 = NULLIF(@residential_zip_plus4, ''),
    residential_country = NULLIF(@residential_country, ''),
    residential_postalcode = NULLIF(@residential_postalcode, ''),
    mailing_address1 = NULLIF(@mailing_address1, ''),
    mailing_address2 = NULLIF(@mailing_address2, ''),
    mailing_address3 = NULLIF(@mailing_address3, ''),
    mailing_city = NULLIF(@mailing_city, ''),
    mailing_state = NULLIF(@mailing_state, ''),
    mailing_zip = NULLIF(@mailing_zip, ''),
    mailing_zip_plus4 = NULLIF(@mailing_zip_plus4, ''),
    mailing_country = NULLIF(@mailing_country, ''),
    mailing_postal_code = NULLIF(@mailing_postal_code, ''),
    career_center = NULLIF(@career_center, ''),
    city = NULLIF(@city, ''),
    city_school_district = NULLIF(@city_school_district, ''),
    county_court_district = NULLIF(@county_court_district, ''),
    congressional_district = NULLIF(@congressional_district, ''),
    court_of_appeals = NULLIF(@court_of_appeals, ''),
    edu_service_center_district = NULLIF(@edu_service_center_district, ''),
    exempted_vill_school_district = NULLIF(@exempted_vill_school_district, ''),
    library = NULLIF(@library, ''),
    local_school_district = NULLIF(@local_school_district, ''),
    municipal_court_district = NULLIF(@municipal_court_district, ''),
    precinct_name = NULLIF(@precinct_name, ''),
    precinct_code = NULLIF(@precinct_code, ''),
    state_board_of_education = NULLIF(@state_board_of_education, ''),
    state_representative_district = NULLIF(@state_representative_district, ''),
    state_senate_district = NULLIF(@state_senate_district, ''),
    township = NULLIF(@township, ''),
    village = NULLIF(@village, ''),
    ward = NULLIF(@ward, ''),
    primary_date = STR_TO_DATE(NULLIF(@primary_date, ''), '%m/%d/%Y'),
    primary_party = NULLIF(@primary_party, ''),
    absentee_type = NULLIF(@absentee_type, ''),
    date_application_received = STR_TO_DATE(NULLIF(@date_application_received, ''), '%m/%d/%Y %H:%i'),
    application_type = NULLIF(@application_type, ''),
    ballot_mailed_date = STR_TO_DATE(NULLIF(@ballot_mailed_date, ''), '%m/%d/%Y %H:%i'),
    ballot_returned_date = STR_TO_DATE(NULLIF(@ballot_returned_date, ''), '%m/%d/%Y %H:%i'),
    ballot_status = NULLIF(@ballot_status, ''),
    ballot_spoiled_reason = NULLIF(@ballot_spoiled_reason, '');

-- Re-enable keys
ALTER TABLE fcabs_temp ENABLE KEYS;
EOF

echo -e "${GREEN}✓ Data loaded into temporary table${NC}"

# Step 2: Get row counts
echo ""
echo -e "${GREEN}Step 2: Analyzing data...${NC}"

TEMP_COUNT=$(mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -sN -e "SELECT COUNT(*) FROM fcabs_temp;")
MAIN_COUNT_BEFORE=$(mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -sN -e "SELECT COUNT(*) FROM $TABLE_NAME;")

echo "Records in CSV file: $TEMP_COUNT"
echo "Records in main table (before): $MAIN_COUNT_BEFORE"

# Step 3: Update existing records and insert new ones
echo ""
echo -e "${GREEN}Step 3: Updating main table...${NC}"

mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" << EOF
-- Update existing records
UPDATE $TABLE_NAME main
INNER JOIN fcabs_temp temp ON main.local_id = temp.local_id
SET
    main.voter_status = temp.voter_status,
    main.county_number = temp.county_number,
    main.county_id = temp.county_id,
    main.last_name = temp.last_name,
    main.first_name = temp.first_name,
    main.middle_name = temp.middle_name,
    main.suffix = temp.suffix,
    main.date_of_birth = temp.date_of_birth,
    main.registration_date = temp.registration_date,
    main.voter_status2 = temp.voter_status2,
    main.party_affiliation = temp.party_affiliation,
    main.residential_address1 = temp.residential_address1,
    main.residential_address2 = temp.residential_address2,
    main.residential_city = temp.residential_city,
    main.residential_state = temp.residential_state,
    main.residential_zip = temp.residential_zip,
    main.residential_zip_plus4 = temp.residential_zip_plus4,
    main.residential_country = temp.residential_country,
    main.residential_postalcode = temp.residential_postalcode,
    main.mailing_address1 = temp.mailing_address1,
    main.mailing_address2 = temp.mailing_address2,
    main.mailing_address3 = temp.mailing_address3,
    main.mailing_city = temp.mailing_city,
    main.mailing_state = temp.mailing_state,
    main.mailing_zip = temp.mailing_zip,
    main.mailing_zip_plus4 = temp.mailing_zip_plus4,
    main.mailing_country = temp.mailing_country,
    main.mailing_postal_code = temp.mailing_postal_code,
    main.career_center = temp.career_center,
    main.city = temp.city,
    main.city_school_district = temp.city_school_district,
    main.county_court_district = temp.county_court_district,
    main.congressional_district = temp.congressional_district,
    main.court_of_appeals = temp.court_of_appeals,
    main.edu_service_center_district = temp.edu_service_center_district,
    main.exempted_vill_school_district = temp.exempted_vill_school_district,
    main.library = temp.library,
    main.local_school_district = temp.local_school_district,
    main.municipal_court_district = temp.municipal_court_district,
    main.precinct_name = temp.precinct_name,
    main.precinct_code = temp.precinct_code,
    main.state_board_of_education = temp.state_board_of_education,
    main.state_representative_district = temp.state_representative_district,
    main.state_senate_district = temp.state_senate_district,
    main.township = temp.township,
    main.village = temp.village,
    main.ward = temp.ward,
    main.primary_date = temp.primary_date,
    main.primary_party = temp.primary_party,
    main.absentee_type = temp.absentee_type,
    main.date_application_received = temp.date_application_received,
    main.application_type = temp.application_type,
    main.ballot_mailed_date = temp.ballot_mailed_date,
    main.ballot_returned_date = temp.ballot_returned_date,
    main.ballot_status = temp.ballot_status,
    main.ballot_spoiled_reason = temp.ballot_spoiled_reason;

-- Insert new records
INSERT INTO $TABLE_NAME
SELECT temp.*
FROM fcabs_temp temp
LEFT JOIN $TABLE_NAME main ON temp.local_id = main.local_id
WHERE main.local_id IS NULL;

-- Clean up temporary table
DROP TABLE fcabs_temp;
EOF

MAIN_COUNT_AFTER=$(mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -sN -e "SELECT COUNT(*) FROM $TABLE_NAME;")
NEW_RECORDS=$((MAIN_COUNT_AFTER - MAIN_COUNT_BEFORE))

echo -e "${GREEN}✓ Main table updated${NC}"
echo "Records in main table (after): $MAIN_COUNT_AFTER"
echo "New records added: $NEW_RECORDS"

# Step 4: Update dates in viewer files
echo ""
echo -e "${GREEN}Step 4: Updating 'Data as of' date in viewer files...${NC}"

# Update PHP file
if [ -f "voter_viewer.php" ]; then
    sed -i "s/Data as of: [^<]*/Data as of: $NEW_DATE/" voter_viewer.php
    echo -e "${GREEN}✓ Updated voter_viewer.php${NC}"
else
    echo -e "${YELLOW}⚠ voter_viewer.php not found${NC}"
fi

# Update Python file
if [ -f "voter_viewer.py" ]; then
    sed -i "s/Data as of: [^<]*/Data as of: $NEW_DATE/" voter_viewer.py
    echo -e "${GREEN}✓ Updated voter_viewer.py${NC}"
else
    echo -e "${YELLOW}⚠ voter_viewer.py not found${NC}"
fi

# Step 5: Deploy to production
echo ""
echo -e "${GREEN}Step 5: Deploying to production...${NC}"

if [ -f "deploy_viewer.sh" ]; then
    # Ask for confirmation
    read -p "Deploy to /var/www/html/ionic/fcabs/? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ./deploy_viewer.sh
        echo -e "${GREEN}✓ Deployed to production${NC}"
        DEPLOYED=true
    else
        echo -e "${YELLOW}⚠ Deployment skipped${NC}"
        DEPLOYED=false
    fi
else
    echo -e "${YELLOW}⚠ deploy_viewer.sh not found, skipping deployment${NC}"
    DEPLOYED=false
fi

# Step 6: Summary
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Update Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Summary:"
echo "  • CSV file: $CSV_FILE"
echo "  • Data date: $NEW_DATE"
echo "  • Records processed: $TEMP_COUNT"
echo "  • Records in database: $MAIN_COUNT_AFTER"
echo "  • New records added: $NEW_RECORDS"
if [ "$DEPLOYED" = true ]; then
    echo "  • Deployed: Yes"
else
    echo "  • Deployed: No"
fi
echo ""
echo "Next steps:"
if [ "$DEPLOYED" = false ]; then
    echo "  1. If needed, run: ./deploy_viewer.sh"
    echo "  2. Commit changes: git add . && git commit -m 'Update data for $NEW_DATE'"
else
    echo "  1. Verify the site looks correct"
    echo "  2. Commit changes: git add . && git commit -m 'Update data for $NEW_DATE'"
fi
echo ""

