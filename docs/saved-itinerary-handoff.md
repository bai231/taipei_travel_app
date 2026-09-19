# 已儲存行程：結果頁與個人頁接入契約

> 更新日期：2026-09-18。底部入口為「個人空間」，內部分為「我的行程／收藏景點／收藏行程／收藏資料夾」。已儲存的自訂行程由「我的行程」展示。目前該區塊僅呈現待接入提示，未讀取雲端。

本文件與 `profile-folder-cloud-handoff.md` 交給同一位隊友。第一份處理收藏資料夾雲端 CRUD；本份處理「個人空間 → 我的行程」的清單及讀取展示。

## 分工與狀態

- 我們：結果頁手動儲存按鈕、完整快照編碼、儲存／清單／讀取 service、測試。
- 隊友：個人頁清單、讀取快照後的展示 UI、登入與錯誤狀態，以及共同完成雲端驗收。
- 2026-09-18 使用者已提供既有欄位：trips 為 id/user_id/title/created_at；trip_places 為 id/trip_id/place_id/created_at，沒有完整排程快照欄位。本次不改、不搬移這兩張表的資料，既有 UserDataService 的用途保留。
- 2026-09-18 已決定採用獨立 `saved_itineraries`。使用者回報建表 SQL 執行 `Success. No rows returned`，並提供 owner policy 查詢結果：authenticated / ALL，USING 與 WITH CHECK 均為 auth.uid() = user_id；另回報 relrowsecurity（rls_enabled）為 true。資料表、owner policy 及 RLS 啟用已確認，尚未完成 App 登入儲存、讀取及跨帳號隔離聯測。以上為使用者提供的雲端執行結果，非代理直接查詢。檔名 `saved-itineraries-schema-proposal.sql` 沿用，作為建置紀錄；該資料庫不要重複執行。
- 資料表未備妥或寫入失敗時按鈕會顯示失敗，不會假報成功。App 實際寫入尚未驗收；雲端建表與本機程式提交／推送是不同狀態，交付版本以 Git 紀錄為準。

## 隊友工作清單與不需重做的項目

- [ ] 將 profile_page.dart 的「我的行程」待接入提示替換為真實列表，呼叫 SavedItineraryService.list()，支援分頁與重新整理。
- [ ] 點選列表項目，以其 id 呼叫 read(id)，建立 v2 快照詳情 UI，呈現日期、每日項目、原排列順序、跨日時間、交通模式與估計／警告資訊。
- [ ] 處理未登入、載入中、空清單、失敗重試、資料不存在與不支援格式；切換帳號時立即清空舊清單／詳情，丟棄過期請求，不顯示上一帳號資料。
- [ ] 閱讀快照時不重新排程、不自動查交通 API；不要把收藏行程的示範詳情當成真實快照顯示。

隊友不需重做：結果頁手動儲存入口、儲存中／成功／失敗處理、同頁防重複 ID、v2 編碼、save/list/read 接口，以及已建立的表與基本權限。我們負責修正這些接口本身的缺陷；隊友負責個人頁的呼叫與顯示。本次不要求新增刪除、改名、還原為可編輯行程、分享或舊資料搬移功能。

接入檔案：個人頁在 `lib/pages/profile_page.dart`；service 在 `lib/services/saved_itinerary_service.dart`；快照格式在 `lib/services/itinerary_snapshot.dart`。真正排程結果及儲存入口在 `lib/features/route_planning/pages/itinerary_result_page.dart`。另一個 `lib/pages/itinerary_result_page.dart` 是既有收藏行程使用的示範結果頁，不是目前完整快照詳情頁；若要重用，必須改成以實際快照資料驅動畫面。

## 使用者操作

1. 結果頁工具列磁碟圖示，提示「儲存行程」。未登入按下提示先登入，不寫入；不自動跳轉，避免丟失行程。
2. 明確按下才儲存，不在產生、重新計算或離開頁面時自動儲存。
3. 儲存中禁用按鈕，顯示進度；成功及失敗用訊息提示。
4. 空行程、重新計算中、仍有待加入項目時不可儲存。
5. 以按下時的快照為準；儲存期間若有後續編輯，需再次按儲存，不能把舊成功訊息當成新版本已同步。

## 防重複與更新語意

同一結果頁生命週期、同一使用者沿用一個安全隨機 32 位十六進位 id；重試與再次儲存使用同一複合鍵 `(user_id,id)` upsert。網路回應遺失後重試不新增第二筆。同頁編輯後按儲存會覆寫該筆快照，不保留歷史版本。不同帳號不共用 id。

