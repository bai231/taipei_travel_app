# 個人頁收藏資料夾雲端接入：隊友交接

本文件與 `saved-itinerary-handoff.md` 交給同一位隊友：本份處理收藏資料夾雲端 CRUD；另一份處理已儲存行程的個人頁清單與展示。兩者資料接口獨立，個人頁入口位置可另行討論。

日期：2026-09-12。對象：負責個人頁收藏與資料夾的開發者。

## 目標與狀態

使用者登入後，在個人頁建立資料夾、加入收藏景點，資料持久化到 Supabase；重開「安排行程 → 新增景點 → 我的收藏」後，可選該資料夾並看到對應景點。

依使用者提供的欄位、約束、RLS 與 policies 結果，讀取契約已確認相容，但尚未用真實帳號端到端驗證。收藏與評分接口列為第一、二批交付；行程儲存及 `saved-itinerary-handoff.md` 屬第三批，暫留個人分支本機，不隨前兩批進入 main。請以實際 Git 提交及推送結果確認交付版本。

## 雙方分工

| 負責端 | 工作 | 狀態 |
| --- | --- | --- |
| 安排行程端（我們） | 景點專屬收藏入口、資料夾選單、雲端讀取、搜尋與評分排序 | 本機已實作並測試 |
| 個人頁端（隊友） | 記憶體資料夾改為雲端 CRUD、成員維護、收藏一致性、錯誤處理 | 待接入 |
| 雙方 | 同專案測試帳號聯測，確認持久化、帳號隔離與失敗處理 | 待驗收 |

我們目前不需再建表或修改讀取接口；需要交付程式、配合聯測並處理實測問題。Realtime 即時同步不是目前必要條件。

## 已確認的資料庫結構

| 表 | 核心欄位 | 約束 |
| --- | --- | --- |
| favorites | id bigint、user_id uuid、place_id bigint | PK id；UNIQUE(user_id, place_id)；user_id → auth.users；place_id → places |
| folders | id bigint、user_id uuid、title text | PK id；user_id → auth.users |
| folder_places | id bigint、folder_id bigint、place_id bigint | PK id；UNIQUE(folder_id, place_id)；folder_id → folders；place_id → places |
| places | id bigint，其他景點欄位 | PK id；UNIQUE(source, source_id) |

前三表另有 created_at。以上外鍵均為 ON DELETE CASCADE。刪除資料夾會連帶刪除成員關聯，不刪 favorites 或 places。刪除 favorites 不會連帶刪除 folder_places，兩者没有該外鍵。

四表 RLS enabled=true、force_rls=false。提供的 policies：favorites/folders 依 auth.uid()=user_id 管理；folder_places 依所屬 folders.user_id=auth.uid() 管理；places 可公開 SELECT。用一般登入者驗證，不能只用 SQL Editor 管理者查詢當成 RLS 驗收。不得關閉 RLS 或將 service_role 放進 App。

### 寫入前確認 ID 產生方式

提供的 id 欄位 column_default 都是 null，不能據此判斷是否有 identity 自動編號。現有新增程式省略 id，請先執行以下唯讀查詢：

```sql
select table_name, column_name, is_identity, identity_generation, column_default
from information_schema.columns
where table_schema = 'public'
  and table_name in ('favorites', 'folders', 'folder_places', 'places')
  and column_name = 'id';
```

若非 identity 且無 default，需再確認 trigger 等 ID 來源；不要猜 id 或使用 max(id)+1。此項不影響讀取端，但寫入端必須確認。

## 寫入契約

1. user_id 使用目前登入者；未登入不可宣稱雲端同步成功。
2. place_id 必須是真正 public.places.id，其字串形式等於景點目錄的 Place.id。不要以名稱比對、剝除其他表前綴冒充 ID，或解析失敗後寫入 0。
3. 加入資料夾前確保 favorites 已有相同 user_id/place_id，再建立 folder_places。針對上述 UNIQUE 組合採可重試、不重複的策略；若採 upsert，明確指定對應衝突鍵。
4. 標題 trim 後不能為空；目前沒有 title 唯一限制，請用 folder.id 識別，不用標題。
5. 移除資料夾成員只刪該 folder_id/place_id 關聯，保留收藏及其他資料夾成員，不刪 places。
6. 結構允許同一景點屬於多個資料夾。若 UI 使用「移動」字樣，先定義是否刪除來源關聯。
7. 取消收藏時要協調資料夾成員清理：若只刪 favorites，重新收藏後舊 folder_places 會再次可見。建議同步清除本人資料夾內該景點的關聯；這是待雙方採納的行為，不是已實作。
8. 多次請求不是單一交易。收藏成功、加入資料夾失敗時，顯示真實部分成功狀態並可重試。若要求原子操作，再評估交易/RPC，不在本接口中自行建立。

