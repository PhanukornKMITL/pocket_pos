import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import '../models/order.dart';
import '../services/database_service.dart';

class OrderDetailScreen extends StatefulWidget {
  final int orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final DatabaseService _db = DatabaseService.instance;
  final NumberFormat _currencyFormat = NumberFormat('#,##0.00');
  Order? _order;
  bool _isLoading = true;
  final Map<int, String?> _productImages = {};

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    setState(() => _isLoading = true);
    try {
      final order = await _db.getOrder(widget.orderId);
      // Preload product images for items
      final images = <int, String?>{};
      if (order != null) {
        for (var item in order.items) {
          if (!images.containsKey(item.productId)) {
            try {
              final product = await _db.getProduct(item.productId);
              images[item.productId] = product?.imagePath;
            } catch (_) {
              images[item.productId] = null;
            }
          }
        }
      }

      setState(() {
        _order = order;
        _productImages.clear();
        _productImages.addAll(images);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('รายละเอียดออเดอร์ #${widget.orderId}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _order == null
              ? const Center(child: Text('ไม่พบออเดอร์'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'สถานะ: ${_order!.status.name}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text('วันที่สร้าง: ${_order!.createdAt}'),
                      if (_order!.completedAt != null) ...[
                        const SizedBox(height: 8),
                        Text('วันที่ปิด: ${_order!.completedAt}'),
                      ],
                      if (_order!.paymentMethod != null) ...[
                        const SizedBox(height: 8),
                        Text('วิธีชำระ: ${_order!.paymentMethod}'),
                      ],
                      const Divider(height: 24),
                      const Text('รายการสินค้า', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Card(
                        child: Column(
                              children: _order!.items.map((item) {
                                final imagePath = _productImages[item.productId];
                                Widget leading;
                                if (imagePath != null && imagePath.isNotEmpty) {
                                  if (kIsWeb) {
                                    if (imagePath.startsWith('http')) {
                                      leading = CircleAvatar(backgroundImage: NetworkImage(imagePath));
                                    } else {
                                      leading = CircleAvatar(
                                        backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                                        child: Icon(Icons.shopping_bag, color: Theme.of(context).primaryColor),
                                      );
                                    }
                                  } else {
                                    try {
                                      final file = File(imagePath);
                                      if (file.existsSync()) {
                                        leading = CircleAvatar(backgroundImage: FileImage(file));
                                      } else {
                                        leading = CircleAvatar(
                                          backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                                          child: Icon(Icons.shopping_bag, color: Theme.of(context).primaryColor),
                                        );
                                      }
                                    } catch (_) {
                                      leading = CircleAvatar(
                                        backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                                        child: Icon(Icons.shopping_bag, color: Theme.of(context).primaryColor),
                                      );
                                    }
                                  }
                                } else {
                                  leading = CircleAvatar(
                                    backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                                    child: Icon(Icons.shopping_bag, color: Theme.of(context).primaryColor),
                                  );
                                }

                                return ListTile(
                                  leading: leading,
                                  title: Text(item.productName),
                                  subtitle: Text('${_currencyFormat.format(item.productPrice)} x ${item.quantity}'),
                                  trailing: Text('${_currencyFormat.format(item.subtotal)}'),
                                );
                              }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Show stored QR image if present
                      if (_order!.qrImage != null) ...[
                        const SizedBox(height: 12),
                        Text('ภาพ QR ที่บันทึกไว้', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Stack(
                          children: [
                            Container(
                              width: 250,
                              height: 250,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[300]!, width: 2),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.memory(
                                  _order!.qrImage!,
                                  fit: BoxFit.cover,
                                  width: 250,
                                  height: 250,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: CircleAvatar(
                                backgroundColor: Colors.white70,
                                child: IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  color: Colors.red,
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('ลบภาพ QR'),
                                        content: const Text('คุณแน่ใจหรือจะลบภาพ QR ที่บันทึกไว้?'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
                                          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('ลบ', style: TextStyle(color: Colors.red))),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      try {
                                        final updated = _order!.copyWith(qrImage: null);
                                        await _db.updateOrder(updated);
                                        await _loadOrder();
                                      } catch (e) {
                                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ไม่สามารถลบได้: $e')));
                                      }
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                      Text(
                        'รวมทั้งหมด: ${_currencyFormat.format(_order!.total)} บาท',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
    );
  }
}
