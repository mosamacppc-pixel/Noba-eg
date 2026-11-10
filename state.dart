import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';
import 'shopify.dart';

double money(dynamic v) => double.tryParse('${v ?? 0}') ?? 0;
String egp(dynamic v, bool ar) => 'LE ${money(v).toStringAsFixed(2)} EGP';

class CartStore extends ChangeNotifier {
  static final i = CartStore._();
  CartStore._();
  Map<String, dynamic>? cart;
  bool busy = false;
  String? error;

  int get count => (cart?['totalQuantity'] as int?) ?? 0;
  double get total => money(cart?['cost']?['totalAmount']?['amount']);
  List get lines => (cart?['lines']?['nodes'] as List?) ?? [];
  String? get checkoutUrl => cart?['checkoutUrl'] as String?;
  String? get code {
    final l = (cart?['discountCodes'] as List?) ?? [];
    return l.isEmpty ? null : l.first['code'] as String?;
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final id = p.getString('cart_id');
    if (id == null) return;
    try {
      cart = await Shopify.cart(id);
      if (cart == null) await p.remove('cart_id');
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _do(Future<Map<String, dynamic>> Function() f) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      cart = await f();
      final p = await SharedPreferences.getInstance();
      await p.setString('cart_id', cart!['id'] as String);
    } catch (e) {
      error = '$e';
    }
    busy = false;
    notifyListeners();
  }

  Future<void> add(String variantId, [int q = 1]) => _do(() => cart == null
      ? Shopify.cartCreate(variantId, q)
      : Shopify.cartAdd(cart!['id'], variantId, q));
  Future<void> setQty(String lineId, int q) => _do(() => q <= 0
      ? Shopify.cartRemove(cart!['id'], lineId)
      : Shopify.cartSetQty(cart!['id'], lineId, q));
  Future<void> applyCode(String code) async {
    if (cart == null) return; // applied later when the first item is added
    await _do(() => Shopify.cartCodes(cart!['id'], [code]));
  }
}

class Gift {
  final String code, titleAr, titleEn, descAr, descEn;
  final int weight;
  const Gift(this.code, this.titleAr, this.titleEn, this.descAr, this.descEn, this.weight);
}

const gifts = [
  Gift('GREEN5', 'مبروك! 🎉', 'Congrats! 🎉', 'كسبت خصم 5%', 'You won 5% off', 28),
  Gift('GREEN10', 'مبروك! 🎉', 'Congrats! 🎉', 'كسبت خصم 10%', 'You won 10% off', 22),
  Gift('GREEN15', 'مبروك! 🎉', 'Congrats! 🎉', 'كسبت خصم 15%', 'You won 15% off', 10),
  Gift('GREEN50', 'مبروك! 💚', 'Congrats! 💚', 'خصم 50 جنيه على طلبات +500', '50 EGP off orders 500+', 16),
  Gift('GREENSHIP', 'مبروك! 🚚', 'Congrats! 🚚', 'شحن مجاني على طلبات +1000', 'Free shipping on orders 1000+', 14),
  Gift('', 'شكرًا لك 💚', 'Thank you 💚', 'مفيش هدية المرة دي، تسوّق من عروض Green Friday', 'No gift this time. Check the Green Friday deals', 10),
];

class GiftStore extends ChangeNotifier {
  static final i = GiftStore._();
  GiftStore._();
  static const _k = 'noba_gf_gift_v1';
  int won = -1;

  bool get live => DateTime.now().toUtc().isBefore(Config.giftEnds);
  bool get canWin => live && won < 0;
  Gift? get gift => won < 0 ? null : gifts[won];

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    won = p.getInt(_k) ?? -1;
    notifyListeners();
  }

  Future<Gift> pick() async {
    final total = gifts.fold<int>(0, (a, g) => a + g.weight);
    var r = Random().nextInt(total);
    var idx = 0;
    for (var n = 0; n < gifts.length; n++) {
      if (r < gifts[n].weight) {
        idx = n;
        break;
      }
      r -= gifts[n].weight;
    }
    won = idx;
    final p = await SharedPreferences.getInstance();
    await p.setInt(_k, idx);
    notifyListeners();
    return gifts[idx];
  }
}
