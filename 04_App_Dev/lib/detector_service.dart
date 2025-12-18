import 'dart:typed_data';
import 'package:flutter_vision/flutter_vision.dart';

class DetectorService {
  late FlutterVision vision;
  bool isReady = false;

  DetectorService() {
    vision = FlutterVision();
  }

  Future<void> loadModel() async {
    await vision.loadYoloModel(
      modelPath: 'assets/models/best.tflite',
      labels: 'assets/models/labels.txt',
      modelVersion: "yolov8", // 雖然座標歪了，但名稱是對的，維持 v8 即可
      numThreads: 4,
      useGpu: false,
    );
    isReady = true;
  }

  // 接收 640x640 影像並回傳原始清單
  Future<List<Map<String, dynamic>>> predictFixedImage(Uint8List bytes) async {
    if (!isReady) return [];
    return await vision.yoloOnImage(
      bytesList: bytes,
      imageHeight: 640,
      imageWidth: 640,
      iouThreshold: 0.4,
      confThreshold: 0.5, // 降低到 0.1 確保能抓到更多樣東西
      classThreshold: 0.5,
    );
  }

  Future<void> dispose() async => await vision.closeYoloModel();
}