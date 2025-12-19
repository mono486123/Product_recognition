from ultralytics import YOLO

# 載入你的 ONNX 模型 (或是原本的 .pt 檔更好)
model = YOLO(r"D:\product_recognition\04_App_Dev\assets\models\best.onnx") 

# 匯出為 TFLite 格式
# format='tflite' 會生成一個包含 .tflite 的資料夾
model.export(format='tflite', imgsz=640)