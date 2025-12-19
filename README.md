# 🛒 雜貨店商品辨識與數據處理系統 (Mobile-Friendly)

這是一個多方協作專案，整合了銷售數據分析 (CSV/Excel)、AI 深度學習模型訓練 (YOLO/ONNX)，以及專為 Android 設備優化的商品辨識 App。

## 🎯 核心目標
1. **數據協作**：建立版本控制系統，處理銷售額與預算數據。
2. **AI 辨識**：開發能精準辨識雜貨商品的 YOLO 模型，並轉換為 ONNX/TFLite 格式。
3. **App 實作**：開發具備「靜態拍照偵測」模式的 App，解決行動裝置效能瓶頸。

## 🚀 專案亮點 (Key Features)
* **硬體優化**：針對 Realme GT 等高畫質連拍機型實作「影像串流模式」，解決 OOM (記憶體溢出) 崩潰問題。
* **相容性強化**：全面適應 Android 14 (API 34) 權限規範。
* **跨平台部署**：支援 ONNX 與 TFLite 雙引擎推論。

## 📂 專案結構 (Project Structure)
本專案採用標準化分層管理，確保路徑在不同開發者環境下皆能運行。

```text
.
├── 01_PM_Office/          # 專案管理與需求文件
├── 02_Design_Studio/      # UI/UX 設計資源
├── 03_AI_Lab/             # AI 模型訓練中心
│   ├── main.py            # YOLO 訓練腳本
│   ├── export_tflite.py   # 模型轉換工具
│   └── 研發部門筆記.txt    # 訓練心得與參數紀錄
├── 04_App_Dev/            # Flutter 行動應用程式
│   ├── assets/models/     # 存放 best.onnx, best.tflite
│   ├── lib/               # Flutter 原始碼 (包含 yolo_decoder)
│   └── 軟體部筆記.txt      # 設備相容性與修復紀錄
├── Data/                  # 原始數據集 (不進 Git)
└── README.md
🛠️ 環境設定 (Setup)
1. Python 環境 (AI 訓練)
Bash

python -m venv venv
# Windows:
.\venv\Scripts\activate
pip install -r 03_AI_Lab/requirements.txt
2. Flutter 環境 (App 開發)
確保已安裝 Flutter SDK (3.x 以上版本)。

進入目錄並獲取套件：

Bash

cd 04_App_Dev
flutter pub get
🤝 協作規範 (Collaborative Guidelines)
路徑處理：嚴禁使用絕對路徑（如 D:\...），請統一使用 Python pathlib 處理相對路徑。

Git 紀錄：在 Push 前請進行 rebase 整理，確保 Commit 訊息清晰（如 Feat:, Fix:, Refactor:）。

大型檔案：模型權重 (.pt) 與大型數據集請確保已加入 .gitignore 或使用 Git LFS 管理。

聯絡資訊：<Your Name / Team Email>


---

## 接下來的 Push 指令步驟

要把這份新的 README 更新上去，請執行以下步驟：

### 1. 修改檔案
將上面的內容覆蓋掉你原本的 `D:\product_recognition\README.md`。

### 2. Commit 並再次 Push
```bash
# 加入修改後的 README
git add README.md

# 提交變動 (這會是你的第 7 個 Commit)
git commit -m "docs: 更新專案結構與技術特點說明 (README)"

# 一口氣把所有 7 個 Commit 送上雲端
git push origin main