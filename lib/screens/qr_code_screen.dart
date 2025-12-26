import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/order.dart';
import '../models/order_item.dart';
import '../services/database_service.dart';
import 'full_screen_image.dart';

class QRCodeScreen extends StatefulWidget {
  final List<OrderItem> cartItems;
  final double total;
  final int? pendingOrderId;

  const QRCodeScreen({
    super.key,
    required this.cartItems,
    required this.total,
    this.pendingOrderId,
  });

  @override
  State<QRCodeScreen> createState() => _QRCodeScreenState();
}

class _QRCodeScreenState extends State<QRCodeScreen> {
  final NumberFormat _currencyFormat = NumberFormat('#,##0.00');
  bool _isProcessing = false;
  // QR upload state
  Uint8List? _qrImageBytes;
  String? _qrImagePath;

  @override
  void initState() {
    super.initState();
    // Always load saved default QR first so it appears for new orders.
    _loadDefaultQr();
    if (widget.pendingOrderId != null) {
      _loadPendingOrderQr();
    }
  }

  Future<void> _loadPendingOrderQr() async {
    try {
      final db = DatabaseService.instance;
      final order = await db.getOrder(widget.pendingOrderId!);
      if (order != null && order.qrImage != null) {
        setState(() {
          _qrImageBytes = order.qrImage;
          _qrImagePath = null;
        });
        return;
      }
    } catch (_) {}
    // No pending-order QR found — keep previously loaded default (if any).
  }

  Future<void> _loadDefaultQr() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final b64 = prefs.getString('default_qr_base64');
      if (b64 != null && b64.isNotEmpty) {
        final bytes = base64Decode(b64);
        if (mounted) setState(() { _qrImageBytes = bytes; _qrImagePath = null; });
      }
    } catch (_) {}
  }

  Future<void> _confirmPayment() async {
    setState(() => _isProcessing = true);

    try {
      // include uploaded QR image bytes if provided
      Uint8List? qrBytes;
      if (_qrImageBytes != null) {
        qrBytes = _qrImageBytes;
      } else if (_qrImagePath != null) {
        try {
          qrBytes = await File(_qrImagePath!).readAsBytes();
        } catch (_) {
          qrBytes = null;
        }
      }

      final order = Order(
        status: OrderStatus.completed,
        total: widget.total,
        paymentMethod: 'QR Code',
        items: widget.cartItems,
        completedAt: DateTime.now(),
        // Do not persist uploaded QR into the order record by default.
        qrImage: null,
      );

      final db = DatabaseService.instance;
      await db.createOrder(order);

      // Delete pending order if exists
      if (widget.pendingOrderId != null) {
        await db.deleteOrder(widget.pendingOrderId!);
      }

      if (mounted) {
        // Pop back to home screen
        Navigator.popUntil(context, (route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('บันทึกออเดอร์สำเร็จ'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
        );
      }
    }
  }

  Future<void> _pickQrImage() async {
    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _qrImageBytes = bytes;
          _qrImagePath = null;
        });
        // persist as default
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('default_qr_base64', base64Encode(bytes));
        } catch (_) {}
      } else {
        // read bytes to persist default as well
        try {
          final fileBytes = await File(picked.path).readAsBytes();
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('default_qr_base64', base64Encode(fileBytes));
        } catch (_) {}
        setState(() {
          _qrImagePath = picked.path;
          _qrImageBytes = null;
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ไม่สามารถเลือกภาพได้: $e')));
    }
  }

  void _clearQrImage() {
    setState(() {
      _qrImageBytes = null;
      _qrImagePath = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Code'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    // QR Code box — tap to open full-screen when image present, otherwise pick
                    GestureDetector(
                      onTap: () {
                        if (_qrImageBytes != null || _qrImagePath != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FullScreenImageScreen(
                                imageBytes: _qrImageBytes,
                                imagePath: _qrImagePath,
                              ),
                            ),
                          );
                        } else {
                          _pickQrImage();
                        }
                      },
                      child: Stack(
                        children: [
                          Container(
                            width: 250,
                            height: 250,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(
                                color: Colors.grey[300]!,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: _qrImageBytes != null
                                  ? Image.memory(
                                      _qrImageBytes!,
                                      width: 250,
                                      height: 250,
                                      fit: BoxFit.cover,
                                    )
                                  : _qrImagePath != null
                                      ? Image.file(
                                          File(_qrImagePath!),
                                          width: 250,
                                          height: 250,
                                          fit: BoxFit.cover,
                                        )
                                      : Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.qr_code,
                                              size: 150,
                                              color: Colors.grey[400],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'QR Code',
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                            ),
                          ),
                          if (_qrImageBytes != null || _qrImagePath != null)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: CircleAvatar(
                                backgroundColor: Colors.white70,
                                child: IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  color: Colors.red,
                                  onPressed: _clearQrImage,
                                  tooltip: 'ลบภาพ QR',
                                ),
                              ),
                            ),
                          // Hint when no image uploaded
                          if (!(_qrImageBytes != null || _qrImagePath != null))
                            Positioned(
                              bottom: 8,
                              left: 8,
                              right: 8,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black45,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'แตะเพื่ออัปโหลดภาพ QR',
                                    style: TextStyle(color: Colors.white, fontSize: 12),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                      const SizedBox(height: 12),
                    Text(
                      'ยอดที่ต้องชำระ',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_currencyFormat.format(widget.total)} บาท',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'รายการสินค้า',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Column(
                        children: [
                          ...widget.cartItems.asMap().entries.map((entry) {
                            final index = entry.key;
                            final item = entry.value;
                            return Column(
                              children: [
                                ListTile(
                                  title: Text(
                                    item.productName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${_currencyFormat.format(item.productPrice)} บาท x ${item.quantity}',
                                  ),
                                  trailing: Text(
                                    '${_currencyFormat.format(item.subtotal)} บาท',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (index < widget.cartItems.length - 1)
                                  const Divider(height: 1),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Total and Confirm Button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'รวมทั้งหมด',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_currencyFormat.format(widget.total)} บาท',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                  onPressed: _isProcessing ? null : _confirmPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                    disabledForegroundColor: Colors.grey[600],
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'ยืนยันการชำระเงิน',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

