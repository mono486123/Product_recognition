import onnxruntime as ort
import numpy as np
import os

# 這是您剛剛提供的路徑
ONNX_PATH = r"D:\product_recognition\03_AI_Lab\runs\train\grocery_recognition_v1\weights\best.onnx"

def check_model():
    if not os.path.exists(ONNX_PATH):
        print(f"❌ 找不到檔案：{ONNX_PATH}")
        return

    print(f"📂 正在讀取模型：{ONNX_PATH}")

    try:
        # 1. 嘗試載入模型
        session = ort.InferenceSession(ONNX_PATH, providers=["CPUExecutionProvider"])
        print("✅ 模型載入成功！")

        # 2. 取得輸入資訊
        input_tensor = session.get_inputs()[0]
        input_shape = input_tensor.shape
        print(f"\n👉 輸入 (Input) Shape: {input_shape}")
        # 通常是 [1, 3, 640, 640]

        # 3. 取得輸出資訊 (最關鍵的資訊！)
        output_tensor = session.get_outputs()[0]
        output_shape = output_tensor.shape
        print(f"👉 輸出 (Output) Shape: {output_shape}")
        # 可能類似 [1, 84, 8400] 或 [1, 8400, 84]

        # 4. 試跑一次推論 (確保沒有錯誤)
        # 根據模型要求的尺寸建立假資料
        h, w = input_shape[2], input_shape[3]
        dummy_input = np.random.rand(1, 3, h, w).astype(np.float32)
        
        result = session.run([output_tensor.name], {input_tensor.name: dummy_input})
        print(f"\n✅ 推論測試成功！模型功能正常。")

        print("-" * 30)
        print("📝 下一步 (Android 開發) 需要的資訊：")
        print(f"1. 請記下輸出 Shape: {output_shape}")
        print("2. 把 best.onnx 複製到 Android 專案的 assets 資料夾")
        print("-" * 30)

    except Exception as e:
        print(f"\n❌ 檢測失敗，錯誤訊息：{e}")

if __name__ == "__main__":
    check_model()