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





### - **1/5：Firebase 雲端與線下整合原理**:


```

今天我們針對您的 Flutter AI 雜貨店收銀系統 進行了深入的開發與除錯，以下為您整理今日的學習重點、問題核心以及解決方案：

1. 今日核心學習：雲端與 AI 的整合原理
即時資料同步 (Real-time Sync)：我們將原本靜態的 products.json 轉向 Firebase Firestore。利用 snapshots().listen() 建立長連接，達成「雲端改價格，手機即時更新」的機制，解決了傳統 App 需要重啟才能更新資訊的痛點。

原子性操作 (Atomic Operations)：學習到在結帳時必須使用 WriteBatch 或 Transaction。這確保了「更新庫存」與「記錄銷售」這兩個動作會同時成功或同時失敗，防止資料庫出現帳目不一致的情況。

標籤金鑰媒合 (Tag-ID Matching)：理解到 AI 辨識出的 tag（例如 marinated_meat）就是連結雲端資料庫的關鍵 Key，兩者的字串必須完全一致才能正確抓取資料。

2. 重點問題回顧：為什麼「醃製肉」價格顯示為 0？
這是今天最關鍵的技術卡關點，原因在於 資料型別不匹配 (Type Mismatch)：

問題根源：Firestore 儲存數字時可能以 double 格式（如 180.0）傳回，而原始程式碼使用 int.tryParse() 處理字串。當 int.tryParse("180.0") 解析失敗傳回 null 時，程式觸發了預設值 ?? 0。

原理點撥：在 Flutter 中，num 是所有數字的父類別。處理來自外部（API 或資料庫）的金額資料時，最安全的方式是先轉為 num 再轉 int。

3. 實作方法與程式碼精華
我們優化了 _loadProductData 的解析邏輯，使其能應對各種格式的價格輸入：

Dart

// 強健的價格解析邏輯
var rawPrice = data['price'];
int price = 0;

if (rawPrice is num) {
  price = rawPrice.toInt(); // 處理 int 或 double
} else if (rawPrice is String) {
  price = double.tryParse(rawPrice)?.toInt() ?? 0; // 處理 "180.0" 這種字串
}
4. 結帳與庫存控制邏輯
針對您提供的 marinated_meat 商品，我們實作了自動扣庫存的功能：

步驟一：點擊結帳時，透過 batch.update 執行 FieldValue.increment(-item.quantity)。

步驟二：同步寫入一筆 sales 文件，記錄該次交易的時間與品項。

步驟三：結帳完成後自動清空購物車並返回主頁面。



```
-------------



### - **1/5：本地SQL使用規則**:


```

在資料庫管理中，最核心的指令統稱為 CRUD（Create, Read, Update, Delete）。針對您目前開發的商品系統（如 marinated_meat），若未來需要從 Flutter 直接操作 SQL 資料庫或在後台管理數據，以下是常用的標準 SQL 語法分類與解釋：

1. 查詢 (Read) - SELECT
這是最常用的指令，用於從資料庫中提取資料。

查詢所有欄位： SELECT * FROM products;

查詢特定欄位並過濾條件（例如找出價格大於 100 的商品）： SELECT name, price FROM products WHERE price > 100;

模糊搜尋（例如搜尋名稱包含「肉」的商品）： SELECT * FROM products WHERE name LIKE '%肉%';

排序（依價格從高到低）： SELECT * FROM products ORDER BY price DESC;

2. 新增 (Create) - INSERT
用於將新商品（如您的醃製肉）放入資料庫。

基本新增： INSERT INTO products (id, name, price, stock, category) VALUES ('marinated_meat', '醃製肉', 180, 10, 'food');

3. 修改 (Update) - UPDATE
用於更新現有資料（例如調整價格或扣除庫存）。

更新價格： UPDATE products SET price = 200 WHERE id = 'marinated_meat';

扣除庫存（結帳時常用）： UPDATE products SET stock = stock - 1 WHERE id = 'marinated_meat'; 注意：務必加上 WHERE 條件，否則全資料庫的商品都會被修改。

4. 刪除 (Delete) - DELETE
用於移除不再販售的商品。

刪除特定商品： DELETE FROM products WHERE id = 'marinated_meat';

5. 進階彙整功能 (Aggregation)
在進行報表分析（如您的 sales 紀錄）時非常有用：

計算總金額 (SUM)： SELECT SUM(total_amount) FROM sales;

計算商品種類數量 (COUNT)： SELECT COUNT(*) FROM products;

分類統計 (GROUP BY)（統計各類別的商品平均價格）： SELECT category, AVG(price) FROM products GROUP BY category;

6. 為什麼您的系統現在沒用到這些？
從您提供的 main.dart 程式碼來看，您目前使用的是 NoSQL (Cloud Firestore) 而非關聯式資料庫 (SQL)。

NoSQL (Firestore)：使用集合 (Collections) 與文件 (Documents)，操作語法是 collection('products').doc(id).update(...)。

SQL (如 SQLite/MySQL)：使用資料表 (Tables) 與列 (Rows)，操作語法即是上述的 SELECT/UPDATE。

解關建議： 如果您是為了單機儲存或更大型的後台分析才學習 SQL，可以參考 sqflite 套件。但在目前的 Firebase 架構下，您只需要掌握 Firestore 的 get(), set(), update(), delete() 方法即可對應上述 SQL 的邏輯。
```






### - **1/5：雲端已有檔案更改位置git add教學**:
```

💡 總結原理：git add 不只是「增加」
很多人會被 add 這個字誤導，以為只有「增加新東西」才要用。但在 Git 裡，git add 的正確意思是 「登記變更」：

檔案內容變了：用 git add 登記修改。

檔案被刪掉了：用 git add 登記刪除。

檔案是新來的：用 git add 登記新增。

```













