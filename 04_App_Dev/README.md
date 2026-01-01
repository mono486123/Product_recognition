###gemini的.md是要直接按複製鍵才行啊.....
---

# 📱 04_Engineering_App - 完整開發與雲端整合紀錄

本文件詳細記錄了從行動端 AI 部署到 Firebase 雲端架構轉型的完整技術細節。

---

## 📅 更新日誌與實作紀錄

### - **12/17：承接 AI Lab ONNX 模型，開始 Flutter 專案環境建置**:

```markdown
第一步 (模型檢視)：把 best.onnx 上傳到 Netron，截圖並確認輸出張量的維度。這決定了你如何寫 NMS 代碼。

第二步 (資源整合)：將模型放入 assets/，修改 pubspec.yaml，執行 flutter pub get。

第三步 (Git 提交)：完成 README 後，也進行一次 commit，標註「工程部啟動，目標設備 realme GT」。

```

### - **12/18：執行、部署與 Hotfix**:

**🚀 執行與部署**

1. 確保 realme GT 已連線並開啟 USB 偵錯。
2. 於根目錄執行 `flutter run`。
3. 若遇到編譯錯誤，執行 `flutter clean` 後再重新編譯。

**⚙️ 當前問題與解決 (Hotfix)**

* **問題**: 首次編譯時間過長。
* **解法**: 檢查網路環境，確保 Gradle 依賴下載完成。

### - **12/18：Bug Fix Log (onnxruntime 1.4.1)**:

* **錯誤**: `OrtSession.fromAsset` 與 `addNnapi` 在 v1.4.1 中不存在。
* **修復**:
* 改用 `rootBundle.load` + `OrtSession.fromBuffer`。
* 暫時關閉 NNAPI 原生呼叫，改用預設 CPU 推理以確保穩定啟動。


* **狀態**: 等待第二次編譯測試。

### - **12/18：程式碼提交紀錄**:

* [x] 修正 `detector_service.dart` 以相容 onnxruntime 1.4.1 緩衝區載入。
* [x] 重構 `main.dart` 啟用 `startImageStream` 降低系統負載。
* [x] 實機測試環境於 realme GT (RMX2202) 部署通過。

### - **12/18：Android 14 (API 34) 相容性修正**:

* **Manifest**: 加入了 `android.permission.CAMERA` 顯式宣告。
* **Camera Pipeline**:
* 修正了 `registerReceiver` 崩潰問題 (透過延遲初始化與 Try-Catch)。
* 改用 `ImageFormatGroup.yuv420` 提升 Snapdragon 888 推理效率。


* **Stability**: 加入 `_isDetecting` 旗標防止 JNI 執行緒競爭。

### - **12/18：輸出張量修復 (RangeError)**:

* **問題**: 輸出長度 33600 導致 RangeError。
* **原因**: 誤將 YOLO 的 4 個座標層當作全部輸出，未包含 Class 資訊。
* **修復**:
* 修改 `predict` 邏輯，確保獲取完整的 117,600 個元素 ()。
* 優化 `YOLODecoder` 以正確解索引 (Index) YOLOv11 的矩陣排列。



### - **12/18：最終突破：靜態影像預處理與清單模式 (Photo-to-List Mode)**:

**🛠 重大架構調整**

* **影像策略轉向**: 放棄即時串流模式，轉向 **靜態拍照辨識 (Static Image Detection)**。
* **解決痛點**: 徹底解決 Android 相機感應器 90 度旋轉導致的辨識問題與座標軸映射偏差。
* **暴力預處理 (Force Resizing)**: 引入 `image` 套件，強制 `copyResize` 至 **640x640 (YOLO 標準尺寸)**。解決 `0 objects found` 問題。

**🐞 座標飽和與 UI 優化**

* **原因**: YOLOv11 輸出張量與套件索引錯位。
* **最終方案 (List Mode)**: 由於品項名稱與信心度辨識極為精準 (實測紅標米酒達 62.8%)，UI 轉向 **「結果列表模式」**。移除不穩定畫框，改以清潔的清單展示：**商品名稱**、**信心度百分比**、**偵測總量統計**。

**📈 效能優化 (realme GT)**

* 關閉 GPU Delegate，改用 CPU 多執行緒 (4 Threads)，確保座標計算不因浮點優化過頭而飽和。
* 加入串流節流閥 (Throttling)，拍照辨識後自動釋放資源，防止驍龍 888 過熱降頻。

### - **12/21：Terminal 指令與預覽黑畫面分析**:

```bash
# 指令：清除快取並重新取得套件
flutter clean
flutter pub get
flutter run -d 8a9b40c7

```

