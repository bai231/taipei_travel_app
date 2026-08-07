# DevelopGuide.md


# 1. 專案目前完成狀態

## Project Status

目前版本：

> Travel Planning App Prototype V1

目標：

建立一個可以根據使用者需求規劃旅遊行程的手機 App。

目前已完成：

---

## 已完成功能

### 1. 景點瀏覽系統

完成：

* 首頁景點展示
* 景點 Card
* 景點假資料
* 景點分類展示

目前資料來源：

```
data/fake_place.dart
```

資料格式：

```dart
Place(
 id,
 name,
 category,
 location,
 description
)
```

---

### 2. 景點收藏系統

完成：

使用者可以：

```
首頁

↓

收藏景點

↓

Profile Page

↓

查看收藏
```

相關檔案：

```
services/
    favorite_service.dart


pages/
    profile_page.dart
```

---

### 3. 行程建立 UI

完成：

使用者可以輸入：

* 行程名稱
* 日期
* 地點
* 人數
* 預算
* 旅遊偏好
* 額外需求

目前只有 UI。

尚未：

* 儲存資料
* 生成行程

相關檔案：

```
pages/
    trip_page.dart


widgets/trip/

    trip_name_field.dart
    trip_date_field.dart
    trip_location_field.dart
    people_counter.dart
    budget_field.dart
    preference_chip_group.dart
    ai_prompt_field.dart
```

---

# 2. 距離正式版本還需要完成什麼？

---

# Phase 1：資料與後端基礎建設

## 目標

不要再使用假資料。

目前：

```
fake_place.dart

↓

App
```

未來：

```
Database/API

↓

App
```

---

## 需要完成

### (1) 真實景點資料庫

需要資料：

* 景點名稱
* 地址
* GPS座標
* 開放時間
* 門票
* 評價
* 圖片
* 類型

例如：

```json
{
"name":"台北101",
"lat":25.0339,
"lng":121.5645,
"type":"景觀"
}
```

---

技術：

可能使用：

* Firebase Firestore
* MySQL
* PostgreSQL

---

負責：

資料庫 / Backend

---

# Phase 2：GPS定位系統

## 目標

讓 App 知道使用者位置。

例如：

使用者：

```
目前位置：

台北車站
```

App 可以：

```
推薦附近景點

↓

中正紀念堂
西門町
北門
```

---

需要：

Flutter:

```
geolocator
```

功能：

* 取得目前位置
* GPS權限
* 距離計算

---

需要資料：

景點：

```
latitude
longitude
```

---

例如：

公式：

```
使用者位置

↓

計算距離

↓

排序最近景點
```

---

# Phase 3：行程生成演算法

## 目標

根據：

使用者需求：

```
日期
地點
人數
預算
偏好
```

產生：

```
Day1

09:00 早餐

10:00 台北101

12:00 午餐

14:00 故宮

18:00 士林夜市
```

---

初版不需要 AI。

可以先使用：

## Rule-based Algorithm

例如：

使用者選：

```
攝影
夜景
```

系統：

搜尋：

```
category == 攝影
category == 夜景
```

排序：

```
距離
評分
營業時間
```

---

之後升級：

Optimization Algorithm：

例如：

* Traveling Salesman Problem(TSP)
* Genetic Algorithm
* Constraint Programming

解決：

最短路線

避免：

來回跑。

---

# Phase 4：AI推薦系統

## 目標

讓 AI 產生更自然的旅遊規劃。

輸入：

```
TripRequest
```

例如：

```text
我要兩天台北旅遊

4個人

預算8000

喜歡攝影、美食

不要太趕
```

送給：

LLM API

例如：

* OpenAI API
* Gemini API

輸出：

```
Day1

上午:
象山拍照

中午:
信義區美食

晚上:
101夜景
```

---

AI負責：

* 理解需求
* 生成描述
* 調整推薦

但是：

GPS與路線：

仍然需要：

地圖服務。

---

# Phase 5：地圖與導航

## 目標

讓使用者看到：

```
地圖

↓

景點位置

↓

行程路線
```

---

技術：

Flutter：

```
google_maps_flutter
```

功能：

* 地圖顯示
* Marker
* 路線

---

需要：

Google Maps API

---

# Phase 6：即時調整系統

（你們原始構想的重要特色）

例如：

原行程：

```
14:00 故宮
```

但是：

火車延誤。

App：

```
偵測目前時間

↓

發現無法抵達

↓

詢問：

是否重新安排？
```

---

需要：

資料：

* GPS
* 時間
* 交通資訊

技術：

* Google Directions API
* Transport API

---

# Phase 7：使用者系統

正式版需要：

* 登入
* 個人資料
* 儲存旅程

技術：

Firebase Authentication

---

# 3. 四人分工建議

我建議不要按照「頁面」分。

因為之後容易互相卡住。

應按照模組分。

---

# A：Frontend / UI 負責人

## 工作

負責所有畫面。

