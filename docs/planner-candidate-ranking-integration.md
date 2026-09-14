# 新增項目候選清單：評分排序接口

> 收藏接入更新：兩個入口目前透過 `CloudPlannerItemPicker` 傳遞相同評分參數給 `PlannerItemPicker`。收藏僅限景點；收藏模式採資料夾而非縣市篩選，詳見 `planner-favorites-supabase-integration.md`。排序接口本身不變。

## 範圍與分工

本接口只調整「安排行程 → 新增項目」清單內的候選顯示順序，也接入結果頁的新增項目選擇器。程式類型為 `PlaceType.attraction`（景點）、`restaurant`（餐廳）、`accommodation`（住宿／飯店）。不改三個類型按鈕的順序，不改已加入的行程、日期分配、交通查詢或路線最佳化。

- 接口方：接收分數、穩定排序、保留搜尋／縣市／收藏篩選與勾選規則。
- 評分方（隊友）：定義公式、權重、資料來源及計算時機，將結果映射至目前目錄的 `Place.id`。
- 本次沒有預設評分算法，不會自動拿 `Place.rating` 當推薦分數，也不呼叫 Gemini 或其他 API。

## 入口

`lib/pages/trip_planner_page.dart` 的 `TripPlannerPage` 新增選填參數：

```dart
final Map<String, num> candidateScoresByPlaceId;
```

頁面會傳給兩個 `PlannerItemPicker` 呼叫點。若直接使用選擇器，`lib/widgets/trip/planner_item_picker.dart` 也接受同名參數。純排序函式在 `lib/services/planner_candidate_ranking.dart`。

```dart
// catalog 是傳入頁面的同一份 List<Place>。
// scoreById 由隊友的評分服務產生；以下數字僅示範接線，不是評分公式。
final scoreById = <String, num>{
  for (var i = 0; i < catalog.length; i++) catalog[i].id: 100 - i,
};

TripPlannerPage(
  request: request,
  places: catalog,
  candidateScoresByPlaceId: scoreById,
);
```

## 資料契約

| 情況 | 行為 |
| --- | --- |
| 分數 | 接受有限的 int/double，越高越前面；零與負數有效 |
| 同分 | 維持傳入目錄中的相對順序 |
| 缺少 ID、NaN、正負 Infinity | 視為未評分，排在所有有效分數之後，彼此維持原順序 |
| 未提供或空 Map | 完全維持原順序 |
| Map 有目錄不存在的 ID | 忽略，不新增候選項目 |
| 三種類型使用不同尺度 | 可以，先依類型篩選，不會跨類型比較 |

ID 必須精確使用 `Place.id`，包括載入目錄時的資料表前綴；不要用名稱、裸資料庫流水號或自行移除前綴。目錄需確保 ID 唯一。接口不修改傳入 List、Map 或 Place。

執行順序：類型／收藏／縣市／關鍵字篩選 → 分數排序 → 顯示。分數不影響篩選資格；缺少有效座標的項目仍可顯示，但依原規則不能勾選。卡片上的星等仍是 `Place.rating`，不是此推薦分數。

勾選用 ID 保存。`onConfirmed` 仍依原目錄順序回傳該類型全部已勾選項目，而不是畫面評分順序；因此不能把本接口當成旅遊路線排序接口。

## 非同步與更新

目前接口是預先計算好的分數快照，不接受 Future，也不負責 loading/error UI。建議隊友先完成評分，再建立頁面或開啟選擇器。失敗時可以傳空 Map，沿用目錄順序，不隱藏任何資料。

直接使用 Picker 時，父層可在相同 widget 身分下傳入新的 Map 並重建，清單會重新排序且保留勾選。不要原地修改 Map 卻不通知 UI 重建。`TripPlannerPage` 目前的 bottom sheet 不保證隨外部評分完成即時刷新；若需開啟中即時更新，隊友需另外接入狀態通知，或關閉後重新開啟。

## 驗收與測試

1. 三種類型各自按高分到低分顯示，同分穩定；無分數時不變。
2. 搜尋、縣市及收藏條件繼續生效，高分不能繞過篩選。
3. 未評分及非有限分數不造成例外；缺座標仍不可勾選。
4. 排序更新不清空勾選，確認回傳順序維持原契約。
5. 行程規劃與 routing optimizer 不因顯示分數而改動。

執行：`flutter test --no-pub test/services/planner_candidate_ranking_test.dart test/widgets/trip/planner_item_picker_test.dart`。
