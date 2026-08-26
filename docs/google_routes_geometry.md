# Google Routes 實際路徑顯示

## Google Cloud 設定

目前 Web 地圖沿用 `web/maps_config.js` 中的 Maps JavaScript API key，不需要把新金鑰寫入 Dart。

請在同一個 Google Cloud 專案啟用：

1. Maps JavaScript API
2. Routes API

API key 建議設定：

- 應用程式限制：網站。
- 開發來源：`http://localhost/*` 與 `http://localhost:*/*`。
- 正式來源：部署後的 HTTPS 網域。
- API 限制：Maps JavaScript API、Routes API。

`web/maps_config.js` 必須維持在 `.gitignore`，只提交 `web/maps_config.example.js`。

## 資料分工

- TDX：交通班次、出發與抵達時間、行程排程。
- Google Routes：地圖上的道路、步行與大眾運輸實際路徑 geometry。
- Google Map：Marker 與 Polyline 顯示。

Google Routes 與 TDX 是不同規劃引擎，因此 Google 顯示的建議路徑可能與 TDX 選出的車次不完全相同。V1 將 Google 路徑視為地圖示意，時間與文字交通資訊仍以 TDX 為準。

## 顯示與降級

- 步行：灰色虛線。
- 公車：橘色實線。
- 捷運：藍色實線。
- 鐵路：紫色實線。
- 無法取得 Routes geometry：退回景點間直線並顯示警告。

同一個起點、終點與出發時間在單次 App 工作階段內會使用快取，避免反覆開關地圖產生重複請求。
