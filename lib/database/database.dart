import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

part 'database.g.dart';

class Products extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  RealColumn get price => real()();
  TextColumn get category => text().nullable()();
  IntColumn get stockQuantity => integer()();
  TextColumn get barcode => text().nullable()();
  TextColumn get imageUrl => text().nullable()();
}

class Sales extends Table {
  IntColumn get id => integer().autoIncrement()();
  RealColumn get totalAmount => real()();
  RealColumn get taxAmount => real()(); // VAT/NHIL/GETFund
  TextColumn get paymentMethod => text()(); // 'Cash', 'MoMo', or 'Card'
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  TextColumn get customerPhone => text().nullable()();
  TextColumn get transactionId => text().nullable()();
}

class SaleItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get saleId => integer().references(Sales, #id)();
  IntColumn get productId => integer()();
  IntColumn get quantity => integer()();
  RealColumn get unitPrice => real()();
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'tillzen_db.sqlite'));

    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }

    final cachebase = (await getTemporaryDirectory()).path;
    sqlite3.tempDirectory = cachebase;

    return NativeDatabase.createInBackground(file);
  });
}

@DriftDatabase(tables: [Products, Sales, SaleItems])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // Insert a Sale with its Items using a Transaction
  Future<void> insertSaleWithItems(
      SalesCompanion sale, List<SaleItemsCompanion> items) {
    return transaction(() async {
      final saleId = await into(sales).insert(sale);

      for (final item in items) {
        await into(saleItems).insert(item.copyWith(saleId: Value(saleId)));
      }
    });
  }

  // Get all sales that have not been synced yet
  Future<List<Sale>> getUnsyncedSales() {
    return (select(sales)..where((tbl) => tbl.isSynced.equals(false))).get();
  }

  // Update the sync status of a specific sale
  Future<int> updateSyncStatus(int saleId) {
    return (update(sales)..where((tbl) => tbl.id.equals(saleId)))
        .write(const SalesCompanion(isSynced: Value(true)));
  }

  // Insert standard Starter Inventory if empty
  Future<void> insertStarterInventory() async {
    final count = await customSelect('SELECT COUNT(*) AS c FROM products').getSingle();
    if (count.read<int>('c') == 0) {
      await batch((b) {
        b.insertAll(products, [
          ProductsCompanion.insert(name: 'Gino Tomato Paste', price: 4.50, stockQuantity: 24),
          ProductsCompanion.insert(name: 'Ideal Milk', price: 6.00, stockQuantity: 50),
          ProductsCompanion.insert(name: 'Geisha Mackerel', price: 12.00, stockQuantity: 15),
          ProductsCompanion.insert(name: 'Pepsodent 175g', price: 8.50, stockQuantity: 30),
        ]);
      });
    }
  }

  // Real-time stream of all products
  Stream<List<Product>> watchAllProducts() {
    return select(products).watch();
  }

  // --- BUSINESS INTELLIGENCE QUERIES ---

  // Get total sales per category
  Future<List<TypedResult>> getCategorySales() {
    final total = (saleItems.unitPrice * saleItems.quantity.cast<double>()).sum();
    return (selectOnly(saleItems).join([
      innerJoin(products, products.id.equalsExp(saleItems.productId)),
    ])
          ..addColumns([products.category, total])
          ..groupBy([products.category]))
        .get();
  }

  // Get daily reconciliation: totals per payment method for today
  Future<List<TypedResult>> getDailyReconciliation() {
    final total = (sales.totalAmount + sales.taxAmount).sum();
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    
    return (selectOnly(sales)
          ..where(sales.timestamp.isBiggerOrEqualValue(startOfDay))
          ..addColumns([sales.paymentMethod, total])
          ..groupBy([sales.paymentMethod]))
        .get();
  }

  // Get products with stock below threshold
  Future<List<Product>> getLowStockProducts({int threshold = 5}) {
    return (select(products)..where((tbl) => tbl.stockQuantity.isSmallerThanValue(threshold))).get();
  }
}
