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

- TDX：預設的大眾運輸班次、出發與抵達時間、行程排程。
- Google Routes：使用者選擇純步行或汽車時的交通時間、距離與實際路徑 geometry。
- Google Map：Marker 與 Polyline 顯示。

結果頁每一段交通預設使用大眾運輸（TDX）。使用者可從該段的「交通方式」改成純步行或汽車，只有被選取的路段改查 Google Routes；其他路段仍維持 TDX。更新後會重新計算後續行程時間。汽車固定使用 `TRAFFIC_UNAWARE`，不讀取即時路況。

新增、刪除、拖曳、修改停留時間或切換單段交通方式時，排程器會沿用起終點與交通方式未改變、且仍能趕上的既有路線。只有新路段、交通方式改變或原班次已無法搭乘的路段才重新查詢 API。

Google Routes 與 TDX 是不同規劃引擎，因此大眾運輸模式的 Google 地圖線條可能與 TDX 選出的實際車次不完全相同；大眾運輸的時間與文字交通資訊仍以 TDX 為準。

## 顯示與降級

- 步行：灰色虛線。
- 公車：橘色實線。
- 捷運：藍色實線。
- 鐵路：紫色實線。
- 汽車：綠色實線。
- 無法取得 Routes geometry：退回景點間直線並顯示警告。

同一個起點、終點與出發時間在單次 App 工作階段內會使用快取，避免反覆開關地圖產生重複請求。
