# Security Configuration

## Database Credentials

Database credentials are now stored in a `.env` file that is **NOT committed to Git**. This keeps your sensitive information secure.

### Setup

1. **Copy the example file:**
   ```bash
   cp .env.example .env
   ```

2. **Edit `.env` with your actual credentials:**
   ```bash
   nano .env
   ```

3. **Never commit `.env` to Git** - it's already in `.gitignore`

### File Structure

**`.env`** (not in Git):
```
DB_HOST=localhost
DB_USER=root
DB_PASS=your_actual_password
DB_NAME=ohsosvoterfiles
TABLE_NAME=fcabs2025
```

**`.env.example`** (committed to Git):
```
DB_HOST=localhost
DB_USER=your_mysql_user
DB_PASS=your_mysql_password
DB_NAME=ohsosvoterfiles
TABLE_NAME=fcabs2025
```

### Files That Use .env

All scripts now read credentials from `.env`:

- `voter_viewer.php` - Web viewer (PHP)
- `voter_viewer.py` - Web viewer (Python)
- `update_and_refresh.sh` - Combined update script
- `update_fcabs.sh` - Database update
- `update_fcabs_history.sh` - Historical update
- `cleanup_duplicates.sh` - Duplicate cleanup
- `deploy_viewer.sh` - Deployment script

### Important Notes

1. **`.env` is in `.gitignore`** - Your credentials will not be pushed to GitHub
2. **Deploy copies `.env`** - The `deploy_viewer.sh` script copies `.env` to the production directory
3. **Keep it secure** - Set appropriate file permissions:
   ```bash
   chmod 600 .env
   ```

### Removing Credentials from Git History

If credentials were previously committed, they need to be removed from Git history:

```bash
# This has already been done for this repository
# If you need to do it again, use:
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch voter_viewer.php voter_viewer.py *.sh" \
  --prune-empty --tag-name-filter cat -- --all

git push origin --force --all
```

## Best Practices

1. ✅ **DO** use `.env` for all sensitive credentials
2. ✅ **DO** keep `.env` in `.gitignore`
3. ✅ **DO** set restrictive permissions on `.env` (600 or 640)
4. ✅ **DO** use `.env.example` as a template for others
5. ❌ **DON'T** commit `.env` to Git
6. ❌ **DON'T** share your `.env` file publicly
7. ❌ **DON'T** hardcode credentials in scripts

