# 02_Engineering_App - 雜貨店商品辨識行動端整合

## 📌 當前狀態
- **模型來源**: `03_AI_Lab/runs/train/.../best.onnx` (12/17 TOP_10 初版)
- **核心技術**: Flutter + ONNX Runtime
- **目標平台**: Android (API 24+), iOS (12.0+)

## 🛠 整合步驟
1. **模型部署**: 將 `best.onnx` 複製至 `assets/models/` 並於 `pubspec.yaml` 宣告。
2. **影像管道**: 
   - 使用 `camera` plugin 獲取 `CameraImage`。
   - 轉換為 `Float32List` 並進行色彩空間轉換 (YUV/RGBA to RGB)。
3. **推理優化**: 開啟 NNAPI (Android) 或 CoreML (iOS) 執行硬體加速。


## 結構

```
04_Engineering_App/
├── lib/
│   ├── main.dart             # 入口
│   ├── detector_service.dart # 處理模型推論邏輯
│   └── camera_view.dart      # 處理相機預覽與框框繪製
├── assets/
│   └── models/
│       └── best.onnx         # 從 AI_Lab 複製過來的模型
└── README.md                 # 您的開發日誌 (下方提供內容)
```



## 實作紀錄

## 📱 測試設備
- **型號**: realme GT (RMX2202)
- **處理器**: Snapdragon 888
- **OS**: Android 11/12/13 (支援 NNAPI)

## 🛠 模型規格 (由 AI_Lab 提供)
- **格式**: ONNX
- **輸入**: `[1, 3, 640, 640]` (Float32)
- **輸出**: `[1, 25200, 15]` (假設為 YOLOv5/v8 格式，10個類別 + 5個座標參數)

## 🚀 實作要點
1. **影像轉換**: Realme GT 的相機輸出的 `CameraImage` 為 **YUV_420_888** 格式。需使用 `image` 套件轉換為 RGB 才能送入模型。
2. **加速方案**: 預計啟用 `NNAPI` 以發揮 SD888 的 AI 效能。
3. **記憶體管理**: 在推理後必須手動 `release()` OrtValue，避免 GPU 內存溢出。

## 📅 更新日誌
- 12/17: 承接 AI Lab ONNX 模型，開始 Flutter 專案環境建置。
```
第一步 (模型檢視)：把 best.onnx 上傳到 Netron，截圖並確認輸出張量的維度。這決定了你如何寫 NMS 代碼。

第二步 (資源整合)：將模型放入 assets/，修改 pubspec.yaml，執行 flutter pub get。

第三步 (Git 提交)：完成 README 後，也進行一次 commit，標註「工程部啟動，目標設備 realme GT」。
```
- 12/18:
```
🚀 執行與部署
1. 確保 realme GT 已連線並開啟 USB 偵錯。
2. 於根目錄執行 `flutter run`。
3. 若遇到編譯錯誤，執行 `flutter clean` 後再重新編譯。

⚙️ 當前問題與解決 (Hotfix)
- **問題**: 首次編譯時間過長。
- **解法**: 檢查網路環境，確保 Gradle 依賴下載完成。
```

```
🐞 Bug Fix Log 
- **錯誤**: `OrtSession.fromAsset` 與 `addNnapi` 在 v1.4.1 中不存在。
- **修復**: 
  - 改用 `rootBundle.load` + `OrtSession.fromBuffer`。
  - 暫時關閉 NNAPI 原生呼叫，改用預設 CPU 推理以確保穩定啟動。
- **狀態**: 等待第二次編譯測試。
```

