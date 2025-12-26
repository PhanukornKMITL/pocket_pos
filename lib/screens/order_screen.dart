import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../models/product.dart';
import '../models/order.dart';
import '../models/order_item.dart';
import '../services/product_service.dart';
import '../services/database_service.dart';
import 'products_list_screen.dart';
import 'checkout_screen.dart';

class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  final ProductService _productService = ProductService();
  final DatabaseService _db = DatabaseService.instance;
  final List<OrderItem> _cartItems = [];
  final NumberFormat _currencyFormat = NumberFormat('#,##0.00');
  String _searchQuery = '';

  double get _total => _cartItems.fold(0.0, (sum, item) => sum + item.subtotal);

  void _addToCart(Product product) {
    setState(() {
      final existingIndex = _cartItems.indexWhere(
        (item) => item.productId == product.id,
      );

      if (existingIndex >= 0) {
        final existingItem = _cartItems[existingIndex];
        _cartItems[existingIndex] = existingItem.copyWith(
          quantity: existingItem.quantity + 1,
          subtotal: existingItem.productPrice * (existingItem.quantity + 1),
        );
      } else {
        _cartItems.add(OrderItem.fromProduct(product));
      }
    });
  }

  void _removeFromCart(int index) {
    setState(() {
      _cartItems.removeAt(index);
    });
  }

  void _updateQuantity(int index, int quantity) {
    if (quantity <= 0) {
      _removeFromCart(index);
      return;
    }

    setState(() {
      final item = _cartItems[index];
      _cartItems[index] = item.copyWith(
        quantity: quantity,
        subtotal: item.productPrice * quantity,
      );
    });
  }

  Future<void> _checkout() async {
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเพิ่มสินค้าในตะกร้าก่อน')),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckoutScreen(
          cartItems: _cartItems,
          total: _total,
        ),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    // If cart is empty allow pop without dialog
    if (_cartItems.isEmpty) return true;

    // Show dialog with three options: Stay, Discard, Save Draft
    final result = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ออกจากหน้าสร้างออเดอร์'),
        content: const Text(
          'คุณยังมีสินค้าในตะกร้า ต้องการบันทึกออเดอร์ชั่วคราวเพื่อทำต่อภายหลังหรือจะทิ้งออเดอร์นี้ไป?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'stay'),
            child: const Text('ทำต่อ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('ไม่บันทึก'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );

    if (result == 'stay' || result == null) {
      // Stay on the page
      return false;
    }

    if (result == 'save') {
      // Save draft as pending order
      try {
        final order = Order(
          status: OrderStatus.pending,
          total: _total,
          items: _cartItems,
        );
        await _db.createOrder(order);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('บันทึกออเดอร์ชั่วคราวแล้ว'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
          );
        }
        // If save fails, do not pop
        return false;
      }
    }

    // For 'discard' or successful 'save', allow pop
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
  child: Scaffold(
      appBar: AppBar(
        title: const Text('สร้างออเดอร์'),
        actions: [
          IconButton(
            icon: const Icon(Icons.inventory_2),
            onPressed: () async {
              final product = await Navigator.push<Product>(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProductsListScreen(),
                ),
              );
              if (product != null) {
                _addToCart(product);
              }
            },
            tooltip: 'เลือกสินค้า',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
          // Search + Products Grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'ค้นหาสินค้า',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),

          Expanded(
            flex: 2,
            child: FutureBuilder<List<Product>>(
              future: _productService.getAllProducts(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'),
                  );
                }

        final products = snapshot.data ?? [];
        final query = _searchQuery.trim().toLowerCase();
        final filtered = query.isEmpty
          ? products
          : products.where((p) => p.name.toLowerCase().contains(query)).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          query.isEmpty ? 'ยังไม่มีสินค้า' : 'ไม่พบสินค้า',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ProductsListScreen(),
                              ),
                            );
                            setState(() {});
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('เพิ่มสินค้า'),
                        ),
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final product = filtered[index];
                    final cartItem = _cartItems.firstWhere(
                      (item) => item.productId == product.id,
                      orElse: () => OrderItem(
                        productId: product.id!,
                        productName: '',
                        productPrice: 0,
                        quantity: 0,
                        orderId: 0,
                      ),
                    );

                    return Card(
                      child: InkWell(
                        onTap: () => _addToCart(product),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Center(
                                  child: (() {
                                    final path = product.imagePath;
                                    if (path != null && path.isNotEmpty) {
                                      // On web, only use network URLs
                                      if (kIsWeb) {
                                        if (path.startsWith('http')) {
                                          return Image.network(
                                            path,
                                            width: 72,
                                            height: 72,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stack) => Icon(
                                              Icons.shopping_bag,
                                              size: 48,
                                              color: product.isOutOfStock
                                                  ? Colors.grey[400]
                                                  : Theme.of(context).primaryColor,
                                            ),
                                          );
                                        }
                                        // No valid image for web, fall back to icon
                                        return Icon(
                                          Icons.shopping_bag,
                                          size: 48,
                                          color: product.isOutOfStock
                                              ? Colors.grey[400]
                                              : Theme.of(context).primaryColor,
                                        );
                                      }

                                      // Mobile / Desktop: try to load local file
                                      try {
                                        final file = File(path);
                                        if (file.existsSync()) {
                                          return Image.file(
                                            file,
                                            width: 72,
                                            height: 72,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stack) => Icon(
                                              Icons.shopping_bag,
                                              size: 48,
                                              color: product.isOutOfStock
                                                  ? Colors.grey[400]
                                                  : Theme.of(context).primaryColor,
                                            ),
                                          );
                                        }
                                      } catch (_) {
                                        // ignore and fall back to icon
                                      }
                                    }

                                    return Icon(
                                      Icons.shopping_bag,
                                      size: 48,
                                      color: product.isOutOfStock
                                          ? Colors.grey[400]
                                          : Theme.of(context).primaryColor,
                                    );
                                  })(),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                product.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_currencyFormat.format(product.price)} บาท',
                                style: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (cartItem.quantity > 0) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).primaryColor,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${cartItem.quantity}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                              if (product.isOutOfStock)
                                Text(
                                  'หมด',
                                  style: TextStyle(
                                    color: Colors.red[700],
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Cart
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_cartItems.isNotEmpty)
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _cartItems.length,
                      itemBuilder: (context, index) {
                        final item = _cartItems[index];
                        return ListTile(
                          title: Text(item.productName),
                          subtitle: Text(
                            '${_currencyFormat.format(item.productPrice)} x ${item.quantity}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove),
                                onPressed: () => _updateQuantity(
                                  index,
                                  item.quantity - 1,
                                ),
                              ),
                              Text(
                                '${item.quantity}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add),
                                onPressed: () => _updateQuantity(
                                  index,
                                  item.quantity + 1,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                color: Colors.red,
                                onPressed: () => _removeFromCart(index),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                if (_cartItems.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'รวมทั้งหมด',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${_currencyFormat.format(_total)} บาท',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton(
                          onPressed: _checkout,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                          ),
                          child: const Text(
                            'ปิดออเดอร์',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ), // Column
    ), // SafeArea
  ), // Scaffold
); // WillPopScope
  }
}