包含：

```
pages/

widgets/
```

工作：

* HomePage
* ProfilePage
* TripPage
* PlaceCard
* UI美化
* Material Design

需要技能：

Flutter UI

---

# B：資料與Backend負責人

## 工作

負責資料流。

包含：

```
models/

services/

data/
```

工作：

* Place Model
* Trip Model
* Firebase
* API串接
* 資料保存

需要技能：

Database
Flutter Service

---

# C：地圖與定位負責人

## 工作

負責：

GPS

Map

Route

新增：

```
services/location_service.dart

pages/map_page.dart
```

工作：

* GPS定位
* 景點距離
* 地圖Marker
* 路線

需要技能：

Google Map API

---

# D：AI與推薦演算法負責人

## 工作

負責：

推薦邏輯。

新增：

```
services/recommend_service.dart

algorithm/
```

工作：

第一階段：

Rule-based推薦

第二階段：

AI API

第三階段：

最佳化演算法

需要技能：

Python / Algorithm / AI

---

# 4. 目前專案架構

下面我會根據你們**目前 Flutter 旅遊 App Prototype 的版本**來介紹檔案架構。

目標是讓之後加入的新組員知道：

* 每個資料夾負責什麼
* 哪些檔案可以修改
* 哪些檔案不要直接亂改
* 未來 GPS、AI、推薦演算法應該放哪裡

---

# 目前專案架構

目前建議：

```text
travel_app/

├── android/
├── ios/
├── web/
├── assets/
│
├── lib/
│   │
│   ├── main.dart
│   │
│   ├── models/
│   │
│   ├── data/
│   │
│   ├── services/
│   │
│   ├── pages/
│   │
│   ├── widgets/
│   │
│   └── dialogs/
│
├── pubspec.yaml
│
└── DevelopGuide.md
```

---

# 1. main.dart

位置：

```text
lib/main.dart
```

## 功能

整個 App 的入口。

Flutter 啟動時第一個執行的檔案。

負責：

* 初始化 App
* 設定 Theme
* 設定首頁
* 設定路由

例如：

```dart
void main(){

 runApp(
   MyApp()
 );

}
```

---

目前可能：

```text
main.dart

↓

HomePage
```

未來：

```text
main.dart

↓

Router

↓

HomePage
TripPage
ProfilePage
MapPage
```

---

# 2. models（資料模型）

位置：

```text
lib/models/
```

用途：

> 定義 App 中「資料長什麼樣子」

目前：

```text
models/

└── place.dart
```

---

## place.dart

代表一個景點。

例如：

```dart
class Place{

final String id;

final String name;

final String category;

}
```

代表：

```text
台北101

id:
001

category:
景觀
```

---

未來新增：

```text
models/

├── place.dart

├── trip.dart

├── user.dart

└── recommendation.dart
```

---

## trip.dart

代表一個旅程。

例如：

```dart
Trip(

title:"台北兩日遊",

budget:8000,

people:4

)
```

---

## user.dart

代表使用者。

例如：

```dart
User(

name,

favoritePlaces,

trips

)
```

---

# 3. data（靜態資料）

位置：

```text
lib/data/
```

用途：

> 放測試資料、假資料

目前：

```text
data/

└── fake_place.dart
```

---

## fake_place.dart

目前取代資料庫。

例如：

```dart
List<Place> places=[

 Place(
  name:"台北101"
 ),

 Place(
  name:"故宮"
 )

];
```

---

目前資料流：

```text
fake_place.dart

↓

PlaceService

↓

HomePage

↓

PlaceCard
```

---

未來：

會被：

```text
Firebase

或

Backend API
```

取代。

變成：

```text
Database

↓

Service

↓

Page
```

---

# 4. services（商業邏輯）

位置：

```text
lib/services/
```

這是非常重要的一層。

用途：

> 處理資料與功能，不直接寫 UI。

目前：

```text
services/

├── place_service.dart

└── favorite_service.dart
```

---

# place_service.dart

負責：

景點資料管理。

例如：

```dart
getPlaces()
```

取得景點：

```text
Place List

↓

HomePage
```

---

未來：

可能變：

```dart
getNearbyPlaces(
 latitude,
 longitude
)
```

加入 GPS。

---

# favorite_service.dart

負責：

收藏功能。

目前：

```text
HomePage

↓

FavoriteService

↓

收藏List

↓

ProfilePage
```

---

未來：

改：

```text
Firebase

↓

FavoriteService

↓

ProfilePage
```

---

未來 services：

```text
services/

├── place_service.dart

├── favorite_service.dart

├── trip_service.dart

├── location_service.dart

├── map_service.dart

├── recommend_service.dart

└── ai_service.dart
```

---

# 5. pages（完整頁面）

位置：

```text
lib/pages/
```

用途：

> App 的主要畫面

目前：

```text
pages/

├── home_page.dart

├── profile_page.dart

└── trip_page.dart
```

---

# home_page.dart

