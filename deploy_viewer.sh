#!/bin/bash
# Deployment script for Franklin County Voter Viewer
# Deploys to /var/www/html/ionic/fcabs

set -e  # Exit on error

SOURCE_DIR="/home/jmknapp/indivisible"
DEPLOY_DIR="/var/www/html/ionic/fcabs"
APP_FILE="voter_viewer.php"

echo "================================================"
echo "Franklin County Voter Viewer - Deployment"
echo "================================================"
echo ""
echo "Source: $SOURCE_DIR/$APP_FILE"
echo "Target: $DEPLOY_DIR/"
echo ""

# Check if source file exists
if [ ! -f "$SOURCE_DIR/$APP_FILE" ]; then
    echo "❌ Error: Source file not found: $SOURCE_DIR/$APP_FILE"
    exit 1
fi

# Create target directory if it doesn't exist
if [ ! -d "$DEPLOY_DIR" ]; then
    echo "📁 Creating deployment directory..."
    sudo mkdir -p "$DEPLOY_DIR"
fi

# Copy the application file
echo "📋 Copying application file..."
sudo cp "$SOURCE_DIR/$APP_FILE" "$DEPLOY_DIR/index.php"

# Copy favicon and logo files
echo "🎨 Copying favicon and logo files..."
if [ -f "$SOURCE_DIR/favicon.ico" ]; then
    sudo cp "$SOURCE_DIR/favicon.ico" "$DEPLOY_DIR/"
    sudo cp "$SOURCE_DIR/favicon-16x16.png" "$DEPLOY_DIR/" 2>/dev/null || true
    sudo cp "$SOURCE_DIR/favicon-32x32.png" "$DEPLOY_DIR/" 2>/dev/null || true
    echo "   Favicon files copied"
else
    echo "   ⚠️  Warning: favicon.ico not found"
fi
if [ -f "$SOURCE_DIR/fearsomefrog.png" ]; then
    sudo cp "$SOURCE_DIR/fearsomefrog.png" "$DEPLOY_DIR/"
    echo "   Logo file copied"
else
    echo "   ⚠️  Warning: fearsomefrog.png not found"
fi

# Create .htaccess for Apache configuration
echo "⚙️  Creating .htaccess configuration..."
sudo tee "$DEPLOY_DIR/.htaccess" > /dev/null << 'EOF'
# Franklin County Voter Viewer - Apache Configuration

# Enable rewrite engine
<IfModule mod_rewrite.c>
    RewriteEngine On
    RewriteBase /ionic/fcabs/
</IfModule>

# Deny access to sensitive files
<FilesMatch "\.(sql|txt|csv|sh|py|md)$">
    Require all denied
</FilesMatch>

# Set default charset
AddDefaultCharset UTF-8

# Enable compression for better performance
<IfModule mod_deflate.c>
    AddOutputFilterByType DEFLATE text/html text/plain text/xml text/css text/javascript application/javascript
</IfModule>

# Cache static assets
<IfModule mod_expires.c>
    ExpiresActive On
    ExpiresByType text/css "access plus 1 month"
    ExpiresByType application/javascript "access plus 1 month"
</IfModule>

# Security headers
<IfModule mod_headers.c>
    Header set X-Content-Type-Options "nosniff"
    Header set X-Frame-Options "SAMEORIGIN"
    Header set X-XSS-Protection "1; mode=block"
</IfModule>
EOF

# Create a simple README in the deployment directory
echo "📝 Creating deployment info file..."
sudo tee "$DEPLOY_DIR/README.txt" > /dev/null << EOF
Franklin County Voter Viewer
Deployed: $(date)
Source: $SOURCE_DIR/$APP_FILE

Access this application at:
http://localhost/ionic/fcabs/
or
http://$(hostname -I | awk '{print $1}')/ionic/fcabs/

To redeploy:
$SOURCE_DIR/deploy_viewer.sh

Database: ohsosvoterfiles.fcabs1004
EOF

# Set proper ownership (assuming www-data for Apache)
echo "👤 Setting file ownership..."
if id "www-data" &>/dev/null; then
    sudo chown -R www-data:www-data "$DEPLOY_DIR"
    echo "   Owner set to: www-data"
