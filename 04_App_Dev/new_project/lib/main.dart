import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 全域變數
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
  final List<ProductItem> _cartItems = [];
  bool _isDataLoaded = false;
  bool _isInListPage = false;

  final TextEditingController _cashController = TextEditingController();
  final TextEditingController _searchController = TextEditingController(); // 搜尋控制器
  String _searchQuery = ""; // 儲存搜尋關鍵字
  int _receivedAmount = 0;

  @override
  void initState() {
    super.initState();
    _loadProductData();
  }

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
        String rawClass = item['class']?.toString() ?? "food";
        String category = rawClass.toLowerCase().trim();

        productDatabase[id] = price;
        labelTranslation[id] = name;
        productCategoryMap[id] = category; 
      }
      
      setState(() => _isDataLoaded = true);
    } catch (e) {
      debugPrint("❌ 資料載入失敗: $e");
    }
  }

  int get totalAmount => _cartItems.fold(0, (sum, item) => sum + item.total);

  // 🛒 加入購物車 + 1秒彈性提示框
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

    // --- 彈性訊息框邏輯 ---
    // 先移除目前的 SnackBar，防止多個商品點擊時出現「排隊」現象
    ScaffoldMessenger.of(context).hideCurrentSnackBar(); 
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "已加入: ${labelTranslation[id]}",
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        duration: const Duration(seconds: 1), // 1秒後消失
        behavior: SnackBarBehavior.floating,   // 懸浮樣式
        width: 250, // 限制寬度使其看起來更像彈窗
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
    if (hasChanged) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ 已套用米酒折抵"), duration: Duration(milliseconds: 500)));
    }
  }

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

  @override
  Widget build(BuildContext context) {
    return _isInListPage ? _buildListPage() : _buildCategoryPickerPage();
  }
  // 1. 在變數宣告區新增這個
  bool _isSearching = false;
  // 2. 修改後的 _buildCategoryPickerPage
  Widget _buildCategoryPickerPage() {
    // 根據搜尋關鍵字過濾商品
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
      // --- 修改點 A: 使用 _isSearching 來判斷顯示文字還是輸入框 ---
      title: !_isSearching 
          ? const Text("雜貨店收銀系統") 
          : TextField(
              controller: _searchController,
              autofocus: true, // 自動彈出鍵盤
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: "輸入商品名稱...",
                hintStyle: TextStyle(color: Colors.white70),
                border: InputBorder.none,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
      centerTitle: true,
      backgroundColor: Colors.blueGrey[900],
      foregroundColor: Colors.white,
      actions: [
        IconButton(
          // --- 修改點 B: 根據搜尋狀態切換圖示 ---
          icon: Icon(_isSearching ? Icons.close : Icons.search),
          onPressed: () {
            setState(() {
              if (_isSearching) {
                // 如果正在搜尋，點擊後關閉搜尋模式並清空字串
                _isSearching = false;
                _searchController.clear();
                _searchQuery = "";
              } else {
                // 如果不在搜尋，點擊後開啟搜尋模式
                _isSearching = true;
              }
            });
          },
        )
      ],
    ),

      body: !_isDataLoaded 
        ? const Center(child: CircularProgressIndicator(color: Colors.white))
        : (_isSearching && _searchQuery.isNotEmpty) // --- 修改點 C: 判斷顯示搜尋結果還是分類 ---
            ? _buildSearchList(searchResults) 
            : _buildCategoryGrid(),
  
      floatingActionButton: _cartItems.isNotEmpty 
        ? FloatingActionButton.extended(
            onPressed: () => setState(() => _isInListPage = true),
            backgroundColor: Colors.orangeAccent,
            icon: const Icon(Icons.shopping_cart),
            label: Text("結帳 (${_cartItems.length})"),
          )
        : null,
    );
  }

  // 搜尋結果清單
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

  // 原始分類方格
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

  // --- 購物清單頁面 (保持不變) ---
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
}