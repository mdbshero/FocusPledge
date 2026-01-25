#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || echo ".")"
cd "$ROOT_DIR"

paths=(lib android ios macos web test assets)
pattern='\b(Bet|Gamble|Wager|Odds|Jackpot|Win money|Prize|Betting)\b'

echo "Scanning project for forbidden terms..."
found=0
for p in "${paths[@]}"; do
  if [ -d "$p" ]; then
    out=$(grep -RInE --exclude-dir={.git,build,".dart_tool"} --color=always "$pattern" "$p" || true)
    if [ -n "$out" ]; then
      echo "$out"
      found=1
    fi
  fi
done

if [ "$found" -ne 0 ]; then
  echo "\nForbidden terms detected. Replace with approved terminology per docs/ios-development-plan.md#Terminology." >&2
  exit 1
fi

echo "No forbidden terms found." 
exit 0
