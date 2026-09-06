# 行程安排分類介面整合紀錄

## 使用流程

1. 「建立新行程」只填寫名稱、日期、人數、預算、偏好與 AI 提示，不再先選縣市。
2. 進入「安排行程」後，可切換「安排景點」、「安排餐廳」、「安排住宿」。
3. 右上角新增按鈕會依目前分類開啟對應 Picker。
4. Picker 內才選縣市，並可用名稱、分類、地址或標籤搜尋；勾選後需按「套用選擇」，避免誤加項目。
5. 三種分類共用 Day 與中間時間軸；底部「不限日期／時間」只顯示目前分類。
6. 完成後，三種分類都會轉成既有 `RoutePlaceInput`，進入相同的路線與 TDX 排程流程。
7. 未指定日期的項目會先依地理鄰近順序排列，再切成連續天數；下一天從前一天最後一站出發。
8. 手動指定時間可選擇 `00:00` 至 `23:59`；自動排程在沒有手動限制時仍以 `09:00` 為預設起始時間。

## Supabase 資料表白名單

行程 Picker 只讀取以下資料表，不會自動掃描或連接其他資料表：

- 景點：`places`
- 餐廳：`Taiwan_Restaurants`、`osm_restaurants`
- 住宿：`Taiwan_Accommodations`

上述名稱是 Supabase 實際資料表名稱；介面中的「taiwan's restaurant」、「osm restaurant」與「taiwan's accomations」分別對應到這三個實際名稱。

## 資料格式

`Place` 新增以下欄位：

- `type`：`attraction`、`restaurant`、`accommodation`。
- `county`：縣市名稱，例如 `台北市`。

`Place.fromJson()` 支援一般 Supabase、TDX 餐廳與住宿資料欄位：

- 類型：優先讀取 `placeType`、`place_type` 或 `kind`，缺少時由 `category` 與 `tags` 推導。
- 縣市：解析 `county`、`city`、`City`、`location` 或 `縣市名稱`；有效縣市欄位優先，其次以座標對照內建縣市界線，最後才從地址辨識。`臺` 與 `台` 統一處理；無法判定時保留未知，不以縣市中心點偽造座標。
- Taiwan 中文欄位：`唯一識別碼`、`資料名稱`、`文字描述`、`縣市名稱`；地址由縣市、行政區及街道組合。
- TDX 名稱與識別碼：`RestaurantName`、`RestaurantID`、`HotelName`、`HotelID`。
- TDX 座標與圖片：`Position.PositionLat`、`Position.PositionLon`、`Picture.PictureUrl1`。

建立行程改以 `getTripCatalog()` 載入完整目錄；安排頁與結果頁的新增選擇器共用此目錄。沒有座標但有縣市欄位的資料仍可顯示、搜尋及依縣市篩選。

所有加入行程的資料仍必須有有效 `latitude` 與 `longitude`；Picker 對缺少座標的項目顯示「缺少座標，暫不可排入行程」並停用勾選。縣市篩選成功不代表已有路線所需的精確位置。

## 修改檔案

- `lib/models/place.dart`：新增三種類型與縣市欄位解析。
- `lib/services/place_service.dart`：新增全台可規劃資料、分類、縣市與關鍵字篩選。
- `lib/pages/trip_page.dart`：移除建立行程時的縣市選擇，改載入全台完整目錄，不在入口排除無座標資料。
- `lib/pages/trip_planner_page.dart`：加入分類切換，共用時間軸並串接分類 Picker。
- `lib/widgets/trip/planner_item_picker.dart`：新增共用選擇器。
- `lib/models/tdx_route.dart`：從 TDX `transport.mode` 辨識公車、捷運、台鐵與高鐵。
- `lib/services/tdx_route_ranker.dart`：以總旅行時間為主排序跨縣市候選路線，並保留步行與轉乘懲罰。
- `lib/services/tdx_service.dart`：將解析完成的 TDX 候選路線交由新的排序器處理。
- `lib/features/route_planning/services/itinerary_planning_service.dart`：加入跨日終點承接與地理連續分天。
- `lib/features/route_planning/widgets/travel_leg_card.dart`：加入台鐵、高鐵、渡輪與纜車中文名稱。
- `lib/services/map_service.dart`：加入台鐵與高鐵路線顏色。
- `lib/features/route_planning/widgets/trip_map_panel.dart`：地圖圖例加入台鐵與高鐵。
- `test/models/place_test.dart`：驗證類型與縣市解析。
- `test/services/place_service_test.dart`：驗證分類、縣市與搜尋。
- `test/widgets/trip/planner_item_picker_test.dart`：驗證 Picker 類型隔離與加入操作。

## 目前限制

- 餐廳可設定餐別、偏好用餐開始時段與停留；住宿可設定日期，並固定為住宿日的最後一站。詳見 `docs/meal-hotel-scheduling.md`。
- `TripRequest.location` 暫時填入 `全台` 以維持既有模型相容；新的縣市選擇以 Picker 為準。
- 第一天直接從排序後的第一個所選地點開始；飯店只顯示在住宿日最後，隔日第一段交通從前一晚飯店出發。未選住宿時暫承接前一天最後一站，並提示住宿尚未設定。
- TDX MaaS API 支援雙鐵，但特定日期、時間或偏遠起訖點仍可能沒有可用班次；此時既有流程會顯示估計時間。
