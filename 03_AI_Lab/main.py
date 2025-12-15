import os
import sys
import cv2
from ultralytics import YOLO

# --- 新增：資料翻轉函數 ---
def augment_dataset_by_flipping(data_root):
    """
    掃描訓練集，自動生成水平翻轉的圖片與標籤
    """
    train_img_dir = os.path.join(data_root, "train", "images")
    train_lab_dir = os.path.join(data_root, "train", "labels")
    
    if not os.path.exists(train_img_dir):
        print(f"⚠️ 找不到訓練資料夾，跳過翻轉步驟：{train_img_dir}")
        return

    print("🔄 正在進行資料翻轉擴充...")
    img_list = [f for f in os.listdir(train_img_dir) if f.lower().endswith(('.jpg', '.jpeg', '.png'))]
    
    for img_name in img_list:
        # 避免重複翻轉已經翻轉過的檔案
        if "_flip" in img_name:
            continue
            
        base_name = os.path.splitext(img_name)[0]
        img_path = os.path.join(train_img_dir, img_name)
        lab_path = os.path.join(train_lab_dir, base_name + ".txt")
        
        # 1. 翻轉圖片
        img = cv2.imread(img_path)
        if img is None: continue
        
        output_img_path = os.path.join(train_img_dir, f"{base_name}_flip.jpg")
        if not os.path.exists(output_img_path):
            flipped_img = cv2.flip(img, 1)
            cv2.imwrite(output_img_path, flipped_img)

        # 2. 翻轉標籤
        if os.path.exists(lab_path):
            output_lab_path = os.path.join(train_lab_dir, f"{base_name}_flip.txt")
            if not os.path.exists(output_lab_path):
                with open(lab_path, 'r') as f:
                    lines = f.readlines()
                
                new_labels = []
                for line in lines:
                    parts = line.split()
                    if len(parts) == 5:
                        cls, x, y, w, h = map(float, parts)
                        new_x = 1.0 - x  # 水平翻轉核心邏輯
                        new_labels.append(f"{int(cls)} {new_x:.6f} {y:.6f} {w:.6f} {h:.6f}")
                
                with open(output_lab_path, 'w') as f:
                    f.write("\n".join(new_labels))
                    
    print("✅ 資料翻轉擴充完成！")

def train_grocery_model():
    # --- 1. 專案設定 ---
    PROJECT_NAME = 'grocery_recognition_v1_Augmented'
    DATA_ROOT = "03_AI_Lab/yolo11_data"  # 資料集根目錄
    DATA_YAML_PATH = os.path.join(DATA_ROOT, "data.yaml")
    MODEL_TYPE = "03_AI_Lab/yolo11n.pt"
    EPOCHS = 100
    IMG_SIZE = 640
    BATCH_SIZE = 16

    # --- 2. 執行手動資料擴充 ---
    # 在訓練開始前，先把資料翻倍
    augment_dataset_by_flipping(DATA_ROOT)

    # 檢查 YAML
    if not os.path.exists(DATA_YAML_PATH):
        print(f"❌ 錯誤：找不到 YAML：{DATA_YAML_PATH}")
        sys.exit(1)

    # --- 3. 載入並訓練模型 ---
    print(f"🚀 開始載入模型：{MODEL_TYPE}...")
    model = YOLO(MODEL_TYPE)

    print(f"🏋️ 開始訓練... (Epochs: {EPOCHS})")
    model.train(
        data=DATA_YAML_PATH,
        epochs=EPOCHS,
        imgsz=IMG_SIZE,
        batch=BATCH_SIZE,
        project='03_AI_Lab/runs/train',
        name=PROJECT_NAME,
        patience=20,
        exist_ok=True,
        device=0,
        # 內建增強也開著，加強效果
        degrees=15.0,
        blur=0.1,
        mosaic=1.0
    )

    # --- 4. 驗證與導出 ---
    metrics = model.val()
    print(f"✅ mAP50: {metrics.box.map50:.4f}")
    model.export(format='onnx', opset=13)

if __name__ == '__main__':
    train_grocery_model()