# Android 實機開發設定（不含正式上架）

## 已完成的程式設定

- Android 開發分支：codex/android-support，從當次最新 origin/main 建立。
- 主 AndroidManifest.xml 宣告 INTERNET，並以 GOOGLE_MAPS_API_KEY placeholder 配置地圖。
- android/app/build.gradle.kts 從忽略追蹤的 android/local.properties 讀取 GOOGLE_MAPS_API_KEY。未提供時使用空值，基本建置不因此中止，但不能視為地圖可用。
- 未改網頁版、未新增定位／背景定位權限、未變更正式簽章，也未實作 Android 路線查詢。

## 環境檢查紀錄

初次檢查尚未安裝 SDK。2026-09-19 已安裝 SDK、API 36、NDK 與 Android Studio，Samsung A57 已完成 ADB 授權。下午接續工作後，已排除 Kotlin 跨磁碟增量快取問題、成功建置 debug APK 並安裝啟動；尚待地圖 key 與實際功能驗收。新版命令列工具造成 Flutter 授權狀態 unknown，詳情與本機 SHA-1 見 [Android 進度紀錄](android-progress-2026-09-19.md)。Visual Studio 缺少只影響 Windows 桌面開發，本次不需處理。

## 使用者需完成

1. 安裝官方 Android Studio，首次啟動透過 Setup Wizard 安裝 Android SDK，親自閱讀及接受必要授權。若已裝在其他位置，提供安裝路徑即可，無需重裝。
2. SDK Manager 確認 SDK Platform、Platform-Tools、Build-Tools 及 Command-line Tools 可用；其他版本需求以 doctor／實際建置結果為準。
3. 手機開啟 USB 偵錯，以資料線連接並在手機上允許這台電腦。
4. 工具鏈就緒後由開發者取得 app debug SHA-1，再到 Google Cloud 啟用 Maps SDK for Android、確認計費，配置 Android 專用金鑰，限制 package name + debug SHA-1 及 Maps SDK for Android。不要更改網頁金鑰的網站限制。
5. 在 android/local.properties 保留 SDK 等原有設定，新增 `GOOGLE_MAPS_API_KEY=實際值`。不要提交或在聊天貼金鑰。套件名稱目前為 com.example.taipei_travel_app。

## 工具鏈就緒後的命令

```powershell
flutter doctor -v
flutter devices
Push-Location android
try { .\gradlew.bat signingReport } finally { Pop-Location }
flutter run -d <device_id> --dart-define-from-file=config/secrets.json
```

如有 SDK 授權未完成，由使用者執行 `flutter doctor --android-licenses` 並自行閱讀確認；不可自動接受授權。

TDX 的現有編譯參數只供內部開發測試，不代表憑證受保護或適合散布 APK。Google 地圖金鑰也會進入 App，必須使用平台及 API 限制。App 能啟動不代表 Google 路線查詢完成：目前非 Web 排程路線服務仍不支援，線條服務仍回傳空資料。

官方環境文件：https://docs.flutter.dev/platform-integration/android/setup
