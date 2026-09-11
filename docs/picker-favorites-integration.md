# 行程選擇器收藏接入

景點、餐廳、住宿共用 `PlannerItemPicker`，提供「全部／我的收藏」。預設全部；切換來源保留勾選、縣市及搜尋條件。收藏只是篩選，不會自動加入行程，也不會更改收藏資料。

## 帳號資料接入介面

呼叫端傳入 `favoritePlaceIds: Set<String>`，內容必須與傳入 `places` 的 `Place.id` 完全相同。空集合表示已載入但沒有收藏；`null` 表示目前尚不可用，顯示 `favoritesUnavailableMessage`（預設「收藏功能準備中，請先使用全部清單」）。未登入、載入中或載入失敗時，可傳入相應文字；載入完成後由父元件重建選擇器並傳入集合。

接入位置為 `lib/pages/trip_planner_page.dart` 的兩個 `PlannerItemPicker` 建構呼叫。此版本不直接查詢帳號資料庫或呼叫 `FavoriteService`。

```dart
favoritePlaceIds: favoriteIds,
favoritesUnavailableMessage: '請先登入以使用收藏',
```

跨資料表 ID 必須保留資料來源，例如目錄已加上的前綴；請依 `Place.fromJson` 與目錄實際 ID 對應，不能僅比名稱或把 ID 強制轉整數。收藏項目必須存在於傳入目錄中才顯示；缺座標項目仍顯示但不可勾選。不要為了顯示收藏捏造座標。

驗收：三種類型皆可篩選收藏；縣市與關鍵字同時生效；切回全部仍保留勾選；登入者切換後父元件更新集合；查詢失敗與空集合分開顯示。
