# GitHub Releases API

以下整理自 GitHub REST API 文件，關於讀取 Release 資訊的端點。

## 列出 Releases (List releases)

取得儲存庫的所有 Releases 列表（不包含未關聯到 Release 的 Git 標籤）。公開儲存庫的已發布 Release 資訊對所有人可用。草稿 Release 僅對有推送權限的使用者顯示。

*   **方法:** `GET`
*   **路徑:** `/repos/{owner}/{repo}/releases`
*   **範例:**
    ```bash
    curl -L \
      -H "Accept: application/vnd.github+json" \
      -H "Authorization: Bearer <YOUR-TOKEN>" \ # 如果需要讀取私有儲存庫或草稿 Release
      -H "X-GitHub-Api-Version: 2022-11-28" \
      https://api.github.com/repos/OWNER/REPO/releases
    ```

## 取得特定 Release (Get a release)

透過 Release 的 `id` 取得單一 Release 的詳細資訊。

*   **方法:** `GET`
*   **路徑:** `/repos/{owner}/{repo}/releases/{release_id}`
*   **範例:**
    ```bash
    curl -L \
      -H "Accept: application/vnd.github+json" \
      -H "Authorization: Bearer <YOUR-TOKEN>" \ # 如果需要讀取私有儲存庫或草稿 Release
      -H "X-GitHub-Api-Version: 2022-11-28" \
      https://api.github.com/repos/OWNER/REPO/releases/RELEASE_ID
    ```

## 取得最新的 Release (Get the latest release)

取得儲存庫中最新發布的「正式」Release（非 prerelease、非 draft）。這是根據 `created_at` 屬性排序的最新 Release。**回應內容中會包含 `tag_name` 欄位，可用於後續查詢。**

*   **方法:** `GET`
*   **路徑:** `/repos/{owner}/{repo}/releases/latest`
*   **範例:**
    ```bash
    curl -L \
      -H "Accept: application/vnd.github+json" \
      -H "Authorization: Bearer <YOUR-TOKEN>" \ # 如果需要讀取私有儲存庫
      -H "X-GitHub-Api-Version: 2022-11-28" \
      https://api.github.com/repos/OWNER/REPO/releases/latest
    ```
    # 從回應 JSON 中取得 "tag_name"

## 透過 Tag 或 Commit SHA 取得 Commit (Get a commit)

使用 Tag 名稱（例如從最新 Release 取得的 `tag_name`）或完整的 Commit SHA 來取得單一 Commit 的詳細資訊。

*   **方法:** `GET`
*   **路徑:** `/repos/{owner}/{repo}/commits/{ref}`
    *   `{ref}`: 可以是 Commit SHA、分支名稱或 Tag 名稱。
*   **範例 (使用 Tag 名稱):**
    ```bash
    # 假設從 /releases/latest 取得的 tag_name 是 v1.0.0
    TAG_NAME="v1.0.0"
    curl -L \
      -H "Accept: application/vnd.github+json" \
      -H "Authorization: Bearer <YOUR-TOKEN>" \ # 如果需要讀取私有儲存庫
      -H "X-GitHub-Api-Version: 2022-11-28" \
      https://api.github.com/repos/OWNER/REPO/commits/$TAG_NAME
    ```
*   **取得 Commit 訊息:** Commit 的詳細訊息（敘述）位於回應 JSON 物件中的 `commit.message` 欄位。

---

**注意:** 您提供的附件內容主要涵蓋 Releases API。若要取得 Pull Requests (PR) 的相關 API 文件，需要查閱 GitHub REST API 文件中的 "Pull Requests" 章節。
