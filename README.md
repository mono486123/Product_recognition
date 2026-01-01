# 🛒 雜貨店智慧收銀與庫存管理系統 (Cloud-Native & Mobile-Friendly)

本專案是一個全方位的零售解決方案，整合了 AI 影像辨識、Firebase 雲端同步以及 Streamlit 管理員後台，專為實體雜貨店優化結帳效率。

## 🎯 核心目標
1. **雲端數據同步**：利用 Firebase Firestore 實現商品價格與庫存的即時同步。
2. **高效 AI 辨識**：採用 YOLOv11 模型偵測商品，並透過靜態影像預處理技術解決移動設備效能瓶頸。
3. **商業自動化**：整合「收銀-扣庫存-銷售紀錄」閉環流程，並提供電腦端管理面板。

## 📂 專案架構 (Updated)
* **03_AI_Lab**: YOLO 訓練中心。包含手動數據擴充腳本 `main.py` (支援翻轉、光影變幻)。
* **04_App_Dev**: Flutter 行動端。支援「AI 拍照辨識」與「手動分類選擇」雙模式，並具備米酒折抵與找零計算功能。
* **Admin Dashboard**: 使用 Python Streamlit 打造的遠端後台，可一鍵修改雲端價格並監控銷售趨勢。

## 🚀 技術亮點 (Technical Highlights)
* **影像處理**：實作 `predictFixedImage` 邏輯，在送入 AI 前將高解析影像強制 Resize 為 640x640，確保辨識精準度。
* **雲端扣庫存**：結帳時採用 `WriteBatch` 原子操作，同步完成庫存扣除與銷售紀錄存檔，確保帳目一致性。
* **相容性**：適配 Android 14 (API 34) 權限規範，並針對 Realme GT (Snapdragon 888) 優化推論效率。