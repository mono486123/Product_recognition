import os
from ultralytics import YOLO

def test_model_accuracy(model_path: str, data_path: str):
    """
    載入訓練好的 YOLO 模型 (.pt 檔案)，並對指定資料集進行推理偵測。

    Args:
        model_path (str): best.pt 模型的完整路徑。
        data_path (str): 包含測試/驗證圖片的資料夾路徑。
    """
    # --- 1. 設定與路徑檢查 ---
    
    # 專案根目錄
    ROOT_DIR = os.path.dirname(os.path.abspath(__file__))
    
    # 將相對路徑轉為絕對路徑，確保模型和資料路徑的準確性
    MODEL_PATH = os.path.join(ROOT_DIR, model_path)
    DATA_PATH = os.path.join(ROOT_DIR, data_path)

    # 檢查模型檔案是否存在
    if not os.path.exists(MODEL_PATH):
        print(f"❌ 錯誤：找不到模型檔案：{MODEL_PATH}")
        print("💡 請確認路徑是否正確。")
        return

    # 檢查測試圖片資料夾是否存在 (這裡使用 yolo11_data/12_16/images，這假設是你最新的測試集)
    # 注意：這裡我保留了你上次程式碼中使用的 "12_16"，但如果你的圖片是在 "valid" 或 "test" 裡，
    # 請記得修正這裡的路徑。
    TEST_IMAGES_PATH = os.path.join(DATA_PATH, "12_16", "images")
    if not os.path.exists(TEST_IMAGES_PATH):
        print(f"❌ 警告：找不到測試圖片資料夾：{TEST_IMAGES_PATH}")
        print("💡 請確認路徑：03_AI_Lab/yolo11_data/12_16/images")
        return


    # --- 2. 載入模型 ---
    print(f"🚀 正在載入模型：{MODEL_PATH}...")
    try:
        model = YOLO(MODEL_PATH)
    except Exception as e:
        print(f"❌ 模型載入失敗：{e}")
        return

    # --- 3. 執行推理 (Prediction) ---
    print(f"🔍 正在對 {TEST_IMAGES_PATH} 中的圖片進行偵測...")
    
    # 使用 predict 模式
    # source: 指定要測試的圖片資料夾
    # conf: 【核心修正】設定最低信心閾值為 0.80 (80%)
    # save: 設為 True，結果圖會自動存在 runs/detect/predictX 資料夾中
    results = model.predict(
        source=TEST_IMAGES_PATH,
        conf=0.80, # <--- **這裡從 0.25 修正為 0.80**
        imgsz=640,
        device=0,  # 繼續使用 GPU 進行加速
        save=True  # 儲存帶有偵測框的圖片結果
    )

    # --- 4. 輸出結果 ---
    if results:
        # 取得儲存結果的路徑 (通常是 runs/detect/predict)
        save_path = results[0].save_dir
        print(f"\n✅ 推理完成！")
        print(f"📂 帶有偵測框的結果圖片已儲存至：{save_path}")
        print("💡 請查看該資料夾，現在只會顯示信心大於 80% 的偵測框。")
    else:
        print("⚠️ 推理失敗或未偵測到任何結果。")

if __name__ == '__main__':
    # 確保路徑指向你的 best.pt 和 yolo11_data 資料夾
    
    # 模型的相對路徑 (從 03_AI_Lab 目錄開始)
    PT_MODEL_PATH = r"runs\train\grocery_recognition_v1_Augmented_fake_background\weights\best.pt"
    
    # 資料集的相對路徑 (從 03_AI_Lab 目錄開始，指向包含 train/valid/test 的資料夾)
    DATA_ROOT_PATH = "yolo11_data" 
    
    test_model_accuracy(
        model_path=PT_MODEL_PATH,
        data_path=DATA_ROOT_PATH
    )