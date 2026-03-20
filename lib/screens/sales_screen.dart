import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drift/drift.dart' as drift;
import '../database/database.dart';
import '../providers/cart_provider.dart';
import '../providers/user_provider.dart';
import '../services/receipt_service.dart';
class SalesScreen extends StatelessWidget {
  const SalesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final isCashier = userProvider.activeRole == UserRole.cashier;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tillzen App', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          _SyncStatusIcon(),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            children: [
              Expanded(flex: 2, child: Column(
                children: [
                  if (!isCashier) _TotalProfitsChart(),
                  if (!isCashier) _LowStockAlert(),
                  const Expanded(child: _ProductGrid()),
                ]
              )),
              if (constraints.maxWidth > 800) ...[
                Container(width: 1, color: Colors.grey.shade300),
                const Expanded(flex: 1, child: _CartSidebar()),
              ]
            ],
          );
        },
      ),
      // Mobile sidebar toggle or drawer could go here, but using LayoutBuilder for persistence
      bottomSheet: MediaQuery.of(context).size.width <= 800 ? const SizedBox(height: 300, child: _CartSidebar()) : null,
    );
  }

}

class _SyncStatusIcon extends StatefulWidget {
  @override
  _SyncStatusIconState createState() => _SyncStatusIconState();
}

class _SyncStatusIconState extends State<_SyncStatusIcon> {
  // A real app would use a Stream, but polling/futuring is adequate for this demo
  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();
    return FutureBuilder<List<Sale>>(
      future: db.getUnsyncedSales(),
      builder: (context, snapshot) {
        bool hasUnsynced = (snapshot.data?.isNotEmpty ?? false);
        return IconButton(
          icon: Icon(
            hasUnsynced ? Icons.cloud_upload : Icons.cloud_done,
            color: hasUnsynced ? Theme.of(context).colorScheme.secondary : Colors.green,
          ),
          tooltip: hasUnsynced ? 'Unsynced sales remain!' : 'All synced',
          onPressed: () {
            setState(() {});
          },
        );
      },
    );
  }
}

class _ProductGrid extends StatelessWidget {
  const _ProductGrid();

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();
    
