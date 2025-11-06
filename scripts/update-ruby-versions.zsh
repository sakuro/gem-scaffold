#!/usr/bin/env zsh

# Generate ruby.json with maintained Ruby versions
# Fetches from endoflife.date API and outputs all maintained versions to stdout

set -euo pipefail

curl -s https://endoflife.date/api/v1/products/ruby | \
  jq '{ruby: [.result.releases | sort_by(.releaseDate) | reverse | .[] | select(.isEol == false) | .name] | reverse}'