此保證只涵蓋目前頁面：關閉頁面、重新整理或重新產生並開新頁後會有新 id，允許存成另一筆。本次沒有跨裝置內容去重，也沒有讀取既有快照後編輯覆寫的 UI。未來若做該功能，要傳遞原 id，不要用新頁的預設 id。

## 儲存表契約（已回報建表成功，待 App 聯測）

| 欄位 | 型別／用途 |
| --- | --- |
| user_id | uuid，目前登入者；FK auth.users |
| id | text，32 位十六進位快照 ID；與 user_id 組成 PK |
| title | text，空名稱以「我的行程」代替 |
| snapshot | jsonb，寫入與讀取都只支援數字 schemaVersion=2 |
| created_at / updated_at | timestamptz，資料庫維護；更新不改建立時間 |

RLS 限制 authenticated 的 auth.uid()=user_id，禁止匿名存取。前端不使用 service_role。文件包含私人偏好、行程日期與位置，不應公開分享整份 JSON 或在 log 印出。

## Snapshot v2 欄位（2026-09-17 模型相容性更新）

最新 main 將 TripRequest.budget 改為 budget_level、Place.estimatedCost 改為 price_level。快照 v2 因此改用 `request.budgetLevel` 與各 `place.priceLevel`，都是等級，不是新台幣金額；不得顯示「元」或直接相加。UI 預算等級為 1～5。序列化保留模型實際值，不把旧測試或不合法輸入的金額強制轉成等級。

v2 另保存 `request.parsedPreference`（可為 null），內容由 TravelPreference.toJson 產生；其中 dailyBudget 仍是 AI 解析出的每日金額，與 budgetLevel 不同。

寫入與讀取統一只接受 v2；v1、缺少版本及未知版本均拒絕，不做舊金額欄位轉換。建表提案也只允許數字版本 2。

歷史紀錄：2026-09-17 使用者查詢回報 `42P01: relation "public.saved_itineraries" does not exist`，當次查詢找不到此表；這不代表已查核其他專案或既有 `trips` 表。2026-09-18 使用者已自行執行建表 SQL 並回報成功，詳見上方狀態。若部署到其他環境，須先檢查既有資料與 constraint，不能直接重跑 CREATE TABLE 或刪除舊快照。

編碼來源：`lib/services/itinerary_snapshot.dart`。這是獨立 DTO，不等於既有模型 fromJson 的格式，不要直接交給 Place.fromJson 或 TdxRoute.fromJson。

| 區塊 | 內容 |
| --- | --- |
| schemaVersion / timeZone / generatedAt | 版本 2、旅遊排程時區 Asia/Taipei、原始產生時間 |
| request | 名稱、起訖日期、地區、人數、budgetLevel、偏好、原始需求文字與 parsedPreference |
| origin / warnings | 起點快照、全行程警告 |
| inputs | 規劃輸入含景點快照、指定天數時間、locked、kind、餐別及偏好 |
| travelModeOverrides | day/originId/destinationId/mode 的陣列，不能以物件 key 編碼 record |
| days[] | 每日 day/date/origin/isValid/warnings、visits 與 travelLegs |
| visits[] | 完整景點快照、sequence、抵達／開始／結束／等待／停留分鐘、指定時間、locked、eventId/occurrenceId、kind、mealType、偏好及提示 |
| travelLegs[] | 起終點、要求出發時間、交通模式、來源、是否估計、錯誤、schedule、當時已有的 route 資訊 |
| route / sections | 轉乘數、時間距離、各段交通方式、路線名稱、起訖站與時間、停站資訊；無路線為 null |

陣列順序就是顯示順序；不要依名稱或推薦分數重排。每日分鐘以該日午夜為基準，可超過 1440，不能用 %1440 丟掉跨日資訊。日期欄位為原模型 ISO 8601 字串，保存原有 UTC 標記；無 offset 的日期／時間依排程時區處理，不能任意當 UTC。DateTime 轉換與顯示由隊友明確處理。

景點快照保存 id/name/type/地址座標/分類/圖片/描述/停留/priceLevel/營業與標籤等模型欄位，不依赖目前目錄內容。不得只用 place.id 當行程項目唯一鍵，住宿與同景點可能多次出現；以 day + occurrenceId（及陣列位置）辨識。

