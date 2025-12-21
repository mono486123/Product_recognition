import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'detector_service.dart';

// -----------------------------------------------------------------------
// 1. 資料模型與全域對照表
// -----------------------------------------------------------------------

class ProductItem {
  final String id;        // 原始標籤 (如 Red_Label_Rice_Wine_Cooking)
  final String name;      // 中文名稱 (如 紅標米酒_料理米酒)
  int originalPrice;      // 原始單價
  int currentPrice;       // 當前單價 (處理折抵用)
  int quantity;           // 數量

  ProductItem({
    required this.id,
    required this.name,
    required this.originalPrice,
    this.quantity = 1,
  }) : currentPrice = originalPrice;

  int get total => currentPrice * quantity;
}

// 標籤轉換為中文名稱 
final Map<String, String> labelTranslation = {
  "Ace_T1_Wang_Pai": "王牌_T1",
  "Ace_T6_Wang_Pai": "王牌_T6",
  "BAR": "BAR",
  "Long_Life_White_Chang_Shou_Bai": "長壽白",
  "Mai_Xiang_Black_Tea_Aluminum": "麥香_紅茶_瓶裝",
  "PENLAN": "PENLAN",
  "Red_Label_Rice_Win_22_Medium": "紅標米酒_22度_中",
  "Red_Label_Rice_Wine_22_Large": "紅標米酒_22度_大",
  "Red_Label_Rice_Wine_Cooking": "紅標米酒_料理米酒",
  "Snow_Mountain_Xue_Shan": "雪山",
};

// 商品原始價格資料庫 [cite: 5, 8]
final Map<String, int> productDatabase = {
  "Red_Label_Rice_Wine_Cooking": 27,
  "Snow_Mountain_Xue_Shan": 35,
  "PENLAN": 55,
  "Red_Label_Rice_Wine_22_Large": 92,
  "Red_Label_Rice_Win_22_Medium": 45,
  "Mai_Xiang_Black_Tea_Aluminum": 10,
  "Ace_T1_Wang_Pai": 80,
  "Ace_T6_Wang_Pai": 80,
  "Long_Life_White_Chang_Shou_Bai": 95,
  "BAR": 35,
};

void main() => runApp(MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: ThemeData(primarySwatch: Colors.blueGrey),
  home: const GroceryMainPage(),
));

