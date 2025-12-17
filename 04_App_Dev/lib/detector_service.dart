import 'dart:typed_data';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:image/image.dart' as img_lib;
import 'utils/yolo_decoder.dart';

class DetectorService {
  OrtSession? _session;
  bool isReady = false;

  // 初始化模型 (針對 realme GT 開啟 NNAPI)
  Future<void> loadModel() async {
    try {
      final sessionOptions = OrtSessionOptions();
      try {
        sessionOptions.addNnapi(); // 嘗試開啟硬體加速
        print("✅ NNAPI Enabled");
      } catch (e) {
        print("⚠️ NNAPI Failed, fallback to CPU");
      }

      _session = await OrtSession.fromAsset('assets/models/best.onnx', sessionOptions);
      isReady = true;
      print("✅ Model Loaded Successfully");
    } catch (e) {
      print("❌ Model Load Failed: $e");
    }
  }

  // 執行預測
  Future<List<DetectionResult>> predict(Uint8List imageBytes, double screenW, double screenH) async {
    if (!isReady || _session == null) return [];

    // 1. 圖片前處理 (Resize & Normalize)
    // 這是最耗時的步驟，為了簡單先用 pure dart 實作
    img_lib.Image? img = img_lib.decodeImage(imageBytes);
    if (img == null) return [];

    img_lib.Image resized = img_lib.copyResize(img, width: 640, height: 640);
    
    // 準備輸入資料 [1, 3, 640, 640]
    final inputData = Float32List(1 * 3 * 640 * 640);
    int pixelIndex = 0;
    for (var y = 0; y < 640; y++) {
      for (var x = 0; x < 640; x++) {
        var pixel = resized.getPixel(x, y);
        inputData[pixelIndex] = pixel.r / 255.0; // R
        inputData[pixelIndex + 640 * 640] = pixel.g / 255.0; // G
        inputData[pixelIndex + 640 * 640 * 2] = pixel.b / 255.0; // B
        pixelIndex++;
      }
    }

    // 2. 執行 ONNX 推論
    final inputOrt = OrtValueTensor.createTensorWithDataList(inputData, [1, 3, 640, 640]);
    final inputs = {'images': inputOrt}; // 輸入節點名稱
    final runOptions = OrtRunOptions();
    
    final outputs = await _session!.run(runOptions, inputs);
    
    // 3. 取得輸出並解碼
    // 輸出通常是 List<List<double>>，需要轉型
    final rawOutput = (outputs[0]?.value as List).cast<double>();
    
    // 計算縮放比例 (假設相機預覽是全螢幕或 4:3)
    // 這裡簡單假設圖片是被拉伸到 640x640 的
    final detections = YOLODecoder.decode(
      rawOutput, 
      scaleX: screenW / 640, 
      scaleY: screenH / 640
    );

    // 釋放記憶體
    inputOrt.release();
    runOptions.release();
    outputs.forEach((element) => element?.release());

    return detections;
  }

  void dispose() {
    _session?.release();
  }
}