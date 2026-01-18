#!/bin/bash

# GitHub repository information
OWNER="ggml-org"
REPO="llama.cpp"
API_VERSION="2022-11-28"
ACCEPT_HEADER="application/vnd.github+json"

# GitHub API URLs
COMMITS_URL="https://api.github.com/repos/${OWNER}/${REPO}/commits"
RELEASES_URL="https://api.github.com/repos/${OWNER}/${REPO}/releases"

# Optional target date (UTC) in YYYY-MM-DD. Can be set via env or first arg.
TARGET_DATE="${TARGET_DATE:-$1}"

if [ -n "$TARGET_DATE" ]; then
  # Parse target date and compute [start, end) in UTC
  START_ISO=$(date -u -d "${TARGET_DATE}T00:00:00Z" '+%Y-%m-%dT00:00:00Z' 2>/dev/null)
  if [ -z "$START_ISO" ]; then
    START_ISO=$(date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "${TARGET_DATE}T00:00:00Z" '+%Y-%m-%dT00:00:00Z' 2>/dev/null)
  fi

  END_ISO=$(date -u -d "${TARGET_DATE} +1 day" '+%Y-%m-%dT00:00:00Z' 2>/dev/null)
  if [ -z "$END_ISO" ]; then
    END_ISO=$(date -u -j -f "%Y-%m-%d" "$TARGET_DATE" -v+1d '+%Y-%m-%dT00:00:00Z' 2>/dev/null)
  fi
else
  # Get yesterday's start time (UTC)
  # Try macOS/BSD date command
  START_ISO=$(date -u -v-1d '+%Y-%m-%dT00:00:00Z' 2>/dev/null)

  # If macOS/BSD command failed, try GNU date command
  if [ -z "$START_ISO" ]; then
    START_ISO=$(date -u -d "yesterday" '+%Y-%m-%dT00:00:00Z' 2>/dev/null)
  fi

  END_ISO=$(date -u '+%Y-%m-%dT00:00:00Z' 2>/dev/null)
fi

# Check if date was obtained successfully
if [ -z "$START_ISO" ] || [ -z "$END_ISO" ]; then
  echo "Error: Could not determine date range. Please ensure your 'date' command supports -v or -d option." >&2
  exit 1
fi

# Log to stderr so stdout can be used for JSON output
echo "Fetching releases for ${OWNER}/${REPO} from ${START_ISO} to ${END_ISO}..." >&2
echo "----------------------------------------" >&2

# Fetch Releases (paginate to ensure completeness)
echo "Fetching releases..." >&2
AUTH_HEADER=()
if [ -n "$GITHUB_TOKEN" ]; then
  AUTH_HEADER=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
fi

RELEASES_JSON="[]"
PAGE=1
while true; do
  echo "Fetching releases page ${PAGE}..." >&2
  RESPONSE=$(timeout 60s curl -sS -L \
    --connect-timeout 10 \
    --max-time 50 \
    -H "Accept: ${ACCEPT_HEADER}" \
    -H "X-GitHub-Api-Version: ${API_VERSION}" \
    "${AUTH_HEADER[@]}" \
    -w "\n%{http_code}" \
    "${RELEASES_URL}?per_page=100&page=${PAGE}")

  CURL_EXIT=$?
  if [ $CURL_EXIT -ne 0 ]; then
    if [ $CURL_EXIT -eq 124 ]; then
      echo "Error: GitHub API request timed out on page ${PAGE}." >&2
    else
      echo "Error: GitHub API request failed (exit ${CURL_EXIT}) on page ${PAGE}." >&2
    fi
    exit 1
  fi

  HTTP_STATUS="${RESPONSE##*$'\n'}"
  HTTP_BODY="${RESPONSE%$'\n'*}"

  if [ -z "$HTTP_STATUS" ] || [ "$HTTP_STATUS" -ge 400 ]; then
    MESSAGE=$(echo "$HTTP_BODY" | jq -r '.message? // empty' 2>/dev/null)
    if echo "$MESSAGE" | grep -qi "rate limit exceeded"; then
      echo "Error: GitHub API rate limit exceeded. Try again later or use a token with higher limits." >&2
    elif echo "$MESSAGE" | grep -qi "abuse detection"; then
      echo "Error: GitHub API abuse detection triggered. Slow down requests and try again later." >&2
    else
      echo "Error: GitHub API returned status ${HTTP_STATUS}. ${MESSAGE}" >&2
    fi
    exit 1
  fi

  if ! echo "$HTTP_BODY" | jq -e 'type == "array"' >/dev/null 2>&1; then
    echo "Error: Unexpected GitHub API response (not an array)." >&2
    echo "$HTTP_BODY" | jq -c '.' >&2 || true
    exit 1
  fi

  PAGE_JSON="$HTTP_BODY"
  PAGE_COUNT=$(echo "$PAGE_JSON" | jq 'length')
  echo "Page ${PAGE} returned ${PAGE_COUNT} releases (HTTP ${HTTP_STATUS})." >&2
  if [ "$PAGE_COUNT" -eq 0 ]; then
    break
  fi

  RELEASES_JSON=$(jq -s '.[0] + .[1]' <(echo "$RELEASES_JSON") <(echo "$PAGE_JSON"))
  OLDEST_PUBLISHED=$(echo "$PAGE_JSON" | jq -r '[.[] | select(.published_at != null) | .published_at] | last // empty')
  if [ -n "$OLDEST_PUBLISHED" ] && [[ "$OLDEST_PUBLISHED" < "$START_ISO" ]]; then
    echo "Oldest release on page ${PAGE} is ${OLDEST_PUBLISHED}; older than start ${START_ISO}. Stopping pagination." >&2
    break
  fi
  PAGE=$((PAGE + 1))
done

# Use jq to filter releases on or after the start date and produce a JSON array containing tag, published_at, and body.
# In the body we:
#  - replace markdown links [text](url) with text
#  - remove any remaining URLs
YESTERDAY_RELEASES_JSON=$(echo "$RELEASES_JSON" | jq --arg start "$START_ISO" --arg end "$END_ISO" '[ .[] |
  select(.published_at != null and .published_at >= $start and .published_at < $end) |
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
