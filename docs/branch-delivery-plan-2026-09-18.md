# 個人分支分批交付計畫

日期：2026-09-18。這是計畫，尚未執行本次 commit 或 push。
目標：origin/klorius-route-optimizer，不直接推 main，不重寫歷史、不 force push。

## 已檢查的基礎狀態

- 已執行 git fetch origin。當前 HEAD 為 6af9f3e；個人分支比遠端個人分支多 10 個提交。
- 相對當次 origin/main，本分支另有 809d671（手動行程儲存接口）及 6af9f3e（整合 main）兩個提交。
- 10 個歷史提交含已進 main 的工作與隊友更新，不代表 10 個全新功能。推送分支會推其尚未存在遠端分支的祖先，不能只挑未提交檔案而略過歷史。
- 目前 HEAD 的儲存程式仍使用舊模型欄位；工作目錄中的 v2 修正必須先提交，再把修正後的分支 tip 推出去，不能先推舊 HEAD 作交付版本。

## 建議切三個提交

### 第一批：v2 模型相容性與儲存契約

建議訊息：`fix(itinerary): align saved snapshots with v2 models`

- lib/services/itinerary_snapshot.dart
- lib/services/saved_itinerary_service.dart
- test/services/saved_itinerary_test.dart
- docs/saved-itineraries-schema-proposal.sql

包含 budgetLevel、priceLevel、parsedPreference、v2-only 讀寫驗證與測試，以及一致的 SQL 檢查。SQL 僅納入版本管理，不重新在雲端執行。

### 第二批：個人空間命名與我的行程入口

建議訊息：`feat(profile): name personal space and add itinerary placeholder`

- lib/pages/main_page.dart
- lib/pages/profile_page.dart

包含導航／導覽名稱、個人空間四個區塊及我的行程待接入提示。不宣稱個人頁雲端列表已完成。

### 第三批：隊友交接文件與診斷腳本

建議訊息：`docs(handoff): finalize profile and saved itinerary integration`

- docs/profile-folder-cloud-handoff.md
- docs/saved-itinerary-handoff.md
- docs/check-saved-itinerary-versions.sql
- docs/branch-delivery-plan-2026-09-18.md

兩份 handoff Markdown 是交給同一位隊友的主要說明。check SQL 是選用的唯讀診斷工具，按檔案步驟分開執行；不需要為已確認的新表重複進行舊版調查。

## 不納入這次交付

- .vscode/settings.json：本機環境設定。
- linux/flutter/generated_plugin_registrant.cc、linux/flutter/generated_plugins.cmake、macos/Flutter/GeneratedPluginRegistrant.swift、windows/flutter/generated_plugin_registrant.cc、windows/flutter/generated_plugins.cmake：目前內容差異為空，Git 顯示換行相關狀態；不加入，也不還原使用者檔案。
- docs/travel-app-development-record-2026-09-11.md：本機工作紀錄，非隊友功能交付。
- config/secrets.json 及任何金鑰／token：不得提交。

## 執行與推送順序

1. 每批以明確檔名 git add，不使用 git add .；檢查 git diff --cached --stat、git diff --cached --check 及暫存內容後 commit。
2. 第一批後先執行 `flutter test test/services/saved_itinerary_test.dart`，並對儲存 service／快照／測試做 analyze。三批完成再做相關 UI 回歸與 git diff --check；既有成功紀錄不取代交付版本檢查。
3. 推薦三個 commit 全部完成再執行一次 `git push origin klorius-route-optimizer`，保留清楚的三批歷史，讓隊友一次取得程式與文件。這也會一併推送上述既有 10 個歷史提交。
4. 若確實要分三次 push，每批 commit 後使用相同 push 指令；第一次必須已包含 v2 修正，且同樣會帶上既有歷史。前兩次推送不等於文件交付已完成。
5. 推送前再次 fetch；若遠端分支有新提交，先評估整合，不 force push。推送後確認本機與遠端分支 tip 相同，回報每批 SHA。
6. 本次計畫不包含合併或推送 main。隊友先取得這個分支的完整交付版本；日後合 main 另行確認。

## 雲端狀態與交付界線

使用者已回報 saved_itineraries 建表成功、owner policy 正確、RLS=true。不得再次執行建表 SQL。實際登入儲存、個人頁讀取與雙帳號隔離仍待聯測。隊友負責個人頁資料夾 CRUD 與我的行程列表／詳情，我們負責既有儲存與讀取接口缺陷的修正。
