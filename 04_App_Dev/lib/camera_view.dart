import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class CameraView extends StatelessWidget {
  final CameraController controller;
  final List<Map<String, dynamic>> results;

  const CameraView({
    super.key,
    required this.controller,
    required this.results,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double screenW = size.width;
    final double screenH = size.height;

    // YOLO 模型標準輸入尺寸 (v11n 通常是 640)
    // 如果你的框框偏移，可以嘗試改成 320 或 416 (取決於你 export 時的參數)
    const double modelInputSize = 640.0; 

    return Stack(
      children: [
        // 1. 相機畫面
        Positioned.fill(child: CameraPreview(controller)),

        // 2. 偵測框繪製
        ...results.map((res) {
          final box = res['box'];
          
          // box[0]=x1, box[1]=y1, box[2]=x2, box[3]=y2 (在 640x640 的世界裡)
          
          // 💡 座標轉換核心 (針對直拿手機 + 轉正視角)
          // 因為我們在 Service 層交換了寬高，這裡的座標軸也變了：
          // AI 的 X -> 螢幕的 Y
          // AI 的 Y -> 螢幕的 X (且需要鏡像翻轉)
          
          double left = (1.0 - (box[3] / modelInputSize)) * screenW;
          double top = (box[0] / modelInputSize) * screenH;
          double width = ((box[3] - box[1]).abs() / modelInputSize) * screenW;
          double height = ((box[2] - box[0]).abs() / modelInputSize) * screenH;

          return Positioned(
            left: left.clamp(0, screenW),
            top: top.clamp(0, screenH),
            width: width.clamp(0, screenW),
            height: height.clamp(0, screenH),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.greenAccent, width: 3),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    color: Colors.greenAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text(
                      "${res['tag']} ${(box[4] * 100).toInt()}%",
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
        
        // 3. 偵錯資訊 (若沒框框，看這裡)
        if (results.isNotEmpty)
          Positioned(
            top: 50, left: 10,
            child: Container(
              padding: const EdgeInsets.all(8),
              color: Colors.black54,
              child: Text(
                "偵測中: ${results.length} 物體\n第一筆: ${results[0]['tag']}",
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}