# Android 直接路線查詢

Android 直接呼叫 Routes API REST，不新增後端；Web 的 JavaScript bridge 不變。
步行／汽車取得時間及實際線條。汽車沿用 Web 的 TRAFFIC_UNAWARE，不宣稱即時路況。
大眾運輸排程仍由 TDX 提供，Google 地圖線條僅為參考，可能不同班次。
大眾運輸保留指定出發日期，超出過去 7 天／未來 100 天不偷偷改日期。

## 本機設定

1. 同一個 Google Cloud 專案建立獨立 Android 路線金鑰。
2. 應用程式限制選 Android，套件 `com.example.taipei_travel_app`。
3. 此電腦 debug SHA-1：`40:53:DE:EB:AC:11:4E:B4:A4:06:CF:B7:AE:D2:68:45:A8:89:62:89`。
4. API 限制只允許 Routes API；確認該 API 已啟用且計費可用。
5. 在被忽略的 `android/local.properties` 新增 `GOOGLE_ROUTES_API_KEY=實際金鑰`；原 GOOGLE_MAPS_API_KEY 保留給底圖。勿提交、截圖或貼出實際值。
6. 重新 build/install；hot reload 不會更新 manifest。

App 從 Android 套件及實際簽章讀取 X-Android-Package/X-Android-Cert。
HTTP 超時 25 秒，失敗不快取、不自動無限重試，不向使用者顯示 Google 原始錯誤本文。
成功查詢在執行期間共用記憶體快取，未持久保存 Google 原始回應。
手機金鑰可被擷取，限制不是無法破解的秘密；應設定配額／用量監控，正式散布前重新評估代理。

## 尚待實際驗證

- 正確 package/SHA-1 可成功，錯誤 package/SHA-1 被 Google 拒絕。
- 手機純步行、汽車時間及線條；大眾運輸參考線條。
- Web 回歸。單元測試與 APK 編譯不代表雲端驗收。

官方：https://developers.google.com/maps/api-security-best-practices
REST：https://developers.google.com/maps/documentation/routes/reference/rest/v2/TopLevel/computeRoutes
