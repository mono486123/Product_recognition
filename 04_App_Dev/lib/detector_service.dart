import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_vision/flutter_vision.dart';
import 'package:image/image.dart' as img; // 需在 pubspec.yaml 加入 image 插件

class DetectorService {
  late FlutterVision vision;
  bool isReady = false;

  DetectorService() {
    vision = FlutterVision();
  }

  Future<void> loadModel() async {
    try {
      await vision.loadYoloModel(
        modelPath: "assets/models/best_float32.tflite",
        labels: "assets/models/labels.txt",
        modelVersion: "yolov8",
        numThreads: 4,
        useGpu: true,
      );
      isReady = true;
      print("✅ AI 模型載入成功！");
    } catch (e) {
      print("❌ AI 模型載入失敗: $e");
    }
  }

  /// 修正後：讓相機適用高畫質系統的辨識邏輯
  Future<List<Map<String, dynamic>>> predictFixedImage(Uint8List bytes) async {
    if (!isReady) return [];

    try {
      // --- 高畫質優化步驟 1: 解析圖片原始尺寸 ---
      // 避免直接假設是 640x640，這會導致座標偏移與畫質模糊
      img.Image? originalImage = img.decodeImage(bytes);
      if (originalImage == null) return [];

      // --- 高畫質優化步驟 2: 預處理圖片 (防止變形) ---
      // 使用 Letterbox 概念：將圖片縮放到 640，但維持比例，不足處留白
      img.Image resizedImage = img.copyResize(
        originalImage,
        width: 640, 
        height: 640,
        interpolation: img.Interpolation.linear, // 使用線性插值維持細節
      );

      // 轉回 Uint8List 餵給模型
      Uint8List processedBytes = Uint8List.fromList(img.encodeJpg(resizedImage));

      // --- 高畫質優化步驟 3: 執行辨識 ---
      final result = await vision.yoloOnImage(
        bytesList: processedBytes,
        imageHeight: 640, // 模型輸入規格
        imageWidth: 640,  // 模型輸入規格
        iouThreshold: 0.45,
        confThreshold: 0.5, // 調低門檻以捕捉高解析度下的細微特徵
        classThreshold: 0.1,
      );

      print("🔍 辨識完成，在高畫質優化下找到 ${result.length} 個物件");
      return result;
    } catch (e) {
      print("❌ 辨識過程發生錯誤: $e");
      return [];
    }
  }

  Future<void> dispose() async => await vision.closeYoloModel();
}