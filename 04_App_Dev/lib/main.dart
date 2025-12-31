// ==========================================
// 1. 套件導入區 (Imports)
// ==========================================
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'detector_service.dart'; // 確保檔案路徑正確

// ==========================================
// 2. 全域變數與啟動進入點
// ==========================================
Map<String, String> labelTranslation = {};
Map<String, int> productDatabase = {};
Map<String, String> productCategoryMap = {};

void main() => runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.grey[100],
      ),
      home: const GroceryMainPage(),
    ));

// ==========================================
// 3. 資料模型 (Data Model)
// ==========================================
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

// ==========================================
// 4. 主頁面組件 (GroceryMainPage)
// ==========================================
class GroceryMainPage extends StatefulWidget {
  const GroceryMainPage({super.key});
  @override
  State<GroceryMainPage> createState() => _GroceryMainPageState();
}

class _GroceryMainPageState extends State<GroceryMainPage> {
  // ------------------------------------------
  // A. 服務與狀態變數
  // ------------------------------------------
  final DetectorService _detector = DetectorService();
  final ImagePicker _picker = ImagePicker();
  
  final List<ProductItem> _cartItems = [];
  final TextEditingController _cashController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  bool _isDataLoaded = false;    // JSON 與模型是否載入完成
  bool _isInListPage = false;    // 是否處於購物清單頁面
  bool _isSearching = false;     // 是否開啟搜尋模式
  bool _isProcessingAI = false; // 是否正在進行 AI 辨識
  
  String _searchQuery = "";      // 搜尋關鍵字
  int _receivedAmount = 0;       // 收銀金額

