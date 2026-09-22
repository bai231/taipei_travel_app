# Android 開發暫停紀錄

記錄時間：2026-09-19 04:29（Asia/Taipei）。使用者要求先記錄，剩下明天再做；不要自動繼續建置或排程喚醒。

## 2026-09-19 下午接續結果（優先於下方暫停時狀態）

- 2026-09-21 交通資訊調整：Android 每段步行／火車／公車及路線名稱保持顯示，站名、方向、途經站等各段獨立展開；大項 16 號半粗體、細項 13 號，保留系統字體縮放。Web 原路段顯示不變。5 項測試、靜態分析與 APK 編譯通過。
- Android 多日工具列：縮小／百分比／放大放在獨立同列，極窄寬度可橫向滑動、不拆行。確認磁碟片為 SaveItineraryButton，ios_share 圖示為 onExport；目前呼叫端未提供 onExport，因此 Android 隱藏未接入匯出按鈕，Web 不變。4 項測試及 APK 編譯通過。
- Android 交通卡片分層：主要顯示起終點、交通方式、時間／總耗時、轉乘次數及估計／失敗提醒；來源、距離、分段與途經站點改為「展開細項」。交通切換及導航保持可見，Web 保留原 ExpansionTile。4 項畫面／交通／平台測試及 APK 編譯通過。
- 2026-09-20 空白時段壓縮：僅 Android 單日課表將連續至少 2 個無景點占用的整點小時合併為短列；可點開、拖曳停留 500ms 展開，或展開全部。拖曳放開後收合臨時展開區。壓縮區拒絕直接放置，仍由展開後原有整點 DragTarget 決定真實時間，不改排程資料或 Web／多日版面。5 項測試通過（含時間對應、跨午夜、hover 展開／放開收合、實際拖曳及非 Android 回歸）。
- 2026-09-20：Android 單日模式改為共用時間課表，欄寬適應手機，保留 Day 切換；單日／多日 Android 卡片改長按拖曳，Web 原 Draggable 不變。跨日移動用多日總覽，鎖定／住宿／重排中仍不可拖動。新增長按移動後送出新時間的測試，3 項平台與交通回歸通過。
- Android 專用排版：以 !kIsWeb && TargetPlatform.android 隔離；新 AndroidDayItinerary 單日列表預設啟用，可切回多日總覽。總覽優先顯示名稱，交通／移除放操作選單；新增待安排景點時切回總覽供拖放。
- Android 未安排住宿／景點卡片改為可捲動直向列表，卡片隨內容增高，時間欄加寬；Web 保留原有分支，不因窄視窗進入 Android 設計。本次不回復先前已做的共用排版修改。
- Android／非 Android 平台隔離、縮放及交通模式 3 項 widget 測試通過，APK 編譯成功。trip_planner_page 靜態分析仍有既有 unused dart:convert 與 async context 提示，不宣稱全專案無警告。
- 使用者設定獨立 Routes key 後，唯讀確認本機已有值、未顯示金鑰。四次電腦端 REST 驗證：錯誤 package 403、錯誤 SHA-1 403、正確識別 WALK 200／1 條路線、DRIVE 200／1 條路線。此為受控 API 驗證，不等同手機畫面驗收。
- 含路線 key 的 Android debug APK 重新編譯成功（88.6 秒），adb install -r Success，MainActivity 啟動 Status: ok；待使用者在 App 重新產生行程確認步行／汽車時間與實際線條。大眾運輸 TDX 及 Google 參考線條尚未實際驗收。未提交／推送。
- 晚間接續驗證：Web build 成功（151.4 秒），直接路線／錯誤提示／結果頁／地圖／排程／選單合計 32 項測試全部通過。本機 GOOGLE_ROUTES_API_KEY 仍未設定，真實 API 驗收待使用者設定；未提交、推送或部署。
- 後續使用者決定 Android 先直接查詢、不部署代理：已新增 native REST client、步行／汽車排程 adapter、各交通方式 geometry adapter，Web 保留 JS bridge。汽車沿用 TRAFFIC_UNAWARE，大眾運輸排程仍用 TDX。
- Android MethodChannel 讀取獨立 GOOGLE_ROUTES_API_KEY、實際套件及 SHA-1，REST 使用 Android 限制標頭。金鑰由 local.properties 經 manifest 注入，未寫入版本庫。
- 6 項新直接查詢／錯誤測試、4 個服務檔靜態分析及 Android debug 編譯通過。本機尚缺 GOOGLE_ROUTES_API_KEY，未執行真實 Routes 查詢／錯誤識別拒絕驗證，也尚未安裝此缺金鑰版本。設定流程見 android-direct-routes.md。
- 結果頁第二輪修正：行程表加入 60%～180% 的加減縮放（調整日欄寬與時間刻度，不縮小系統字體），卡片依字體大小／可用寬高切換精簡樣式，日期表頭適應大字體；工具列可換行，移除常駐拖曳教學文字。
- 警告去重並移除「已自動移除重複景點」提示，其餘重要行程提醒改為計數入口，點開才顯示完整內容；沒有刪除排程本身的可行性警告。
- 新增 390px／1.5 倍字體縮放、警告收合測試，與既有交通模式切換測試共 2 項通過。未接入 Android 真實路線，不能把紅色示意線視為導航路線。
- 手機截圖確認底圖與景點列表能顯示；同時發現縣市選單右側溢出、地圖提示遮擋、交通例外直接顯示 URL。
- 已修正：窄螢幕／大字體將搜尋與選單上下排列，縣市下拉限制寬度；地圖完整說明、圖例與重試移至說明對話框；交通錯誤改為不含 URL 的簡短訊息，非 Web 路線線條明確回報未支援。
- 26 項相關測試通過（含 390px、1.5 倍字體及重試路段回歸），5 個修改來源檔靜態分析無問題，debug APK 建置成功。
- TDX 診斷：手機此次已能解析 tdx.transportdata.tw；ping 無回應不能判定 HTTPS 失敗。原截圖的 DNS 錯誤未重現，尚未驗證實際 TDX 路線請求成功；未更換金鑰、未修改 DNS 或消耗路線額度。
- Android Google 真實路線查詢與線條仍未實作；需另行確認後端代理與部署，勿將本次版面／提示修正當作路線功能完成。
- 14:09 左右更新：使用者表示地圖金鑰已設定；確認 android/local.properties 的 GOOGLE_MAPS_API_KEY 有非空值，檔案仍受忽略且未追蹤，未輸出金鑰。Google Cloud 截圖已顯示 Maps SDK for Android，不需重複啟用；新金鑰雲端限制未由工具獨立驗證。
- 帶入金鑰重新建置 debug APK 成功（Gradle 14.4 秒），adb install -r 成功，保留 App 資料並重新啟動 MainActivity（Status: ok）。App 程序持續執行，所查近期程序日誌沒有 AndroidRuntime/flutter/Google Maps Android API 錯誤；尚待使用者打開地圖確認底圖，不能據此視為地圖授權或登入／儲存流程驗收通過。
- 使用者已要求繼續。手機 ADB 狀態為 device，API 36 平台確認已安裝。
- Gradle 成功載入專案，依既有授權自動安裝 NDK 28.2.13676358，未手改授權檔或代同意新條款。
- 初次 APK 建置因 Kotlin 增量快取跨 C/D 磁碟出現 different roots，在 package_info_plus、url_launcher_android、shared_preferences_android、google_maps_flutter_android 失敗。
- android/gradle.properties 新增 kotlin.incremental=false，使用完整 Kotlin 編譯避開跨磁碟快取問題；代價是 Kotlin 重編速度，未修改執行時功能或 Web。官方設定：https://kotlinlang.org/docs/gradle-compilation-and-caches.html
- 重試 `flutter build apk --debug --dart-define-from-file=config/secrets.json` 成功（158.5 秒）。產物 build/app/outputs/flutter-apk/app-debug.apk，173485606 bytes，僅供內部測試，不散布含開發配置的 APK。
- debug.keystore 已由正常建置產生；未建立正式簽章。
- Application ID：com.example.taipei_travel_app。
- 本機 debug SHA-1：40:53:DE:EB:AC:11:4E:B4:A4:06:CF:B7:AE:D2:68:45:A8:89:62:89。
- 已用 adb install -r 成功安裝到使用者授權的 Samsung 手機，am start -W 回報 Status: ok、MainActivity 啟動，並取得 App PID。這是啟動層級確認，不等同登入／畫面／地圖／儲存驗收。
- 下一步需要使用者在 Google Cloud 啟用 Maps SDK for Android，建立 Android 專用 key，以以上 application ID + SHA-1 限制，API 限制僅 Maps SDK for Android；不要變更 Web key。實際 key 填入 android/local.properties 的 GOOGLE_MAPS_API_KEY，勿貼到聊天室或提交。
- 設定 key 後重新建置安裝（manifest 變更不能只 hot reload），再測底圖與基本流程。Android 路線查詢與線條仍未實作。
- 本次未 commit/push；原有使用者本機檔案保持不動。

