# Manual Deployment Instructions

If the automated script requires interaction, follow these manual steps:

## Step 1: Create Directory

```bash
sudo mkdir -p /var/www/html/ionic/fcabs
```

## Step 2: Copy Application File

```bash
sudo cp /home/jmknapp/indivisible/voter_viewer.php /var/www/html/ionic/fcabs/index.php
```

## Step 3: Create .htaccess File

```bash
sudo tee /var/www/html/ionic/fcabs/.htaccess > /dev/null << 'EOF'
# Franklin County Voter Viewer - Apache Configuration

<IfModule mod_rewrite.c>
    RewriteEngine On
    RewriteBase /ionic/fcabs/
</IfModule>

<FilesMatch "\.(sql|txt|csv|sh|py|md)$">
    Require all denied
</FilesMatch>

AddDefaultCharset UTF-8

<IfModule mod_deflate.c>
    AddOutputFilterByType DEFLATE text/html text/plain text/xml text/css text/javascript application/javascript
</IfModule>

<IfModule mod_headers.c>
    Header set X-Content-Type-Options "nosniff"
    Header set X-Frame-Options "SAMEORIGIN"
    Header set X-XSS-Protection "1; mode=block"
</IfModule>
EOF
```

## Step 4: Set Ownership

```bash
sudo chown -R www-data:www-data /var/www/html/ionic/fcabs
```

(If your system uses `apache` instead of `www-data`, use that)

## Step 5: Set Permissions

```bash
sudo chmod 755 /var/www/html/ionic/fcabs
sudo chmod 644 /var/www/html/ionic/fcabs/index.php
sudo chmod 644 /var/www/html/ionic/fcabs/.htaccess
```

## Step 6: Stop PHP Built-in Server (if running)

```bash
pkill -f "php -S.*voter_viewer.php"
```

## Step 7: Reload Apache

```bash
sudo systemctl reload apache2
# or on some systems:
# sudo systemctl reload httpd
```

## Step 8: Test

Open in your browser:
- http://localhost/ionic/fcabs/

## Verify

```bash
# Check if file exists
ls -la /var/www/html/ionic/fcabs/

# Check permissions
stat /var/www/html/ionic/fcabs/index.php

# Test Apache
systemctl status apache2

# Test database connection
mysql -u root -pR_250108_z ohsosvoterfiles -e "SELECT COUNT(*) FROM fcabs2025;"
```

---

## Quick One-Liner (All Steps)

```bash
sudo mkdir -p /var/www/html/ionic/fcabs && \
sudo cp /home/jmknapp/indivisible/voter_viewer.php /var/www/html/ionic/fcabs/index.php && \
sudo chown -R www-data:www-data /var/www/html/ionic/fcabs && \
sudo chmod 755 /var/www/html/ionic/fcabs && \
sudo chmod 644 /var/www/html/ionic/fcabs/index.php && \
pkill -f "php -S.*voter_viewer.php" 2>/dev/null; \
echo "✅ Deployed! Access at: http://localhost/ionic/fcabs/"
```

---

## Troubleshooting

### "403 Forbidden" Error
- Check file permissions: `ls -la /var/www/html/ionic/fcabs/`
- Check Apache error log: `sudo tail -f /var/log/apache2/error.log`
- Verify ownership: `stat /var/www/html/ionic/fcabs/index.php`

### "500 Internal Server Error"
- Check PHP error log: `sudo tail -f /var/log/apache2/error.log`
- Verify MySQL connection credentials in index.php
- Test database: `mysql -u root -pR_250108_z ohsosvoterfiles -e "SELECT 1;"`

### "Connection refused" Database Error
- Check MySQL is running: `systemctl status mysql`
- Verify credentials work: `mysql -u root -pR_250108_z ohsosvoterfiles`

### Page shows PHP code instead of running
- PHP not installed: `sudo apt-get install php libapache2-mod-php php-mysql`
- Apache not processing PHP: `sudo a2enmod php8.2` (adjust version)
- Restart Apache: `sudo systemctl restart apache2`


