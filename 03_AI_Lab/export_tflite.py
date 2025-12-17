import os
import sys
import numpy as np
import onnxruntime as ort
from ultralytics import YOLO

# ================= 設定區 =================
# 請將此路徑改為您 best.pt 的實際位置
PT_MODEL_PATH = "runs/detect/train/weights/best.pt" 
# 匯出目標尺寸 (YOLOv8 預設通常是 640)
IMG_SIZE = 640 
# =========================================

def export_and_verify():
    # 1. 檢查檔案是否存在
    if not os.path.exists(PT_MODEL_PATH):
        print(f"❌ 錯誤：找不到模型檔案：{PT_MODEL_PATH}")
        print("請修改程式碼中的 PT_MODEL_PATH 變數。")
        sys.exit(1)

    print(f"🚀 載入模型：{PT_MODEL_PATH}...")
    try:
        model = YOLO(PT_MODEL_PATH)
    except Exception as e:
        print(f"❌ 模型載入失敗，請確認 ultralytics 已安裝且檔案未損毀。\n錯誤：{e}")
        return

    # 2. 執行匯出 (使用 Ultralytics 內建的 export，最穩定)
    print("\n📦 Step 1: 正在匯出為 ONNX 格式...")
    try:
        # format='onnx': 指定格式
        # opset=12: Android 相容性最好的版本之一
        # simplify=True: 簡化模型結構，提升手機執行速度
        path = model.export(format="onnx", imgsz=IMG_SIZE, opset=12, simplify=True)
        print(f"🎉 ONNX 匯出成功！檔案路徑：{path}")
    except Exception as e:
        print(f"❌ ONNX 匯出失敗：{e}")
        return

    # 3. 驗證 ONNX (模擬手機推論)
    print("\n🔍 Step 2: 正在驗證 ONNX 模型 (檢查 Input/Output Shape)...")
    try:
        onnx_path = path # export 回傳的是路徑字串
        
        # 建立推論 Session (模擬手機上的 OrtSession)
        session = ort.InferenceSession(onnx_path, providers=["CPUExecutionProvider"])
        
        # 取得輸入資訊
        input_info = session.get_inputs()[0]
        input_name = input_info.name
        input_shape = input_info.shape
        print(f"   👉 輸入名稱: {input_name}")
        print(f"   👉 輸入 Shape: {input_shape} (Batch, Channel, Height, Width)")

        # 取得輸出資訊
        output_info = session.get_outputs()[0]
        output_name = output_info.name
        output_shape = output_info.shape
        print(f"   👉 輸出名稱: {output_name}")
        print(f"   👉 輸出 Shape: {output_shape} (Batch, Anchors, Class+Box)")

        # 建立一個假的輸入資料進行測試
        # 注意：YOLOv8 export 預設 input shape 包含 batch (通常是 1x3x640x640)
        dummy_input = np.random.rand(1, 3, IMG_SIZE, IMG_SIZE).astype(np.float32)
        
        # 執行推論
        result = session.run([output_name], {input_name: dummy_input})
        
        print("\n✅ 驗證成功！此 ONNX 模型可以在 ONNX Runtime 上執行。")
        print("---------------------------------------------------")
        print("💡 給 Android 開發的重點筆記：")
        print(f"1. Android Assets 檔名請改為: best.onnx")
        print(f"2. 輸入圖片需 Resize 成: {IMG_SIZE} x {IMG_SIZE}")
        print(f"3. 您的模型輸出 Shape 為: {output_shape}")
        print("   (這代表後處理迴圈需要遍歷這個數量的預測框)")
        print("---------------------------------------------------")

    except Exception as e:
        print(f"❌ 驗證失敗：{e}")

if __name__ == "__main__":
    export_and_verify()