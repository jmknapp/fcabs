#!/bin/bash

# Script to update fcabs database and refresh the "Data as of" date
# Usage: ./update_and_refresh.sh <csv_file>

set -e  # Exit on any error

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Load environment variables from .env file
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
else
    echo -e "${RED}Error: .env file not found${NC}"
    echo "Please copy .env.example to .env and configure your database credentials."
    exit 1
fi

# Database configuration from environment variables
DB_USER="${DB_USER}"
DB_PASS="${DB_PASS}"
DB_NAME="${DB_NAME}"
TABLE_NAME="${TABLE_NAME}"

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

# Use current date
NEW_DATE=$(date "+%B %-d, %Y")

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

# Step 1: Get record count before clearing
echo ""
echo -e "${GREEN}Step 1: Checking current data...${NC}"

MAIN_COUNT_BEFORE=$(mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -sN -e "SELECT COUNT(*) FROM $TABLE_NAME;")
echo "Records in table (before): $MAIN_COUNT_BEFORE"

# Step 2: Clear the table
echo ""
echo -e "${GREEN}Step 2: Clearing existing data...${NC}"

mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" << EOF
TRUNCATE TABLE $TABLE_NAME;
EOF

echo -e "${GREEN}✓ Table cleared${NC}"

# Step 3: Load new data
echo ""
echo -e "${GREEN}Step 3: Loading new data from CSV...${NC}"

mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" << EOF
-- Disable keys for faster loading
ALTER TABLE $TABLE_NAME DISABLE KEYS;

-- Load data from CSV (preprocessed with underscores and status field)
-- First specify CSV column order, then map to table columns
LOAD DATA LOCAL INFILE '$CSV_FILE'
INTO TABLE $TABLE_NAME
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(@PRECINCT_NAME, @PRECINCT_CODE, @PRECINCT_CODE_WITH_SPLIT, @CITY_OR_VILLAGE,
 @SCHOOL_DISTRICT, @TOWNSHIP, @HOUSE_DISTRICT, @SENATE_DISTRICT, @CONGRESS_DISTRICT,
 @POLICE_DISTRICT, @ROAD_DISTRICT, @FIRE_DISTRICT, @PARK_DISTRICT, @COURT_APPEALS_NAME,
 @BOARD_OF_ED_NAME, @PARTY, @DATE_MAILED, @DATE_REGISTERED, @LOCAL_ID, @YEAR_OF_BIRTH,
 @FIRST_NAME, @MIDDLE_NAME, @LAST_NAME, @SUFFIX_NAME, @ADDRESS_LINE_1, @ADDRESS_LINE_2,
 @ADDRESS_LINE_3, @ADDRESS_LINE_4, @CITY, @STATE, @ZIP, @ZIP_PLUS_4, @MAILED,
 @DATE_REQUESTED, @DATE_RETURNED, @BALLOT_STYLE, @status)
SET
    precinct_name = NULLIF(@PRECINCT_NAME, ''),
    precinct_code = NULLIF(@PRECINCT_CODE, ''),
    precinct_code_with_split = NULLIF(@PRECINCT_CODE_WITH_SPLIT, ''),
    city_or_village = NULLIF(@CITY_OR_VILLAGE, ''),
    school_district = NULLIF(@SCHOOL_DISTRICT, ''),
    township = NULLIF(@TOWNSHIP, ''),
    house_district = NULLIF(@HOUSE_DISTRICT, ''),
    senate_district = NULLIF(@SENATE_DISTRICT, ''),
    congress_district = NULLIF(@CONGRESS_DISTRICT, ''),
    police_district = NULLIF(@POLICE_DISTRICT, ''),
    road_district = NULLIF(@ROAD_DISTRICT, ''),
    fire_district = NULLIF(@FIRE_DISTRICT, ''),
    park_district = NULLIF(@PARK_DISTRICT, ''),
    court_appeals_name = NULLIF(@COURT_APPEALS_NAME, ''),
    board_of_ed_name = NULLIF(@BOARD_OF_ED_NAME, ''),
    party = NULLIF(@PARTY, ''),
    date_mailed = STR_TO_DATE(NULLIF(@DATE_MAILED, ''), '%m/%d/%Y'),
    date_registered = STR_TO_DATE(NULLIF(@DATE_REGISTERED, ''), '%m/%d/%Y'),
    local_id = NULLIF(@LOCAL_ID, ''),
    year_of_birth = NULLIF(@YEAR_OF_BIRTH, ''),
    first_name = NULLIF(@FIRST_NAME, ''),
    middle_name = NULLIF(@MIDDLE_NAME, ''),
    last_name = NULLIF(@LAST_NAME, ''),
    suffix_name = NULLIF(@SUFFIX_NAME, ''),
    address_line_1 = NULLIF(@ADDRESS_LINE_1, ''),
    address_line_2 = NULLIF(@ADDRESS_LINE_2, ''),
    address_line_3 = NULLIF(@ADDRESS_LINE_3, ''),
    address_line_4 = NULLIF(@ADDRESS_LINE_4, ''),
    city = NULLIF(@CITY, ''),
    state = NULLIF(@STATE, ''),
    zip = NULLIF(@ZIP, ''),
    zip_plus_4 = NULLIF(@ZIP_PLUS_4, ''),
    mailed = NULLIF(@MAILED, ''),
    date_requested = STR_TO_DATE(NULLIF(@DATE_REQUESTED, ''), '%m/%d/%Y'),
    date_returned = STR_TO_DATE(NULLIF(@DATE_RETURNED, ''), '%m/%d/%Y'),
    ballot_style = NULLIF(@BALLOT_STYLE, ''),
    status = NULLIF(@status, '');

-- Re-enable keys
ALTER TABLE $TABLE_NAME ENABLE KEYS;
EOF

MAIN_COUNT_AFTER=$(mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -sN -e "SELECT COUNT(*) FROM $TABLE_NAME;")

echo -e "${GREEN}✓ Data loaded successfully${NC}"
echo "Records loaded: $MAIN_COUNT_AFTER"

# Step 4: Update dates in viewer files
echo ""
echo -e "${GREEN}Step 4: Updating 'Data as of' date in viewer files...${NC}"

# Update PHP file
if [ -f "voter_viewer.php" ]; then
    sed -i "s|Data as of: .*</strong>|Data as of: <strong>$NEW_DATE</strong>|" voter_viewer.php
    echo -e "${GREEN}✓ Updated voter_viewer.php${NC}"
else
    echo -e "${YELLOW}⚠ voter_viewer.php not found${NC}"
fi

# Update Python file
if [ -f "voter_viewer.py" ]; then
    sed -i "s|Data as of: .*</strong>|Data as of: <strong>$NEW_DATE</strong>|" voter_viewer.py
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
echo "  • Records before: $MAIN_COUNT_BEFORE"
echo "  • Records after: $MAIN_COUNT_AFTER"
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

