import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/product.dart';
import '../models/order.dart';
import '../models/order_item.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('pocket_pos.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Products table
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        stock INTEGER NOT NULL DEFAULT 0,
        barcode TEXT,
        description TEXT,
        image_path TEXT,
        options TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Orders table
    await db.execute('''
      CREATE TABLE orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        status TEXT NOT NULL,
        total REAL NOT NULL,
        qr_image BLOB,
        payment_method TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        completed_at TEXT
      )
    ''');

    // Order items table
    await db.execute('''
      CREATE TABLE order_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        product_price REAL NOT NULL,
        quantity INTEGER NOT NULL,
        subtotal REAL NOT NULL,
        options TEXT,
        FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');

    // Create indexes for better performance
    await db.execute('CREATE INDEX idx_products_barcode ON products(barcode)');
    await db.execute('CREATE INDEX idx_orders_status ON orders(status)');
    await db.execute('CREATE INDEX idx_orders_created_at ON orders(created_at)');
    await db.execute('CREATE INDEX idx_order_items_order_id ON order_items(order_id)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add image_path column to products table
      await db.execute('ALTER TABLE products ADD COLUMN image_path TEXT');
    }
    if (oldVersion < 3) {
      // Add qr_image blob column to orders table
      await db.execute('ALTER TABLE orders ADD COLUMN qr_image BLOB');
    }
    if (oldVersion < 4) {
      // Add options column to products and order_items
      await db.execute('ALTER TABLE products ADD COLUMN options TEXT');
      await db.execute('ALTER TABLE order_items ADD COLUMN options TEXT');
    }
  }

  // Product CRUD operations
  Future<int> createProduct(Product product) async {
    final db = await database;
    print('Creating product: ${product.name}');
    print('Product toMap: ${product.toMap()}');
    return await db.insert('products', product.toMap());
  }

  Future<List<Product>> getAllProducts() async {
    final db = await database;
    final result = await db.query('products', orderBy: 'name ASC');
    return result.map((map) => Product.fromMap(map)).toList();
  }

  Future<Product?> getProduct(int id) async {
    final db = await database;
    final result = await db.query(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isEmpty) return null;
    return Product.fromMap(result.first);
  }

  Future<List<Product>> searchProducts(String query) async {
    final db = await database;
    final result = await db.query(
      'products',
      where: 'name LIKE ? OR barcode LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'name ASC',
    );
    return result.map((map) => Product.fromMap(map)).toList();
  }

  Future<int> updateProduct(Product product) async {
    final db = await database;
    print('Updating product: ${product.name}');
    print('Product toMap: ${product.toMap()}');
    return await db.update(
      'products',
      product.copyWith(updatedAt: DateTime.now()).toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<int> deleteProduct(int id) async {
    final db = await database;
    return await db.delete(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Order CRUD operations
  Future<int> createOrder(Order order) async {
    final db = await database;
    final batch = db.batch();

    // Insert order
    final orderMap = order.toMap();
    // ensure qr_image stored as bytes or null
    if (order.qrImage != null) {
      orderMap['qr_image'] = order.qrImage;
    }
    final orderId = await db.insert('orders', orderMap);

    // Insert order items (ensure we don't pass an existing `id` to avoid UNIQUE constraint)
    for (var item in order.items) {
      final itemMap = item.copyWith(orderId: orderId).toMap();
      // Remove id if present so DB can assign a new autoincrement id
      itemMap.remove('id');
      batch.insert('order_items', itemMap);
    }

    await batch.commit(noResult: true);
    return orderId;
  }

  Future<List<Order>> getAllOrders({OrderStatus? status, DateTime? startDate, DateTime? endDate}) async {
    final db = await database;
    String? whereClause;
    List<dynamic>? whereArgs;

    final whereParts = <String>[];
    final args = <dynamic>[];

    if (status != null) {
      whereParts.add('status = ?');
      args.add(status.name);
    }

    if (startDate != null) {
      whereParts.add('created_at >= ?');
      args.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      whereParts.add('created_at <= ?');
      args.add(endDate.toIso8601String());
    }

    if (whereParts.isNotEmpty) {
      whereClause = whereParts.join(' AND ');
      whereArgs = args;
    }

    final result = await db.query(
      'orders',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
    );

    final orders = <Order>[];
    for (var map in result) {
      final orderId = map['id'] as int;
      final items = await getOrderItems(orderId);
      orders.add(Order.fromMap(map, items: items));
    }

    return orders;
  }

  Future<Order?> getOrder(int id) async {
    final db = await database;
    final result = await db.query(
      'orders',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isEmpty) return null;

    final items = await getOrderItems(id);
    return Order.fromMap(result.first, items: items);
  }

  Future<List<OrderItem>> getOrderItems(int orderId) async {
    final db = await database;
    final result = await db.query(
      'order_items',
      where: 'order_id = ?',
      whereArgs: [orderId],
    );
    return result.map((map) => OrderItem.fromMap(map)).toList();
  }

  Future<int> updateOrder(Order order) async {
    final db = await database;
    return await db.update(
      'orders',
      order.toMap(),
      where: 'id = ?',
      whereArgs: [order.id],
    );
  }

  Future<int> completeOrder(int orderId, String paymentMethod) async {
    final db = await database;
    return await db.update(
      'orders',
      {
        'status': OrderStatus.completed.name,
        'payment_method': paymentMethod,
        'completed_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  Future<int> deleteOrder(int id) async {
    final db = await database;
    // Order items will be deleted automatically due to CASCADE
    return await db.delete(
      'orders',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Finalize an existing pending order by updating its fields and replacing items.
  /// Runs in a transaction to ensure consistency.
  Future<void> finalizeOrder(int orderId, Order order) async {
    final db = await database;
    await db.transaction((txn) async {
      // Update order row
      await txn.update(
        'orders',
        {
          'status': OrderStatus.completed.name,
          'payment_method': order.paymentMethod,
          'total': order.total,
          'qr_image': order.qrImage,
          'completed_at': order.completedAt?.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [orderId],
      );

      // Delete existing items for this order
      await txn.delete(
        'order_items',
        where: 'order_id = ?',
        whereArgs: [orderId],
      );

      // Insert new items (without id)
      for (var item in order.items) {
        final itemMap = item.copyWith(orderId: orderId).toMap();
        itemMap.remove('id');
        await txn.insert('order_items', itemMap);
      }
    });
  }

  // Statistics
  Future<Map<String, dynamic>> getSalesStatistics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await database;
    String whereClause = 'status = ?';
    List<dynamic> whereArgs = [OrderStatus.completed.name];

    if (startDate != null) {
      whereClause += ' AND created_at >= ?';
      whereArgs.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      whereClause += ' AND created_at <= ?';
      whereArgs.add(endDate.toIso8601String());
    }

    final result = await db.rawQuery('''
      SELECT 
        COUNT(*) as total_orders,
        SUM(total) as total_revenue
      FROM orders
      WHERE $whereClause
    ''', whereArgs);

    if (result.isEmpty) {
      return {'total_orders': 0, 'total_revenue': 0.0};
    }

    return {
      'total_orders': result.first['total_orders'] as int? ?? 0,
      'total_revenue': (result.first['total_revenue'] as num?)?.toDouble() ?? 0.0,
    };
  }

  // Sales Detail by Product
  Future<List<Map<String, dynamic>>> getSalesDetailByProduct({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await database;
    String whereClause = 'o.status = ?';
    List<dynamic> whereArgs = [OrderStatus.completed.name];

    if (startDate != null) {
      whereClause += ' AND o.created_at >= ?';
      whereArgs.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      whereClause += ' AND o.created_at <= ?';
      whereArgs.add(endDate.toIso8601String());
    }

    final result = await db.rawQuery('''
      SELECT 
        oi.product_name,
        oi.product_id,
        oi.options,
        p.image_path as image_path,
        SUM(oi.quantity) as total_quantity,
        SUM(oi.subtotal) as total_revenue
      FROM order_items oi
      INNER JOIN orders o ON oi.order_id = o.id
      LEFT JOIN products p ON oi.product_id = p.id
      WHERE $whereClause
      GROUP BY oi.product_id, oi.product_name, oi.options
      ORDER BY total_revenue DESC
    ''', whereArgs);

    return result;
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}

