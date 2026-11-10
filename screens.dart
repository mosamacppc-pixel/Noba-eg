import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'config.dart';
import 'shopify.dart';
import 'state.dart';
import 'util.dart';

Widget img(String? url, {double? h, BoxFit fit = BoxFit.cover}) => url == null
    ? Container(height: h, color: const Color(0xFFE6F3ED), child: const Icon(Icons.spa, color: green))
    : Image.network(url, height: h, width: double.infinity, fit: fit,
        errorBuilder: (_, __, ___) => Container(height: h, color: const Color(0xFFE6F3ED)));

Future<void> openWhatsApp() => launchUrl(Uri.parse('https://wa.me/${Config.whatsapp}'), mode: LaunchMode.externalApplication);

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [HomeScreen(onShop: () => setState(() => tab = 1)), const CategoriesScreen(), const CartScreen(), const AccountScreen()];
    return ListenableBuilder(
      listenable: Listenable.merge([CartStore.i, GiftStore.i]),
      builder: (context, _) {
        final cart = CartStore.i;
        return Scaffold(
          body: Stack(children: [
            IndexedStack(index: tab, children: pages),
            if (GiftStore.i.gift != null)
              PositionedDirectional(
                start: 12,
                bottom: 12,
                child: ActionChip(
                  backgroundColor: green,
                  side: const BorderSide(color: gold, width: 2),
                  label: Text(tr(context, '🎁 هديتي', '🎁 My gift'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  onPressed: () => showGift(context, GiftStore.i.gift!, () => setState(() => tab = 1)),
                ),
              ),
          ]),
          bottomNavigationBar: NavigationBar(
            selectedIndex: tab,
            onDestinationSelected: (i) => setState(() => tab = i),
            destinations: [
              NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: tr(context, 'الرئيسية', 'Home')),
              NavigationDestination(icon: const Icon(Icons.grid_view), label: tr(context, 'الأقسام', 'Shop')),
              NavigationDestination(
                  icon: Badge(isLabelVisible: cart.count > 0, label: Text('${cart.count}'), child: const Icon(Icons.shopping_bag_outlined)),
                  label: tr(context, 'السلة', 'Cart')),
              NavigationDestination(icon: const Icon(Icons.person_outline), label: tr(context, 'حسابي', 'Account')),
            ],
          ),
        );
      },
    );
  }
}

void showGift(BuildContext context, Gift g, VoidCallback shop) {
  final ar = isAr(context);
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: gold, width: 3)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(ar ? g.titleAr : g.titleEn, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: green)),
          const SizedBox(height: 6),
          Text(ar ? g.descAr : g.descEn, textAlign: TextAlign.center),
          if (g.code.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF3F9F6), borderRadius: BorderRadius.circular(14), border: Border.all(color: gold, width: 2)),
              child: Text(g.code, textAlign: TextAlign.center, textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 3, color: greenD)),
            ),
            const SizedBox(height: 6),
            Text(tr(ctx, 'صالح لحد 30 نوفمبر 2026، على المنتجات خارج عروض Green Friday', 'Valid until Nov 30, 2026 on products outside Green Friday deals'),
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
          const SizedBox(height: 14),
          Row(children: [
            if (g.code.isNotEmpty)
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: g.code));
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(ctx, 'تم نسخ الكود', 'Code copied'))));
                  },
                  child: Text(tr(ctx, 'نسخ الكود', 'Copy code')),
                ),
              ),
            if (g.code.isNotEmpty) const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: () {
                  if (g.code.isNotEmpty) CartStore.i.applyCode(g.code);
                  Navigator.pop(ctx);
                  shop();
                },
                child: Text(tr(ctx, 'تسوّق الآن', 'Shop now')),
              ),
            ),
          ]),
        ]),
      ),
    ),
  );
}

