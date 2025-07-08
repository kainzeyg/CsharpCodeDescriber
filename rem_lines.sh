#!/bin/bash

DIR="$1"

if [[ -z "$DIR" || ! -d "$DIR" ]]; then
  echo "Usage: $0 <directory>"
  exit 1
fi

find "$DIR" -type f | while read -r file; do
  sed -i '2,8d' "$file"
  echo "Updated: $file"
done