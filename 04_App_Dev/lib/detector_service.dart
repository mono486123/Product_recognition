import 'dart:typed_data';
import 'package:flutter/services.dart'; // 引入這個以讀取 assets
import 'package:flutter_vision/flutter_vision.dart';

class DetectorService {
  late FlutterVision vision;
  bool isReady = false;

  DetectorService() {
    vision = FlutterVision();
  }

  Future<void> loadModel() async {
      try {
        // 修正 1: 全部改用正斜線 "/"
        // 修正 2: 檔名要跟 pubspec.yaml 裡的 best_float32.tflite 一致
        await vision.loadYoloModel(
          modelPath: "assets/models/best_float32.tflite", 
          labels: "assets/models/labels.txt", // 修正 3: 路徑要指到 models 資料夾內
          modelVersion: "yolov8",
          numThreads: 4,
          useGpu: false,
        );
        isReady = true;
        print("✅ AI 模型載入成功！");
      } catch (e) {
        print("❌ AI 模型載入失敗 (請檢查 assets 路徑或檔名): $e");
      }
    }
  // 接收圖片並回傳
  Future<List<Map<String, dynamic>>> predictFixedImage(Uint8List bytes) async {
    if (!isReady) {
      print("⚠️ 模型尚未準備好，跳過辨識");
      return [];
    }
    
    try {
      final result = await vision.yoloOnImage(
        bytesList: bytes,
        imageHeight: 640,
        imageWidth: 640,
        iouThreshold: 0.4,
        confThreshold: 0.3, // 建議調低一點 (0.3)，避免東西沒辨識出來
        classThreshold: 0.4,
      );
      print("🔍 辨識結果數量: ${result.length}");
      return result;
    } catch (e) {
      print("❌ 辨識過程發生錯誤: $e");
      return [];
    }
  }

  Future<void> dispose() async => await vision.closeYoloModel();
}