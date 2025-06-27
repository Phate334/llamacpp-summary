#!/bin/bash

# GitHub repository information
OWNER="ggml-org"
REPO="llama.cpp"
API_VERSION="2022-11-28"
ACCEPT_HEADER="application/vnd.github+json"

# GitHub API URLs
COMMITS_URL="https://api.github.com/repos/${OWNER}/${REPO}/commits"
RELEASES_URL="https://api.github.com/repos/${OWNER}/${REPO}/releases"
PULLS_URL="https://api.github.com/repos/${OWNER}/${REPO}/pulls"

# Get date range for last 2 days
# Try macOS/BSD date command first
TWO_DAYS_AGO_ISO=$(date -u -v-2d '+%Y-%m-%dT00:00:00Z' 2>/dev/null)

# If macOS/BSD command failed, try GNU date command
if [ $? -ne 0 ]; then
  TWO_DAYS_AGO_ISO=$(date -u -d "2 days ago" '+%Y-%m-%dT00:00:00Z' 2>/dev/null)
fi

# Check if date was obtained successfully
if [ -z "$TWO_DAYS_AGO_ISO" ]; then
  echo "Error: Could not determine date 2 days ago. Please ensure your 'date' command supports -v or -d option."
  exit 1
fi

echo "Fetching releases, commits, and merged PRs for ${OWNER}/${REPO} since ${TWO_DAYS_AGO_ISO}..."
echo "=========================================="

