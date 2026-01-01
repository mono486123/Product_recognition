import os

def clean_augmented_files(data_root):
    """
    🧹 專門刪除 YOLO 格式資料集中的擴充檔案
    包含: .jpg, .png, .txt (標籤)
    """
    # 定義要掃描的子路徑 (可根據需求增加，如 val, test)
    sub_dirs = [
        os.path.join("train", "images"),
        os.path.join("train", "labels")    ]
    
    tags = ["_blur", "_noise"]
    count = 0

    print(f"🚀 開始清理路徑: {data_root}")

    for sub in sub_dirs:
        folder_path = os.path.join(data_root, sub)
        
        if not os.path.exists(folder_path):
            print(f"ℹ️ 跳過不存在的資料夾: {sub}")
            continue

        for filename in os.listdir(folder_path):
            # 檢查檔名是否包含指定的標籤
            if any(tag in filename for tag in tags):
                file_path = os.path.join(folder_path, filename)
                try:
                    os.remove(file_path)
                    count += 1
                except Exception as e:
                    print(f"❌ 無法刪除 {filename}: {e}")

    print(f"✅ 清理完畢！總共刪除了 {count} 個擴充檔案。")

# --- 測試區塊：如果你直接執行 Tools.py 就會執行這裡 ---
if __name__ == "__main__":
    # 這裡填入你的資料集根目錄
    TARGET_PATH = r"D:\product_recognition\03_AI_Lab\yolo11_data"
    clean_augmented_files(TARGET_PATH)