## 選擇器讀取規則

- 全部收藏 = 目前目錄景點 ∩ favorites。
- 指定資料夾 = 目前目錄景點 ∩ favorites ∩ 該資料夾成員。
- 不在目錄中的收藏不另行补入；缺座標可顯示但不可加入路線。
- 僅景點有收藏選項，餐廳／住宿沒有。
- 收藏模式停用隱藏縣市篩選，仍套用搜尋與評分排序。
- 每次開啟景點選擇器重新讀取；沒有資料表 Realtime 訂閱，個人頁寫入後先關閉再重開選擇器驗證。
- 帳號變更會重新讀取，不顯示前帳號資料；載入失敗有重試，不偽裝成空收藏。資料夾查詢失敗時不呈現不完整的收藏快照。

## 隊友需檢查的檔案

以下使用 repository 相對路徑，方便跨電腦定位：

- `lib/pages/profile_page.dart`：`_folders` 仍是記憶體清單，需接入讀取、建立、改名、刪除及成員維護。
- `lib/services/user_data_service.dart`：已有 fetchFolders/createFolder，但不是完整 CRUD；createFolder 目前把無效 placeId 轉成 0，且未保證 favorites 一致性，需修正驗證與失敗處理。
- `lib/services/favorite_service.dart`：現行 isFavorite 比對 ID 或名稱，寫入失敗只 log，樂觀 UI 可能與雲端不一致。不得把 toggleFavorite 的 bool 當成雲端寫入成功證明；需確認真實 ID、結果與重複寫入的衝突鍵。

我們的讀取端：`lib/models/planner_favorites.dart`、`lib/services/planner_favorites_service.dart`、`lib/widgets/trip/cloud_planner_item_picker.dart`、`lib/widgets/trip/planner_item_picker.dart`；兩個入口在 `lib/pages/trip_planner_page.dart`。

不需修改 itinerary_planning_service、route_optimizer 或評分公式接口。需動共同檔案時先協調，避免覆寫尚未提交的變更。

## 聯測清單

使用專用測試帳號與可清除的測試資料，先取得測試者同意，不操作正式收藏。

| 操作 | 預期 |
| --- | --- |
| 帳號 A 收藏一筆目錄景點 | favorites 有 A/place_id，重載仍保留 |
| 建立空資料夾 | 重開個人頁及選擇器可見，選取時為空清單 |
| 加入收藏景點，重開選擇器 | 下拉有資料夾，對應景點出現 |
| 重複加入 | 無重複資料，不誤報成功 |
| 修改資料夾名稱 | 重開後更新，同一 id 保留成員 |
| 移除資料夾成員 | 該夾不顯示，全部收藏仍保留 |
| 刪除資料夾 | 選單移除，收藏保留 |
| 取消再重新收藏 | 確認成員清理約定與實際顯示一致 |
| 搜尋、切資料夾、切回全部 | 篩選、排序正確，勾選保留 |
| 登出、帳號 B 登入 | 不顯示 A 資料；B 直接查詢 A 資料也受 RLS 限制 |
| 斷網或寫入拒絕 | 不假報成功，可重試且不重複建立 |

回報分支／commit、操作與預期／實際結果、去識別化錯誤訊息。不提供密碼、token、API key 或完整使用者資料。

## 完成定義

目前 9 項 UI／排序相關測試與 2 項模擬 HTTP 服務測試共 11 項通過，但不代表真實雲端驗證完成。需等隊友寫入可持久化、選擇器可讀取，且帳號隔離及錯誤情境通過，才算端到端完成。提交與推送需另行授權。
