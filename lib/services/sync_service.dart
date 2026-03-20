import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../database/database.dart';

class SyncService {
  final AppDatabase db;
  final String shopId;
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isSyncing = false;

  SyncService({required this.db, required this.shopId}) {
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none)) {
        syncUnsyncedSales();
      }
    });
  }

  void dispose() {
    _subscription?.cancel();
  }

  Future<void> syncUnsyncedSales() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final unsyncedSales = await db.getUnsyncedSales();
      if (unsyncedSales.isEmpty) {
        _isSyncing = false;
        return;
      }

      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      
      final salesRef = firestore.collection('shops').doc(shopId).collection('sales');

      for (final sale in unsyncedSales) {
        final docRef = salesRef.doc(sale.id.toString());
        batch.set(docRef, {
          'id': sale.id,
          'totalAmount': sale.totalAmount,
          'taxAmount': sale.taxAmount,
          'paymentMethod': sale.paymentMethod,
          'transactionId': sale.transactionId,
          'timestamp': sale.timestamp.toIso8601String(),
          'customerPhone': sale.customerPhone,
        });
      }

      // Commit the batch to Firestore
      await batch.commit();

      // Only update local SQLite isSynced flag AFTER successful commit
      for (final sale in unsyncedSales) {
        await db.updateSyncStatus(sale.id);
      }
      
      debugPrint('Sync successful! Synced ${unsyncedSales.length} items.');
    } catch (e) {
      debugPrint('Sync failed: $e');
    } finally {
      _isSyncing = false;
    }
  }
}
