#!/bin/bash
tmpfile="/tmp/sshmenurc-jessica"

echo "Removing old temp file..."
rm -f "$tmpfile"

echo "Creating new temp file..."
touch "$tmpfile"
chmod 600 "$tmpfile"

save_tmp() {
    echo "save_tmp() called with argument: '$1'"
    if [[ -z "$1" ]]; then
        echo "❌ No data provided to save_tmp()"
        return 1
    fi
    echo "$1" >> "$tmpfile"
    echo "✅ Data written: $(cat "$tmpfile")"
}

save_tmp "Test data entry"
cat "$tmpfile"