# **1/5：資安防護教學**:


針對您目前的資產防護演習進度，撰寫一份高品質的 `README.md` 不僅能紀錄技術細節，更是業界展現專案開發規範（Best Practices）的重要環節。

根據您上傳的檔案結構與目前的修改進度，以下是為您建議的 `README.md` 內容框架：

---

# 🏬 雜貨店商品辨識系統 - 後端管理與資料同步 (Security Practice)

本專案為雜貨店收銀系統的後台管理與雲端同步模組，目前已完成核心資安防護演習，導入環境變數管理機制以保護敏感憑證。

## 🛡️ 資安防護實施說明 (Security Enhancements)

在本階段的開發中，我們實施了以下資安強化措施：

* **憑證與代碼分離 (Decoupling)**：不再將 `serviceAccountKey.json` 路徑硬編碼於 Python 程式碼中。
* **環境變數管理**：導入 `python-dotenv` 套件，透過 `.env` 檔案管理資料庫路徑與 Firebase 金鑰路徑。
* **版控過濾**：配置 `.gitignore` 檔案，嚴格禁止敏感設定檔（`.env`）與金鑰檔案流向遠端儲存庫。
* **預防 SQL 注入**：本地資料庫操作全面採用參數化查詢，確保資料匯入安全性。

## 📂 腳本功能清單

| 檔案名稱 | 功能描述 |
| --- | --- |
| `admin_dashboard.py` | 基於 Streamlit 的管理員後台，提供即時庫存監控與銷售統計。 |
| `push_sql_to_cloud.py` | 將本地 SQLite 資料庫的產品資訊同步推播至 Firebase Firestore。 |
| `Cloud pullback.py` | 從 Firebase 抓取最新的產品與銷售資料，並轉存為本地 JSON 快照。 |
| `json_to_sql.py` | 負責將拉取回來的 JSON 資料清理並匯入本地 `grocery_system.db`。 |

## 🚀 環境設定步驟

1. **安裝依賴套件**：
```bash
pip install firebase-admin streamlit pandas python-dotenv

```


2. **配置環境變數**：
於 `04_App_Dev/Firebase__database_download/` 目錄下建立 `.env` 檔案，範例如下：
```text
FIREBASE_KEY_PATH=serviceAccountKey.json
BASE_SAVE_PATH=D:/你的路徑/Firebase__database_download
DB_PATH=grocery_system.db

```


3. **放入金鑰**：
將從 Firebase Console 下載的 `serviceAccountKey.json` 放入指定目錄。

## 📈 運作流程圖

1. `Cloud pullback.py` → 取得雲端 JSON。
2. `json_to_sql.py` → 轉換 JSON 為 SQL。
3. `admin_dashboard.py` → 管理員視讀與編輯。
4. `push_sql_to_cloud.py` → 將變動推回雲端。

---

### 會建議寫很多嗎？

在業界，`README.md` 的長短取決於「**誰會看這份檔案**」。

* **如果是個人試作**：寫出**環境設定步驟**（如上方的步驟 1~3）最重要，因為三個月後你一定會忘記怎麼啟動環境。
* **如果是求職作品**：寫出**資安防護思路**（Security Enhancements）最有價值，這能向面試官證明你具備處理敏感資料的職業素養。

### 您需要我幫您補充哪一個部分？

------------------------------------------------------------
---------------------------
-----------











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




## 🚀 專案總結

「本系統成功將 **YOLOv11** 行動端辨識與 **Firebase 雲端後台** 整合。從最初的單機 ONNX 推論，演進至具備實時 SKU 管理、庫存預警與營收分析能力的完整商業系統。」

---











### - **1/7：更新並優化手機端(正式發布)**:
```

一、 App 核心功能優化 (Flutter & AI)

啟動流程：原本設有管理密碼（xxxx），現已註解掉改為直接啟動以利個人使用，但保留代碼供日後開啟。

AI 辨識系統：補全了 _takePhotoAndAIProcess 方法。流程為：拍照 $\rightarrow$ 轉位元組 $\rightarrow$ AI 推論 $\rightarrow$ 標籤比對 $\rightarrow$ 自動加入購物車。

購物車邏輯：實現了分類搜尋與手動增減，並包含特殊的米酒空瓶折抵功能（每瓶自動折 2 元）。

二、 Firebase 雲端架構與安全 (關鍵突破)

實時同步：利用 Firestore snapshots() 監聽，達成「雲端改價，手機秒更新」。

安全規則 (Security Rules) 修正：

解決卡關：修正了原本禁止寫入導致「扣庫存失敗」的問題。

精準授權：設定規則為「允許更新庫存，但嚴禁更改價格與品名」，確保前端無法竄改售價。

原子性交易：使用 WriteBatch 確保「帳單產生」與「庫存扣除」必須同時成功，防止帳目不符。

三、 Android 打包與發佈安全

權限修正：在 AndroidManifest.xml 中補上 INTERNET 權限，解決 Firebase 連線失敗的問題。

安全打包：使用 --obfuscate (代碼混淆) 指令，防止程式邏輯被逆向工程破解。

版本區分：釐清了 Debug 模式（開發除錯用）與 Release 模式（正式店內使用）的差異。

四、 視覺自定義 (App Icon)

路徑報錯修復：修正了 Windows 路徑反斜線 \ 造成的 YAML 解析錯誤。

圖示生成：使用 flutter_launcher_icons 成功生成 Android 圖標，並關閉了 iOS 報錯。

適應性圖標：設定了 adaptive_icon 的前景與背景，確保在 realme GT 等現代手機上圖示不失真。

```
