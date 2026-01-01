import os
import cv2
import numpy as np
import shutil
import yaml
from ultralytics import YOLO
from pathlib import Path

# ==========================================
# 第一部分：增強版資料擴充 (含翻轉、光影)
# ==========================================

def augment_dataset(data_root):
    train_img_dir = os.path.join(data_root, "train", "images")
    train_lab_dir = os.path.join(data_root, "train", "labels")
    
    if not os.path.exists(train_img_dir):
        print(f"⚠️ 找不到目錄：{train_img_dir}")
        return

    print("🔄 啟動資料擴充：處理水平翻轉與光影變幻...")
    
    # 僅處理原始檔案，不處理已經帶有後綴的擴充檔
    img_list = [f for f in os.listdir(train_img_dir) if f.lower().endswith(('.jpg', '.jpeg', '.png')) 
                and not any(x in f for x in ['_flip', '_bright', '_dark'])]
    
    for img_name in img_list:
        base_name = os.path.splitext(img_name)[0]
        img_path = os.path.join(train_img_dir, img_name)
        lab_path = os.path.join(train_lab_dir, base_name + ".txt")
        
        img = cv2.imread(img_path)
        if img is None: continue

        # 準備要產生的變體清單：(後綴, 影像處理函式)
        variants = [
            ("_flip", lambda x: cv2.flip(x, 1)),
            ("_bright", lambda x: cv2.convertScaleAbs(x, alpha=1.2, beta=30)),
            ("_dark", lambda x: cv2.convertScaleAbs(x, alpha=0.8, beta=-30))
        ]

        for suffix, func in variants:
            aug_name = f"{base_name}{suffix}.jpg"
            aug_img_path = os.path.join(train_img_dir, aug_name)
            aug_lab_path = os.path.join(train_lab_dir, f"{base_name}{suffix}.txt")

            if not os.path.exists(aug_img_path):
                # 處理並儲存圖片
                new_img = func(img)
                cv2.imwrite(aug_img_path, new_img)
                
                # 處理標籤
                if os.path.exists(lab_path):
                    with open(lab_path, 'r') as f:
                        lines = f.readlines()
                    
                    new_labels = []
                    for line in lines:
                        parts = line.split()
                        if len(parts) == 5:
                            cls, x, y, w, h = map(float, parts)
                            # 如果是翻轉，需要重新計算 x 座標
                            if suffix == "_flip":
                                x = 1.0 - x
                            new_labels.append(f"{int(cls)} {x:.6f} {y:.6f} {w:.6f} {h:.6f}")
                    
                    with open(aug_lab_path, 'w') as f:
                        f.write("\n".join(new_labels))

    print(f"✅ 資料擴充已完成！目前訓練集規模：{len(os.listdir(train_img_dir))} 張圖片")

# ==========================================
# 第二部分：訓練流程與一致性檢查
# ==========================================

def train_grocery_model():
    DATA_ROOT = r"D:\product_recognition\03_AI_Lab\yolo11_data\drink"
    DATA_YAML = os.path.join(DATA_ROOT, "data.yaml")
    MODEL_WEIGHTS = "yolo11m.pt" 

    # 0. 檢查 YAML 內容 (確保 Index 23 的 Small_Water 有補進去)
    with open(DATA_YAML, 'r') as f:
        config = yaml.safe_load(f)
    if len(config['names']) != config['nc']:
        print(f"❌ 警告：nc={config['nc']} 但 names 只有 {len(config['names'])} 個！請修正 data.yaml")
        return

    # 1. 執行手動擴充
    augment_dataset(DATA_ROOT)

    # 2. 初始化 YOLO 模型
    print(f"🚀 載入模型：{MODEL_WEIGHTS}...")
    model = YOLO(MODEL_WEIGHTS)

    # 3. 開始訓練 (針對小樣本與混淆類別優化)
    print("🏋️ 開始針對性強化訓練...")
    results = model.train(
        data=DATA_YAML,
        epochs=300,
        imgsz=640,
        batch=8,
        patience=50,
        workers=4,
        
        # --- 權重與平滑 (防誤判) ---
        cls=2.0,           # 提高類別權重，讓模型更在意「認錯人」
        label_smoothing=0.1, 

        # --- 數據增強 (小樣本特效藥) ---
        degrees=20.0,      # 旋轉
        shear=10.0,        # 透視變形 (解決國農上拍問題)
        perspective=0.001,
        mosaic=1.0,        # 必開
        mixup=0.2,         # 解決麥香/咖啡廣場顏色相似
        copy_paste=0.4,    # 最強招：隨機將商品貼到不同背景
        
        optimizer='SGD',   # 樣本少時 SGD 較穩定
        device=0,
        project='03_AI_Lab/runs/train',
        name='grocery_v4_stable_final',
    )

    # 4. 驗證與匯出
    model.val()
    print("📦 導出手機端專用 ONNX (FP16)...")
    model.export(format='onnx', opset=13, half=True, simplify=True)

if __name__ == '__main__':
    train_grocery_model()