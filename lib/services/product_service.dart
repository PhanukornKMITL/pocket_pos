import '../models/product.dart';
import 'database_service.dart';

class ProductService {
  final DatabaseService _db = DatabaseService.instance;

  Future<List<Product>> getAllProducts() async {
    return await _db.getAllProducts();
  }

  Future<Product?> getProduct(int id) async {
    return await _db.getProduct(id);
  }

  Future<List<Product>> searchProducts(String query) async {
    if (query.isEmpty) return await getAllProducts();
    return await _db.searchProducts(query);
  }

  Future<int> createProduct(Product product) async {
    return await _db.createProduct(product);
  }

  Future<int> updateProduct(Product product) async {
    return await _db.updateProduct(product);
  }

  Future<int> deleteProduct(int id) async {
    return await _db.deleteProduct(id);
  }
}

