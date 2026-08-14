# Development Demo Entrypoints

本專案保留兩個獨立的 Flutter Demo 入口，供功能開發、除錯與整合前驗證使用。它們不屬於正式 App 導覽，也不應從 `lib/main.dart` 或底部導覽列開啟。

## TDX Route Demo

- 入口：`lib/main_tdx_demo.dart`
- 頁面：`lib/pages/tdx_route_demo_page.dart`
- 原始功能來源：`clairelee20041020-TDXmodel-1`
- 用途：獨立測試 TDX 路線查詢、回傳解析與路線資訊 UI。
- 維護範圍：TDX 共用服務由團隊共用；Demo UI 主要用於保留 Claire 原本的單頁測試流程。

執行方式：

```powershell
flutter run -d chrome -t lib/main_tdx_demo.dart
```

## Route Planning Demo

- 入口：`lib/main_route_planning_demo.dart`
- 功能模組：`lib/features/route_planning/`
- 用途：獨立測試固定台北車站起點、景點排序、逐段 TDX 查詢、停留時間、每日行程、交通資訊與 Google Map 顯示。
- 維護範圍：GPS、地圖、路線與 TDX 行程串接功能。

執行方式：

```powershell
flutter run -d chrome -t lib/main_route_planning_demo.dart
```

## Required Local Configuration

Web Google Maps API Key 必須放在本機的 `web/maps_config.js`：

```javascript
window.MAPS_API_KEY = 'YOUR_WEB_GOOGLE_MAPS_API_KEY';
```

`web/maps_config.js` 不可提交至 Git。`web/maps_config.example.js` 只能保留 placeholder，不可放入真實 API Key。

TDX Demo 與 Route Planning Demo 會發送真實 TDX 請求，可能受到 API rate limit、429、班次時間與網路狀態影響。真實網路測試不應放入一般 CI 測試流程。

## Maintenance Rules

- 正式 App 入口固定使用 `lib/main.dart`。
- Demo 不加入底部導覽或正式 named routes。
- Demo 不保存 API Key、Token 或其他憑證。
- 修改共用 TDX Model 或 Service 時，兩個 Demo 都應重新驗證。
- 只有在正式頁面已能完整取代 Demo、相關負責人同意，且不再需要獨立除錯入口時，才可刪除 Demo。
- 刪除入口時，應同時移除只被該入口使用的頁面，避免留下無人知道用途的孤立檔案。