// -----------------------------------------------------------------------
// 2. 主頁面：拍照與辨識結果清單 (Page 1, 2, 3, 7, 8)
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
  bool _isInListPage = false; // 控制顯示 Page 1 還是 Page 2

  @override
  void initState() {
    super.initState();
    _detector.loadModel();
  }

  // 計算所有商品總額 [cite: 6, 11]
  int get totalAmount => _cartItems.fold(0, (sum, item) => sum + item.total);

  // 拍照辨識邏輯 [cite: 2]
  Future<void> _takePhotoAndProcess() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo == null) return;

    setState(() => _isProcessing = true);

    final Uint8List originalBytes = await photo.readAsBytes();
    img.Image? originalImg = img.decodeImage(originalBytes);
    
    if (originalImg != null) {
      img.Image resizedImg = img.copyResize(originalImg, width: 640, height: 640);
      Uint8List aiBytes = Uint8List.fromList(img.encodeJpg(resizedImg));
      final results = await _detector.predictFixedImage(aiBytes);

      // 合併偵測結果並轉為中文 [cite: 5]
      Map<String, ProductItem> merged = {};
      for (var res in results) {
        String tag = res['tag'].toString();
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

  // 刪除按鈕邏輯：按一次減1，再按移除 
  void _handleDeleteItem(int index) {
    setState(() {
      if (_cartItems[index].quantity > 1) {
        _cartItems[index].quantity--;
      } else {
        _cartItems.removeAt(index);
      }
    });
  }

  // 酒瓶抵扣按鈕：特定品項減 2 元 
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

  // Page 1: 拍照頁面
  Widget _buildCameraPage() {
    return Scaffold(
      body: Stack(
        children: [
          Container(color: Colors.grey[800], child: const Center(child: Text("拍攝預覽畫面", style: TextStyle(color: Colors.white)))),
          if (_isProcessing) const Center(child: CircularProgressIndicator()),
          // 拍照與功能鈕 [cite: 2, 3]
          Positioned(
            bottom: 40,
            left: 0, right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                IconButton(onPressed: () {}, icon: const Icon(Icons.calculate, size: 45, color: Colors.blue)), // 計算機
                GestureDetector(
                  onTap: _takePhotoAndProcess,
                  child: Container(padding: const EdgeInsets.all(5), decoration: const BoxDecoration(color: Colors.orangeAccent, shape: BoxShape.circle), child: const Icon(Icons.camera_alt, size: 60, color: Colors.white)),
                ),
                const SizedBox(width: 45), // 佔位
              ],
            ),
          )
        ],
      ),
    );
  }

  // Page 2: 清單頁面
  Widget _buildListPage() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          const SizedBox(height: 50),
          Expanded(
            child: ListView.builder(
              itemCount: _cartItems.length,
              itemBuilder: (context, index) {
                final item = _cartItems[index];
                return _buildGridListItem(item, index);
              },
            ),
          ),
          // 底部控制區 [cite: 6, 8, 9]
          _buildBottomControlBar(),
        ],
      ),
    );
  }

  Widget _buildGridListItem(ProductItem item, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      child: Row(
        children: [
          Expanded(flex: 5, child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.grey[300], border: Border.all(color: Colors.grey)),
            child: Stack(
              children: [
                Text(item.name, style: const TextStyle(fontSize: 16)),
                Positioned(right: 0, top: 0, child: GestureDetector(
                  onTap: () => _handleDeleteItem(index),
                  child: const Icon(Icons.cancel, color: Colors.red, size: 20),
                )),
              ],
            ),
          )),
          const SizedBox(width: 5),
          _buildBox("${item.currentPrice}", 60),
          const SizedBox(width: 5),
          _buildBox("${item.quantity}", 50),
        ],
      ),
    );
  }

  Widget _buildBox(String text, double width) {
    return Container(
      width: width, padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.grey[300], border: Border.all(color: Colors.grey)),
      child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildBottomControlBar() {
    return Container(
      color: const Color(0xFFE1F5FE),
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), color: Colors.white, child: Text("TOTAL: $totalAmount 元", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
              const SizedBox(height: 10),
              IconButton(onPressed: _applyBottleDiscount, icon: const Icon(Icons.wine_bar, size: 40)), // 酒瓶鈕 [cite: 8]
            ],
          ),
          Column(
            children: [
              IconButton(onPressed: () => setState(() => _isInListPage = false), icon: const Icon(Icons.undo, size: 40)), // 返回鈕 [cite: 8]
              const SizedBox(height: 10),
              IconButton(onPressed: _openSearchPage, icon: const Icon(Icons.add_shopping_cart, size: 40)), // 推車鈕 [cite: 9]
            ],
          )
        ],
      ),
    );
  }

  void _openSearchPage() async {
    final List<ProductItem>? selected = await Navigator.push(
      context, MaterialPageRoute(builder: (context) => const ManualSearchPage()),
    );
    if (selected != null && selected.isNotEmpty) {
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
// 3. 手動搜尋頁面 (Page 4, 5, 6)
// -----------------------------------------------------------------------

class ManualSearchPage extends StatefulWidget {
  const ManualSearchPage({super.key});
  @override
  State<ManualSearchPage> createState() => _ManualSearchPageState();
}

class _ManualSearchPageState extends State<ManualSearchPage> {
  String _keyword = "";
  Map<String, int> _tempCounts = {}; // 暫存選中的數量

  @override
  Widget build(BuildContext context) {
    // 過濾搜尋結果 [cite: 13]
    final filteredTags = labelTranslation.entries
        .where((e) => e.value.contains(_keyword))
        .map((e) => e.key)
        .toList();

    return Scaffold(
      body: Column(
        children: [
          const SizedBox(height: 50),
          // 搜尋框 [cite: 13]
          Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              decoration: const InputDecoration(border: OutlineInputBorder(), prefixIcon: Icon(Icons.search), hintText: "輸入關鍵字"),
              onChanged: (val) => setState(() => _keyword = val),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filteredTags.length,
              itemBuilder: (context, idx) {
                String tag = filteredTags[idx];
                String name = labelTranslation[tag]!;
                int count = _tempCounts[tag] ?? 0;

                return ListTile(
                  title: Container(padding: const EdgeInsets.all(10), color: Colors.grey[200], child: Text(name)),
                  trailing: Container(width: 40, height: 40, alignment: Alignment.center, color: Colors.grey[200], child: Text("$count")),
                  onTap: () {
                    setState(() => _tempCounts[tag] = 1); // 選中變 1 [cite: 15]
                    _showToast(name); // 跳出提示框 [cite: 18]
                  },
                );
              },
            ),
          ),
          // 下方控制鈕 [cite: 19]
          Padding(
            padding: const EdgeInsets.only(bottom: 30),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(onPressed: _confirmAdd, icon: const Icon(Icons.add_shopping_cart, size: 60)), // 確認推車
                const SizedBox(width: 40),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.undo, size: 40)), // 返回
              ],
            ),
          )
        ],
      ),
    );
  }

  void _showToast(String name) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("$name x1"), behavior: SnackBarBehavior.floating, duration: const Duration(milliseconds: 700)),
    );
  }

  void _confirmAdd() {
    List<ProductItem> selectedItems = [];
    _tempCounts.forEach((tag, count) {
      if (count > 0) {
        selectedItems.add(ProductItem(id: tag, name: labelTranslation[tag]!, originalPrice: productDatabase[tag]!));
      }
    });
    Navigator.pop(context, selectedItems); // 只有按下推車鈕才傳回 
  }
}