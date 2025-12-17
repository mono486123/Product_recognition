# Grocery AI Top10 — YOLO 專案說明

## 專案目標 (Project Goal)

訓練一個可辨識 **10 種商品** 的 YOLO 模型，並轉換為 **手機可用的 `.tflite`** 格式，供 Android / iOS App 使用。

---

## 專案流程總覽 (Project Pipeline)

1. 環境建置與 Git 版控（Foundation）
2. 數據採集與標註（Data Ops）
3. 模型訓練與輸出（Training & Export）
4. Troubleshooting 與最佳化

---

## 第一階段：環境建置與 Git 版控 (Foundation)

### 為什麼要用 Git？

Git 是版本時光機，每一次 `commit` 都是一個**不可覆蓋的快照**，可隨時回復。

### 初始化專案

```bash
git init
```

### .gitignore（必放在**根目錄**）

> ❗ 資料集與模型權重**不可上 Git**

```gitignore
# Dataset
datasets/
images/
labels/

# Training outputs
runs/
*.pt
*.tflite
*.onnx

# Python
__pycache__/
*.py[cod]
.env
venv/

# IDE
.vscode/
.idea/
```

### 第一次提交

```bash
git add .
git commit -m "Initial commit: 設定專案結構與 gitignore"
```

### 驗證 Git 歷史

```bash
git log
```
###  Git 單獨檔案

```
雜貨店商品辨識系統_使用手機
自訂 Gem
在 Git 中，如果你只想針對單個檔案進行版本控制（不影響其他已經修改的檔案），核心步驟是精準使用 git add 指令。

目前你的專案中有很多 modified（已修改）和 untracked（未追蹤）的檔案，請按照以下步驟「單獨處理」你的檔案：

一、 實作步驟：以 train_grocery_model.py 為例
假設你剛剛修改了訓練腳本，只想提交這一個檔案：

步驟 1：確認檔案路徑
先看清楚 Git 顯示的路徑名稱。

Bash
git status
步驟 2：將單一檔案加入暫存區 (Add)
不要使用 git add .（這會全加），請直接輸入檔案路徑：

Bash
git add 03_AI_Lab/train_grocery_model.py
步驟 3：確認是否只有該檔案被選中
再次輸入 git status，你會發現只有這個檔案變成綠色（Changes to be committed），其他檔案維持紅色。

步驟 4：提交該檔案 (Commit)
Bash
git commit -m "Update training script with manual flipping logic"
步驟 5：推送到遠端 (Push)
Bash
git push
```


---

## Git 重要觀念補充

### Commit 不會刪舊檔

* 傳統存檔：新檔覆蓋舊檔
* Git Commit：建立新快照，**舊版本永久存在**

### Dry-run（演習）

```bash
git add 03_AI_Lab -n
```

只顯示「會被加入的檔案」，不會真的加入。

### ⚠️ 禁止巢狀 Git 倉庫

警告：`adding embedded git repository`

代表資料夾內 **又有一個 `.git/`**。

**處理方式（推薦）**：刪除內層 `.git`

```bash
cd 03_AI_Lab
rmdir /s /q .git   # Windows
# rm -rf .git      # Mac/Linux
```

---

## 第二階段：數據採集與標註 (Data Ops)

### 拍攝原則

* 多角度：正面、側面、手持
* 多環境：貨架、桌面、強光、陰影
* 數量：每商品 **50–100 張**（最低 20）
* **負樣本**：空桌面、只有手、不畫框

### Roboflow 標註流程

1. 上傳圖片
2. 畫 Bounding Box（貼邊）
3. Data Augmentation

   * Rotation
   * Brightness
   * Noise
4. Export → **YOLOv8 format**

> ⚠️ 檔名、資料夾、class 名稱 **不可使用中文**

---

## 第三階段：模型訓練 (YOLOv8 / YOLO11)

### 建議環境

* 無 NVIDIA GPU → **Google Colab**
* 手機端模型 → **Nano 版 (yolov8n / yolo11n)**

### 專案結構

```
Grocery_Project/
├── main.py
├── yolov11n.pt
├── .gitignore
└── datasets/
    ├── grocery_data.yaml
    ├── images/
    │   ├── train/
    │   └── val/
    └── labels/
        ├── train/
        └── val/
```

### data.yaml 範例

```yaml
path: ../datasets
train: images/train
val: images/val

nc: 3
names: ['coke', 'chips', 'noodles']
```

---

## 訓練主程式（main.py 重點）

* Transfer Learning（使用預訓練模型）
* imgsz=640（準確度與速度平衡）
* mAP50 > 0.8 為實用門檻
* 匯出 `.tflite`（可加 int8 量化）

