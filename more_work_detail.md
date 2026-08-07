
---

# 整體開發階段規劃

我先定義你們的目標版本：

## V1 Prototype（目前 → 可展示）

目標：

完成：

* 景點瀏覽
* 收藏景點
* 建立旅程
* 基本推薦
* 地圖定位展示

---

## V2 Intelligent Travel App

目標：

加入：

* GPS
* 路線最佳化
* AI 行程生成
* 即時調整

---

# Timeline 建議

假設有約 8～10 週開發時間：

| 階段      | 時間       | 目標          |
| ------- | -------- | ----------- |
| Phase 0 | Week 1   | 架構整理、UI統一   |
| Phase 1 | Week 2-3 | 完成核心 App 流程 |
| Phase 2 | Week 4-5 | 加入資料庫與定位    |
| Phase 3 | Week 6-7 | 推薦演算法       |
| Phase 4 | Week 8-9 | AI + 最佳化    |
| Phase 5 | Week 10  | 測試、簡報       |

---

# 人員分配

---

# A：Frontend / UI / Flutter整合負責人

## 主要任務

負責：

> 使用者看到與操作的部分

負責資料夾：

```
lib/pages/

lib/widgets/

lib/routes/
```

---

# Phase 0（Week 1）

## 任務

### 1. 整理 Flutter UI 架構

完成：

```
pages/

widgets/

theme/
```

建立：

```
theme/
 └── app_theme.dart
```

統一：

* 顏色
* 字體
* Button樣式

---

### 2. 完成首頁 UI

目前：

HomePage

需要改善：

* 搜尋列
* 景點分類
* 橫向 Card
* 熱門推薦區

例如：

```
熱門景點

< PlaceCard >
< PlaceCard >
< PlaceCard >
```

---

### 3. 完成 PlaceCard

加入：

* 景點圖片
* 評分
* 距離
* 收藏按鈕
* 詳細資訊

---

# Phase 1（Week 2-3）

完成：

## Trip流程 UI

包含：

### TripPage

已經開始做：

* 行程名稱
* 日期
* 地點
* 預算
* 偏好

新增：

### TripDetailPage

顯示：

```
我的行程

Day1

09:00 台北101

12:00 午餐

18:00 夜景
```

---

# Phase 2

加入：

### MapPage UI

負責：

* Google Map 顯示
* Marker UI
* 行程路線顯示

---

# Phase 3

負責：

AI結果呈現

例如：

AI產生：

```
推薦行程

Day1:
...
```

---

# B：Backend / Database / Data Manager

## 主要任務

負責：

> App資料如何流動

資料夾：

```
models/

services/

data/
```

---

# Phase 0

## 整理資料模型

建立：

```
models/

place.dart

trip.dart

user.dart
```

---

## Place Model

目前：

```dart
Place(
 id,
 name,
 category
)
```

擴充：

加入：

```dart
latitude

longitude

openingTime

rating

imageUrl
```

---

## Trip Model

建立：

```dart
Trip(

 id,

 title,

 startDate,

 endDate,

 location,

 people,

 budget,

 preferences

)
```

---

# Phase 1

完成：

## 收藏系統

目前：

```
FavoriteService
```

改成：

永久保存。

例如：

Firebase:

```
users

 └── favorites

      ├── place1
      └── place2
```

---

## 行程保存

完成：

```
TripService
```

功能：

新增行程

修改行程

刪除行程

---

# Phase 2

## Firebase

建立：

* Authentication
* Firestore

資料：

```
users

places

trips
```

---

# Phase 3

提供推薦系統資料：

例如：

輸出：

```json
{
budget:5000,

preference:[
"food",
"photo"
]
}
```

給推薦模組。

---

# C：GPS / Map / Route Engineer

## 主要任務

負責：

> 空間資訊與路線

資料夾：

新增：

```
services/

location_service.dart

map_service.dart


algorithm/

route_optimizer.dart
```

---

# Phase 0

研究 API：

需要：

Google Maps API

Flutter：

```
google_maps_flutter

geolocator
```

---

# Phase 1

完成：

## GPS定位

功能：

取得：

```
latitude

longitude
```

例如：

使用者：

```
25.0478
121.5170
```

---

# Phase 2

完成：

## 地圖功能

包含：

### Marker

顯示：

```
📍台北101

📍故宮
```

---

### 距離計算

例如：

使用者：

台北車站

計算：

```
台北101

3.5km
```

---

# Phase 3

完成：

## 路線規劃初版

不要一開始做 AI。

先做：

Rule:

```
距離最近
↓

排序
↓

產生路線
```

---

# Phase 4

進階：

加入：

TSP

Genetic Algorithm

目標：

減少：

```
台北101

↓

故宮

↓

又回信義區
```

這種問題。

---

# D：AI / Recommendation Algorithm

## 主要任務

負責：

> 行程智慧化

資料夾：

新增：

```
algorithm/

recommendation.dart


services/

ai_service.dart
```

---

# Phase 0

研究：

需求如何轉成推薦條件。

例如：

使用者：

```
喜歡：

攝影

夜景

預算5000
```

轉：

```
filter:

category=photo

category=night
```

---

# Phase 1

完成：

## Rule-based Recommendation

不用 AI。

例如：

規則：

```
如果喜歡攝影

推薦：

象山

101

大稻埕
```

---

# Phase 2

加入：

推薦排序。

考慮：

權重：

```
distance 30%

rating 30%

preference 40%
```

產生：

推薦分數。

---

# Phase 3

加入 AI API

流程：

```
User Input

↓

TripRequest

↓

Prompt Generator

↓

AI API

↓

Generated Trip
```

---

例如：

產生：

Prompt:

```
請安排台北兩日旅遊

需求：

4人

預算8000

喜歡攝影
```

---

# Phase 4

AI與Route結合

AI：

負責：

```
去哪裡
```

Route：

負責：

```
怎麼走
```

兩者結合。

---

# 四人合作關係

最後整合：

```
             User

              |

          Flutter UI

              |

       TripRequest Model

              |

 ┌────────────┼────────────┐

Backend    GPS        AI

資料       地圖       推薦

              |

        Final Trip

              |

       TripDetailPage
```

---

# 每週 Milestone (看看就好 時間好像沒這麼多(..;))

## Week 1

所有人：

完成：

* 架構整理
* Git流程
* UI規格

A：
首頁UI

B：
Model整理

C：
研究Google Map

D：
推薦規則設計

---

## Week 2-3

目標：

完成 MVP

必須能：

```
瀏覽景點

↓

收藏

↓

建立旅程

↓

查看行程
```

---

## Week 4-5

加入：

```
GPS

Firebase

真實資料
```

---

## Week 6-7

加入：

```
推薦演算法

路線排序
```

---

## Week 8-9

加入：

```
AI API

Prompt生成

AI行程
```

---

## Week 10

比賽準備：

* Demo流程
* UI美化
* PPT
* 技術文件

---