  // ------------------------------------------
  // B. 初始化 (Init State)
  // ------------------------------------------
  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    await _loadProductData(); // 載入 JSON
    await _detector.loadModel(); // 載入 AI 模型
    if (mounted) setState(() => _isDataLoaded = true);
  }

  // ------------------------------------------
  // C. 資料載入邏輯 (JSON Parsing)
  // ------------------------------------------
  Future<void> _loadProductData() async {
    try {
      final String response = await rootBundle.loadString('assets/products.json');
      final List<dynamic> data = json.decode(response);
      
      productDatabase.clear();
      labelTranslation.clear();
      productCategoryMap.clear();

      for (var item in data) {
        String id = item['id']?.toString() ?? "unknown";
        int price = (item['price'] is int) ? item['price'] : (int.tryParse(item['price'].toString()) ?? 0);
        String name = item['name']?.toString() ?? "未命名商品";
        String category = (item['class']?.toString() ?? "food").toLowerCase().trim();

        productDatabase[id] = price;
        labelTranslation[id] = name;
        productCategoryMap[id] = category; 
      }
    } catch (e) {
      debugPrint("❌ 資料載入失敗: $e");
    }
  }

  // ------------------------------------------
  // D. AI 辨識處理邏輯
  // ------------------------------------------
  Future<void> _takePhotoAndAIProcess() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo == null) return;

    setState(() => _isProcessingAI = true);

    try {
      final Uint8List photoBytes = await photo.readAsBytes();
      final results = await _detector.predictFixedImage(photoBytes);

      if (results.isNotEmpty) {
        for (var res in results) {
          String tag = res['tag'].toString();
          if (productDatabase.containsKey(tag)) {
            _addItemToCart(tag);
          }
        }
        setState(() => _isInListPage = true);
      } else {
        _showSimpleSnackBar("AI 未能辨識商品");
      }
    } catch (e) {
      debugPrint("AI 辨識錯誤: $e");
    } finally {
      setState(() => _isProcessingAI = false);
    }
  }

  // ------------------------------------------
  // E. 購物車與折扣邏輯
  // ------------------------------------------
  int get totalAmount => _cartItems.fold(0, (sum, item) => sum + item.total);

  void _addItemToCart(String id) {
    setState(() {
      int idx = _cartItems.indexWhere((item) => item.id == id);
      if (idx != -1) {
        _cartItems[idx].quantity++;
      } else {
        _cartItems.add(ProductItem(
          id: id,
          name: labelTranslation[id] ?? id,
          originalPrice: productDatabase[id] ?? 0,
        ));
      }
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar(); 
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("已加入: ${labelTranslation[id]}", textAlign: TextAlign.center),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        width: 250,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.blueGrey[800],
      ),
    );
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
    bool hasChanged = false;
    setState(() {
      for (var item in _cartItems) {
        if (item.id == "Red_Label_Rice_Wine_22_Large" || item.id == "Red_Label_Rice_Wine_Cooking") {
          if (item.currentPrice == item.originalPrice) {
             item.currentPrice = item.originalPrice - 2;
             hasChanged = true;
          }
        }
      }
    });
    if (hasChanged) _showSimpleSnackBar("✅ 已套用米酒折抵");
  }

  void _showSimpleSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(milliseconds: 800)));
  }

  // ------------------------------------------
  // F. 對話框 UI (找零 / 分類選擇)
  // ------------------------------------------
  void _showChangeCalculator() {
    _cashController.text = "";
    _receivedAmount = 0;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          int change = _receivedAmount - totalAmount;
          return AlertDialog(
            title: const Text("找零助手"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("應收: $totalAmount 元", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                TextField(
                  controller: _cashController,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: "收銀金額", border: OutlineInputBorder(), prefixText: "\$ "),
                  onChanged: (v) => setDialogState(() => _receivedAmount = int.tryParse(v) ?? 0),
                ),
                const SizedBox(height: 20),
                Text("找錢: ${change < 0 ? 0 : change} 元", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: change >= 0 ? Colors.green : Colors.red)),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("完成")),
            ],
          );
        },
      ),
    );
  }

  void _showItemSelector(String title, String type) {
    List<String> filteredIds = productCategoryMap.entries
        .where((e) => e.value == type)
        .map((e) => e.key)
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: filteredIds.length,
                itemBuilder: (context, index) {
                  String id = filteredIds[index];
                  return ListTile(
                    title: Text(labelTranslation[id] ?? id),
                    subtitle: Text("\$${productDatabase[id]}"),
                    trailing: const Icon(Icons.add_circle, color: Colors.blueGrey),
                    onTap: () => _addItemToCart(id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------
  // G. 核心介面建構 (Build Methods)
  // ------------------------------------------
  @override
  Widget build(BuildContext context) {
    // 根據 _isInListPage 切換頁面
    return _isInListPage ? _buildListPage() : _buildCategoryPickerPage();
  }

  // 1. 分類選擇頁面
  Widget _buildCategoryPickerPage() {
    List<String> searchResults = [];
    if (_searchQuery.isNotEmpty) {
      searchResults = labelTranslation.entries
          .where((entry) => entry.value.contains(_searchQuery))
          .map((entry) => entry.key)
          .toList();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF263238),
      appBar: AppBar(
        title: !_isSearching 
            ? const Text("雜貨店 AI 收銀系統") 
            : TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(hintText: "搜尋商品...", border: InputBorder.none),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
        centerTitle: true,
        backgroundColor: Colors.blueGrey[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () => setState(() { 
              _isSearching = !_isSearching; 
              if(!_isSearching) { _searchQuery = ""; _searchController.clear(); } 
            }),
          )
        ],
      ),
      body: Stack(
        children: [
          !_isDataLoaded 
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : (_isSearching && _searchQuery.isNotEmpty) 
                ? _buildSearchList(searchResults) 
                : _buildCategoryGrid(),
          
          // AI 處理中遮罩
          if (_isProcessingAI)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.orange),
                    SizedBox(height: 20),
                    Text("AI 正在辨識商品...", style: TextStyle(color: Colors.white, fontSize: 18)),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "ai_cam",
            onPressed: _takePhotoAndAIProcess,
            backgroundColor: Colors.blueAccent,
            child: const Icon(Icons.camera_alt, color: Colors.white),
          ),
          const SizedBox(height: 12),
          if (_cartItems.isNotEmpty)
            FloatingActionButton.extended(
              heroTag: "checkout",
              onPressed: () => setState(() => _isInListPage = true),
              backgroundColor: Colors.orangeAccent,
              icon: const Icon(Icons.shopping_cart),
              label: Text("結帳 (${_cartItems.length})"),
            ),
        ],
      ),
    );
  }

  // 2. 搜尋結果子區塊
  Widget _buildSearchList(List<String> results) {
    return ListView.builder(
      itemCount: results.length,
      padding: const EdgeInsets.all(10),
      itemBuilder: (context, index) {
        String id = results[index];
        return Card(
          child: ListTile(
            title: Text(labelTranslation[id] ?? id),
            subtitle: Text("\$${productDatabase[id]}"),
            trailing: const Icon(Icons.add_shopping_cart, color: Colors.green),
            onTap: () => _addItemToCart(id),
          ),
        );
      },
    );
  }

  // 3. 分類方格子區塊
  Widget _buildCategoryGrid() {
    return GridView.count(
      padding: const EdgeInsets.all(20),
      crossAxisCount: 2,
      mainAxisSpacing: 20, crossAxisSpacing: 20,
      childAspectRatio: 1.1,
      children: [
        _categoryCard("香菸區", Icons.smoke_free, Colors.orange, "tobacco"),
        _categoryCard("飲料區", Icons.local_drink, Colors.lightBlue, "drink"),
        _categoryCard("酒類區", Icons.wine_bar, Colors.pinkAccent, "alcohol"),
        _categoryCard("食品/雜項", Icons.fastfood, Colors.lightGreen, "food"),
      ],
    );
  }

  Widget _categoryCard(String title, IconData icon, Color color, String type) {
    return Material(
      color: color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _showItemSelector(title, type),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: color.withOpacity(0.5), width: 2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 50, color: color),
              const SizedBox(height: 10),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  // 4. 購物清單頁面 (與原本邏輯一致)
  Widget _buildListPage() {
    return Scaffold(
      appBar: AppBar(
        title: const Text("確認購貨清單"),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios), onPressed: () => setState(() => _isInListPage = false)),
      ),
      body: Column(
        children: [
          Expanded(
            child: _cartItems.isEmpty 
              ? const Center(child: Text("購物車是空的")) 
              : ListView.separated(
                  itemCount: _cartItems.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final item = _cartItems[index];
                    return ListTile(
                      title: Text(item.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      subtitle: Text("單價: ${item.currentPrice}"),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () => _handleDeleteItem(index)),
                          Text("${item.quantity}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => setState(() => item.quantity++)),
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

  // 5. 底部控制欄
  Widget _buildBottomControlBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, -5))],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20))
      ),
      padding: const EdgeInsets.all(20),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("總計金額:", style: TextStyle(fontSize: 18)),
                Text("$totalAmount 元", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.redAccent)),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(child: OutlinedButton.icon(onPressed: _applyBottleDiscount, icon: const Icon(Icons.wine_bar), label: const Text("米酒折抵"))),
                const SizedBox(width: 10),
                Expanded(child: OutlinedButton.icon(style: OutlinedButton.styleFrom(foregroundColor: Colors.red), onPressed: () => setState(() { _cartItems.clear(); _isInListPage = false; }), icon: const Icon(Icons.delete_outline), label: const Text("清空"))),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity, 
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                onPressed: _cartItems.isNotEmpty ? _showChangeCalculator : null,
                icon: const Icon(Icons.attach_money),
                label: const Text("結帳 / 找零計算", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              )
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------
  // H. 資源回收
  // ------------------------------------------
  @override
  void dispose() {
    _detector.dispose();
    _searchController.dispose();
    _cashController.dispose();
    super.dispose();
  }
}