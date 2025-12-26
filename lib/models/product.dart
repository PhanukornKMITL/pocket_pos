import 'dart:convert';

class Product {
  final int? id;
  final String name;
  final double price;
  final int stock;
  final String? barcode;
  final String? description;
  final String? imagePath;
  final List<ProductOption> options;
  final DateTime createdAt;
  final DateTime updatedAt;

  Product({
    this.id,
    required this.name,
    required this.price,
    this.stock = 0,
    this.barcode,
    this.description,
    this.imagePath,
    List<ProductOption>? options,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        options = options ?? [];

  Map<String, dynamic> toMap() {
    final optionsJson = options.isNotEmpty ? jsonEncode(options.map((o) => o.toMap()).toList()) : null;
    print('Product.toMap() - name: $name, options: $options, optionsJson: $optionsJson');
    return {
      'id': id,
      'name': name,
      'price': price,
      'stock': stock,
      'barcode': barcode,
      'description': description,
      'image_path': imagePath,
      'options': optionsJson,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int?,
      name: map['name'] as String,
      price: (map['price'] as num).toDouble(),
      stock: map['stock'] as int? ?? 0,
      barcode: map['barcode'] as String?,
      description: map['description'] as String?,
      imagePath: map['image_path'] as String?,
      options: map['options'] != null
          ? (jsonDecode(map['options'] as String) as List).map((m) => ProductOption.fromMap(m as Map<String, dynamic>)).toList()
          : [],
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Product copyWith({
    int? id,
    String? name,
    double? price,
    int? stock,
    String? barcode,
    String? description,
    String? imagePath,
    List<ProductOption>? options,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      barcode: barcode ?? this.barcode,
      description: description ?? this.description,
      imagePath: imagePath ?? this.imagePath,
      options: options ?? this.options,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isOutOfStock => stock <= 0;
}

class ProductOption {
  final String name;
  final double price;

  ProductOption({required this.name, required this.price});

  Map<String, dynamic> toMap() => {'name': name, 'price': price};

  factory ProductOption.fromMap(Map<String, dynamic> map) => ProductOption(
        name: map['name'] as String? ?? '',
        price: (map['price'] as num?)?.toDouble() ?? 0.0,
      );
}

