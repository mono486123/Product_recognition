import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'detector_service.dart';
import 'dart:convert'; // <--- 必須加上這一行！
// 全域變數：供主頁面與搜尋頁面共用
Map<String, String> labelTranslation = {};
Map<String, int> productDatabase = {};

void main() => runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blueGrey),
      home: const GroceryMainPage(),
    ));

// -----------------------------------------------------------------------
// 1. 資料模型
// -----------------------------------------------------------------------
class ProductItem {
  final String id;
  final String name;
  int originalPrice;
  int currentPrice;
  int quantity;

  ProductItem({
    required this.id,
    required this.name,
    required this.originalPrice,
    this.quantity = 1,
  }) : currentPrice = originalPrice;

  int get total => currentPrice * quantity;
}

// -----------------------------------------------------------------------
// 2. 主頁面邏輯
// -----------------------------------------------------------------------
class GroceryMainPage extends StatefulWidget {
  const GroceryMainPage({super.key});
  @override
  State<GroceryMainPage> createState() => _GroceryMainPageState();
}

class _GroceryMainPageState extends State<GroceryMainPage> {
  final DetectorService _detector = DetectorService();
  final ImagePicker _picker = ImagePicker();

  List<ProductItem> _cartItems = [];
  bool _isProcessing = false;
  bool _isInListPage = false;
  bool _isDataLoaded = false;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  // 初始化：載入 AI 模型與 CSV 數據
  // 初始化：分開載入，互不影響
    Future<void> _initApp() async {
      // 1. 先載入商品資料 (CSV)，這樣就算 AI 壞掉，搜尋功能還能用
      await _loadProductData();
      
      // 2. 再載入 AI 模型
      await _detector.loadModel();
      
      // 3. 更新畫面
      if (mounted) {
        setState(() => _isDataLoaded = true);
      }
    }
  
    Future<void> _loadProductData() async {
      try {
        print("📂 開始讀取 JSON...");
        final String response = await DefaultAssetBundle.of(context).loadString('assets/products.json');
        final List<dynamic> data = json.decode(response);
        
        // 先清空，確保資料不會重複疊加
        productDatabase.clear();
        labelTranslation.clear();
    
        int loadedCount = 0;
        for (var item in data) {
          String id = item['id'];
          int price = item['price'];
          String name = item['name'];
    
          productDatabase[id] = price;
          labelTranslation[id] = name;
          loadedCount++;
        }
        print("✅ 成功載入 $loadedCount 筆商品資料");
      } catch (e) {
        print("❌ 資料載入失敗 (請檢查 JSON 格式或 Import): $e");
      }
    }






  int get totalAmount => _cartItems.fold(0, (sum, item) => sum + item.total);

  Future<void> _takePhotoAndProcess() async {
    if (!_isDataLoaded) return;
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo == null) return;

    setState(() => _isProcessing = true);

    final Uint8List originalBytes = await photo.readAsBytes();
    img.Image? originalImg = img.decodeImage(originalBytes);

