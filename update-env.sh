#!/bin/bash
# Usage: sudo ./update-env.sh KEY VALUE

set -euo pipefail

KEY="$1"
VALUE="$2"
FILE="/etc/environment"

# Escape double quotes
ESCAPED_VALUE=$(printf '%s' "$VALUE" | sed 's/"/\\"/g')

if grep -qE "^${KEY}=" "$FILE"; then
    sudo sed -i "s|^${KEY}=.*|${KEY}=\"${ESCAPED_VALUE}\"|" "$FILE"
else
    echo "${KEY}=\"${ESCAPED_VALUE}\"" | sudo tee -a "$FILE" > /dev/null
fi
