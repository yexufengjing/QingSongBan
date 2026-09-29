import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'presentation/inventory_home_page.dart';
import 'presentation/inventory_issue_detail_page.dart';
import 'presentation/inventory_issue_form_page.dart';
import 'presentation/inventory_issues_page.dart';
import 'presentation/inventory_material_detail_page.dart';
import 'presentation/inventory_material_form_page.dart';
import 'presentation/inventory_materials_page.dart';
import 'presentation/inventory_receipt_detail_page.dart';
import 'presentation/inventory_receipt_form_page.dart';
import 'presentation/inventory_receipts_page.dart';
import 'presentation/inventory_replenishments_page.dart';
import 'presentation/inventory_stock_page.dart';
import 'presentation/inventory_stock_adjustment_page.dart';
import 'presentation/inventory_stocktake_detail_page.dart';
import 'presentation/inventory_stocktake_form_page.dart';
import 'presentation/inventory_stocktakes_page.dart';
import 'presentation/inventory_transactions_page.dart';
import 'presentation/inventory_warnings_page.dart';

/// Routes for the inventory feature. Keep common operations one tap from home.
List<RouteBase> inventoryRoutes() => [
  GoRoute(
    path: '/inventory',
    name: 'inventory-home',
    builder: (context, state) => const InventoryHomePage(),
    routes: [
      GoRoute(
        path: 'materials',
        name: 'inventory-materials',
        builder: (context, state) => const InventoryMaterialsPage(),
        routes: [
          GoRoute(
            path: 'new',
            name: 'inventory-material-new',
            builder: (context, state) => const InventoryMaterialFormPage(),
          ),
          GoRoute(
            path: ':materialId',
            name: 'inventory-material-detail',
            builder: (context, state) {
              final id = int.tryParse(state.pathParameters['materialId'] ?? '');
              return id == null
                  ? const _InvalidInventoryRoute()
                  : InventoryMaterialDetailPage(materialId: id);
            },
            routes: [
              GoRoute(
                path: 'edit',
                name: 'inventory-material-edit',
                builder: (context, state) {
                  final id = int.tryParse(
                    state.pathParameters['materialId'] ?? '',
                  );
                  return id == null
                      ? const _InvalidInventoryRoute()
                      : InventoryMaterialFormPage(materialId: id);
                },
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: 'receipts',
        name: 'inventory-receipts',
        builder: (context, state) => const InventoryReceiptsPage(),
        routes: [
          GoRoute(
            path: 'new',
            name: 'inventory-receipt-new',
            builder: (context, state) => const InventoryReceiptFormPage(),
          ),
          GoRoute(
            path: ':receiptId',
            name: 'inventory-receipt-detail',
            builder: (context, state) {
              final id = int.tryParse(state.pathParameters['receiptId'] ?? '');
              return id == null
                  ? const _InvalidInventoryRoute()
                  : InventoryReceiptDetailPage(receiptId: id);
            },
          ),
        ],
      ),
      GoRoute(
        path: 'issues',
        name: 'inventory-issues',
        builder: (context, state) => const InventoryIssuesPage(),
        routes: [
          GoRoute(
            path: 'new',
            name: 'inventory-issue-new',
            builder: (context, state) => const InventoryIssueFormPage(),
          ),
          GoRoute(
            path: ':issueId',
            name: 'inventory-issue-detail',
            builder: (context, state) {
              final id = int.tryParse(state.pathParameters['issueId'] ?? '');
              return id == null
                  ? const _InvalidInventoryRoute()
                  : InventoryIssueDetailPage(issueId: id);
            },
          ),
        ],
      ),
      GoRoute(
        path: 'stock',
        name: 'inventory-stock',
        builder: (context, state) => const InventoryStockPage(),
      ),
      GoRoute(
        path: 'stocktake',
        name: 'inventory-stocktakes',
        builder: (context, state) => const InventoryStocktakesPage(),
        routes: [
          GoRoute(
            path: 'new',
            name: 'inventory-stocktake-new',
            builder: (context, state) => const InventoryStocktakeFormPage(),
          ),
          GoRoute(
            path: ':stocktakeId',
            name: 'inventory-stocktake-detail',
            builder: (context, state) {
              final id = int.tryParse(
                state.pathParameters['stocktakeId'] ?? '',
              );
              return id == null
                  ? const _InvalidInventoryRoute()
                  : InventoryStocktakeDetailPage(stocktakeId: id);
            },
          ),
        ],
      ),
      GoRoute(
        path: 'warnings',
        name: 'inventory-warnings',
        builder: (context, state) => const InventoryWarningsPage(),
      ),
      GoRoute(
        path: 'replenishment',
        name: 'inventory-replenishments',
        builder: (context, state) => const InventoryReplenishmentsPage(),
      ),
      GoRoute(
        path: 'transactions',
        name: 'inventory-transactions',
        builder: (context, state) => const InventoryTransactionsPage(),
      ),
      GoRoute(
        path: 'adjust',
        name: 'inventory-adjust',
        builder: (context, state) {
          final id = int.tryParse(
            state.uri.queryParameters['materialId'] ?? '',
          );
          return id == null
              ? const _InvalidInventoryRoute()
              : InventoryStockAdjustmentPage(materialId: id);
        },
      ),
    ],
  ),
];

class _InvalidInventoryRoute extends StatelessWidget {
  const _InvalidInventoryRoute();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('无效的库存记录编号')));
}
