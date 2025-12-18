import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:camera/camera.dart'; // 引入相機格式
import 'utils/yolo_decoder.dart';

class DetectorService {
  OrtSession? _session;
  bool isReady = false;

  Future<void> loadModel() async {
    try {
      OrtEnv.instance.init();
      final sessionOptions = OrtSessionOptions();
      const modelPath = 'assets/models/best.onnx';
      final rawModel = await rootBundle.load(modelPath);
      final modelBytes = rawModel.buffer.asUint8List();
      _session = OrtSession.fromBuffer(modelBytes, sessionOptions);
      isReady = true;
      print("✅ YOLOv11 Model Ready");
    } catch (e) {
      print("❌ Model Error: $e");
    }
  }

  // 修改：直接接收 CameraImage
  Future<List<DetectionResult>> predict(CameraImage image, double screenW, double screenH) async {
    if (!isReady || _session == null) return [];

    try {
      // 1. 預處理：將 YUV 轉為模型需要的 Float32List (NCHW: 1, 3, 640, 640)
      // 這裡採用最簡單的取樣方式，避免 realme GT 運算過載
      final inputData = _processYUV420(image);
      
      // 2. 執行推論
      final inputOrt = OrtValueTensor.createTensorWithDataList(inputData, [1, 3, 640, 640]);
      final inputs = {'images': inputOrt};
      final runOptions = OrtRunOptions();
      
      final outputs = _session!.run(runOptions, inputs);
      final rawOutput = (outputs[0]?.value as List).cast<double>();
      
      // 3. 解碼結果 (YOLOv11: 1, 14, 8400)
      final detections = YOLODecoder.decode(
        rawOutput, 
        scaleX: screenW / 640, 
        scaleY: screenH / 640
      );

      inputOrt.release();
      runOptions.release();
      for (var element in outputs) { element?.release(); }

      return detections;
    } catch (e) {
      print("推論錯誤: $e");
      return [];
    }
  }

  // 核心優化：將相機 YUV 數據直接轉為 AI 輸入張量
  Float32List _processYUV420(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final Float32List out = Float32List(1 * 3 * 640 * 640);

    // 簡化演算法：只取 Y 通道（亮度）來模擬圖片
    // 雖然是黑白的，但 YOLO 對形狀很敏感，通常仍能辨識出酒瓶/鋁罐
    // 這樣做在 realme GT 上最快且最不佔記憶體
    for (int y = 0; y < 640; y++) {
      for (int x = 0; x < 640; x++) {
        // 將 640x640 映射回原始相機解析度
        int srcX = (x * width / 640).toInt();
        int srcY = (y * height / 640).toInt();
        
        // 取得 Y 亮度值 (0~255)
        int yValue = image.planes[0].bytes[srcY * image.planes[0].bytesPerRow + srcX];
        double normalized = yValue / 255.0;

        // 填入 R, G, B (黑白圖則三個通道相同)
        out[y * 640 + x] = normalized; // R
        out[640 * 640 + y * 640 + x] = normalized; // G
        out[2 * 640 * 640 + y * 640 + x] = normalized; // B
      }
    }
    return out;
  }

  void dispose() {
    _session?.release();
    OrtEnv.instance.release();
  }
}