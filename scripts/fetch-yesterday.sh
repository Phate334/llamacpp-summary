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
  echo "Error: Could not determine yesterday's date. Please ensure your 'date' command supports -v or -d option."
  exit 1
fi

echo "Fetching releases and commits for ${OWNER}/${REPO} since ${YESTERDAY_START_ISO}..."
echo "----------------------------------------"

# Fetch Releases and filter
echo "Fetching releases..."
RELEASES_JSON=$(curl -s -L \
  -H "Accept: ${ACCEPT_HEADER}" \
  -H "X-GitHub-Api-Version: ${API_VERSION}" \
  "${RELEASES_URL}")

# Check if curl was successful
if [ $? -ne 0 ]; then
    echo "Error: Failed to fetch releases from GitHub API."
    # Optionally print $RELEASES_JSON for error details
    exit 1
fi

# Use jq to filter yesterday's Releases (based on published_at)
YESTERDAY_RELEASES=$(echo "$RELEASES_JSON" | jq -r --arg date "$YESTERDAY_START_ISO" '
  .[] |
  # Select releases published on or after the specified start date
  select(.published_at != null and .published_at >= $date) |
  "Release Tag: " + .tag_name + "\nName: " + .name + "\nPublished: " + .published_at + "\nBody:\n" + .body + "\n---"
')

# Fetch yesterday's Commits
echo "Fetching commits..."
# Use since parameter to filter commits
COMMITS_JSON=$(curl -s -L \
  -H "Accept: ${ACCEPT_HEADER}" \
  -H "X-GitHub-Api-Version: ${API_VERSION}" \
  "${COMMITS_URL}?since=${YESTERDAY_START_ISO}")

# Check if curl was successful
if [ $? -ne 0 ]; then
    echo "Error: Failed to fetch commits from GitHub API."
    # Optionally print $COMMITS_JSON for error details
    exit 1
fi

# Use jq to process commits
# Filter out merge commits (messages usually start with "Merge pull request" or "Merge branch")
# Extract SHA and the full commit message
YESTERDAY_COMMITS=$(echo "$COMMITS_JSON" | jq -r --arg date "$YESTERDAY_START_ISO" '
  .[] |
  # Ensure commit date is actually on or after the specified start time
  select(.commit.author.date >= $date) |
  # Filter out common merge commit messages
  select(.commit.message | startswith("Merge pull request") | not) |
  select(.commit.message | startswith("Merge branch") | not) |
  "Commit: " + .sha + "\nMessage:\n" + .commit.message + "\n---" # Get the full message
')


# Output combined results
echo "Yesterday's Activity (Releases and Commits):"
echo "----------------------------------------"

if [ -z "$YESTERDAY_RELEASES" ] && [ -z "$YESTERDAY_COMMITS" ]; then
  echo "No new releases or non-merge commits found since ${YESTERDAY_START_ISO}."
else
  if [ -n "$YESTERDAY_RELEASES" ]; then
    echo "Releases:"
    echo -e "$YESTERDAY_RELEASES" # Use -e to interpret \n
  else
    echo "No new releases found since ${YESTERDAY_START_ISO}."
  fi
  echo # Add a newline for separation if both exist

  if [ -n "$YESTERDAY_COMMITS" ]; then
    echo "Commits (excluding merges):"
    echo -e "$YESTERDAY_COMMITS" # Use -e to interpret \n
  else
    echo "No new non-merge commits found since ${YESTERDAY_START_ISO}."
  fi
fi
echo "----------------------------------------"

exit 0
