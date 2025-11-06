#!/usr/bin/env bash
set -euo pipefail
BASE='https://electionlink.franklincountyohio.gov/portals/ElectionVault/PublicRecords.aspx'
EVENTTARGET='ctl00$ElectionVaultMaster$gvRecord$cell0_0$TC$btnDownload'
OUT='/tmp/fcabs.csv'  # save as CSV, overwriting if it exists

# 1) Get the page to grab cookies + hidden fields
curl -sS "$BASE" -c cookies.txt -o page.html

# 2) Extract hidden fields
VIEWSTATE=$(grep -oP 'id="__VIEWSTATE"[^>]*value="\K[^"]+' page.html | head -1)
VIEWSTATEGEN=$(grep -oP 'id="__VIEWSTATEGENERATOR"[^>]*value="\K[^"]+' page.html | head -1)
EVENTVALID=$(grep -oP 'id="__EVENTVALIDATION"[^>]*value="\K[^"]+' page.html | head -1)
REQVERTOKEN=$(grep -oP 'name="__RequestVerificationToken"[^>]*value="\K[^"]+' page.html | head -1)

# 3) Post back to trigger the file download (curl will overwrite OUT if it exists)
curl -sS "$BASE" \
  -b cookies.txt -c cookies.txt \
  --data-urlencode "__EVENTTARGET=$EVENTTARGET" \
  --data-urlencode "__EVENTARGUMENT=" \
  --data-urlencode "__VIEWSTATE=$VIEWSTATE" \
  --data-urlencode "__VIEWSTATEGENERATOR=$VIEWSTATEGEN" \
  --data-urlencode "__EVENTVALIDATION=$EVENTVALID" \
  --data-urlencode "__RequestVerificationToken=$REQVERTOKEN" \
  -o "$OUT"

echo "Downloaded: $OUT"

# Preprocess the CSV
echo "Preprocessing CSV..."

# Convert DOS line endings to Unix
dos2unix "$OUT" 2>/dev/null || sed -i 's/\r$//' "$OUT"

# Replace spaces with underscores in header, change VAL/REJECTED to status
HEADER=$(head -1 "$OUT")
# Replace spaces with underscores and VAL/REJECTED with status
NEW_HEADER=$(echo "$HEADER" | sed 's/ /_/g' | sed 's/VAL\/REJECTED/status/g')
# Create temp file with new header and original data
TEMP_FILE="${OUT}.tmp"
echo "$NEW_HEADER" > "$TEMP_FILE"
tail -n +2 "$OUT" >> "$TEMP_FILE"
mv "$TEMP_FILE" "$OUT"
echo "Saved: $OUT"

# Update database with the new file
/home/jmknapp/indivisible/update_and_refresh.sh "$OUT"
