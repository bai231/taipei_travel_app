# 已儲存行程：結果頁與個人頁接入契約

本文件與 `profile-folder-cloud-handoff.md` 交給同一位隊友。第一份處理收藏資料夾雲端 CRUD；本份處理已儲存行程的清單及讀取展示。個人頁入口叫「我的行程」或放在「我的收藏」尚待討論，資料接口不依賴此位置。

## 分工與狀態

- 我們：結果頁手動儲存按鈕、完整快照編碼、儲存／清單／讀取 service、測試。
- 隊友：個人頁清單、讀取快照後的展示 UI、登入與錯誤狀態，以及資料庫方案確認。
- Supabase 尚未建置或實測。已知舊 `UserDataService` 使用 trips/trip_places，但未取得其完整 schema，不擅自新增欄位或混用。
- 本次程式預設使用獨立 `saved_itineraries`；`saved-itineraries-schema-proposal.sql` 是未執行的候選方案，需先確認採用。若要沿用 trips，先提供欄位、constraints、RLS、policies，再調整 service；不得直接對未知結構執行。
- 資料表未備妥時按鈕會顯示失敗，不會假報成功。沒有提交、推送、部署或實際寫入雲端。

## 使用者操作

1. 結果頁工具列磁碟圖示，提示「儲存行程」。未登入按下提示先登入，不寫入；不自動跳轉，避免丟失行程。
2. 明確按下才儲存，不在產生、重新計算或離開頁面時自動儲存。
3. 儲存中禁用按鈕，顯示進度；成功及失敗用訊息提示。
4. 空行程、重新計算中、仍有待加入項目時不可儲存。
5. 以按下時的快照為準；儲存期間若有後續編輯，需再次按儲存，不能把舊成功訊息當成新版本已同步。

## 防重複與更新語意

同一結果頁生命週期、同一使用者沿用一個安全隨機 32 位十六進位 id；重試與再次儲存使用同一複合鍵 `(user_id,id)` upsert。網路回應遺失後重試不新增第二筆。同頁編輯後按儲存會覆寫該筆快照，不保留歷史版本。不同帳號不共用 id。

此保證只涵蓋目前頁面：關閉頁面、重新整理或重新產生並開新頁後會有新 id，允許存成另一筆。本次沒有跨裝置內容去重，也沒有讀取既有快照後編輯覆寫的 UI。未來若做該功能，要傳遞原 id，不要用新頁的預設 id。

## 儲存表契約（待確認建置）

| 欄位 | 型別／用途 |
| --- | --- |
| user_id | uuid，目前登入者；FK auth.users |
| id | text，32 位十六進位快照 ID；與 user_id 組成 PK |
| title | text，空名稱以「我的行程」代替 |
| snapshot | jsonb，schemaVersion=1 的完整展示快照 |
| created_at / updated_at | timestamptz，資料庫維護；更新不改建立時間 |

RLS 限制 authenticated 的 auth.uid()=user_id，禁止匿名存取。前端不使用 service_role。文件包含私人偏好、行程日期與位置，不應公開分享整份 JSON 或在 log 印出。

## Snapshot v1 欄位

編碼來源：`lib/services/itinerary_snapshot.dart`。這是獨立 DTO，不等於既有模型 fromJson 的格式，不要直接交給 Place.fromJson 或 TdxRoute.fromJson。

| 區塊 | 內容 |
| --- | --- |
| schemaVersion / timeZone / generatedAt | 版本 1、旅遊排程時區 Asia/Taipei、原始產生時間 |
| request | 名稱、起訖日期、地區、人數、預算、偏好與原始需求文字 |
| origin / warnings | 起點快照、全行程警告 |
| inputs | 規劃輸入含景點快照、指定天數時間、locked、kind、餐別及偏好 |
| travelModeOverrides | day/originId/destinationId/mode 的陣列，不能以物件 key 編碼 record |
| days[] | 每日 day/date/origin/isValid/warnings、visits 與 travelLegs |
| visits[] | 完整景點快照、sequence、抵達／開始／結束／等待／停留分鐘、指定時間、locked、eventId/occurrenceId、kind、mealType、偏好及提示 |
| travelLegs[] | 起終點、要求出發時間、交通模式、來源、是否估計、錯誤、schedule、當時已有的 route 資訊 |
| route / sections | 轉乘數、時間距離、各段交通方式、路線名稱、起訖站與時間、停站資訊；無路線為 null |

陣列順序就是顯示順序；不要依名稱或推薦分數重排。每日分鐘以該日午夜為基準，可超過 1440，不能用 %1440 丟掉跨日資訊。日期欄位為原模型 ISO 8601 字串，保存原有 UTC 標記；無 offset 的日期／時間依排程時區處理，不能任意當 UTC。DateTime 轉換與顯示由隊友明確處理。

景點快照保存 id/name/type/地址座標/分類/圖片/描述/停留/費用/營業與標籤等模型欄位，不依赖目前目錄內容。不得只用 place.id 當行程項目唯一鍵，住宿與同景點可能多次出現；以 day + occurrenceId（及陣列位置）辨識。

這是完整「已產生結果」的展示快照，不是 App 全狀態備份：不含尚未加入的項目、地圖 polyline、Google/TDX 快取、session/token。沒有 RouteItinerary 的還原方法或自動重新規劃；重新查路線會產生新結果／可能計費，不能在讀取時暗中執行。正式持久化第三方路線內容前，需另外確認所用 API 的儲存及保留條款，本次未做條款驗證。

## 隊友如何接入

```dart
final service = SavedItineraryService(Supabase.instance.client);
final summaries = await service.list(offset: 0, limit: 20);
// 點擊一筆摘要後：
final snapshot = await service.read(summaries.first['id'] as String);
// 依 snapshot['days'] 顯示快照，不觸發交通 API。
```

服務在 `lib/services/saved_itinerary_service.dart`。list 回傳 id/title/created_at/updated_at，預設每頁20筆，上限100；read 依使用者與 id 讀取 JSON，未知版本／缺少 days 會拒絕。隊友 UI 仍要驗證巢狀欄位與 null，顯示不支援／資料不存在／無權限等狀態，不直接強制轉型後崩潰。列出與讀取在帳號變更時丟棄結果。

## 需要使用者／隊友確認

先確認採用獨立 saved_itineraries，或提供既有 trips/trip_places 的四份結構結果。可使用收藏 schema 檢查 SQL 的相同 SELECT，將表名換成 trips/trip_places（只讀）。確認後才執行建置及以專用帳號測試。不要提供金鑰、密碼、token。

## 聯測驗收

本機已通過 5 項快照／按鈕測試及 6 項既有結果頁相關測試，共 11 項。命令：`flutter test --no-pub test/services/saved_itinerary_test.dart test/widgets/trip/visit_preferences_dialog_test.dart`。按鈕測試使用替身 gateway，不是實際 Supabase 寫入測試。

- 未登入按鈕提示、不發送寫入；登入 A 後成功儲存兩日含餐廳住宿的結果。
- 多日日期、每次住宿事件、順序、時間、交通模式及估計標記一致。
- 連點只有一次請求；失敗後重試仍同 id；再次修改並手動儲存覆寫原筆。
- 新頁儲存可建立新筆；只編輯而不按儲存時，雲端不變。
- 隊友的清單與詳情可讀；未知版本能提示，且不呼叫排程或交通服務。
- 登出／切 B 後不能讀寫 A 資料；直接 API 測試也由 RLS 阻擋。
- 表未建立、斷網、RLS 拒絕要提示失敗，不能當成功。
- 本次本機測試不能取代上述真實 Supabase 聯測。
