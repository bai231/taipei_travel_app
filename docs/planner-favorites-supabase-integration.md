# 選擇景點：雲端收藏與資料夾接入

> 2026-09-12 確認更新：使用者已提供四份欄位／約束／RLS／policies 結果，與讀取接口相容，四表均已啟用 RLS。以下「需提供 schema」段落保留為查核方式，不代表仍缺這四份資料。個人頁寫入分工、ID 自動產生待確認項目與聯測清單，請見 `profile-folder-cloud-handoff.md`。真實帳號端到端測試尚未完成。

## 已實作

- 收藏入口僅限景點，餐廳／住宿只有搜尋及縣市。
- 全部模式顯示縣市；收藏模式同位置顯示收藏資料夾，預設「全部收藏」。切回全部保留原縣市；收藏模式不套用隱藏的縣市條件。
- 指定資料夾只顯示「目前目錄景點 ∩ 使用者收藏 ∩ 資料夾成員」，搜尋及評分排序繼續生效。空資料夾顯示空結果，不退回全部。已取消收藏的資料夾殘留項目不顯示。
- `CloudPlannerItemPicker` 已接入安排行程頁與結果頁的兩個新增入口。每次開啟景點選擇器重新讀取；有載入、未登入、錯誤與重試狀態。帳號切換會清除前一帳號顯示資料並重新讀取。沒有 Realtime 訂閱資料表，其他頁面變更後需重新開啟。
- `PlannerFavoritesService` 只讀，不更動資料庫或既有收藏寫入服務；查詢分頁每頁 500 筆，錯誤不假裝空資料。

## 現有程式所依據的資料契約（尚需確認實際 Supabase）

| 表 | 使用欄位 | 用途 |
| --- | --- | --- |
| `public.favorites` | `user_id`, `place_id` | 目前登入使用者收藏 |
| `public.folders` | `id`, `user_id`, `title` | 使用者資料夾 |
| `public.folder_places` | `folder_id`, `place_id` | 資料夾成員 |
| `public.places` | `id` | 景點目錄的來源 ID |

依據為現有 `FavoriteService` 與 `UserDataService`，並非已檢查雲端 schema。`place_id.toString()` 必須等於目錄景點的 `Place.id`；目前 `getPlaces()` 不加前綴，所以不依名稱猜測或把不同資料表 ID 混用。收藏存在但不在傳入目錄中的景點不會被另外補入。

所有查詢必須受 RLS 保護：favorites/folders 只能讀本人，folder_places 只能讀本人擁有資料夾的成員。前端 `.eq` 不是安全邊界。請勿為了讓接口可用而關閉 RLS、公開全部收藏，或把 service_role 放在 App。

## 目前真正的待接部分

`ProfilePage._folders` 仍是本機記憶體的模擬清單，建立資料夾及移入景點也僅修改此清單；尚未呼叫 `UserDataService` 寫入 Supabase。因此在個人頁新建的資料夾不會自動出現在此雲端選單。需先確認以下 schema，再安排個人頁的資料夾 CRUD 接入；本次沒有默默改寫這個流程。

## 請提供什麼、如何取得

在 Supabase Dashboard 選擇專案 → SQL Editor → New query，貼上同目錄 `planner-favorites-schema-inspection.sql` 執行。它只有 SELECT，不讀收藏內容、不修改資料。將各段結果匯出或複製提供即可。

需要確認：四張表的欄位及型別、主鍵／外鍵／唯一限制、RLS 是否啟用與 policies。若表名不同，提供實際名稱。另請提供去識別化範例：一筆 favorites、一筆 folders、一筆 folder_places 和其 places.id；user_id 可統一換成 USER_A，保留 ID 之間的關係即可。可在 Table Editor 查看對應表，不需匯出整張表。

不需要密碼、JWT、API key、service_role key 或所有使用者資料。若某表不存在或權限報錯，直接提供表名／錯誤訊息即可；不要先建立猜測的表或放寬權限。

## 純 UI 接口

`PlannerItemPicker` 保留 `favoritePlaceIds`，新增 `favoriteFolders: List<PlannerFavoriteFolder>`。每個 folder 有 `id`、`title`、`placeIds`。null favoritePlaceIds 表示不可用，空集合表示成功但沒有收藏。可用此接口以測試資料驗證 UI，不須真實 API。
