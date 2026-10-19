# 💰 打工薪水帳｜工讀生排班紀錄與精準薪資計算

單一 `index.html` 打造的 Mobile-First Web App（HTML5 + Tailwind CSS + JavaScript + FontAwesome），資料全部存在瀏覽器 `localStorage`。

## 功能
- 本月薪資儀表板（正常工時 / 分鐘級加班費 / 全勤獎金狀態）
- 🖋 色塊印章模式：選班別 → 點日期一鍵蓋章
- 當日微調面板：表定時間、無薪休息、+1/+5/+10/+15/+30 分加班、出勤狀態
- 加班倍率（×1.0 / 1.34 / 1.67 / 2.0 / 自訂）、單日或整月四捨五入
- 月底對帳單（可截圖、可複製文字）
- 📸 AI 智慧辨識匯入班表（Gemini `gemini-2.5-flash`）＋ 免 Key 的 JSON 貼上模式，匯入前可逐列核對修改
- 備份匯出 / 匯入

## 部署到 GitHub + Vercel
1. 在 GitHub 建立新 repository（例如 `shift-pay-app`）
2. 把本資料夾的 `index.html`、`vercel.json`、`README.md` 推上去：
   ```bash
   git init
   git add .
   git commit -m "init: shift pay app"
   git branch -M main
   git remote add origin https://github.com/<你的帳號>/shift-pay-app.git
   git push -u origin main
   ```
   （沒有安裝 Git 也可以在 GitHub 網頁上按 **Add file → Upload files** 直接拖曳上傳）
3. 到 <https://vercel.com/new> → Import 這個 repo → Framework Preset 選 **Other** → 直接 **Deploy**（不需要 build 指令）
4. 之後每次 push 到 `main`，Vercel 會自動重新部署

## 注意
- Gemini API Key 只存在你自己裝置的瀏覽器中，由前端直接呼叫 Google API，不會經過任何伺服器。請勿在公用電腦儲存 Key。
- 換手機 / 換瀏覽器資料不會同步，請用「設定 → 匯出備份」轉移。