class HomeScreen extends StatefulWidget {
  final VoidCallback onShop;
  const HomeScreen({super.key, required this.onShop});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 3400))..repeat();
  late Future<List<Map<String, dynamic>>> cols = Shopify.collections();
  late Future<List<Map<String, dynamic>>> best = Shopify.products(best: true);

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  Future<void> _open(BuildContext context) async {
    final g = await GiftStore.i.pick();
    if (context.mounted) showGift(context, g, widget.onShop);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async => setState(() {
          cols = Shopify.collections();
          best = Shopify.products(best: true);
        }),
        child: ListView(padding: const EdgeInsets.fromLTRB(14, 8, 14, 80), children: [
          const Center(child: Text('NOBA', textDirection: TextDirection.ltr, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 8, color: greenD))),
          const SizedBox(height: 10),
          ListenableBuilder(
            listenable: GiftStore.i,
            builder: (context, _) => Container(
              height: 170,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), gradient: const LinearGradient(colors: [green, greenD])),
              child: Stack(children: [
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tr(context, 'عروض Green Friday\nلحد 30 نوفمبر', 'Green Friday deals\nUntil Nov 30'),
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, height: 1.3)),
                    const SizedBox(height: 4),
                    if (GiftStore.i.canWin)
                      Text(tr(context, 'اضغط على صندوق الهدية 🎁', 'Tap a gift box 🎁'), style: const TextStyle(color: Colors.white70)),
                    const Spacer(),
                    FilledButton(style: FilledButton.styleFrom(backgroundColor: gold, foregroundColor: const Color(0xFF1D1608)), onPressed: widget.onShop, child: Text(tr(context, 'تسوّق', 'Shop'))),
                  ]),
                ),
                if (GiftStore.i.canWin)
                  for (var n = 0; n < 3; n++)
                    AnimatedBuilder(
                      animation: _ac,
                      builder: (context, _) {
                        final t = (_ac.value + n * .33) % 1.0;
                        return PositionedDirectional(
                          end: 24.0 + n * 62,
                          top: -50 + t * 200,
                          child: GestureDetector(onTap: () => _open(context), child: const _GiftBox()),
                        );
                      },
                    ),
              ]),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 96,
            child: FutureBuilder(
              future: cols,
              builder: (context, s) {
                final l = s.data ?? [];
                return ListView(scrollDirection: Axis.horizontal, children: [
                  for (final c in l)
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductList(title: c['title'], collection: c['handle']))),
                      child: SizedBox(
                        width: 76,
                        child: Column(children: [
                          ClipOval(child: SizedBox(width: 58, height: 58, child: img(c['image']?['url']))),
                          const SizedBox(height: 4),
                          Text(c['title'], maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ),
                ]);
              },
            ),
          ),
          Text(tr(context, 'الأكثر مبيعًا', 'Best sellers'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ProductGrid(future: best),
        ]),
      ),
    );
  }
}

class _GiftBox extends StatelessWidget {
  const _GiftBox();
  @override
  Widget build(BuildContext context) => Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: const LinearGradient(colors: [Color(0xFF2E9E74), greenD]),
          border: Border.all(color: gold, width: 2),
          boxShadow: const [BoxShadow(color: Color(0xAAC9A24A), blurRadius: 14)],
        ),
        child: const Icon(Icons.card_giftcard, color: gold),
      );
}

