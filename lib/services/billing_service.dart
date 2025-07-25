import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sage_wallet_reborn/core/di/injector.dart';
import 'package:sage_wallet_reborn/providers/pro_status_provider.dart';
import 'package:sage_wallet_reborn/services/api_client.dart';

abstract class BillingService {
  Future<void> init();
  Future<void> loadProducts();
  Future<void> buyProSubscription();
  Future<void> restorePurchases();
  void dispose();
}

class AppStoreBillingService implements BillingService {
  static const String _proSubscriptionId = 'pro_monthly_sub';

  final InAppPurchase _iap = InAppPurchase.instance;
  final ApiClient _apiClient = getIt<ApiClient>();
  late StreamSubscription<List<PurchaseDetails>> _purchaseStream;
  
  List<ProductDetails> _products = [];
  List<ProductDetails> get products => _products;
  
  final ProStatusProvider _proStatusProvider = getIt<ProStatusProvider>();

  @override
  Future<void> init() async {
    final bool available = await _iap.isAvailable();
    if (!available) {
      debugPrint("Billing service is not available.");
      return;
    }

    _purchaseStream = _iap.purchaseStream.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _purchaseStream.cancel();
    }, onError: (error) {
      debugPrint("Billing stream error: $error");
    });

    await loadProducts();
  }

  @override
  Future<void> loadProducts() async {
    try {
      final ProductDetailsResponse response = await _iap.queryProductDetails({_proSubscriptionId});
      if (response.notFoundIDs.isNotEmpty) {
        debugPrint("Products not found: ${response.notFoundIDs}");
        _products = [];
        return;
      }
      _products = response.productDetails;
    } catch (e) {
      debugPrint("Error loading products: $e");
    }
  }

  @override
  Future<void> buyProSubscription() async {
    if (_products.isEmpty) {
      debugPrint("No products to buy. Trying to load them again...");
      await loadProducts();
      if (_products.isEmpty) {
        return;
      }
    }
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: _products.first);
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  @override
  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.purchased || purchaseDetails.status == PurchaseStatus.restored) {
        _handleAndVerifyPurchase(purchaseDetails);
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        debugPrint("Purchase error: ${purchaseDetails.error}");
      }
    }
  }

  Future<void> _handleAndVerifyPurchase(PurchaseDetails purchaseDetails) async {
    final bool isValid = await _verifyPurchaseOnBackend(purchaseDetails);

    if (isValid) {
      await _iap.completePurchase(purchaseDetails);
      _proStatusProvider.setProStatus(true);
      debugPrint("SUCCESS: Purchase completed and verified.");
    } else {
      debugPrint("ERROR: Backend verification failed. Purchase not completed.");
    }
  }

  Future<bool> _verifyPurchaseOnBackend(PurchaseDetails purchaseDetails) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final packageName = packageInfo.packageName;

      await _apiClient.post(
        '/billing/verify-purchase',
        body: {
          'purchase_token': purchaseDetails.verificationData.serverVerificationData,
          'subscription_id': purchaseDetails.productID,
          'package_name': packageName,
        },
      );
      return true;
    } catch (e) {
      debugPrint("API Client Error during verification: $e");
      return false;
    }
  }

  @override
  void dispose() {
    _purchaseStream.cancel();
  }
}

class FakeBillingService implements BillingService {
  final ProStatusProvider _proStatusProvider = getIt<ProStatusProvider>();

  @override
  Future<void> init() async {
    debugPrint("FakeBillingService initialized.");
  }

  @override
  Future<void> loadProducts() async {
     debugPrint("FakeBillingService: Loading fake products.");
  }

  @override
  Future<void> buyProSubscription() async {
    debugPrint("FakeBillingService: Simulating Pro subscription purchase...");
    await Future.delayed(const Duration(seconds: 2));
    await _proStatusProvider.setProStatus(true);
    debugPrint("FakeBillingService: Pro status activated.");
  }

  @override
  Future<void> restorePurchases() async {
    debugPrint("FakeBillingService: Simulating purchase restore...");
    await Future.delayed(const Duration(seconds: 1));
    await _proStatusProvider.setProStatus(true);
  }

  @override
  void dispose() {
    debugPrint("FakeBillingService disposed.");
  }
}