---

## 第四階段：常見卡關 (Troubleshooting)

### 1️⃣ 什麼都認不到

**原因**：data.yaml 路徑錯 / labels 對不上

**解法**：確認 images 與 labels 結構一致

---

### 2️⃣ 手被認成商品

**原因**：背景太單純

**解法**：加入負樣本（不畫框）

---

### 3️⃣ 手機跑很慢

**解法**：

* 使用 Nano 模型
* imgsz=320 / 416
* 匯出 TFLite + int8

```python
model.export(format='tflite', int8=True, data='path/to/data.yaml')
```

---

## 環境需求 (Requirements)

```bash
pip install ultralytics
pip install tensorflow
pip install onnx
```

---

## 開發紀錄 (Log)

* **12/14**：開始使用 Roboflow 標註 Top10，確認 data 無中文
* **12/15**：Top10 標註完成，加入翻轉與噪音增強
* **12/15**：.gitignore要放在根目錄,top_10 tag完成並翻轉與噪音增強。
* **12/15**：增加 pip install onnx2tf onnx onnxruntime，把結果存在03_AI_Lab而不是根目錄，yolov11.pt下載到03_AI_Lab\
* **12/15**：無法導出.TFLite所以修改model.export那一行也順便更改只有拉到四張(轉換時，程式找不到你的資料集，所以它跑去用官方預設的 coco8 資料集（只有 4 張圖）來做校準。這會導致模型雖然轉出來了，但精準度會很差。)pip內容>>(pip install tensorflow tf_keras onnx onnx2tf onnx-graphsurgeon sng4onnx onnxslim)。
* **12/15**：目前ai-edge-litert無法在win使用(只有接受mac與linx)，所以採取另一種方法(當你設定 int8=False (預設值，或是直接忽略) 時，它會使用最傳統、最穩定的 Float32 轉換 模式。這個模式只需要基本的 tensorflow 就能完成。雖然 Float32 的模型檔會稍微大一點、運行速度會慢一點，但這是確保轉換成功的最快和最可靠的方法。)<<未成功
* **12/15**：當我們為了繞過套件依賴問題，而採用 PyTorch ⮕ ONNX ⮕ TFLite 這種手動的「兩步驟轉換」方法，並且捨棄了 INT8 量化（改用 Float32）。onnx2tf依然依賴ai-edge-litert。
* **12/15**：venv環境可能有壞損，所以直接開啟新環境gpu版本記得下載(pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118)，版本兼容問題最大。ubuntu的git要重用。
* **12/15**：今天大致上遇到的問題為TFLite無法在win使用所以改為wsl內，要注意版本一致要不會爆，然後暫時用清華鏡像(要不下載太慢)，研發部的檔案會慢慢轉入wsl，包括如何一致之前版本的git(這要問問)。下載太慢會先嘗試測試export_tflite.py包括下載必要套件，可行包裝再train，提醒自己把wsl設定系統整理到效率最好(在適用於L...設定)，要想怎麼提高pip下載速度(很重要)。
* **12/15**:目前做完能在win進行yolo train，但還沒看效率，目前忙轉移至wsl。
* **12/16**:今天已經大致了解在train之後會自動生成.onnx，所以目前會先在train一次，.kt會延後。已測試(目前的辨識程度較為低，需要更多資料與變化及TRAIN方法)


* **12/17**:未改版v1_train_img為117張，增強data(翻轉與遮擋建議直接用yolo調整即可，不需要增加data量)。

```
1. 多樣化的拍攝環境（最有效）
改變背景：在櫃檯拍、在層架拍、拿在手裡拍。

改變光線：開燈拍、關燈拍、日光下拍。

2. 多樣化的商品姿勢（解決你的卡關點）
旋轉商品：不要只拍正面，拍 45 度、側面、甚至背面。

堆疊與遮擋：故意放幾瓶飲料疊在一起，讓模型學習「看到一半標籤也能認出」的能力。

3. 負樣本 (Background Images)
拍一些「沒有商品」但「長得很像雜貨店背景」的照片放進資料集，這能大幅減少模型「亂認東西」的機率。
```
* **12/17**:增加fake_background圖片10張，有稍稍提升一點不過可能暫未達90分標準(預判85分)，先由這版進行整個專案執行，如果需增加及優化，遵從另一版。

---

## 下一步行動 (Action Item)

* 完成 Top10 商品拍攝與標註
* 確認 `data.yaml` 可正常被 YOLO 讀取
* 開始第一次正式訓練