這是完整「已產生結果」的展示快照，不是 App 全狀態備份：不含尚未加入的項目、地圖 polyline、Google/TDX 快取、session/token。沒有 RouteItinerary 的還原方法或自動重新規劃；重新查路線會產生新結果／可能計費，不能在讀取時暗中執行。正式持久化第三方路線內容前，需另外確認所用 API 的儲存及保留條款，本次未做條款驗證。

## 隊友如何接入

```dart
final service = SavedItineraryService(Supabase.instance.client);
final summaries = await service.list(offset: 0, limit: 20);
// UI 先處理空列表；使用者點擊一筆摘要後，傳入該筆的 id：
// final snapshot = await service.read(selectedSummary['id'] as String);
// 依 snapshot['days'] 顯示快照，不觸發交通 API。
```

服務在 `lib/services/saved_itinerary_service.dart`。list 回傳 id/title/created_at/updated_at，預設每頁20筆，上限100；read 依使用者與 id 讀取 JSON，未知版本／缺少 days 會拒絕。隊友 UI 仍要驗證巢狀欄位與 null，顯示不支援／資料不存在／無權限等狀態，不直接強制轉型後崩潰。列出與讀取在帳號變更時丟棄結果。

## 建表操作（使用者執行，隊友接手前確認）

目前使用者已回報建表成功、owner policy 結果及 rls_enabled = true。下列建表步驟保留供紀錄／新環境使用，隊友在同一資料庫不要重複建表；接下來進行 App 聯測。

1. 開啟 App 實際使用的 Supabase 專案，進入 SQL Editor，新增查詢並使用 postgres 角色。
2. 貼上同目錄 [saved-itineraries-schema-proposal.sql](saved-itineraries-schema-proposal.sql) 的完整內容，一次執行。腳本用 transaction 建立表、主鍵、v2 JSON 檢查、RLS、登入者權限與更新時間 trigger，不修改 trips/trip_places。
3. 腳本只執行一次。若出現 already exists，停止並檢查既有物件，勿刪表或自行改成 IF NOT EXISTS 掩蓋結構差異。若 SQL Editor 顯示交易已中止，先單獨執行 ROLLBACK，再處理原始錯誤。
4. 執行成功後用下方唯讀 SQL 確認；預期表名存在、RLS 為 true、owner policy 存在。將執行日期及結果回報隊友，避免隊友重複建表。這只是結構檢查，仍須完成下節登入聯測。

```sql
select to_regclass('public.saved_itineraries') as table_name;
select relrowsecurity as rls_enabled
from pg_class where oid = to_regclass('public.saved_itineraries');
select policyname, roles, cmd, qual, with_check
from pg_policies
where schemaname = 'public' and tablename = 'saved_itineraries';
```

`snapshot` 是一個 jsonb 欄位：把按下儲存當時的多日行程內容包成一份 JSON，包括每日項目、順序、時間、交通及景點資訊；不是截圖，也不是整個資料庫備份。`schemaVersion: 2` 是這份 JSON 的資料格式版本。修改來源景點或重新計算行程不會自動更新快照；同頁再次按儲存才覆寫該筆。

隊友接入時必須讓「我的行程」呼叫 SavedItineraryService 讀取 saved_itineraries，不要繼續以 trips/trip_places 當作這項新功能的資料來源。既有收藏行程功能保持原流程，兩者本次不自動同步、不搬移資料。前端僅用一般 Supabase client 加登入 session，不放 service_role 金鑰；不要提供金鑰、密碼或 token。

## 聯測驗收

v2-only 調整後，7 項快照／按鈕測試全部通過，相關 service 與測試靜態分析無問題。測試命令：`flutter test test/services/saved_itinerary_test.dart`。按鈕測試使用替身 gateway，不是實際 Supabase 寫入測試。

- 未登入按鈕提示、不發送寫入；登入 A 後成功儲存兩日含餐廳住宿的結果。
- 多日日期、每次住宿事件、順序、時間、交通模式及估計標記一致。
- 連點只有一次請求；失敗後重試仍同 id；再次修改並手動儲存覆寫原筆。
- 新頁儲存可建立新筆；只編輯而不按儲存時，雲端不變。
- 隊友的清單與詳情可讀；未知版本能提示，且不呼叫排程或交通服務。
- 登出／切 B 後不能讀寫 A 資料；直接 API 測試也由 RLS 阻擋。
- 表未建立、斷網、RLS 拒絕要提示失敗，不能當成功。
- 本次本機測試不能取代上述真實 Supabase 聯測。
