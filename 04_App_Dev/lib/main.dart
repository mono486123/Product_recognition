import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

import 'detector_service.dart';
import 'camera_view.dart';
import 'utils/yolo_decoder.dart';

// 商品類別名稱 (確認與 AI Lab 訓練順序一致)
const List<String> LABELS = [
  "Ace_T1_Wang_Pai", "Ace_T6_Wang_Pai", "BAR", "Long_Life_White_Chang_Shou_Bai", 
  "Mai_Xiang_Black_Tea_Aluminum", "PENLAN", "Red_Label_Rice_Win_22_Medium", 
  "Red_Label_Rice_Wine_22_Large", "Red_Label_Rice_Wine_Cooking", "Snow_Mountain_Xue_Shan"
];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: GroceryPage()
  ));
}

class GroceryPage extends StatefulWidget {
  const GroceryPage({super.key});
  @override
  State<GroceryPage> createState() => _GroceryPageState();
}

class _GroceryPageState extends State<GroceryPage> {
  final DetectorService _detector = DetectorService();
  CameraController? _controller;
  List<DetectionResult> _results = [];
  bool _isDetecting = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    // 請求權限
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
    ].request();

    if (statuses[Permission.camera] != PermissionStatus.granted) {
      print("❌ 使用者拒絕了相機權限");
      return;
    }

    await _detector.loadModel();

    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _controller = CameraController(
      cameras[0], 
      ResolutionPreset.low, 
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420, // 針對 Android 優化
    );

    try {
      await _controller!.initialize();
      if (mounted) {
        setState(() {});
        // 延遲啟動串流，給系統一點反應時間
        Future.delayed(const Duration(seconds: 1), () {
          _controller!.startImageStream(_processCameraImage);
        });
      }
    } catch (e) {
      print("🚨 相機初始化失敗: $e");
    }
  }

  // --- 關鍵：處理串流影像 ---
  void _processCameraImage(CameraImage image) async {
    if (_isDetecting) return;
    _isDetecting = true;

    try {
      final screenSize = MediaQuery.of(context).size;
      
      // 呼叫 Service 進行辨識
      final results = await _detector.predict(
        image, 
        screenSize.width, 
        screenSize.height
      );

      if (mounted) {
        setState(() {
          _results = results;
        });
      }
    } catch (e) {
      print("⚠️ 辨識過程發生錯誤: $e");
    } finally {
      // 限制 Snapdragon 888 的運算頻率，每 400ms 跑一次
      await Future.delayed(const Duration(milliseconds: 400));
      _isDetecting = false;
    }
  }

  @override
  void dispose() {
    _controller?.stopImageStream();
    _controller?.dispose();
    _detector.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("雜貨店 AI 辨識 (Android 14)"),
        backgroundColor: Colors.green[700],
      ),
      body: CameraView(
        controller: _controller!,
        results: _results,
        labels: LABELS,
      ),
    );
  }
}