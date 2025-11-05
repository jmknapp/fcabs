# Updating Voter Data - Quick Guide

## Single Command Update

Use the `update_and_refresh.sh` script to update both the database and the "Data as of" date in one step:

```bash
./update_and_refresh.sh fcabs1105.csv
```

## What It Does

1. **Loads CSV data** into a temporary table
2. **Updates existing records** in the main `fcabs2025` table
3. **Inserts new records** that don't exist yet
4. **Automatically extracts the date** from the filename (e.g., `fcabs1105.csv` → "November 5, 2025")
5. **Updates the date** in both `voter_viewer.php` and `voter_viewer.py`
6. **Deploys to production** (asks for confirmation first)
7. **Shows a summary** of what was changed

## Date Format

The script automatically parses the date from filenames like:
- `fcabs1105.csv` → "November 5, 2025"
- `fcabs0104.csv` → "January 4, 2025"
- `fcabs1231.csv` → "December 31, 2025"

If the filename doesn't match this pattern, you'll be prompted to enter the date manually.

## Example Output

```
========================================
Franklin County Voter Data Update
========================================

CSV File: fcabs1105.csv
Data Date: November 5, 2025
Database: ohsosvoterfiles
Table: fcabs2025

Proceed with update? (y/n) y

Step 1: Loading CSV data into temporary table...
✓ Data loaded into temporary table

Step 2: Analyzing data...
Records in CSV file: 19881
Records in main table (before): 19753

Step 3: Updating main table...
✓ Main table updated
Records in main table (after): 19881
New records added: 128

Step 4: Updating 'Data as of' date in viewer files...
✓ Updated voter_viewer.php
✓ Updated voter_viewer.py

Step 5: Deploying to production...
Deploy to /var/www/html/ionic/fcabs/? (y/n) y
✓ Deployed to production

========================================
Update Complete!
========================================
```

## After Updating

1. **Verify the site**: Check that the data and date look correct
2. **Commit to git**: `git add . && git commit -m "Update data for November 5, 2025"`
3. **Push to GitHub**: `git push`

Note: The script handles deployment automatically (with confirmation), so you typically don't need to run `deploy_viewer.sh` separately.

## Alternative: Manual Steps

If you prefer to do each step separately:

1. **Update database only**: `./update_fcabs.sh fcabs1105.csv`
2. **Update date only**: `./update_data_date.sh "November 5, 2025"`

## Troubleshooting

- **File not found**: Make sure the CSV file is in the current directory
- **Permission denied**: Run `chmod +x update_and_refresh.sh`
- **MySQL error**: Check that the database credentials are correct
- **Date not parsing**: The script will prompt you to enter the date manually