## 目標與範圍

- 保留 Web，共用 Flutter 程式，只拆平台實作；不做正式上架、正式簽章或新 application ID。
- 先完成 Android 基本啟動與地圖，再另行補路線查詢／線條。個人頁資料夾及行程列表／詳情仍由隊友接入。
- main 與 klorius-route-optimizer 上次均已推到 5ade497；本次未重新 fetch，不能把它視為明天的最新遠端狀態。

## Git 與檔案

- 當前分支 codex/android-support，從當次最新 origin/main 建立，HEAD 5ade497。Android 工作尚未 commit/push。
- android/app/src/main/AndroidManifest.xml：新增 INTERNET 與 com.google.android.geo.API_KEY placeholder。
- android/app/build.gradle.kts：透過 Properties 讀取 android/local.properties 的 GOOGLE_MAPS_API_KEY，缺少時空字串。
- docs/android-development-setup.md：環境操作文件；初次檢查段落已更新，詳情以本紀錄為準。
- android/local.properties 已確認受 Git ignore，不受追蹤。先前檢查未配置 Android Maps key，不要印出或提交真實金鑰。
- Flutter 初次建置已補齊原本缺少的 android/gradlew.bat 等 wrapper 本機檔案。
- 既有 .vscode/settings.json、Linux/macOS/Windows 生成檔修改，以及 docs/travel-app-development-record-2026-09-11.md，均須保留、不混入 Android 提交。
- XML、INTERNET 與地圖 placeholder 靜態檢查通過，git diff --check 通過；未完成 Android 編譯或實機功能驗收。