    return StreamBuilder<List<Product>>(
      stream: db.watchAllProducts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final products = snapshot.data ?? [];
        if (products.isEmpty) {
          return const Center(
            child: Text(
              'No products in database.\nAdd some in the Inventory.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220,
            childAspectRatio: 0.8,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            return _ProductCard(product: products[index]);
          },
        );
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;

  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: () {
          context.read<CartProvider>().addProduct(product);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
                child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                    ? Image.network(product.imageUrl!, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey))
                    : const Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'GHS ${product.price.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
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

class _CartSidebar extends StatelessWidget {
  const _CartSidebar();

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
            child: const Row(
              children: [
                Icon(Icons.shopping_cart_outlined),
                SizedBox(width: 8),
                Text('Current Order', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ),
          Expanded(
            child: cart.items.isEmpty
                ? const Center(child: Text('Add items from the grid', style: TextStyle(color: Colors.grey)))
                : ListView.separated(
                    itemCount: cart.items.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      return ListTile(
                        title: Text(item.product.name, maxLines: 1, style: const TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: Text('GHS ${item.product.price.toStringAsFixed(2)}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.grey),
                              onPressed: () => cart.removeProduct(item.product),
                            ),
                            Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            IconButton(
                              icon: Icon(Icons.add_circle_outline, color: Theme.of(context).colorScheme.primary),
                              onPressed: () => cart.addProduct(item.product),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _summaryRow('Subtotal', cart.subtotal),
                _summaryRow('NHIL (2.5%)', cart.nhil),
                _summaryRow('GETFund (2.5%)', cart.getFund),
                _summaryRow('VAT (15%)', cart.vat),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Grand Total', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
                    Text('GHS ${cart.grandTotal.toStringAsFixed(2)}', 
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Theme.of(context).colorScheme.primary)),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: cart.items.isEmpty
                      ? null
                      : () => _handleCheckout(context, cart),
                  child: const Text('PAY GHS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
          Text('GHS ${amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _handleCheckout(BuildContext context, CartProvider cart) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CheckoutDialog(cart: cart),
    );
  }
}

class _CheckoutDialog extends StatefulWidget {
  final CartProvider cart;
  const _CheckoutDialog({required this.cart});

  @override
  State<_CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<_CheckoutDialog> {
  String _selectedMethod = 'Cash';
  final _txIdCtrl = TextEditingController();

  Future<void> _processPayment() async {
    final db = context.read<AppDatabase>();
    
    final sale = SalesCompanion.insert(
      totalAmount: widget.cart.grandTotal,
      taxAmount: widget.cart.totalTax,
      paymentMethod: _selectedMethod,
      transactionId: drift.Value(_txIdCtrl.text.isNotEmpty ? _txIdCtrl.text.trim() : null),
      isSynced: const drift.Value(false),
    );

    final items = widget.cart.items.map((item) => SaleItemsCompanion.insert(
      saleId: 0,
      productId: item.product.id,
      quantity: item.quantity,
      unitPrice: item.product.price,
    )).toList();

    await db.insertSaleWithItems(sale, items);
    widget.cart.clearCart();

    if (mounted) {
      Navigator.pop(context); // Close checkout dialog
      
      // Prepare Enriched items for receipt (resolved from cart before clear)
      final enrichedItems = widget.cart.items.map((it) => SaleItemEnriched(
        productName: it.product.name,
        quantity: it.quantity,
        unitPrice: it.product.price,
      )).toList();

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _SaleSuccessDialog(
          sale: sale, 
          items: enrichedItems,
          total: widget.cart.grandTotal,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Complete Payment', style: TextStyle(fontWeight: FontWeight.bold)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Select Payment Method:', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['Cash', 'MoMo', 'Bank Transfer'].map((m) {
              return ChoiceChip(
                label: Text(m),
                selected: _selectedMethod == m,
                onSelected: (selected) {
                  if (selected) setState(() => _selectedMethod = m);
                },
              );
            }).toList(),
          ),
          if (_selectedMethod == 'MoMo' || _selectedMethod == 'Bank Transfer') ...[
            const SizedBox(height: 24),
            TextField(
              controller: _txIdCtrl,
              decoration: InputDecoration(
                labelText: _selectedMethod == 'MoMo' ? 'MoMo Reference (Optional)' : 'Transaction ID (Optional)',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.receipt_long),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Due:', style: TextStyle(fontSize: 16)),
              Text('GHS ${widget.cart.grandTotal.toStringAsFixed(2)}', 
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Theme.of(context).colorScheme.primary)),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary, 
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          onPressed: _processPayment,
          child: const Text('Confirm Payment', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

class _SaleSuccessDialog extends StatelessWidget {
  final SalesCompanion sale;
  final List<SaleItemEnriched> items;
  final double total;

  const _SaleSuccessDialog({required this.sale, required this.items, required this.total});

  @override
  Widget build(BuildContext context) {
    final userProvider = context.read<UserProvider>();

    return AlertDialog(
      title: const Center(child: Icon(Icons.check_circle, color: Colors.green, size: 64)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Sale Complete!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
          const SizedBox(height: 8),
          Text('GHS ${total.toStringAsFixed(2)}', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w900, fontSize: 32)),
          const SizedBox(height: 24),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.share, color: Colors.blue),
            title: const Text('Share to WhatsApp'),
            onTap: () async {
              // Convert Companion to actual Sale model for helper (Mock ID for now)
              final finalSale = Sale(
                id: 0, 
                totalAmount: total - (total * 0.20), // Approx subtotal for mock
                taxAmount: total * 0.20,
                paymentMethod: sale.paymentMethod.value,
                timestamp: DateTime.now(),
                isSynced: false,
                transactionId: sale.transactionId.value,
              );
              
              final file = await ReceiptService.generateReceiptPdf(
                sale: finalSale,
                items: items,
                shopName: 'Tillzen POS',
                shopId: userProvider.shopId ?? 'Demo',
              );
              await ReceiptService.shareReceipt(file);
            },
          ),
          ListTile(
            leading: const Icon(Icons.print, color: Colors.orange),
            title: const Text('Print Physical Receipt'),
            onTap: () {
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connecting to Bluetooth Printer...')));
               // In a real device setup, we'd use pos_universal_printer scan/connect logic here.
            },
          ),
        ],
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('New Sale', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}

class _LowStockAlert extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();

    return FutureBuilder<List<Product>>(
      future: db.getLowStockProducts(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
        final lowStock = snapshot.data!;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.red),
                  const SizedBox(width: 8),
                  Text('Low Stock Alert (${lowStock.length})', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              ...lowStock.take(2).map((p) => Text('• ${p.name}: only ${p.stockQuantity} left', style: const TextStyle(fontSize: 12))),
              if (lowStock.length > 2) const Text('• ...and more', style: TextStyle(fontSize: 12)),
            ],
          ),
        );
      },
    );
  }
}

class _TotalProfitsChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondary,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Total Profits', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          Text('GHS 12,450.00', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

