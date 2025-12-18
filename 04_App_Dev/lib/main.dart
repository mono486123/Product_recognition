import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'detector_service.dart';

void main() => runApp(const MaterialApp(
  debugShowCheckedModeBanner: false,
  home: GroceryResultPage()
));

class GroceryResultPage extends StatefulWidget {
  const GroceryResultPage({super.key});
  @override
  State<GroceryResultPage> createState() => _GroceryResultPageState();
}

class _GroceryResultPageState extends State<GroceryResultPage> {
  final DetectorService _detector = DetectorService();
  final ImagePicker _picker = ImagePicker();
  
  File? _displayImage;
  List<Map<String, dynamic>> _results = [];
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _detector.loadModel();
  }

  Future<void> _processPhoto() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo == null) return;

    setState(() {
      _isProcessing = true;
      _displayImage = File(photo.path);
      _results = [];
    });

    final Uint8List originalBytes = await photo.readAsBytes();
    img.Image? originalImg = img.decodeImage(originalBytes);
    
    if (originalImg != null) {
      // 暴力縮放至 640x640 給 AI
      img.Image resizedImg = img.copyResize(originalImg, width: 640, height: 640);
      Uint8List aiBytes = Uint8List.fromList(img.encodeJpg(resizedImg));

      final results = await _detector.predictFixedImage(aiBytes);

      setState(() {
        _results = results;
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("雜貨辨識清單模式"),
        backgroundColor: Colors.blueGrey[900],
      ),
      backgroundColor: Colors.grey[200],
      body: Column(
        children: [
          // 1. 照片顯示區域 (佔畫面 40%)
          Expanded(
            flex: 4,
            child: Container(
              width: double.infinity,
              color: Colors.black,
              child: _displayImage != null
                  ? Image.file(_displayImage!, fit: BoxFit.contain)
                  : const Center(child: Text("請拍攝商品照片", style: TextStyle(color: Colors.white))),
            ),
          ),
          
          // 2. 數據輸出區域 (佔畫面 60%)
          Expanded(
            flex: 6,
            child: Container(
              padding: const EdgeInsets.all(16.0),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: _isProcessing
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                      ? const Center(child: Text("尚未偵測到商品", style: TextStyle(fontSize: 18)))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 總結欄
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.blueGrey[50],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text("偵測結果", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                  Text("共 ${_results.length} 樣", style: const TextStyle(fontSize: 18, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            const Divider(height: 30),
                            // 詳細清單
                            Expanded(
                              child: ListView.separated(
                                itemCount: _results.length,
                                separatorBuilder: (ctx, idx) => const Divider(),
                                itemBuilder: (ctx, idx) {
                                  final item = _results[idx];
                                  final double confidence = item['box'][4] * 100;
                                  
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.blueGrey,
                                      child: Text("${idx + 1}", style: const TextStyle(color: Colors.white)),
                                    ),
                                    title: Text(
                                      item['tag'].toString().replaceAll('_', ' '),
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                                    ),
                                    trailing: Text(
                                      "${confidence.toStringAsFixed(1)}%",
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: confidence > 50 ? Colors.green : Colors.orange,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _processPhoto,
        label: const Text("拍商品拍照辨識"),
        icon: const Icon(Icons.camera_alt),
        backgroundColor: Colors.blueGrey[900],
      ),
    );
  }
}