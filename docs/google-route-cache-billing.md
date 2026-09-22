# Google 路線按需查詢與快取

排程只取時間與距離；地圖開啟後才取路徑。未合併 API 回傳欄位，也未改動 TDX。

兩個 Web 服務使用 `GoogleRouteRequestCache.shared`。`information:` 與 `geometry:` 分開保存不同內容，避免把時間資料誤當路徑；同用途、同參數的進行中請求共用 Future。成功結果在網頁執行期間重用，重新整理後清除；錯誤與空路徑不保留，後续可再查。

座標及交通方式構成查詢鍵。僅 TRANSIT 包含 UTC 出發時間；WALKING 與 TRAFFIC_UNAWARE 汽車不受出發時間微調影響。排程重用時間結果時，仍按新的出發時間產生抵達時間。未新增跨時間的大眾運輸重用。

首次步行／汽車排程為一次時間查詢；首次開圖通常再一次路徑查詢；其後相同參數命中快取不送出路線請求。底圖載入不包含在路線快取內。不同用途的請求不合併成同一次網路呼叫。

## 官方計費核對（2026-09-08）

目前 JavaScript `Route.computeRoutes` 的步行、無即時路況汽車及一般 transit，依現有參數判斷屬 Compute Routes Essentials；没有使用進階途經點、路況、機車、過路費或交通著色等觸發較高 SKU 的功能。基本 duration/distance/path 並不是各自獨立計費；每次成功請求按其最高級別的一個 SKU 計費。

全球標準隨用隨付價：Compute Routes Essentials 每月免費 10,000 次，第一個付費區間每 1,000 次 USD 5；Dynamic Maps 每月免費 10,000 次載入，第一個付費區間每 1,000 次 USD 7。時間與路徑共用路線 SKU 額度，不是各有一份免費額度。這不是帳號剩餘額度查核；實際帳單仍以 Cloud Billing 的 SKU、合約及其他用量為準。

- https://developers.google.com/maps/documentation/javascript/usage-and-billing
- https://developers.google.com/maps/billing-and-pricing/sku-details
- https://developers.google.com/maps/billing-and-pricing/pricing

測試包含同時請求去重、完成後重用、時間鍵差異、不同用途隔離，以及失敗／空結果可重試。不使用真實金鑰或發送計費查詢。
