import os
from ultralytics import YOLO

def resume_grocery_model():
    # --- 1. 路徑設定 (指向你上次訓練出的權重) ---
    # 使用你剛提到的路徑
    PREVIOUS_BEST_MODEL = r"D:\product_recognition\03_AI_Lab\runs\train\grocery_recognition_v2_Augmented_fake_background\weights\last.pt"
    DATA_YAML_PATH = "03_AI_Lab/yolo11_data/data.yaml"  # 確保路徑正確
    PROJECT_NAME = 'grocery_recognition_v2_Augmented_fake_background'
    
    # --- 2. 訓練參數設定 ---
    # 既然是繼續訓練，可以再跑 100 次，或是視情況調整
    ADDITIONAL_EPOCHS = 100 
    IMG_SIZE = 640
    BATCH_SIZE = 8

    # 檢查權重檔案是否存在
    if not os.path.exists(PREVIOUS_BEST_MODEL):
        print(f"❌ 錯誤：找不到權重檔案 {PREVIOUS_BEST_MODEL}")
        return

    # --- 3. 載入模型並繼續訓練 ---
    print(f"🔄 正在載入先前的最佳權重進行續練：{PREVIOUS_BEST_MODEL}")
    model = YOLO(PREVIOUS_BEST_MODEL)

    # 開始訓練
    model.train(
        data=DATA_YAML_PATH,
        epochs=ADDITIONAL_EPOCHS,   # 這裡設定的是「總共」要跑到的次數或額外次數
        imgsz=IMG_SIZE,
        batch=BATCH_SIZE,
        workers=1,
        project='03_AI_Lab/runs/train',
        name=PROJECT_NAME,
        exist_ok=True,             # 設為 True，新的訓練結果會覆蓋或存入同一個資料夾
        device=0,
        # 建議：續練時可以稍微降低學習率，或保持原始增強設定
        degrees=15.0,
        mosaic=1.0,
        lr0=0.001                  # 視情況調小學習率（可選）
    )

    print("✅ 續練完成！")

if __name__ == '__main__':
    resume_grocery_model()