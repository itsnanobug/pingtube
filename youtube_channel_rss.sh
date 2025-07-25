#!/bin/bash
# Interactive YouTube RSS extractor using <link ... application/rss+xml ...>
# Works reliably for @handles and /channel/ links

REQUIRED_PKGS=("curl" "grep" "sed")

for pkg in "${REQUIRED_PKGS[@]}"; do
    if ! command -v "$pkg" &>/dev/null; then
        echo "Installing missing package: $pkg ..."
        sudo apt update -qq >/dev/null
        sudo apt install -y "$pkg" >/dev/null 2>&1
    fi
done

read -rp "Enter YouTube channel URL: " URL
if [ -z "$URL" ]; then
    echo "No URL entered. Exiting."
    exit 1
fi

TMPFILE=$(mktemp)
echo "Fetching page from YouTube..."
curl -sL "$URL" -o "$TMPFILE"

# Extract the href from the RSS <link> tag
RSS_URL=$(grep -oP 'type="application/rss\+xml"[^>]+href="[^"]+' "$TMPFILE" | \
           sed -E 's/.*href="([^"]+)/\1/' | head -n 1)

rm "$TMPFILE"

if [ -z "$RSS_URL" ]; then
    echo "Error: Could not find RSS link on $URL"
    exit 1
fi

# Extract channel_id from URL
CHANNEL_ID=$(echo "$RSS_URL" | sed -E 's/.*channel_id=([^&]+).*/\1/')

echo
echo "Input URL  : $URL"
echo "Channel ID : $CHANNEL_ID"
echo "RSS feed   : $RSS_URL"
echo
