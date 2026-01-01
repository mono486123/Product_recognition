import os
from pathlib import Path

# 設定你的路徑
label_path = r"D:\product_recognition\03_AI_Lab\yolo11_data\drink\test\labels" # 請確認這是你 labels 的實際路徑
num_classes = 31

print(f"--- 開始掃描標籤 (目標範圍: 0-30) ---")
found_error = False

for txt_file in Path(label_path).glob('*.txt'):
    with open(txt_file, 'r') as f:
        for i, line in enumerate(f):
            parts = line.split()
            if not parts: continue
            
            class_id = int(parts[0])
            if class_id >= num_classes:
                print(f"❌ 錯誤位置: {txt_file.name} | 第 {i+1} 行 | ID 為 {class_id}")
                found_error = True

if not found_error:
    print("✅ 訓練集標籤檢查完畢，未發現越界。請也對 valid/labels 執行相同檢查。")