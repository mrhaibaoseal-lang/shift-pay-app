# 💰 打工薪水帳 V3｜iOS 27 原生 App (Feather 滿血版) & Web V2

本儲存庫同時提供 **iOS 27 原生 Swift App（專為 FlareStore 付費憑證 + Feather 簽名優化）** 與 **Web V2 單頁應用（`index.html`）**，兩者支援 **100% 雙向無痛備份匯入/匯出（`shiftpay.v1` JSON 相容）**。

## 📱 iOS 27 原生版（V3）核心亮點
- **🧠 iOS 27 `FoundationModels` + `Vision` + `DynamicProfile` 班表視讀引擎**：支援 Apple 裝置端離線辨識、Vision 表格座標對齊（`VisionOCRTool`）、以及透過統一 `ShiftLanguageModel` 協定動態切換 `gemini-3.8-flash` 與 `Claude` 多圖跨頁合併。
- **⏰ 原生 `EventKit` 行事曆自動同步 + 高優先級起床鬧鐘**：一鍵直接寫入 iPhone 原生「💰 打工班表」日曆（內建前一晚 + 起床雙 `EKAlarm`），免手動匯出 `.ics`。
- **🧩 原生 `WidgetKit` 互動小工具 + `ActivityKit` 動態島跳錶**：透過同 Team ID 共用 Keychain 通道，Feather 簽名後零設定秒同步；支援在桌面小工具直接按 **`⚡+15m / ⚡+30m`** 記加班！
- **🚀 Feather 軟體源網址**：`https://raw.githubusercontent.com/mrhaibaoseal-lang/shift-pay-app/main/feather-repo.json`

---


# 💰 打工薪水帳 V2｜工讀生排班紀錄與精準薪資計算

單一 `index.html` 打造的 Mobile-First Web App（HTML5 + Tailwind CSS + JavaScript + FontAwesome），資料全部存在瀏覽器 `localStorage`（向下相容 V1 `shiftpay.v1`）。

## V2 核心功能
- **底部 iOS 毛玻璃導覽列（4 大分頁）**：
  - 📅 **【排班】**：精簡版「本月預估總薪資 + 全勤燈號」、常用班別印章列、互動月曆、點擊日期微調與分鐘級加班面板
  - 💰 **【帳單】**：三大薪資拆解卡片、每日工時與加班費明細表、截圖專用對帳單與文字複製
  - ⏰ **【提醒與小工具】**：上班前一天提醒 + 當日起床鬧鐘自動推算、Web Notification 推播、**一鍵匯出 `.ics` 手機原生行事曆雙鬧鐘（`VALARM`）**、**iOS Scriptable 桌面小工具連動中心**
  - ⚙️ **【設定】**：基本時薪、加班倍率、小數點進位機制、全勤金額、AI 模型名稱自訂（預設 `gemini-3.8-flash`）、資料備份匯出/匯入
- **無薪休息時間升級**：內建 `不扣除`、`0.5h`、`1h`、`1.5h`、`2h`，並提供 `+ 自訂時間` 自動新增為常駐快捷按鈕
- **📸 多張手寫班表批次上傳與跨頁合併**：
  - 支援一次選取或分次拍攝多張照片（第 1 頁、第 2 頁…縮圖預覽與單張移除）
  - 一次傳送多張圖片給 Gemini API（`gemini-3.8-flash`），自動跨頁合併、去重、依日期排序
  - 匯入前核對清單提供 **➕ 合併追加模式（預設，保留其他日期與已記加班）** 與 **🔄 整月覆蓋模式**
- **防誤觸縮放 ＆ 類原生 PWA 體驗**：
  - 鎖定 Viewport 縮放與開啟 iOS Web App 全螢幕模式
  - 全域 `touch-action: manipulation`、表單字體 `>= 16px`、攔截雙指手勢與雙擊放大

## 部署到 GitHub + Vercel
1. 在 GitHub 建立新 repository（或更新現有 repo）
2. 上傳 `index.html`、`vercel.json`、`README.md`
3. 到 <https://vercel.com/new> → Import 這個 repo → Framework Preset 選 **Other** → 直接 **Deploy**
