# Franklin County Voter Viewer - Web Interface

Two web interfaces are available to view and filter voter data from the `fcabs2025` table.

## Status Categories Available

The dropdown allows filtering by these ballot statuses:

| Status | Count | Description |
|--------|-------|-------------|
| **VAL** | 14,803 | Validated/Accepted ballots |
| **Outstanding** | 4,995 | Not yet returned |
| **IDNOMATCH** | 22 | ID doesn't match |
| **REFUSED** | 20 | Ballot refused |
| **NOSIG** | 18 | No signature |
| **NOID** | 11 | No ID provided |
| **MOVED** | 7 | Voter moved |
| **NAMECHG** | 4 | Name changed |
| **SPRET** | 1 | Special return |

---

## Option 1: PHP Version (voter_viewer.php)

### Requirements:
- PHP (any version 7.0+)
- MySQL extension for PHP
- Web server (Apache, Nginx, or PHP built-in server)

### Quick Start with PHP Built-in Server:

```bash
cd /home/jmknapp/indivisible
php -S localhost:8000 voter_viewer.php
```

Then open in your browser: **http://localhost:8000**

### Alternative: Using Apache/Nginx

If you have Apache or Nginx configured:

1. Copy or symlink the file to your web root:
   ```bash
   sudo ln -s /home/jmknapp/indivisible/voter_viewer.php /var/www/html/voters.php
   ```

2. Access at: **http://localhost/voters.php**

---

## Option 2: Python Flask Version (voter_viewer.py)

### Requirements:
- Python 3
- Flask
- mysql-connector-python

### Install Dependencies:

```bash
pip3 install flask mysql-connector-python
```

### Run the Application:

```bash
cd /home/jmknapp/indivisible
python3 voter_viewer.py
```

Or simply:
```bash
./voter_viewer.py
```

Then open in your browser: **http://localhost:5000**

---

## Features

### 🎯 Filter by Status
- Dropdown at the top shows all available status categories
- Shows count for each category
- Click to instantly filter the voter list

### 📊 Voter Table Displays:
- **Name**: Last, First Middle Initial
- **Party**: D (Democrat), R (Republican), U (Unaffiliated)
  - Color-coded: Blue for D, Red for R, Gray for U
- **Address**: Street address
- **City**: City, State ZIP
- **Precinct**: Precinct name
- **Requested**: Date ballot was requested
- **Returned**: Date ballot was returned (if applicable)
- **Status**: Color-coded badge
  - Green: VAL (validated)
  - Yellow: Outstanding
  - Red: Problems (IDNOMATCH, REFUSED, etc.)

### 📈 Statistics Bar
- Shows number of voters displayed
- Indicates if results are limited (max 1000 shown)

### 🎨 Modern UI
- Responsive design
- Clean, professional appearance
- Sticky table header for easy scrolling
- Hover effects on rows

---

## Performance Notes

- **Limit**: Shows first 1,000 voters per query for performance
- **Indexes**: Table has proper indexes on `status` and `local_id` for fast filtering
- **Sorting**: Results sorted alphabetically by last name, first name

---

## Customization

### Change Result Limit

Edit the `LIMIT 1000` in either file:

**PHP** (line ~89):
```php
$voter_query .= " ORDER BY last_name, first_name LIMIT 1000";
```

**Python** (line ~193):
```python
voter_query += " ORDER BY last_name, first_name LIMIT 1000"
```

### Change Port (Python only)

Edit the last line of `voter_viewer.py`:
```python
app.run(host='0.0.0.0', port=5000, debug=True)  # Change port here
```

### Add More Columns

To display additional fields, modify the SELECT query and add corresponding `<th>` and `<td>` elements in the HTML.

---

## Security Notes

⚠️ **Important for Production Use:**

1. **Database Password**: Currently hardcoded. For production, use environment variables:
   ```bash
   export DB_PASSWORD="R_250108_z"
   ```

2. **Access Control**: This viewer has no authentication. For public deployment:
   - Add login system
   - Use HTTPS
   - Limit access by IP or VPN

3. **SQL Injection**: Python version uses parameterized queries. PHP version uses `real_escape_string()` for safety.

---

## Troubleshooting

### PHP: "Connection failed"
- Check MySQL is running: `systemctl status mysql`
- Verify credentials in file (lines 5-8)
- Test connection: `mysql -u root -pR_250108_z ohsosvoterfiles`

### Python: "No module named 'flask'"
- Install Flask: `pip3 install flask mysql-connector-python`
- Or use virtualenv:
  ```bash
  python3 -m venv venv
  source venv/bin/activate
  pip install flask mysql-connector-python
  ```

### "Address already in use"
- Port 5000 or 8000 already taken
- Change port in startup command or script
- Or kill the existing process

### Browser shows blank page
- Check terminal for errors
- Verify database connection
- Check MySQL slow query log if performance issues

---

## Example Queries for Analysis

Once you can view the data, you might want to analyze it. Here are some useful queries:

```sql
-- Return rate by party
SELECT party, 
       COUNT(*) as total,
       SUM(CASE WHEN status='VAL' THEN 1 ELSE 0 END) as returned,
       ROUND(100.0 * SUM(CASE WHEN status='VAL' THEN 1 ELSE 0 END) / COUNT(*), 1) as return_rate
FROM fcabs2025 
GROUP BY party;

-- Outstanding ballots by precinct
SELECT precinct_name, COUNT(*) as outstanding
FROM fcabs2025
WHERE status IS NULL OR status = ''
GROUP BY precinct_name
ORDER BY outstanding DESC
LIMIT 20;

-- Average days to return ballot
SELECT AVG(DATEDIFF(date_returned, date_requested)) as avg_days
FROM fcabs2025
WHERE date_returned IS NOT NULL;
```