class ProductGrid extends StatelessWidget {
  final Future<List<Map<String, dynamic>>> future;
  const ProductGrid({super.key, required this.future});
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: future,
      builder: (context, s) {
        if (s.connectionState != ConnectionState.done) return const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()));
        if (s.hasError) return Padding(padding: const EdgeInsets.all(20), child: Text(tr(context, 'تعذّر تحميل المنتجات. اسحب للتحديث.', 'Could not load products. Pull to refresh.')));
        final l = s.data ?? [];
        if (l.isEmpty) return Padding(padding: const EdgeInsets.all(20), child: Text(tr(context, 'مفيش منتجات', 'No products')));
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: l.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: .68),
          itemBuilder: (_, i) {
            final p = l[i];
            final cmp = money(p['variants']['nodes'][0]['compareAtPrice']?['amount']);
            final price = money(p['priceRange']['minVariantPrice']['amount']);
            return InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductScreen(p: p))),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE9E4D6))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(width: double.infinity, child: img(p['featuredImage']?['url'])))),
                  const SizedBox(height: 6),
                  Text(p['title'], maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  Row(children: [
                    Text(egp(price, isAr(context)), style: const TextStyle(color: green, fontWeight: FontWeight.w800)),
                    if (cmp > price) ...[
                      const SizedBox(width: 6),
                      Text(egp(cmp, isAr(context)), style: const TextStyle(fontSize: 11, color: Colors.black45, decoration: TextDecoration.lineThrough)),
                    ],
                  ]),
                ]),
              ),
            );
          },
        );
      },
    );
  }
}

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});
  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final ctl = TextEditingController();
  late Future<List<Map<String, dynamic>>> cols = Shopify.collections();
  Future<List<Map<String, dynamic>>>? results;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(padding: const EdgeInsets.fromLTRB(14, 12, 14, 80), children: [
        TextField(
          controller: ctl,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: tr(context, 'ابحث عن منتج', 'Search products'),
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
          onSubmitted: (v) => setState(() => results = v.trim().isEmpty ? null : Shopify.products(search: v.trim())),
        ),
        const SizedBox(height: 14),
        if (results != null) ProductGrid(future: results!) else
          FutureBuilder(
            future: cols,
            builder: (context, s) {
              if (s.connectionState != ConnectionState.done) return const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()));
              final l = s.data ?? [];
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: l.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.1),
                itemBuilder: (_, i) {
                  final c = l[i];
                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductList(title: c['title'], collection: c['handle']))),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(fit: StackFit.expand, children: [
                        img(c['image']?['url']),
                        Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.center, colors: [Color(0xCC034B37), Colors.transparent]))),
                        Positioned(left: 10, right: 10, bottom: 8, child: Text(c['title'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
                      ]),
                    ),
                  );
                },
              );
            },
          ),
      ]),
    );
  }
}

class ProductList extends StatelessWidget {
  final String title, collection;
  const ProductList({super.key, required this.title, required this.collection});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: ListView(padding: const EdgeInsets.all(14), children: [ProductGrid(future: Shopify.products(collection: collection))]),
      );
}

