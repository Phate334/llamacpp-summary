#!/bin/bash

# GitHub 儲存庫資訊
OWNER="ggml-org"
REPO="llama.cpp"
API_VERSION="2022-11-28"
ACCEPT_HEADER="application/vnd.github+json"

# GitHub API URL
LATEST_RELEASE_URL="https://api.github.com/repos/${OWNER}/${REPO}/releases/latest"
COMMITS_URL="https://api.github.com/repos/${OWNER}/${REPO}/commits"

echo "Fetching latest release tag from ${OWNER}/${REPO}..."

# 1. 取得最新 Release 的 Tag Name
TAG_NAME=$(curl -s -L \
  -H "Accept: ${ACCEPT_HEADER}" \
  -H "X-GitHub-Api-Version: ${API_VERSION}" \
  "${LATEST_RELEASE_URL}" | jq -r '.tag_name')

if [ -z "$TAG_NAME" ] || [ "$TAG_NAME" == "null" ]; then
  echo "Error: Could not fetch latest release tag."
  exit 1
fi

echo "Latest release tag: ${TAG_NAME}"
echo "Fetching commit details for tag ${TAG_NAME}..."

# 2. 透過 Tag Name 取得 Commit 資訊
# 3. 從 Commit 資訊中提取 Commit Message
COMMIT_MESSAGE=$(curl -s -L \
  -H "Accept: ${ACCEPT_HEADER}" \
  -H "X-GitHub-Api-Version: ${API_VERSION}" \
  "${COMMITS_URL}/${TAG_NAME}" | jq -r '.commit.message')

if [ -z "$COMMIT_MESSAGE" ] || [ "$COMMIT_MESSAGE" == "null" ]; then
  echo "Error: Could not fetch commit message for tag ${TAG_NAME}."
  exit 1
fi

echo "----------------------------------------"
echo "Commit message for the latest release (${TAG_NAME}):"
echo "----------------------------------------"
echo "$COMMIT_MESSAGE"
echo "----------------------------------------"

exit 0
