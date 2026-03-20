import 'package:flutter/foundation.dart';
import '../database/database.dart';

class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});
}

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => _items;

  double get subtotal => _items.fold(
      0.0, (sum, item) => sum + (item.product.price * item.quantity));

  // Ghana 2026 Tax Engine (Act 1151)
  // Base taxable value is the subtotal.
  double get nhil => subtotal * 0.025;
  double get getFund => subtotal * 0.025;
  double get vat => subtotal * 0.150;
  
  // COVID-19 Levy (1%) abolished; it is intentionally excluded from calculations.

  double get totalTax => nhil + getFund + vat;
  double get grandTotal => subtotal + totalTax;

  void addProduct(Product product) {
    final existingIndex = _items.indexWhere((item) => item.product.id == product.id);
    if (existingIndex >= 0) {
      _items[existingIndex].quantity++;
    } else {
      _items.add(CartItem(product: product));
    }
    notifyListeners();
  }

  void removeProduct(Product product) {
    final existingIndex = _items.indexWhere((item) => item.product.id == product.id);
    if (existingIndex >= 0) {
      if (_items[existingIndex].quantity > 1) {
        _items[existingIndex].quantity--;
      } else {
        _items.removeAt(existingIndex);
      }
      notifyListeners();
    }
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }
}
