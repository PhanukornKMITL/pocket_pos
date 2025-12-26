import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import '../models/product.dart';
import '../services/product_service.dart';

class ProductFormScreen extends StatefulWidget {
  final Product? product;

  const ProductFormScreen({super.key, this.product});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final ProductService _productService = ProductService();
  bool _isSaving = false;
  String? _imagePath;
  Uint8List? _imageBytes; // used for web preview
  List<ProductOption> _options = [];

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      _nameController.text = widget.product!.name;
      _priceController.text = widget.product!.price.toString();
      _stockController.text = widget.product!.stock.toString();
      _barcodeController.text = widget.product!.barcode ?? '';
      _descriptionController.text = widget.product!.description ?? '';
      _imagePath = widget.product!.imagePath;
      _options = List.from(widget.product!.options); // Copy list to allow modifications
    } else {
      _options = []; // Initialize empty list for new products
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _barcodeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final product = Product(
        id: widget.product?.id,
        name: _nameController.text.trim(),
        price: double.parse(_priceController.text),
        stock: int.tryParse(_stockController.text) ?? 0,
        barcode: _barcodeController.text.trim().isEmpty
            ? null
            : _barcodeController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        imagePath: _imagePath,
        options: _options,
      );

      print('Saving product: ${product.name}');
      print('Options to save: $_options');
      print('Product map: ${product.toMap()}');

      if (widget.product == null) {
        await _productService.createProduct(product);
      } else {
        await _productService.updateProduct(product);
      }

      print('Product saved successfully');

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.product == null
                  ? 'เพิ่มสินค้าสำเร็จ'
                  : 'แก้ไขสินค้าสำเร็จ',
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
        );
      }
    }
  }

  Future<void> _pickProductImage() async {
    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _imageBytes = bytes;
          _imagePath = null;
        });
      } else {
        setState(() {
          _imagePath = picked.path;
          _imageBytes = null;
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ไม่สามารถเลือกภาพได้: $e')));
    }
  }

  void _clearImage() {
    setState(() {
      _imagePath = null;
      _imageBytes = null;
    });
  }

  Future<void> _showAddOptionDialog() async {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    
    if (!mounted) return;
    
    showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        title: const Text('เพิ่มตัวเลือก'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'ชื่อ'),
              onEditingComplete: () {
                priceController.clear();
                FocusManager.instance.primaryFocus?.unfocus();
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              decoration: const InputDecoration(labelText: 'ราคาเพิ่ม (บาท)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onEditingComplete: () {
                FocusManager.instance.primaryFocus?.unfocus();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              FocusManager.instance.primaryFocus?.unfocus();
              Navigator.pop(dialogContext, false);
              Future.delayed(const Duration(milliseconds: 100), () {
                nameController.dispose();
                priceController.dispose();
              });
            },
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () {
              final name = nameController.text.trim();
              final price = double.tryParse(priceController.text) ?? 0.0;
              FocusManager.instance.primaryFocus?.unfocus();
              if (name.isNotEmpty && mounted) {
                setState(() => _options.add(ProductOption(name: name, price: price)));
              }
              Navigator.pop(dialogContext, true);
              Future.delayed(const Duration(milliseconds: 100), () {
                nameController.dispose();
                priceController.dispose();
              });
            },
            child: const Text('เพิ่ม'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product == null ? 'เพิ่มสินค้า' : 'แก้ไขสินค้า'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'ชื่อสินค้า *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'กรุณากรอกชื่อสินค้า';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'ราคา *',
                  border: OutlineInputBorder(),
                  suffixText: 'บาท',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'กรุณากรอกราคา';
                  }
                  final price = double.tryParse(value);
                  if (price == null || price < 0) {
                    return 'กรุณากรอกราคาที่ถูกต้อง';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _stockController,
                decoration: const InputDecoration(
                  labelText: 'จำนวนสต็อก',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final stock = int.tryParse(value);
                    if (stock == null || stock < 0) {
                      return 'กรุณากรอกจำนวนที่ถูกต้อง';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _barcodeController,
                decoration: const InputDecoration(
                  labelText: 'บาร์โค้ด',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'รายละเอียด',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              // Image upload / preview
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: _imageBytes != null
                            ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                            : (_imagePath != null && _imagePath!.isNotEmpty)
                                ? (kIsWeb
                                    ? Image.network(_imagePath!, fit: BoxFit.cover)
                                    : Image.file(File(_imagePath!), fit: BoxFit.cover))
                                : Center(
                                    child: Icon(
                                      Icons.photo_camera_outlined,
                                      size: 48,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: _pickProductImage,
                          child: const Text('อัพโหลดรูปสินค้า'),
                        ),
                        const SizedBox(width: 12),
                        if (_imagePath != null || _imageBytes != null)
                          TextButton(
                            onPressed: _clearImage,
                            child: const Text('ลบรูป', style: TextStyle(color: Colors.red)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Options
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ตัวเลือกสินค้า', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (_options.isEmpty)
                        Text('ยังไม่มีตัวเลือก', style: TextStyle(color: Colors.grey[600])),
                      ..._options.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final opt = entry.value;
                        return ListTile(
                          dense: true,
                          title: Text(opt.name),
                          subtitle: Text('+${opt.price.toStringAsFixed(2)} บาท'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => setState(() => _options.removeAt(idx)),
                          ),
                        );
                      }).toList(),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: _showAddOptionDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('เพิ่มตัวเลือก'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveProduct,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(widget.product == null ? 'บันทึก' : 'อัพเดท'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