    if (originalImg != null) {
      img.Image resizedImg = img.copyResize(originalImg, width: 640, height: 640);
      Uint8List aiBytes = Uint8List.fromList(img.encodeJpg(resizedImg));
      final results = await _detector.predictFixedImage(aiBytes);

      Map<String, ProductItem> merged = {};
      for (var res in results) {
        String tag = res['tag'].toString();
        // 核心對照邏輯：從 CSV 讀取的 Map 中找尋中文與價格
        String chineseName = labelTranslation[tag] ?? tag;
        int price = productDatabase[tag] ?? 0;

        if (merged.containsKey(tag)) {
          merged[tag]!.quantity++;
        } else {
          merged[tag] = ProductItem(id: tag, name: chineseName, originalPrice: price);
        }
      }

      setState(() {
        _cartItems = merged.values.toList();
        _isProcessing = false;
        _isInListPage = true;
      });
    }
  }

  void _handleDeleteItem(int index) {
    setState(() {
      if (_cartItems[index].quantity > 1) {
        _cartItems[index].quantity--;
      } else {
        _cartItems.removeAt(index);
      }
    });
  }

  void _applyBottleDiscount() {
    setState(() {
      for (var item in _cartItems) {
        if (item.name.contains("米酒")) {
          item.currentPrice = item.originalPrice - 2;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return _isInListPage ? _buildListPage() : _buildCameraPage();
  }

  Widget _buildCameraPage() {
      return Scaffold(
        body: Stack(
          children: [
            // 背景：不用黑色，改用深灰色，並顯示提示文字
            Container(
              color: Colors.blueGrey[900],
              width: double.infinity,
              height: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt_outlined, size: 100, color: Colors.white.withOpacity(0.3)),
                  const SizedBox(height: 20),
                  // 根據載入狀態顯示不同文字
                  Text(
                    _isDataLoaded ? "點擊下方按鈕\n開啟相機拍照" : "系統初始化中...",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
            ),
            
            // 狀態 1: 如果還在載入資料 (CSV/Model)，顯示轉圈圈
            if (!_isDataLoaded)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.orange),
                      SizedBox(height: 10),
                      Text("正在載入商品資料...", style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ),
  
            // 狀態 2: 如果正在處理照片 (Processing)，顯示轉圈圈
            if (_isProcessing)
              Container(
                color: Colors.black54,
                child: const Center(child: CircularProgressIndicator(color: Colors.orange)),
              ),
  
            // 底部按鈕區
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(
                    onPressed: () {}, 
                    icon: const Icon(Icons.calculate, size: 45, color: Colors.blue)
                  ),
                  GestureDetector(
                    // 只有資料載入完成才允許點擊
                    onTap: _isDataLoaded ? _takePhotoAndProcess : null,
                    child: Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        // 如果還沒載入好，按鈕變灰色
                        color: _isDataLoaded ? Colors.orange : Colors.grey, 
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt, size: 40, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 45), // 佔位用
                ],
              ),
            )
          ],
        ),
      );
    }

  Widget _buildListPage() {
    return Scaffold(
      appBar: AppBar(title: const Text("辨識結果清單"), leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _isInListPage = false))),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _cartItems.length,
              itemBuilder: (context, index) {
                final item = _cartItems[index];
                return ListTile(
                  title: Text(item.name),
                  subtitle: Text("單價: ${item.currentPrice} 元"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("x${item.quantity}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red), onPressed: () => _handleDeleteItem(index)),
                    ],
                  ),
                );
              },
            ),
          ),
          _buildBottomControlBar(),
        ],
      ),
    );
  }

  Widget _buildBottomControlBar() {
    return Container(
      color: Colors.blueGrey[50],
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("總計: $totalAmount 元", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red)),
              TextButton.icon(onPressed: _applyBottleDiscount, icon: const Icon(Icons.discount), label: const Text("米酒折抵 -2 元")),
            ],
          ),
          ElevatedButton.icon(
            onPressed: _openSearchPage,
            icon: const Icon(Icons.search),
            label: const Text("手動新增"),
          )
        ],
      ),
    );
  }

  void _openSearchPage() async {
    final List<ProductItem>? selected = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ManualSearchPage()),
    );
    if (selected != null) {
      setState(() {
        for (var newItem in selected) {
          int idx = _cartItems.indexWhere((item) => item.id == newItem.id);
          if (idx != -1) {
            _cartItems[idx].quantity++;
          } else {
            _cartItems.add(newItem);
          }
        }
      });
    }
  }
}

// -----------------------------------------------------------------------
// 3. 手動搜尋頁面
// -----------------------------------------------------------------------
class ManualSearchPage extends StatefulWidget {
  const ManualSearchPage({super.key});
  @override
  State<ManualSearchPage> createState() => _ManualSearchPageState();
}

class _ManualSearchPageState extends State<ManualSearchPage> {
  String _keyword = "";
  final Map<String, int> _tempSelection = {};

  @override
  Widget build(BuildContext context) {
    // 過濾邏輯
    final filteredTags = labelTranslation.entries
        .where((e) => e.value.contains(_keyword) || e.key.toLowerCase().contains(_keyword.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text("搜尋商品")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(hintText: "搜尋中文或標籤...", prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
              onChanged: (v) => setState(() => _keyword = v),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filteredTags.length,
              itemBuilder: (context, idx) {
                final entry = filteredTags[idx];
                return ListTile(
                  title: Text(entry.value),
                  subtitle: Text(entry.key),
                  trailing: _tempSelection.containsKey(entry.key) ? const Icon(Icons.check_circle, color: Colors.green) : null,
                  onTap: () {
                    setState(() => _tempSelection[entry.key] = 1);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("已選中: ${entry.value}"), duration: const Duration(milliseconds: 500)));
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              onPressed: () {
                List<ProductItem> results = [];
                _tempSelection.forEach((id, qty) {
                  results.add(ProductItem(id: id, name: labelTranslation[id]!, originalPrice: productDatabase[id]!));
                });
                Navigator.pop(context, results);
              },
              child: const Text("確認新增"),
            ),
          )
        ],
      ),
    );
  }
}