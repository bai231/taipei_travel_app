# main 與行程守護功能整合：給隊友確認

> 2026-10-01 進度：此版 `main` 已整合進工作分支；下方是原先的交接要求，不再代表程式仍有 Git 衝突。結果頁採「先顯示天氣綜覽，再啟動守護」；CWA 失敗不阻止 GPS。跨縣市快取未命中時遵守一小時查詢間隔，不繞過節流。全套 Flutter 測試已通過，但 Android APK 建置及實機驗收仍待完成。

歷史比對基準：當時遠端 `main` 為 `e5803c7`，工作分支為 `klorius-route-optimizer`。以下第 1～4 節保留原始整合契約與當時的確認問題；已完成狀態以本文件開頭的進度及目前程式為準。目前不修改 Supabase 資料表，也不自動套用任何備案。

## 1. 結果頁：開始行程與風險提示

共同修改 `lib/features/route_planning/pages/itinerary_result_page.dart`，保留：

- `main`：今日第一個景點的天氣綜覽、雨／強紫外線時的室內建議請求 `onRequestIndoorItineraryAlternatives`、Debug 模擬延誤。
- 我們：通知權限提示、`ActiveGuardianSession` 頁面外持續守護、30 秒時間檢查、公車／臺鐵風險、逐段交通備案、Before／After 確認及可注入的測試依賴。

需要合併 `_startTracking()`、`_handleTrackingUpdate()` 與頁面關閉／返回流程，不能保留兩套獨立的追蹤器。建議「天氣查詢失敗仍可啟動 GPS 守護」；室內建議只提出候選，不因點擊「查看室內建議」直接覆寫行程。背景期間只發 Android 通知，不從已關閉頁面彈對話框；使用者回到結果頁後才呈現備案。

**請隊友確認：**天氣綜覽要在 GPS／前景服務啟動前顯示，還是在守護啟動後顯示？若 CWA 暫不可用，是否直接跳過綜覽並繼續守護？我們建議不讓 CWA 失敗阻斷追蹤。

## 2. 天氣服務：共用查詢額度與資料快取

共同修改 `lib/services/weather_advisory_service.dart`，保留 `main` 的 CWA 縣市／鄉鎮解析、第一景點綜覽與 `WeatherCheckResult`；保留我們的 `CwaQueryLimiter`（跨行程及 App 重啟的一小時查詢間隔）和「風險達標 → 解除 → 再達標才再次通知」。欄位缺失、HTTP 失敗不能當作風險解除。

綜覽 `overviewForPlace()` 和 GPS `check()` 必須共用同一查詢入口：先檢查可覆蓋所需地區的快取；需要發出 HTTP 時才向共用 limiter 預留額度；失敗的 HTTP 嘗試也消耗本機的一小時間隔。快取命中不再消耗一次額度。不同服務實例也不得在一小時內各查一次。

**請隊友確認：**若先查景點所在縣市，旅客一小時內移到快取以外的縣市，是顯示「暫無新資料」並等待下次額度，還是改採範圍較大的單次查詢？不能一面宣稱一小時節流，一面讓跨縣市的 GPS 查詢繞過它。這是 App 端節流，不是跨裝置的伺服器配額。

## 3. 追蹤服務：真實時鐘、定時重查與模擬時間

共同修改 `lib/services/live_itinerary_tracking_service.dart`。`TripTrackingUpdate.observedAt` 應由注入的時鐘提供；Debug 模擬延誤可明確指定模擬時間。守護服務的 `checkNow()` 在 GPS 沒移動時以最後位置重評估，但**不將相同座標追加為新的路徑點**。延誤判斷、今日日期與通知去重都須使用同一筆事件時間，避免畫面使用模擬時間、備案卻使用系統真實時間。保留兩邊的停止及釋放行為。

模擬延誤僅產生風險與備案預覽，不自動重排套用。已完成進度以使用者確認為準，不能因時間已過或 GPS 靠近而自行標成完成。

## 4. 主程式、定位與通知

- `lib/main.dart`：只有一個 `MaterialApp`；保留 `main` 的 `LanguageService`／localization delegates，也保留我們的 `appNavigatorKey`、通知點擊開啟守護行程及「返回守護行程」入口。切換語言時不得遺失正在守護的 session。
- `lib/services/location_service.dart`：保留 `main` 的 `getDistance()` 與錯誤紀錄；Android 使用 `AndroidSettings` 和 `ForegroundNotificationConfig`，其他平台沿用一般 `LocationSettings`。取消定位 stream 時前景服務須停止；切換 App 或鎖屏時不因結果頁關閉而停止 session。
- `lib/services/trip_notification_service.dart`：保留 `main` 的 Linux 初始化與通知細節；保留我們的 Android 通知權限檢查、守護風險 payload 和點擊回行程。通知只告知風險，不在背景套用備案。

## 5. 已整合項目與後續驗收

本分支已把 `main` 的 `geo:` 外部連結查詢宣告加進 Android Manifest，同時保留定位／前景服務／通知權限；`pubspec.yaml` 保留 localization、Linux 通知與 `shared_preferences` 依賴，並重新解析 `pubspec.lock`。天氣綜覽與 GPS 查詢已共用 CWA 節流及快取；測試包含不同服務實例共用一小時間隔。

`lib/services/itinerary_snapshot.dart` 現已寫入 `district`、營業時間原始值與解析欄位、`phone`、`website`；天氣綜覽測試亦已整合。這些變更仍需以實際 Android 裝置及雲端舊快照完成回歸驗收。

## 6. 整合完成的驗收

1. Android 啟動、切到其他 App、鎖屏與返回結果頁，守護 session 和定位常駐通知正確；按停止後全部結束。
2. 開始行程時可見天氣綜覽；天氣查詢失敗仍可守護。綜覽與 GPS 天氣檢查不會突破共用一小時查詢限制。
3. 模擬延誤與真實 GPS／定時檢查都只提出 Before／After，使用者按「套用」前原行程不變。
4. Android 通知點擊可回到正在守護的行程；Linux 通知設定、語言切換及網頁功能不退化。
5. 快照新增欄位後，舊快照仍可讀，新快照能保留景點地區與詳細資訊。

## 7. 營業時間分工

我們沒有修改既有的 `Place.fromJson`、`Place.hasKnownOpeningHours` 或初次排程服務 `ItineraryPlanningService` 的營業時間判斷，也沒有改 Supabase 的營業時間資料。依照分工，已從新增的 `lib/services/live_itinerary_alternative_planner.dart` 撤回 `hasKnownOpeningHours`／`openMinutes`／`closeMinutes` 判斷及「營業時間未知」警告；即時備案目前只檢查交通、固定時間與當天結束時間，**不保證景點或餐廳在新到達時間仍營業**。

遠端 `main` 擴充 `Place` 的文字營業時間欄位與來源解析。請負責營業時間的隊友決定如何驗證星期別、假日例外、跨日營業及資料缺漏，再將該驗證接入初次排程與即時備案；在此之前不能把即時備案標示為「營業時間已驗證」。
