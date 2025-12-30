
import os
import cv2
from ultralytics import YOLO
from pathlib import Path

# ================= 配置設定 =================
MODEL_PATH = r"D:\product_recognition\03_AI_Lab\runs\train\grocery_v4_stable_final\weights\best.pt"
SOURCE_DIR = r"D:\product_recognition\03_AI_Lab\yolo11_data\drink\test\images" # 你新拍的照片夾
OUTPUT_DIR = r"D:\product_recognition\03_AI_Lab\yolo11_data\drink\test_output" # 輸出結果
CONF_THRESHOLD = 0.4 
# ===========================================

def auto_labeling():
    # 1. 載入模型
    model = YOLO(MODEL_PATH)
    
    # 2. 建立輸出目錄
    output_path = Path(OUTPUT_DIR)
    img_out = output_path / "visual_check"  
    lab_out = output_path / "labels"        
    img_out.mkdir(parents=True, exist_ok=True)
    lab_out.mkdir(parents=True, exist_ok=True)

    # 3. 取得所有新照片
    valid_extensions = ('.jpg', '.jpeg', '.png')
    images = [f for f in os.listdir(SOURCE_DIR) if f.lower().endswith(valid_extensions)]
    
    if not images:
        print(f"⚠️ 在 {SOURCE_DIR} 中找不到圖片，請檢查路徑。")
        return

    print(f"🚀 開始自動辨識 {len(images)} 張照片...")

    for img_name in images:
        img_path = os.path.join(SOURCE_DIR, img_name)
        
        # 進行推理
        results = model.predict(source=img_path, conf=CONF_THRESHOLD, verbose=False)[0]

        # --- A. 儲存辨識後的框圖 (供人工檢查) ---
        annotated_frame = results.plot()
        cv2.imwrite(str(img_out / img_name), annotated_frame)

        # --- B. 儲存 YOLO 格式標籤 (修正報錯部分) ---
        # 定義輸出的 txt 檔名
        txt_name = Path(img_name).stem + ".txt"
        txt_path = lab_out / txt_name
        
        # 使用官方內建方法直接存成標籤檔
        # 它會自動處理歸一化、類別 ID 等細節
        results.save_txt(str(txt_path))

    print(f"\n✅ 處理完成！")
    print(f"1. 檢查圖片：{img_out}")
    print(f"2. 取得標籤：{lab_out}")

if __name__ == "__main__":
    auto_labeling()