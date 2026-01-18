#!/bin/bash

# GitHub repository information
OWNER="ggml-org"
REPO="llama.cpp"
API_VERSION="2022-11-28"
ACCEPT_HEADER="application/vnd.github+json"

# GitHub API URLs
COMMITS_URL="https://api.github.com/repos/${OWNER}/${REPO}/commits"
RELEASES_URL="https://api.github.com/repos/${OWNER}/${REPO}/releases"

# Get yesterday's start time (UTC)
# Try macOS/BSD date command
YESTERDAY_START_ISO=$(date -u -v-1d '+%Y-%m-%dT00:00:00Z' 2>/dev/null)

# If macOS/BSD command failed, try GNU date command
if [ $? -ne 0 ]; then
  YESTERDAY_START_ISO=$(date -u -d "yesterday" '+%Y-%m-%dT00:00:00Z' 2>/dev/null)
fi

# Check if date was obtained successfully
if [ -z "$YESTERDAY_START_ISO" ]; then
  echo "Error: Could not determine yesterday's date. Please ensure your 'date' command supports -v or -d option." >&2
  exit 1
fi

# Log to stderr so stdout can be used for JSON output
echo "Fetching releases for ${OWNER}/${REPO} since ${YESTERDAY_START_ISO}..." >&2
echo "----------------------------------------" >&2

# Fetch Releases and filter
echo "Fetching releases..." >&2
RELEASES_JSON=$(curl -s -L \
  -H "Accept: ${ACCEPT_HEADER}" \
  -H "X-GitHub-Api-Version: ${API_VERSION}" \
  "${RELEASES_URL}")

# Check if curl was successful
if [ $? -ne 0 ]; then
    echo "Error: Failed to fetch releases from GitHub API." >&2
    # Optionally print $RELEASES_JSON for error details
    exit 1
fi

# Use jq to filter releases on or after the start date and produce a JSON array containing tag, published_at, and body.
# In the body we:
#  - replace markdown links [text](url) with text
#  - remove any remaining URLs
YESTERDAY_RELEASES_JSON=$(echo "$RELEASES_JSON" | jq --arg date "$YESTERDAY_START_ISO" '[ .[] |
  select(.published_at != null and .published_at >= $date) |
  {
    tag: .tag_name,
    published_at: .published_at,
    body: (
      (.body // "") |
      # remove markdown link URL portion: "...](http...)" -> "]" so the link text remains in brackets
      gsub("\\]\\(https?://[^)]*\\)"; "]") |
      # remove remaining square brackets from markdown links
      gsub("\\[|\\]"; "") |
      # remove any leftover plain URLs
      gsub("https?://[^\\s]+"; "") |
      gsub("\\n{2,}"; "\\n\\n") |
      gsub("(^[[:space:]]+|[[:space:]]+$)"; "")
    )
  }
]')

# Output compact JSON object (single line) with execution timestamp and data array on stdout.
EXECUTED_AT=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
# Use jq -n -c to emit compact JSON without extra pretty formatting
jq -n -c --arg executed_at "$EXECUTED_AT" --argjson data "$YESTERDAY_RELEASES_JSON" '{executed_at: $executed_at, data: $data}'

exit 0