首頁。

負責：

* 顯示景點
* 搜尋
* 分類推薦

流程：

```text
HomePage

↓

PlaceService

↓

PlaceCard
```

---

# profile_page.dart

個人頁。

目前：

顯示：

* 收藏景點

未來：

增加：

* 我的行程
* 使用者資料
* 設定

---

# trip_page.dart

建立旅程頁。

目前：

輸入：

* 行程名稱
* 日期
* 地點
* 人數
* 預算
* 偏好
* AI需求

未來：

送：

```text
TripRequest

↓

AI

↓

TripDetailPage
```

---

# 6. widgets（可重複使用元件）

位置：

```text
lib/widgets/
```

用途：

> 小型 UI 元件。

目前：

```text
widgets/

├── place_card.dart

└── trip/

```

---

# place_card.dart

景點卡片。

顯示：

```text
圖片

名稱

分類

收藏按鈕
```

使用：

```dart
PlaceCard()
```

---

## trip 資料夾

專門放建立行程相關元件。

目前：

```text
widgets/trip/

├── trip_name_field.dart

├── trip_date_field.dart

├── trip_location_field.dart

├── people_counter.dart

├── budget_field.dart

├── preference_chip_group.dart

├── ai_prompt_field.dart

└── create_trip_button.dart
```

---

## 各自功能

### trip_name_field.dart

行程名稱輸入：

```text
台北兩日遊
```

---

### trip_date_field.dart

日期選擇：

```text
8/15 ~ 8/17
```

---

### trip_location_field.dart

地點：

```text
台北市
```

---

### people_counter.dart

人數：

```text
- 4 +
```

---

### budget_field.dart

預算：

```text
8000
```

---

### preference_chip_group.dart

偏好：

```text
美食
攝影
夜景
```

---

### ai_prompt_field.dart

自由需求：

```text
不要太趕
想拍夜景
```

---

### create_trip_button.dart

按鈕：

```text
AI規劃行程
```

---

# 7. dialogs（彈出視窗）

位置：

```text
lib/dialogs/
```

用途：

放需要跳出的視窗。

例如：

未來：

```text
新增行程

↓

Dialog

↓

輸入資料
```

---

目前可能還沒有很多內容。

未來：

```text
dialogs/

├── add_to_trip_dialog.dart

├── create_trip_dialog.dart

└── place_detail_dialog.dart
```

---

# 8. assets（圖片與資源）

位置：

```text
assets/
```

放：

圖片：

```text
assets/images/

taipei101.png

museum.png
```

---

字型：

```text
assets/fonts/
```

---

使用前要在：

```text
pubspec.yaml
```

註冊。

---

# 整體資料流（非常重要）

目前：

```text
             fake_place.dart
                    |
                    ↓
            place_service.dart
                    |
                    ↓
                HomePage
                    |
                    ↓
              PlaceCard
                    |
                    ↓
             FavoriteService
                    |
                    ↓
             ProfilePage
```

---

未來完整版本：

```text
User

↓

Flutter UI

↓

Service Layer

↓

Database/API

↓

AI / GPS / Algorithm

↓

Result

↓

UI展示
```

---

# 組員修改指南

## 如果我要改畫面

改：

```text
pages/

widgets/
```

不要碰：

```text
services/
models/
```

---

## 如果我要改資料格式

例如增加：

景點評分

改：

```text
models/place.dart
```

---

## 如果我要接 Firebase

改：

```text
services/
```

不要改：

Page。

---

## 如果我要加入 AI

新增：

```text
services/

ai_service.dart


algorithm/

recommendation.dart
```

---

## 如果我要加入 GPS

新增：

```text
services/

location_service.dart

map_service.dart
```

---

# 最後建議你在 DevelopGuide.md 補一張表

| 資料夾       | 用途    | 主要負責人          |
| --------- | ----- | -------------- |
| models    | 資料結構  | Backend        |
| data      | 測試資料  | Backend        |
| services  | 功能邏輯  | Backend/AI/GPS |
| pages     | 完整畫面  | Frontend       |
| widgets   | UI元件  | Frontend       |
| dialogs   | 彈窗    | Frontend       |
| algorithm | 推薦演算法 | AI             |

---

這份整理可以直接放進 `DevelopGuide.md` 的「Project Structure」章節。之後不管是教授、隊友、甚至半年後的自己回來看，都可以快速理解整個專案。


---

# 5. 建議開發順序

我建議：

```
現在
 |
 ↓
完成 Trip Model
 |
 ↓
收藏 → 行程建立
 |
 ↓
Firebase資料保存
 |
 ↓
GPS定位
 |
 ↓
地圖
 |
 ↓
推薦演算法
 |
 ↓
AI API
 |
 ↓
即時調整
```

原因：

AI 不應該最先做。

真正的核心其實是：

```
資料
 +
位置
 +
推薦邏輯
```

AI 是最後包裝使用者體驗的工具。

---
