# Franklin County Absentee Ballot Data - Update Strategy

## Overview
This document explains the strategies for updating the `fcabs2025` table with daily CSV files from Franklin County.

## Current Data Structure

- **Total Records**: ~19,885 voters
- **Primary Identifier**: `local_id` (mostly unique, 99.98%)
- **Edge Case**: Some voters have multiple ballot requests (different `date_requested`)
- **Updatable Fields**: `status`, `date_returned`, addresses, etc.

## Update Strategies

### Strategy 1: Keep Latest Record Per Voter (RECOMMENDED)
**Script**: `update_fcabs.sh`

**Best for**: 
- Daily snapshots showing current ballot status
- When you only care about the most recent state per voter
- Cleaner data with one record per voter

**How it works**:
1. Loads new CSV into temporary table
2. Updates existing records (matched by `local_id`)
3. Inserts new voters not in the database
4. Result: One current record per voter

**Usage**:
```bash
./update_fcabs.sh fcabs1005.csv
```

**Pros**:
- ✓ Simple, clean data (one voter = one record)
- ✓ Fast queries
- ✓ Easier to understand and analyze
- ✓ No duplicates to worry about

**Cons**:
- ✗ Loses historical changes
- ✗ Can't track when status changed
- ✗ Can't see multiple ballot requests

---

### Strategy 2: Keep All Historical Records
**Script**: `update_fcabs_history.sh`

**Best for**:
- Tracking voter behavior over time
- Seeing multiple ballot requests per voter
- Audit trail requirements
- Analyzing status change patterns

**How it works**:
1. Uses unique index on (`local_id` + `date_requested`)
2. Updates records with same voter+date combination
3. Inserts truly new records
4. Result: Multiple records per voter with different request dates

**Usage**:
```bash
./update_fcabs_history.sh fcabs1005.csv
```

**First-time setup** (run once):
```bash
mysql -u root -pR_250108_z ohsosvoterfiles -e "
ALTER TABLE fcabs1004 
ADD UNIQUE INDEX idx_voter_request (local_id, date_requested);"
```

**Pros**:
- ✓ Complete historical record
- ✓ Can track changes over time
- ✓ Shows multiple ballot requests
- ✓ Audit trail preserved

**Cons**:
- ✗ More complex queries (need to filter for latest)
- ✗ Larger database size
- ✗ Need to handle duplicates in analysis

---

### Strategy 3: Complete Replacement (Simple but Destructive)

**Best for**: 
- When the CSV is always a complete snapshot
- When historical data doesn't matter
- Quick and simple updates

**How it works**:
```bash
mysql -u root -pR_250108_z ohsosvoterfiles << EOF
TRUNCATE TABLE fcabs1004;
LOAD DATA LOCAL INFILE 'fcabs1005.csv'
INTO TABLE fcabs1004
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(precinct_name, precinct_code, ... , status)
SET
 date_mailed = STR_TO_DATE(SUBSTRING_INDEX(@date_mailed, ' ', 1), '%m/%d/%Y'),
 ...;
EOF
```

**Pros**:
- ✓ Very simple
- ✓ Always matches source file exactly
- ✓ No duplicate concerns

**Cons**:
- ✗ Loses ALL previous data
- ✗ No way to track changes
- ✗ If file is incomplete, you lose data

---

## Recommendation

**Start with Strategy 1 (Latest Record)** unless you specifically need historical tracking.

### When to use each:

| Need | Strategy |
|------|----------|
| Current ballot status dashboard | Strategy 1 |
| "Who hasn't returned their ballot?" | Strategy 1 |
| "When did status change to VAL?" | Strategy 2 |
| "How many voters requested multiple ballots?" | Strategy 2 |
| Quick daily refresh, no history needed | Strategy 3 |

## Query Examples

### Strategy 1 (Latest Record):
```sql
-- Simple: one record per voter
SELECT COUNT(*) FROM fcabs1004 WHERE status = 'VAL';
SELECT party, COUNT(*) FROM fcabs1004 GROUP BY party;
```

### Strategy 2 (Historical):
```sql
-- Get latest record per voter
SELECT * FROM fcabs1004 f1
WHERE date_requested = (
    SELECT MAX(date_requested) 
    FROM fcabs1004 f2 
    WHERE f2.local_id = f1.local_id
);

-- Find voters with multiple requests
SELECT local_id, COUNT(*) as requests
FROM fcabs1004
GROUP BY local_id
HAVING COUNT(*) > 1;
```

## Automation

### Daily Cron Job Example:
```bash
# Add to crontab: crontab -e
0 2 * * * /home/jmknapp/indivisible/update_fcabs.sh /home/jmknapp/indivisible/fcabs_$(date +\%m\%d).csv >> /home/jmknapp/indivisible/update.log 2>&1
```

## Backup Before Updates

**Always backup before major updates:**
```bash
mysqldump -u root -pR_250108_z ohsosvoterfiles fcabs1004 > fcabs1004_backup_$(date +%Y%m%d).sql
```

## Monitoring

Check for issues after update:
```sql
-- Verify record counts
SELECT COUNT(*) FROM fcabs1004;

-- Check for missing dates
SELECT COUNT(*) FROM fcabs1004 WHERE date_requested IS NULL;

-- Verify data quality
SELECT COUNT(DISTINCT local_id) as unique_voters FROM fcabs1004;
```