```
📦 12/18 程式碼提交紀錄
- [x] 修正 `detector_service.dart` 以相容 onnxruntime 1.4.1 緩衝區載入。
- [x] 重構 `main.dart` 啟用 `startImageStream` 降低系統負載。
- [x] 實機測試環境於 realme GT (RMX2202) 部署通過。
```
```
## 🛠 Android 14 (API 34) 相容性修正
- **Manifest**: 加入了 `android.permission.CAMERA` 顯式宣告。
- **Camera Pipeline**: 
  - 修正了 `registerReceiver` 崩潰問題 (透過延遲初始化與 Try-Catch)。
  - 改用 `ImageFormatGroup.yuv420` 提升 Snapdragon 888 推理效率。
- **Stability**: 加入 `_isDetecting` 旗標防止 JNI 執行緒競爭。

## 🛠 Android 14 (API 34) 相容性修正
- **Manifest**: 加入了 `android.permission.CAMERA` 顯式宣告。
- **Camera Pipeline**: 
  - 修正了 `registerReceiver` 崩潰問題 (透過延遲初始化與 Try-Catch)。
  - 改用 `ImageFormatGroup.yuv420` 提升 Snapdragon 888 推理效率。
- **Stability**: 加入 `_isDetecting` 旗標防止 JNI 執行緒競爭。


## 🐞 12/18 輸出張量修復
- **問題**: 輸出長度 33600 導致 RangeError。
- **原因**: 誤將 YOLO 的 4 個座標層當作全部輸出，未包含 Class 資訊。
- **修復**: 
  - 修改 `predict` 邏輯，確保獲取完整的 117,600 個元素 ($14 \times 8400$)。
  - 優化 `YOLODecoder` 以正確解索引 (Index) YOLOv11 的矩陣排列。


## 🚀 12/18 最終突破：靜態影像預處理與清單模式 (Photo-to-List Mode)

### 🛠 重大架構調整
- **影像策略轉向**: 
  - 放棄即時串流 (Real-time Stream) 模式，轉向 **靜態拍照辨識 (Static Image Detection)**。
  - **解決痛點**: 徹底解決 Android 相機感應器 90 度旋轉導致的「需傾斜 75 度才能辨識」以及座標軸映射偏差問題。
- **暴力預處理 (Force Resizing)**:
  - 引入 `image` 套件，在影像送入 AI 前，強制進行 `copyResize` 至 **640x640 (YOLO 標準尺寸)**。
  - **修復**: 解決了 `Detection completed: 0 objects found` 的問題，確保 Float32 模型能獲得穩定比例的像素數據。

### 🐞 座標飽和與 UI 優化
- **問題**: 座標輸出一律顯示 `[640, 640, 640, 640]`。
- **原因**: 判定為 YOLOv11 輸出張量 (Tensor) 與 `flutter_vision` 套件解析索引錯位。
- **最終方案 (List Mode)**: 
  - 由於品項名稱與信心度辨識極為精準 (實測紅標米酒達 62.8%)，UI 轉向 **「結果列表模式」**。
  - 移除不穩定畫框，改以清潔的清單展示：**商品名稱**、**信心度百分比**、**偵測總量統計**。
  
### 📈 效能優化 (realme GT)
- 關閉 GPU Delegate，改用 CPU 多執行緒 (4 Threads)，確保座標計算不因浮點優化過頭而飽和。
- 加入串流節流閥 (Throttling)，拍照辨識後自動釋放資源，防止驍龍 888 過熱降頻。


```
- **ubuntu_onnx轉Tflite**: (venv) kunzh@USER0408:~/product_recognition_linux$ onnx2tf -i best.onnx -o tflite_output





## 輸入規範

### 📱 測試設備
- **型號**: realme GT (RMX2202)
- **處理器**: Snapdragon 888
- **OS**: Android 11/12/13 (支援 NNAPI)

### 🛠 模型規格 (由 AI_Lab 提供)
- **格式**: ONNX
- **輸入**: `[1, 3, 640, 640]` (Float32)
- **輸出**: `[1, 25200, 15]` (假設為 YOLOv5/v8 格式，10個類別 + 5個座標參數)

### 🚀 實作要點
1. **影像轉換**: Realme GT 的相機輸出的 `CameraImage` 為 **YUV_420_888** 格式。需使用 `image` 套件轉換為 RGB 才能送入模型。
2. **加速方案**: 預計啟用 `NNAPI` 以發揮 SD888 的 AI 效能。
3. **記憶體管理**: 在推理後必須手動 `release()` OrtValue，避免 GPU 內存溢出。

### 📅 更新日誌
- 12/17: 承接 AI Lab ONNX 模型，開始 Flutter 專案環境建置。



## ⚠️ 已知挑戰 (Roadblock)
- **NMS 效能**: 目前在 Dart 層級執行 NMS 運算較慢，考慮未來移至 C++ 或尋找優化後的 Dart Plugin。
- **輸入尺寸**: 研發部模型固定為 640x640，需處理不同手機螢幕比例的 Padding 填充問題。

## Flutter App 開發最容易卡關的地方：相機串流是 YUV 格式，但模型要的是 RGB。

解決方法： 不要在 Dart 層逐個像素轉換（會非常慢），推薦使用 package:image 或者利用底層 C++ 處理。初步開發可先用簡單的轉換，確保功能通暢：