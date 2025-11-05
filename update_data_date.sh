#!/bin/bash
# Update the "Data as of" date in the voter viewer files
# Usage: ./update_data_date.sh "October 5, 2025"
#    or: ./update_data_date.sh  (prompts for date)

SOURCE_DIR="/home/jmknapp/indivisible"
PHP_FILE="$SOURCE_DIR/voter_viewer.php"
PY_FILE="$SOURCE_DIR/voter_viewer.py"
DEPLOY_DIR="/var/www/html/ionic/fcabs"

# Get the new date
if [ -z "$1" ]; then
    echo "Current date in files:"
    grep -A 1 "Data as of:" "$PHP_FILE" | grep "strong" | sed 's/.*<strong>\(.*\)<\/strong>.*/  \1/'
    echo ""
    read -p "Enter new date (e.g., October 5, 2025): " NEW_DATE
else
    NEW_DATE="$1"
fi

if [ -z "$NEW_DATE" ]; then
    echo "Error: No date provided"
    exit 1
fi

echo "Updating data date to: $NEW_DATE"
echo ""

# Update PHP file
if [ -f "$PHP_FILE" ]; then
    sed -i "s/Data as of: <strong>.*<\/strong>/Data as of: <strong>$NEW_DATE<\/strong>/" "$PHP_FILE"
    echo "✅ Updated: $PHP_FILE"
else
    echo "⚠️  Not found: $PHP_FILE"
fi

# Update Python file
if [ -f "$PY_FILE" ]; then
    sed -i "s/Data as of: <strong>.*<\/strong>/Data as of: <strong>$NEW_DATE<\/strong>/" "$PY_FILE"
    echo "✅ Updated: $PY_FILE"
else
    echo "⚠️  Not found: $PY_FILE"
fi

# Update deployed version if it exists
if [ -f "$DEPLOY_DIR/index.php" ]; then
    echo ""
    read -p "Update deployed version at $DEPLOY_DIR? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo sed -i "s/Data as of: <strong>.*<\/strong>/Data as of: <strong>$NEW_DATE<\/strong>/" "$DEPLOY_DIR/index.php"
        echo "✅ Updated: $DEPLOY_DIR/index.php"
        
        # Optionally reload Apache
        if systemctl is-active --quiet apache2; then
            sudo systemctl reload apache2
            echo "✅ Apache reloaded"
        elif systemctl is-active --quiet httpd; then
            sudo systemctl reload httpd
            echo "✅ httpd reloaded"
        fi
    fi
fi

echo ""
echo "✅ Data date update complete!"
echo "   New date: $NEW_DATE"