## 電腦與手機狀態

- Flutter 3.47.0，Dart 3.13.0；Flutter 路徑 C:\Users\user\flutter。
- Android SDK 已安裝：C:\Users\user\AppData\Local\Android\sdk。
- doctor 回報 platform android-37.0、Build-Tools 36.0.0；是否另有 android-36 平台需明天核對，不能將 Build-Tools 36 當成平台已安裝。
- Android Studio JBR：C:\Program Files\Android\Android Studio\jbr，Java 25.0.3。
- Gradle wrapper 9.1.0，AGP 9.0.1，Kotlin 2.3.20。尚未修改版本。
- 手機 Samsung SM-A576B（A57）、Android 16 API 36。先前 unauthorized，使用者確認後 ADB 已回報 device，Flutter 可辨識。明天重新查 devices，不假設裝置持續連線。
- 自動封鎖程式曾阻擋 USB／無線偵錯，已向使用者說明測試完應關閉 USB 偵錯並恢復防護；不要代操作安全設定。
- Visual Studio 缺少僅影響 Windows 桌面版，本次不用處理。

## SDK 授權提示的根因

使用者親自執行 flutter doctor --android-licenses，得到 sdkmanager deprecated 與 --licenses no longer needed，未出現逐項授權。

已檢查本機原始碼：Command-line Tools 23.0 的 sdkmanager.bat 對 --licenses 只輸出新警告；Flutter 3.47.0 的 android_workflow.dart 仍解析舊式 All SDK package licenses accepted 訊息，未匹配則 unknown。因此目前是檢查相容性問題，不代表已證實缺少授權，也不代表所有元件授權已確認。

不要重複要求使用者跑相同指令、不要自動同意授權、不要手改 licenses 檔。以實際 Gradle 結果判斷是否缺少套件或授權，有新條款交給使用者確認。

## 本次建置與暫停

1. 直接跑 :app:signingReport 因 gradlew.bat 不存在失敗。
2. 改執行 flutter build apk --debug --dart-define-from-file=config/secrets.json，Flutter 補齊 wrapper 並下載 Android 引擎元件。
3. 已進入 assembleDebug，啟動 Gradle 9.1.0 daemon；只看到 Java native-access 警告，尚無明確失敗原因，不能把警告當作失敗根因。
4. 使用者要求暫停後，對本次執行 session 69517 傳送 Ctrl+C，程序以 exit code 1 結束。此結束來自中止，不代表編譯錯誤。Gradle 背景 daemon 是否仍閒置未另行確認，未任意停止其他 Java 程序。
5. 暫停時未見 build/app/outputs/flutter-apk 產物；C:\Users\user\.android\debug.keystore 不存在，SHA-1 尚未取得；未安裝 App 到手機。

## 明天接續順序

1. 先讀本紀錄、確認 Git 差異與裝置授權；不要覆蓋未提交的 Android 設定或既有使用者檔案。
2. 檢查目前 Gradle 程序／日誌及 SDK 元件，避免重複啟動仍在運作的任務。視需要用具體錯誤排查下載、Java、Gradle 或 SDK 相容性，不預設需要升降版。
3. 繼續 debug 建置；若需要新套件授權，停下請使用者確認。不要宣稱只要等待就一定成功。
4. wrapper 已有後可在 android 目錄執行 :app:signingReport，僅在該 shell 設定 JAVA_HOME 為 Android Studio jbr。若 debug keystore 仍不存在，先完成正常 debug 建置再取指紋，不建立正式簽章。
5. 取得 application ID（目前 com.example.taipei_travel_app）與實際 debug SHA-1 後，提供給使用者設定 Google Cloud Maps SDK for Android／Android 專用受限金鑰。不要改網頁金鑰限制。
6. 使用者將 key 填到忽略追蹤的 local.properties 後，再用已授權手機啟動 App，檢查首頁、登入、資料讀取與底圖。
7. Android 的 GoogleRoutePlanningService stub 仍拋不支援錯誤，geometry stub 回傳空資料；產生估計交通時間不代表真實路線已支援。後端代理方案、Android 路線功能與 Web 回歸後續另做。

目前不需使用者再輸入金鑰、提供密碼或重做 USB 授權；明天以檢查結果為準。