* **🛑 黑畫面原因分析**: 程式邏輯使用 `image_picker` 而非相機串流。
* **按鈕沒反應？**: 通常是因為你在 `_takePhotoAndProcess` 裡寫了 `if (!_isDataLoaded) return;`。如果模型或 CSV 載入失敗，`_isDataLoaded` 永遠是 false。

### - **12/25：Git 更新與雲端環境建置**:

```bash
git add assets/products.json pubspec.yaml lib/detector_service.dart lib/main.dart
git status
git commit -m "修正 JSON 讀取與 AI 路徑問題，改用 products.json"

```

### - **12/25：Ubuntu (WSL) 環境操作與模型轉換**:

**進入 ubuntu 從 win 置入檔案並尋找檔案位置:**

```bash
cd ~/product_recognition_linux
source venv/bin/activate

*查看檔案櫃有什麼*
ls

cp "/mnt/d/product_recognition/03_AI_Lab/runs/train/grocery_recognition_v2_Augmented_fake_background/weights/best.onnx" .

```

**ubuntu_onnx 轉 Tflite:**

```bash
(venv) kunzh@USER0408:~/product_recognition_linux$ onnx2tf -i best.onnx -o tflite_output 

(venv) kunzh@USER0408:~/product_recognition_linux$ ls -lh tflite_output/  

**轉到 win_04_App**
cp ~/product_recognition_linux/tflite_output/best_float32.tflite "/mnt/d/product_recognition/04_App_Dev/assets/models/"

*檢查*
ls -lh "/mnt/d/product_recognition/04_App_Dev/assets/models/best_float32.tflite"

```

### - **12/28：Android 重大修改清單 (避免閃退 5 要點)**:

* **build.gradle.kts**: 更新 `namespace` 與 `applicationId` 為 `com.example.product_recognition_app_ai`。
* **資料夾路徑**: 搬移至 `src/main/kotlin/com/example/product_recognition_app_ai/`。
* **MainActivity.kt**: 首行 package 宣告需一致。
* **AndroidManifest.xml**: 確認 Activity 名稱為 `.MainActivity`，修改 `android:label` 以區分圖示文字。
* **main.dart**: 確保 `detector_service.dart` 導入路徑正確。

---

## ☁️ 雲端架構轉型與 Firebase 實作

### - **12/28：從單機邁向雲端架構 (Cloud Migration Note)**:

1. **轉型核心**: 數據持久化、跨裝置對帳、實時庫存 (Real-time SKU)。
2. **技術選型**: **Firebase (Cloud Firestore)** 與 FlutterFire SDK。
3. **實作重點**:
* **數據驅動 UI**: 改用 `Stream` 監聽達成即時更新。
* **原子性交易 (Batch Update)**: 同時更新「銷售紀錄」與「商品庫存」，防止網路閃退導致帳目差異。
* **資料搬遷**: 開發 JSON to Cloud 腳本將 `products.json` 推送至 Firestore。



### - **12/28：Firebase 同步功能開發紀錄本**:

* **⚠️ 常犯錯誤**: `google-services.json` 應放在 `android/app/` 內。SHA-1 指紋未設定會導致權限錯誤。
* **🛠️ Firebase 標準架設流程 (SOP)**:
* **Console 設定**: 新增 App A (AI版) 與 App B (手動版)，開啟 Firestore 規則。
* **Android 原生層**: 修改專案級與 App 級 `build.gradle`，加入 Google 服務插件。
* **Flutter 實作**: 初始化 `Firebase.initializeApp()` 並實作 `_syncProductsFromFirebase` 監聽。



---

## 💻 管理端系統

### - **1/1：電腦端管理後台 (Python Dashboard)**:

1. **開發核心**: Python + Streamlit + Firebase Admin SDK。
2. **關鍵錯誤排除**:
* `pip install firebase-admin` (正確套件名)。
* 啟動指令：`streamlit run admin_dashboard.py`。


3. **功能亮點**:
* **數據同步**: 使用 `serviceAccountKey.json` 認證實現跨平台一致性。
* **營收統計**: `st.metric` 顯示今日營業額，`st.line_chart` 繪製趨勢圖。
* **庫存控制**: 自動篩選 `stock < 10` 商品，支援 `st.data_editor` 批量編輯。



---

## 🚀 專案總結

「本系統成功將 **YOLOv11** 行動端辨識與 **Firebase 雲端後台** 整合。從最初的單機 ONNX 推論，演進至具備實時 SKU 管理、庫存預警與營收分析能力的完整商業系統。」

---

Would you like me to help you format the Python admin dashboard script or the Flutter detection service code to match this documentation?