elif id "apache" &>/dev/null; then
    sudo chown -R apache:apache "$DEPLOY_DIR"
    echo "   Owner set to: apache"
else
    echo "   ⚠️  Warning: Could not determine web server user (www-data/apache not found)"
    echo "   Files owned by: $(stat -c '%U:%G' $DEPLOY_DIR)"
fi

# Set proper permissions
echo "🔒 Setting file permissions..."
sudo chmod 755 "$DEPLOY_DIR"
sudo chmod 644 "$DEPLOY_DIR/index.php"
sudo chmod 644 "$DEPLOY_DIR/.htaccess"
sudo chmod 644 "$DEPLOY_DIR/README.txt"
sudo chmod 644 "$DEPLOY_DIR"/favicon* 2>/dev/null || true
sudo chmod 644 "$DEPLOY_DIR/fearsomefrog.png" 2>/dev/null || true

# Stop the PHP built-in server if it's running
if pgrep -f "php -S.*voter_viewer.php" > /dev/null; then
    echo "🛑 Stopping PHP built-in server..."
    pkill -f "php -S.*voter_viewer.php" || true
    echo "   PHP built-in server stopped"
fi

# Test Apache/web server configuration
echo ""
echo "🔍 Checking web server status..."
if systemctl is-active --quiet apache2; then
    echo "   ✅ Apache2 is running"
    WEB_SERVER="apache2"
elif systemctl is-active --quiet httpd; then
    echo "   ✅ httpd is running"
    WEB_SERVER="httpd"
elif systemctl is-active --quiet nginx; then
    echo "   ✅ Nginx is running"
    WEB_SERVER="nginx"
else
    echo "   ⚠️  Warning: Could not detect a running web server"
    WEB_SERVER="unknown"
fi

# Reload web server if needed
if [ "$WEB_SERVER" != "unknown" ]; then
    read -p "Reload $WEB_SERVER to apply changes? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "♻️  Reloading $WEB_SERVER..."
        sudo systemctl reload "$WEB_SERVER"
        echo "   ✅ $WEB_SERVER reloaded"
    fi
fi

# Display completion message
echo ""
echo "================================================"
echo "✅ Deployment Complete!"
echo "================================================"
echo ""
echo "Application deployed to: $DEPLOY_DIR"
echo ""
echo "Access your application at:"
echo "  • http://localhost/ionic/fcabs/"
if command -v hostname &> /dev/null; then
    IP_ADDR=$(hostname -I | awk '{print $1}')
    if [ ! -z "$IP_ADDR" ]; then
        echo "  • http://$IP_ADDR/ionic/fcabs/"
    fi
fi
echo ""
echo "Files deployed:"
echo "  • index.php (main application)"
echo "  • .htaccess (Apache configuration)"
echo "  • README.txt (deployment info)"
echo "  • favicon.ico, favicon-*.png (site icons)"
echo "  • fearsomefrog.png (logo image)"
echo ""

# Check for potential issues
echo "🔍 Quick checks:"

# Check PHP MySQL extension
if php -m | grep -q mysqli; then
    echo "  ✅ PHP mysqli extension is installed"
else
    echo "  ⚠️  Warning: PHP mysqli extension may not be installed"
    echo "     Install with: sudo apt-get install php-mysql"
fi

# Check database connectivity
if mysql -u root -pR_250108_z -e "USE ohsosvoterfiles; SELECT COUNT(*) FROM fcabs2025;" &>/dev/null; then
    echo "  ✅ Database connection successful"
else
    echo "  ⚠️  Warning: Could not connect to database"
    echo "     Check MySQL credentials and table name in index.php"
fi

# Check directory permissions
if [ -r "$DEPLOY_DIR/index.php" ]; then
    echo "  ✅ File permissions look good"
else
    echo "  ⚠️  Warning: File permissions may need adjustment"
fi

echo ""
echo "================================================"
echo "Next steps:"
echo "  1. Open http://localhost/ionic/fcabs/ in your browser"
echo "  2. Test the status dropdown filter"
echo "  3. Review README.txt in deployment directory"
echo "================================================"


