import os
import cv2
from ultralytics import YOLO

def augment_dataset_by_flipping(data_root):
    """
    掃描訓練集，自動生成水平翻轉的圖片與標籤 (YOLO 格式)
    """
    train_img_dir = os.path.join(data_root, "train", "images")
    train_lab_dir = os.path.join(data_root, "train", "labels")
    
    if not os.path.exists(train_img_dir):
        print(f"⚠️ 找不到訓練資料夾，跳過翻轉步驟：{train_img_dir}")
        return

    print("🔄 正在啟動資料翻轉擴充 (Offline Augmentation)...")
    img_list = [f for f in os.listdir(train_img_dir) if f.lower().endswith(('.jpg', '.jpeg', '.png'))]
    
    count = 0
    for img_name in img_list:
        # 避免重複翻轉已經翻轉過的檔案
        if "_flip" in img_name:
            continue
            
        base_name = os.path.splitext(img_name)[0]
        img_path = os.path.join(train_img_dir, img_name)
        lab_path = os.path.join(train_lab_dir, base_name + ".txt")
        
        # 1. 翻轉圖片並儲存
        output_img_path = os.path.join(train_img_dir, f"{base_name}_flip.jpg")
        if not os.path.exists(output_img_path):
            img = cv2.imread(img_path)
            if img is None: continue
            flipped_img = cv2.flip(img, 1) # 1 代表水平翻轉
            cv2.imwrite(output_img_path, flipped_img)

        # 2. 翻轉標籤並儲存
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
                        # 水平翻轉核心邏輯：新的 x 座標 = 1.0 - 原本的 x 座標
                        new_x = 1.0 - x
                        new_labels.append(f"{int(cls)} {new_x:.6f} {y:.6f} {w:.6f} {h:.6f}")
                
                with open(output_lab_path, 'w') as f:
                    f.write("\n".join(new_labels))
                count += 1
                    
    print(f"✅ 資料翻轉擴充完成！共新增了 {count} 組圖片與標籤。")

def finetune_grocery_model():
    # --- 1. 路徑設定 ---
    # 資料集根目錄 (包含 train/val 資料夾的地方)
    DATA_ROOT = r"D:\product_recognition\03_AI_Lab\yolo11_data"
    DATA_YAML_PATH = os.path.join(DATA_ROOT, "data.yaml")
    
    # 之前表現最好的權重
    PREVIOUS_BEST_MODEL = r"D:\product_recognition\03_AI_Lab\runs\train\grocery_recognition_v2_Augmented_fake_background\weights\best.pt"
    
    # 新訓練任務名稱
    PROJECT_NAME = 'grocery_recognition_v2_Finetuned_with_Flip'
    
    # --- 2. 執行線下擴充 ---
    # 這步會改動硬碟空間，只需執行一次（腳本內已包含過濾邏輯）
    augment_dataset_by_flipping(DATA_ROOT)

    # --- 3. 載入模型與微調訓練 ---
    if not os.path.exists(PREVIOUS_BEST_MODEL):
        print(f"❌ 錯誤：找不到基礎權重檔案 {PREVIOUS_BEST_MODEL}")
        return

    print(f"🔄 載入 {PREVIOUS_BEST_MODEL} 進行微調...")
    model = YOLO(PREVIOUS_BEST_MODEL)

    model.train(
        data=DATA_YAML_PATH,
        epochs=250,
        imgsz=640,
        batch=16,
        project='03_AI_Lab/runs/train',
        name=PROJECT_NAME,
        exist_ok=True,
        device=0,
        lr0=0.001,      # 微調使用較小學習率
        patience=10,    # 10代沒進步自動停止
        workers=2,
        augment=True    # 開啟 YOLO 內建的線上增強
    )

    # --- 4. 驗證與導出 ---
    print("📊 執行最後驗證...")
    model.val()

    print("📦 正在導出手機端專用 ONNX...")
    onnx_path = model.export(format='onnx', opset=13)
    print(f"🚀 導出成功！檔案位於：{onnx_path}")

if __name__ == '__main__':
    finetune_grocery_model()