class ProductScreen extends StatefulWidget {
  final Map<String, dynamic> p;
  const ProductScreen({super.key, required this.p});
  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  int v = 0;
  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final vars = (p['variants']['nodes'] as List);
    final sel = vars[v];
    final imgs = (p['images']['nodes'] as List).map((e) => e['url'] as String).toList();
    final ar = isAr(context);
    return Scaffold(
      appBar: AppBar(),
      body: ListView(padding: const EdgeInsets.fromLTRB(0, 0, 0, 100), children: [
        SizedBox(
          height: 360,
          child: PageView(children: [for (final u in imgs.isEmpty ? [p['featuredImage']?['url']] : imgs) img(u as String?, fit: BoxFit.cover)]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p['title'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(egp(sel['price']['amount'], ar), style: const TextStyle(fontSize: 22, color: green, fontWeight: FontWeight.w800)),
            if (vars.length > 1) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 8, children: [
                for (var i = 0; i < vars.length; i++)
                  ChoiceChip(label: Text(vars[i]['title']), selected: v == i, onSelected: vars[i]['availableForSale'] == true ? (_) => setState(() => v = i) : null),
              ]),
            ],
            const SizedBox(height: 14),
            Text('${p['description']}', style: const TextStyle(height: 1.7, color: Colors.black87)),
          ]),
        ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ListenableBuilder(
            listenable: CartStore.i,
            builder: (context, _) => FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: sel['availableForSale'] != true || CartStore.i.busy
                  ? null
                  : () async {
                      await CartStore.i.add(sel['id']);
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(context, 'اتضاف للسلة', 'Added to cart'))));
                    },
              child: Text(sel['availableForSale'] == true ? tr(context, 'أضف للسلة', 'Add to cart') : tr(context, 'غير متوفر', 'Sold out')),
            ),
          ),
        ),
      ),
    );
  }
}

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final ar = isAr(context);
    return SafeArea(
      child: ListenableBuilder(
        listenable: CartStore.i,
        builder: (context, _) {
          final c = CartStore.i;
          final left = (Config.freeShipAt - c.total).clamp(0, Config.freeShipAt).toDouble();
          if (c.lines.isEmpty) return Center(child: Text(tr(context, 'السلة فاضية', 'Your cart is empty')));
          return ListView(padding: const EdgeInsets.fromLTRB(14, 12, 14, 80), children: [
            Text(tr(context, 'السلة', 'Cart'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            for (final l in c.lines)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(width: 56, height: 56, child: img(l['merchandise']['image']?['url']))),
                title: Text(l['merchandise']['product']['title'], maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text(egp(l['cost']['totalAmount']['amount'], ar)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () => c.setQty(l['id'], (l['quantity'] as int) - 1)),
                  Text('${l['quantity']}'),
                  IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => c.setQty(l['id'], (l['quantity'] as int) + 1)),
                ]),
              ),
            const Divider(),
            Text(left > 0 ? tr(context, 'باقي ${left.round()} جنيه للشحن المجاني', '${left.round()} EGP left for free shipping') : tr(context, '🎉 شحنك مجاني', '🎉 Free shipping unlocked')),
            const SizedBox(height: 6),
            LinearProgressIndicator(value: (c.total / Config.freeShipAt).clamp(0, 1).toDouble(), minHeight: 8, borderRadius: BorderRadius.circular(6)),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tr(context, 'كود الخصم', 'Discount code')),
              trailing: Text(c.code ?? '—', textDirection: TextDirection.ltr, style: const TextStyle(fontWeight: FontWeight.w800)),
              onTap: () => _codeDialog(context),
            ),
            ListTile(contentPadding: EdgeInsets.zero, title: Text(tr(context, 'الإجمالي', 'Total'), style: const TextStyle(fontWeight: FontWeight.w800)), trailing: Text(egp(c.total, ar), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: green))),
            if (c.error != null) Text(c.error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            const SizedBox(height: 8),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: gold, foregroundColor: const Color(0xFF1D1608), minimumSize: const Size.fromHeight(52)),
              onPressed: c.checkoutUrl == null ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => WebPage(title: tr(context, 'إتمام الطلب', 'Checkout'), url: c.checkoutUrl!))),
              child: Text(tr(context, 'إتمام الطلب', 'Checkout')),
            ),
          ]);
        },
      ),
    );
  }

  void _codeDialog(BuildContext context) {
    final t = TextEditingController(text: GiftStore.i.gift?.code ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr(ctx, 'كود الخصم', 'Discount code')),
        content: TextField(controller: t, textDirection: TextDirection.ltr, textCapitalization: TextCapitalization.characters),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr(ctx, 'إلغاء', 'Cancel'))),
          FilledButton(onPressed: () { CartStore.i.applyCode(t.text.trim()); Navigator.pop(ctx); }, child: Text(tr(ctx, 'تطبيق', 'Apply'))),
        ],
      ),
    );
  }
}

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});
  @override
  Widget build(BuildContext context) {
    Widget row(IconData i, String t, VoidCallback f) => ListTile(leading: Icon(i, color: green), title: Text(t), trailing: const Icon(Icons.chevron_right), onTap: f);
    return SafeArea(
      child: ListView(padding: const EdgeInsets.fromLTRB(8, 12, 8, 80), children: [
        Padding(padding: const EdgeInsets.all(8), child: Text(tr(context, 'حسابي', 'Account'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
        row(Icons.login, tr(context, 'تسجيل الدخول وطلباتي', 'Sign in & my orders'), () => Navigator.push(context, MaterialPageRoute(builder: (_) => WebPage(title: tr(context, 'حسابي', 'Account'), url: 'https://${Config.shopDomain}/account')))),
        row(Icons.local_shipping_outlined, tr(context, 'سياسة الشحن', 'Shipping policy'), () => Navigator.push(context, MaterialPageRoute(builder: (_) => WebPage(title: tr(context, 'سياسة الشحن', 'Shipping policy'), url: 'https://${Config.shopDomain}/policies/shipping-policy')))),
        row(Icons.chat, tr(context, 'تواصل معنا على واتساب', 'Chat on WhatsApp'), openWhatsApp),
      ]),
    );
  }
}

class WebPage extends StatefulWidget {
  final String title, url;
  const WebPage({super.key, required this.title, required this.url});
  @override
  State<WebPage> createState() => _WebPageState();
}

class _WebPageState extends State<WebPage> {
  late final WebViewController c = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..loadRequest(Uri.parse(widget.url));
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(widget.title)), body: WebViewWidget(controller: c));
}