# Function to call OpenAI API for summarization
summarize_with_openai() {
    local content="$1"
    
    # Check if required environment variables are set
    if [ -z "$OPENAI_API_BASE" ] || [ -z "$OPENAI_API_KEY" ] || [ -z "$OPENAI_MODEL" ]; then
        echo "Warning: OpenAI environment variables not set. Skipping summarization."
        echo "Required: OPENAI_API_BASE, OPENAI_API_KEY, OPENAI_MODEL"
        echo "$content"
        return
    fi
    
    # Prepare the prompt for summarization
    local prompt="Please summarize the following llama.cpp repository updates from the last 2 days into a clear, organized markdown format. Include sections for releases, merged pull requests, and significant commits. Focus on the most important changes and improvements:

$content"
    
    # Create JSON payload for OpenAI API
    local json_payload=$(jq -n \
        --arg model "$OPENAI_MODEL" \
        --arg prompt "$prompt" \
        '{
            model: $model,
            messages: [
                {
                    role: "user",
                    content: $prompt
                }
            ],
            max_tokens: 2000,
            temperature: 0.3
        }')
    
    # Call OpenAI API
    local response=$(curl -s -X POST "${OPENAI_API_BASE}/chat/completions" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $OPENAI_API_KEY" \
        -d "$json_payload")
    
    # Extract the summarized content
    if echo "$response" | jq -e '.choices[0].message.content' > /dev/null 2>&1; then
        echo "$response" | jq -r '.choices[0].message.content'
    else
        echo "Error: Failed to get summary from OpenAI API"
        echo "Response: $response"
        echo "Returning original content..."
        echo "$content"
    fi
}

# Fetch Releases
echo "Fetching releases..."
RELEASES_JSON=$(curl -s -L \
  -H "Accept: ${ACCEPT_HEADER}" \
  -H "X-GitHub-Api-Version: ${API_VERSION}" \
  "${RELEASES_URL}")

# Check if we got valid JSON
if [ $? -ne 0 ] || ! echo "$RELEASES_JSON" | jq empty 2>/dev/null; then
    echo "Warning: Failed to fetch releases from GitHub API or got invalid response."
    RECENT_RELEASES=""
else
    # Filter releases from last 2 days
    RECENT_RELEASES=$(echo "$RELEASES_JSON" | jq -r --arg date "$TWO_DAYS_AGO_ISO" '
      .[] |
      select(.published_at != null and .published_at >= $date) |
      "## Release: " + .tag_name + "\n**Name:** " + .name + "\n**Published:** " + .published_at + "\n**Description:**\n" + .body + "\n"
    ' 2>/dev/null || echo "")
fi

# Fetch Commits
echo "Fetching commits..."
COMMITS_JSON=$(curl -s -L \
  -H "Accept: ${ACCEPT_HEADER}" \
  -H "X-GitHub-Api-Version: ${API_VERSION}" \
  "${COMMITS_URL}?since=${TWO_DAYS_AGO_ISO}")

# Check if we got valid JSON
if [ $? -ne 0 ] || ! echo "$COMMITS_JSON" | jq empty 2>/dev/null; then
    echo "Warning: Failed to fetch commits from GitHub API or got invalid response."
    RECENT_COMMITS=""
else
    # Filter non-merge commits from last 2 days
    RECENT_COMMITS=$(echo "$COMMITS_JSON" | jq -r --arg date "$TWO_DAYS_AGO_ISO" '
      .[] |
      select(.commit.author.date >= $date) |
      select(.commit.message | startswith("Merge pull request") | not) |
      select(.commit.message | startswith("Merge branch") | not) |
      "### Commit: " + .sha[0:7] + "\n**Date:** " + .commit.author.date + "\n**Message:** " + .commit.message + "\n"
    ' 2>/dev/null | head -20 || echo "")  # Limit to 20 most recent commits
fi

# Fetch Merged Pull Requests
echo "Fetching merged pull requests..."
MERGED_PRS_JSON=$(curl -s -L \
  -H "Accept: ${ACCEPT_HEADER}" \
  -H "X-GitHub-Api-Version: ${API_VERSION}" \
  "${PULLS_URL}?state=closed&sort=updated&direction=desc")

# Check if we got valid JSON
if [ $? -ne 0 ] || ! echo "$MERGED_PRS_JSON" | jq empty 2>/dev/null; then
    echo "Warning: Failed to fetch pull requests from GitHub API or got invalid response."
    RECENT_MERGED_PRS=""
else
    # Filter merged PRs from last 2 days
    RECENT_MERGED_PRS=$(echo "$MERGED_PRS_JSON" | jq -r --arg date "$TWO_DAYS_AGO_ISO" '
      .[] |
      select(.merged_at != null and .merged_at >= $date) |
      "## PR #" + (.number | tostring) + ": " + .title + "\n**Author:** " + .user.login + "\n**Merged:** " + .merged_at + "\n**Description:**\n" + (.body // "No description provided") + "\n"
    ' 2>/dev/null || echo "")
fi

# Combine all content
RAW_CONTENT=""

if [ -n "$RECENT_RELEASES" ]; then
    RAW_CONTENT+="# Recent Releases (Last 2 Days)

$RECENT_RELEASES

"
fi

if [ -n "$RECENT_MERGED_PRS" ]; then
    RAW_CONTENT+="# Recently Merged Pull Requests (Last 2 Days)

$RECENT_MERGED_PRS

"
fi

if [ -n "$RECENT_COMMITS" ]; then
    RAW_CONTENT+="# Recent Commits (Last 2 Days)

$RECENT_COMMITS

"
fi

if [ -z "$RAW_CONTENT" ]; then
    RAW_CONTENT="# llama.cpp Activity Summary

No significant releases, merged pull requests, or commits found in the last 2 days.

*Note: This could be due to no activity or API access issues.*

*Generated on $(date -u '+%Y-%m-%d %H:%M:%S UTC')*"
else
    RAW_CONTENT="# llama.cpp Activity Summary

*Generated on $(date -u '+%Y-%m-%d %H:%M:%S UTC')*
*Data from: $(echo "$TWO_DAYS_AGO_ISO" | cut -d'T' -f1) to $(date -u '+%Y-%m-%d')*

$RAW_CONTENT"
fi

echo "Content gathered. Processing with OpenAI..."

# Summarize content with OpenAI
SUMMARIZED_CONTENT=$(summarize_with_openai "$RAW_CONTENT")

# Ensure docs directory exists
mkdir -p "$(dirname "docs/summary.md")"

# Write to summary file
echo "$SUMMARIZED_CONTENT" > docs/summary.md

echo "Summary written to docs/summary.md"
echo "=========================================="
echo "Process completed successfully!"