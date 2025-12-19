import 'dart:math';

/// 偵測結果資料模型
class DetectionResult {
  final int classId;
  final double score;
  final double x; // 左上角 X
  final double y; // 左上角 Y
  final double w; // 寬度
  final double h; // 高度

  DetectionResult(this.classId, this.score, this.x, this.y, this.w, this.h);
}

class YOLODecoder {
  static List<DetectionResult> decode(
    List<double> data, {
    required double scaleX, 
    required double scaleY,
    int numClasses = 10,
    double confidenceThreshold = 0.25, // 稍微回調門檻，避免雜訊
    double iouThreshold = 0.45,
  }) {
    List<DetectionResult> allDetections = [];
    int numElements = 4 + numClasses; // 14
    int numBoxes = 8400;

    // 檢查數據長度
    if (data.length < numElements * numBoxes) {
      print("數據長度不符: ${data.length}");
      return [];
    }

    for (int i = 0; i < numBoxes; i++) {
      double maxScore = 0;
      int classId = -1;
      
      // 找出信心度最高的類別
      for (int j = 0; j < numClasses; j++) {
        double currentScore = data[i + (4 + j) * numBoxes];
        if (currentScore > maxScore) {
          maxScore = currentScore;
          classId = j;
        }
      }

      // 如果超過門檻，進行座標轉換
      if (maxScore > confidenceThreshold) {
        // 1. 取得模型輸出的歸一化比例 (0.0 ~ 1.0)
        double nx = data[i + 0 * numBoxes] / 640.0;
        double ny = data[i + 1 * numBoxes] / 640.0;
        double nw = data[i + 2 * numBoxes] / 640.0;
        double nh = data[i + 3 * numBoxes] / 640.0;

        // 2. 針對直向螢幕 (Portrait) 的座標旋轉映射
        // AI 看到的是橫的 (Landscape)，手機拿的是直的
        // 螢幕 X 對應 AI 的 Y (反轉)
        // 螢幕 Y 對應 AI 的 X
        double finalX = (1.0 - ny) * scaleX;
        double finalY = nx * scaleY;
        double finalW = nh * scaleX; 
        double finalH = nw * scaleY;

        allDetections.add(DetectionResult(
          classId,
          maxScore,
          finalX - finalW / 2, // 轉為左上角 X
          finalY - finalH / 2, // 轉為左上角 Y
          finalW,
          finalH,
        ));
      }
    }
    
    // 執行非極大值抑制，移除重疊框
    return _performNMS(allDetections, iouThreshold);
  }

  static List<DetectionResult> _performNMS(List<DetectionResult> boxes, double iouThreshold) {
    if (boxes.isEmpty) return [];
    
    // 依分數從高到低排序
    boxes.sort((a, b) => b.score.compareTo(a.score));
    
    List<DetectionResult> selected = [];
    List<bool> active = List.filled(boxes.length, true);

    for (int i = 0; i < boxes.length; i++) {
      if (!active[i]) continue;
      selected.add(boxes[i]);
      
      for (int j = i + 1; j < boxes.length; j++) {
        if (!active[j]) continue;
        if (calculateIoU(boxes[i], boxes[j]) > iouThreshold) {
          active[j] = false;
        }
      }
    }
    return selected;
  }

  static double calculateIoU(DetectionResult a, DetectionResult b) {
    double xA = max(a.x, b.x);
    double yA = max(a.y, b.y);
    double xB = min(a.x + a.w, b.x + b.w);
    double yB = min(a.y + a.h, b.y + b.h);

    double interArea = max(0, xB - xA) * max(0, yB - yA);
    if (interArea <= 0) return 0;
    
    double areaA = a.w * a.h;
    double areaB = b.w * b.h;
    return interArea / (areaA + areaB - interArea);
  }
}