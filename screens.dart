import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'config.dart';
import 'shopify.dart';
import 'state.dart';
import 'util.dart';

// ───────────────────────── helpers ─────────────────────────

const logoUrl = 'https://nobaeg.com/cdn/shop/files/main_logo_2-01.png?v=1756291803';
const slideUrls = [
  'https://nobaeg.com/cdn/shop/files/318014.jpg?v=1793815764',
  'https://nobaeg.com/cdn/shop/files/318022.jpg?v=1793816135',
  'https://nobaeg.com/cdn/shop/files/318023.jpg?v=1793816278',
];
const catHandles = ['skin-care', 'hair-care', 'makeup', 'fragrance', 'personal-care', 'nail-care', 'men-care', 'kids-care-zone'];
const homeCatHandles = ['hair-care', 'kids-care-zone', 'nail-care', 'makeup', 'men-care', 'skin-care', 'fragrance'];
const brandHandles = ['beesline', 'bio-soft', 'capixy', 'clary', 'cybele', 'eva', 'hepta', 'johnson', 'karseell', 'note', 'palette-1', 'perla-pink', 'rose-gold', 'seropipe', 'tresemme', 'twist-go', 'vaseline', 'zak', 'rushbrush'];
const menuBrandHandles = ['cybele', 'vatika', 'bio-soft', 'sunsilk', 'dove', 'l-oreal-paris', 'eva', 'dodge', 'sandra', 'note'];

String cdn(String url, int w) => url.contains('?') ? '$url&width=$w' : '$url?width=$w';

Widget img(String? url, {BoxFit fit = BoxFit.cover, int w = 600}) {
  final ph = Container(color: soft, child: const Center(child: Icon(Icons.spa_outlined, color: Colors.black26)));
  if (url == null) return ph;
  return Image.network(cdn(url, w), width: double.infinity, height: double.infinity, fit: fit, errorBuilder: (_, __, ___) => ph, loadingBuilder: (c, child, p) => p == null ? child : Container(color: soft));
}

Future<void> openWhatsApp([String? text]) => launchUrl(
    Uri.parse('https://wa.me/${Config.whatsapp}?text=${Uri.encodeComponent(text ?? 'مرحبا، أريد الاستفسار عن منتجات نوبا')}'),
    mode: LaunchMode.externalApplication);

void goWeb(BuildContext c, String title, String path) {
  final ar = isAr(c);
  final url = path.startsWith('http') ? path : 'https://${Config.shopDomain}${!ar && !path.startsWith('/account') ? '/en' : ''}$path';
  Navigator.push(c, MaterialPageRoute(builder: (_) => WebPage(title: title, url: url)));
}

void goCollection(BuildContext c, String handle, [String? title]) =>
    Navigator.push(c, MaterialPageRoute(builder: (_) => CollectionScreen(handle: handle, title: title)));
void goProduct(BuildContext c, Map<String, dynamic> p) => Navigator.push(c, MaterialPageRoute(builder: (_) => ProductScreen(p: p)));
void goCart(BuildContext c) => Navigator.push(c, MaterialPageRoute(builder: (_) => const CartScreen()));
void goSearch(BuildContext c) => Navigator.push(c, MaterialPageRoute(builder: (_) => const SearchScreen()));

Widget loading() => const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator(color: ink, strokeWidth: 2)));

// ───────────────────────── page frame (announcement bar + header + drawer) ─────────────────────────

class StorePage extends StatelessWidget {
  final Widget body;
  final bool isHome;
  final String? waText;
  const StorePage({super.key, required this.body, this.isHome = false, this.waText});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final canPop = Navigator.canPop(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        drawer: const NavDrawer(),
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(top + 34 + 56),
          child: Column(children: [
            Container(color: ink, padding: EdgeInsets.only(top: top), height: top + 34, child: const AnnounceBar()),
            Container(
              height: 56,
              decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: line))),
              child: Row(children: [
                (canPop && !isHome)
                    ? const BackButton()
                    : Builder(builder: (c) => IconButton(icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(c).openDrawer())),
                Expanded(
                  child: Center(
                    child: GestureDetector(
                      onTap: () => Navigator.popUntil(context, (r) => r.isFirst),
                      child: Image.network(cdn(logoUrl, 400), height: 32, errorBuilder: (_, __, ___) => const Text('NOBA', style: TextStyle(fontSize: 22, letterSpacing: 6, fontWeight: FontWeight.w700))),
                    ),
                  ),
                ),
                IconButton(icon: const Icon(Icons.search), onPressed: () => goSearch(context)),
                IconButton(icon: const Icon(Icons.person_outline), onPressed: () => goWeb(context, tr(context, 'حسابي', 'Account'), '/account')),
                ListenableBuilder(
                  listenable: CartStore.i,
                  builder: (context, _) => IconButton(
                    icon: Badge(isLabelVisible: CartStore.i.count > 0, label: Text('${CartStore.i.count}'), backgroundColor: ink, child: const Icon(Icons.shopping_bag_outlined)),
                    onPressed: () => goCart(context),
                  ),
                ),
              ]),
            ),
          ]),
        ),
        body: MediaQuery.removePadding(
          context: context,
          removeTop: true,
          child: Stack(children: [
          body,
          PositionedDirectional(
            end: 14,
            bottom: 14,
            child: FloatingActionButton.small(
              heroTag: null,
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
              onPressed: () => openWhatsApp(waText),
              child: const Icon(Icons.chat),
            ),
          ),
          ListenableBuilder(
            listenable: GiftStore.i,
            builder: (context, _) => GiftStore.i.gift == null
                ? const SizedBox.shrink()
                : PositionedDirectional(
                    start: 14,
                    bottom: 14,
                    child: ActionChip(
                      backgroundColor: green,
                      side: const BorderSide(color: gold, width: 2),
                      shape: const StadiumBorder(),
                      label: Text(tr(context, '🎁 هديتي', '🎁 My gift'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      onPressed: () => showGift(context, GiftStore.i.gift!, () {}),
                    ),
                  ),
          ),
        ]),
        ),
      ),
    );
  }
}

class AnnounceBar extends StatefulWidget {
  const AnnounceBar({super.key});
  @override
  State<AnnounceBar> createState() => _AnnounceBarState();
}

class _AnnounceBarState extends State<AnnounceBar> {
  int i = 0;
  Timer? t;
  @override
  void initState() {
    super.initState();
    t = Timer.periodic(const Duration(seconds: 4), (_) => setState(() => i = (i + 1) % 3));
  }

  @override
  void dispose() {
    t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final msgs = [
      tr(context, 'احصل الآن على شحن مجاني للطلبات الأكثر من 700 جنيه مصري', 'Get free shipping on orders over 700 EGP'),
      tr(context, 'اهلا بكم فى نوبا لمستحضرات التجميل و العناية الشخصية', 'Welcome to NOBA Cosmetics & Personal Care'),
      tr(context, 'تسوق الآن بـ 375 جنيه واحصل على خصم إضافي 5%', 'Shop now from 375 EGP and get an extra 5% off'),
    ];
    return InkWell(
      onTap: i == 2 ? () => goCollection(context, 'green-friday') : null,
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(msgs[i], key: ValueKey(i), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white, fontSize: 12.5, decoration: i == 2 ? TextDecoration.underline : null, decorationColor: Colors.white)),
        ),
      ),
    );
  }
}

class NavDrawer extends StatelessWidget {
  const NavDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final ar = isAr(context);
    final nav = Navigator.of(context);
    void close(void Function(BuildContext) f) {
      nav.pop();
      f(nav.context);
    }

    return Drawer(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: Shopify.collectionsByHandles([...catHandles, ...menuBrandHandles]),
          builder: (context, s) {
            final titles = {for (final c in (s.data ?? [])) c['handle'] as String: c['title'] as String};
            Widget sub(String h) => ListTile(
                  dense: true,
                  contentPadding: const EdgeInsetsDirectional.only(start: 32, end: 16),
                  title: Text(titles[h] ?? h),
                  onTap: () => close((c) => goCollection(c, h, titles[h])),
                );
            Widget item(String t, VoidCallback f) => ListTile(title: Text(t, style: const TextStyle(fontWeight: FontWeight.w600)), onTap: f);
            return ListView(children: [
              Padding(padding: const EdgeInsets.all(18), child: Image.network(cdn(logoUrl, 400), height: 36, alignment: AlignmentDirectional.centerStart, errorBuilder: (_, __, ___) => const Text('NOBA', style: TextStyle(fontSize: 22, letterSpacing: 6)))),
              const Divider(height: 1),
              item(tr(context, 'الرئيسية', 'Home'), () => nav.popUntil((r) => r.isFirst)),
              ExpansionTile(
                shape: const Border(),
                collapsedShape: const Border(),
                title: Text(tr(context, 'التصنيفات', 'Categories'), style: const TextStyle(fontWeight: FontWeight.w600)),
                children: [for (final h in catHandles) sub(h)],
              ),
              item(tr(context, 'عن نوبا', 'About NOBA'), () => close((c) => goWeb(c, tr(c, 'عن نوبا', 'About NOBA'), '/pages/about-noba'))),
              ExpansionTile(
                shape: const Border(),
                collapsedShape: const Border(),
                title: Text(tr(context, 'الماركات', 'Brands'), style: const TextStyle(fontWeight: FontWeight.w600)),
                children: [for (final h in menuBrandHandles) sub(h)],
              ),
              item(tr(context, 'عروض خاصة', 'Special offers'), () => close((c) => goCollection(c, 'green-friday'))),
              item(tr(context, 'الأكثر مبيعًا', 'Best sellers'), () => close((c) => goCollection(c, 'besr-seller'))),
              item(tr(context, 'وصل حديثًا', 'New arrivals'), () => close((c) => goCollection(c, 'new-arrival'))),
              item(tr(context, 'تواصل معنا', 'Contact us'), () => close((c) => goWeb(c, tr(c, 'تواصل معنا', 'Contact us'), '/pages/contact'))),
              item(tr(context, 'مجلة الجمال', 'Beauty magazine'), () => close((c) => goWeb(c, tr(c, 'مجلة الجمال', 'Beauty magazine'), '/blogs/news'))),
              item(tr(context, 'الأسئلة الشائعة', 'FAQ'), () => close((c) => goWeb(c, tr(c, 'الأسئلة الشائعة', 'FAQ'), '/pages/faq'))),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.language),
                title: Text(ar ? 'English' : 'العربية'),
                onTap: () async {
                  nav.popUntil((r) => r.isFirst);
                  final code = ar ? 'en' : 'ar';
                  try {
                    (await SharedPreferences.getInstance()).setString('lang', code);
                  } catch (_) {}
                  appLocale.value = Locale(code);
                },
              ),
            ]);
          },
        ),
      ),
    );
  }
}

// ───────────────────────── gift feature ─────────────────────────

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

class GiftBanner extends StatefulWidget {
  const GiftBanner({super.key});
  @override
  State<GiftBanner> createState() => _GiftBannerState();
}

class _GiftBannerState extends State<GiftBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 3400))..repeat();
  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  Future<void> _open(BuildContext context) async {
    final g = await GiftStore.i.pick();
    if (context.mounted) showGift(context, g, () {});
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: GiftStore.i,
      builder: (context, _) {
        if (!GiftStore.i.live) return const SizedBox.shrink();
        return Container(
          height: 150,
          margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          clipBehavior: Clip.antiAlias,
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [green, greenD])),
          child: Stack(children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr(context, 'عروض Green Friday\nلحد 30 نوفمبر', 'Green Friday deals\nUntil Nov 30'), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, height: 1.3)),
                const SizedBox(height: 4),
                Text(GiftStore.i.canWin ? tr(context, 'اضغط على صندوق الهدية 🎁', 'Tap a gift box 🎁') : tr(context, 'هديتك محفوظة 🎁', 'Your gift is saved 🎁'), style: const TextStyle(color: Colors.white70)),
                const Spacer(),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: gold, foregroundColor: const Color(0xFF1D1608), minimumSize: const Size(0, 36)),
                  onPressed: GiftStore.i.canWin ? null : () => showGift(context, GiftStore.i.gift!, () {}),
                  child: Text(tr(context, 'هديتي', 'My gift')),
                ),
              ]),
            ),
            if (GiftStore.i.canWin)
              for (var n = 0; n < 3; n++)
                AnimatedBuilder(
                  animation: _ac,
                  builder: (context, _) {
                    final t = (_ac.value + n * .33) % 1.0;
                    return PositionedDirectional(end: 20.0 + n * 62, top: -50 + t * 190, child: GestureDetector(onTap: () => _open(context), child: const _GiftBox()));
                  },
                ),
          ]),
        );
      },
    );
  }
}

// ───────────────────────── product card & lists ─────────────────────────

class ProductCard extends StatelessWidget {
  final Map<String, dynamic> p;
  const ProductCard({super.key, required this.p});

  @override
  Widget build(BuildContext context) {
    final ar = isAr(context);
    final vars = (p['variants']['nodes'] as List);
    final price = money(p['priceRange']['minVariantPrice']['amount']);
    final cmp = vars.isEmpty ? 0.0 : money(vars.first['compareAtPrice']?['amount']);
    final sold = p['availableForSale'] != true;
    final single = vars.length == 1;
    final vendor = (p['vendor'] ?? '') as String;
    return InkWell(
      onTap: () => goProduct(context, p),
      child: Container(
        decoration: BoxDecoration(border: Border.all(color: line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AspectRatio(
            aspectRatio: 1,
            child: Stack(fit: StackFit.expand, children: [
              img(p['featuredImage']?['url'], w: 500),
              if (cmp > price && !sold)
                PositionedDirectional(top: 6, start: 6, child: Container(color: ink, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), child: Text(tr(context, 'خصم', 'Sale'), style: const TextStyle(color: Colors.white, fontSize: 11)))),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (vendor.isNotEmpty) Text(vendor, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.black54)),
              const SizedBox(height: 2),
              Text(p['title'], maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, height: 1.25)),
            ]),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, children: [
              Text(egp(price, ar), textDirection: TextDirection.ltr, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cmp > price ? const Color(0xFFB3261E) : ink)),
              if (cmp > price) Text(egp(cmp, ar), textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 11, color: Colors.black45, decoration: TextDecoration.lineThrough)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38), padding: EdgeInsets.zero),
                onPressed: sold
                    ? null
                    : single
                        ? () async {
                            await CartStore.i.add(vars.first['id']);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(tr(context, 'تمت الإضافة إلى السلة', 'Added to cart')),
                                action: SnackBarAction(label: tr(context, 'عرض السلة', 'View cart'), onPressed: () => goCart(context)),
                              ));
                            }
                          }
                        : () => goProduct(context, p),
                child: Text(sold ? tr(context, 'نفذ', 'Sold out') : single ? tr(context, 'أضف إلى السلة', 'Add to cart') : tr(context, 'اختر الخيارات', 'Choose options'), style: const TextStyle(fontSize: 12.5)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class ProductGridList extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  const ProductGridList({super.key, required this.items});
  @override
  Widget build(BuildContext context) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, mainAxisExtent: 360),
        itemBuilder: (_, i) => ProductCard(p: items[i]),
      );
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? handle;
  final String? sub;
  const SectionHeader(this.title, {super.key, this.handle, this.sub});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 28, 14, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700))),
            if (handle != null)
              TextButton(onPressed: () => goCollection(context, handle!), child: Text(tr(context, 'عرض الكل', 'View all'), style: const TextStyle(color: ink, decoration: TextDecoration.underline))),
          ]),
          if (sub != null) Text(sub!, style: const TextStyle(color: Colors.black54, height: 1.4)),
        ]),
      );
}

class ProductRow extends StatefulWidget {
  final String title, handle;
  final Future<ProdPage> future;
  final bool showDesc;
  const ProductRow({super.key, required this.title, required this.handle, required this.future, this.showDesc = false});
  @override
  State<ProductRow> createState() => _ProductRowState();
}

class _ProductRowState extends State<ProductRow> {
  final ctl = ScrollController();
  @override
  void dispose() {
    ctl.dispose();
    super.dispose();
  }

  void _scroll(int dir) {
    if (!ctl.hasClients) return;
    final to = (ctl.offset + dir * 376).clamp(0.0, ctl.position.maxScrollExtent).toDouble();
    ctl.animateTo(to, duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    final ar = isAr(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionHeader(widget.title, handle: widget.handle),
      SizedBox(
        height: 360,
        child: FutureBuilder<ProdPage>(
          future: widget.future,
          builder: (context, s) {
            if (s.connectionState != ConnectionState.done) return loading();
            if (s.hasError) return Center(child: Text(tr(context, 'تعذّر تحميل المنتجات', 'Could not load products')));
            final l = s.data!.nodes;
            return Stack(children: [
              ListView.separated(
                controller: ctl,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: l.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) => SizedBox(width: 178, child: ProductCard(p: l[i])),
              ),
              PositionedDirectional(start: 2, top: 120, child: _arrow(ar ? Icons.chevron_right : Icons.chevron_left, () => _scroll(ar ? 1 : -1))),
              PositionedDirectional(end: 2, top: 120, child: _arrow(ar ? Icons.chevron_left : Icons.chevron_right, () => _scroll(ar ? -1 : 1))),
            ]);
          },
        ),
      ),
      if (widget.showDesc)
        FutureBuilder<ProdPage>(
          future: widget.future,
          builder: (context, s) {
            final d = s.data?.description ?? '';
            return d.isEmpty ? const SizedBox.shrink() : Padding(padding: const EdgeInsets.fromLTRB(14, 14, 14, 0), child: ExpandText(d));
          },
        ),
    ]);
  }
}

class ExpandText extends StatefulWidget {
  final String text;
  const ExpandText(this.text, {super.key});
  @override
  State<ExpandText> createState() => _ExpandTextState();
}

class _ExpandTextState extends State<ExpandText> {
  bool open = false;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.text, maxLines: open ? null : 4, overflow: open ? TextOverflow.visible : TextOverflow.ellipsis, style: const TextStyle(height: 1.7, color: Colors.black87)),
        TextButton(onPressed: () => setState(() => open = !open), child: Text(open ? tr(context, 'عرض أقل', 'Show less') : tr(context, 'عرض المزيد', 'Show more'), style: const TextStyle(color: ink))),
      ]);
}

// ───────────────────────── home ─────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _pages = <String, Future<ProdPage>>{};
  Future<ProdPage> pg(String h) => _pages.putIfAbsent(h, () => Shopify.collectionPage(h, n: 12));
  late Future<List<Map<String, dynamic>>> cats = Shopify.collectionsByHandles(homeCatHandles);
  late Future<List<Map<String, dynamic>>> brands = Shopify.collectionsByHandles(brandHandles);
  final email = TextEditingController();

  Future<void> _subscribe() async {
    final e = email.text.trim();
    if (!e.contains('@')) return;
    try {
      await http.post(Uri.https(Config.shopDomain, '/contact'), body: {'form_type': 'customer', 'utf8': '✓', 'contact[tags]': 'newsletter', 'contact[email]': e});
    } catch (_) {}
    email.clear();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(context, 'شكرًا لاشتراكك!', 'Thanks for subscribing!'))));
  }

  @override
  Widget build(BuildContext context) {
    return StorePage(
      isHome: true,
      body: RefreshIndicator(
        color: ink,
        onRefresh: () async => setState(() {
          _pages.clear();
          cats = Shopify.collectionsByHandles(homeCatHandles);
          brands = Shopify.collectionsByHandles(brandHandles);
        }),
        child: ListView(padding: const EdgeInsets.only(bottom: 90), children: [
          const Slideshow(),
          const GiftBanner(),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 32, 14, 0),
            child: Column(children: [
              Text(tr(context, 'نوبا – متجر مستحضرات التجميل والعناية بالبشرة الأصلية في مصر', 'NOBA – Original cosmetics & skincare store in Egypt'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700, height: 1.4)),
              const SizedBox(height: 8),
              Text(tr(context, 'تسوقي أحدث منتجات العناية بالبشرة والشعر والمكياج من أشهر الماركات العالمية والمحلية', 'Shop the latest skin care, hair care and makeup from top global and local brands'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54, height: 1.5)),
            ]),
          ),
          SectionHeader(tr(context, 'تسوق حسب الفئة', 'Shop by category')),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: cats,
            builder: (context, s) {
              if (s.connectionState != ConnectionState.done) return loading();
              final l = s.data ?? [];
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: l.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 14, crossAxisSpacing: 10, mainAxisExtent: 215),
                itemBuilder: (_, i) {
                  final c = l[i];
                  return InkWell(
                    onTap: () => goCollection(context, c['handle'], c['title']),
                    child: Column(children: [
                      Expanded(child: img(c['image']?['url'], w: 500)),
                      Padding(padding: const EdgeInsets.only(top: 8), child: Text(c['title'], textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
                    ]),
                  );
                },
              );
            },
          ),
          ProductRow(title: tr(context, 'تسوق الافضل مبيعا', 'Shop best sellers'), handle: 'green-friday', future: pg('green-friday')),
          ProductRow(title: 'MAKEUP COLLECTION', handle: 'makeup', future: pg('makeup'), showDesc: true),
          SectionHeader(tr(context, 'تسوق حسب العلامة التجارية', 'Shop by brand'), sub: tr(context, 'اكتشف أفضل العلامات التجارية لدينا', 'Discover our best brands')),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: brands,
            builder: (context, s) {
              if (s.connectionState != ConnectionState.done) return loading();
              final l = s.data ?? [];
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: l.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: .9),
                itemBuilder: (_, i) {
                  final c = l[i];
                  return InkWell(
                    onTap: () => goCollection(context, c['handle'], c['title']),
                    child: Container(
                      decoration: BoxDecoration(border: Border.all(color: line)),
                      padding: const EdgeInsets.all(6),
                      child: Column(children: [
                        Expanded(child: img(c['image']?['url'], fit: BoxFit.contain, w: 300)),
                        const SizedBox(height: 4),
                        Text(c['title'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                      ]),
                    ),
                  );
                },
              );
            },
          ),
          ProductRow(title: tr(context, 'تسوق وصلنا حديثا', 'Shop new arrivals'), handle: 'skin-care', future: pg('skin-care')),
          ProductRow(title: tr(context, 'استكشف عطور مختارة', 'Explore selected fragrances'), handle: 'fragrance', future: pg('fragrance')),
          SectionHeader(tr(context, 'ما نقدمه فى NOBA', 'What we offer at NOBA')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(children: [
              for (final f in [
                ('https://nobaeg.com/cdn/shop/files/Original_Products.png?v=1756678158', tr(context, 'منتجات أصلية', 'Original products'), tr(context, 'نحن ملتزمون بتقديم منتجات أصلية 100% من منتجات العناية بالبشرة المتميزة إلى مستحضرات التجميل الخالدة والعناية الذاتية الأساسية، كل منها مصمم لتعزيز الجمال الطبيعي وإلهام الثقة.', 'We are committed to 100% original products, from premium skin care to timeless makeup and essential self-care, each designed to enhance natural beauty and inspire confidence.')),
                ('https://nobaeg.com/cdn/shop/files/Fast_Shipping.jpg?v=1756678211', tr(context, 'شحن سريع', 'Fast shipping'), tr(context, 'مع الشحن السريع والموثوق، تضمن NOBA وصول مستحضرات التجميل الأساسية إليك بسرعة وأمان، حتى تتمكني من الاستمتاع بالأناقة دون تأخير.', 'With fast and reliable shipping, NOBA gets your beauty essentials to you quickly and safely, so you can enjoy elegance without delay.')),
                ('https://nobaeg.com/cdn/shop/files/After_Sales_247.png?v=1756678252', tr(context, 'خدمة ما بعد البيع', 'After-sales service'), tr(context, 'لأن رضاكم مهم، فإن فريق دعم ما بعد البيع لدينا متاح على مدار الساعة طوال أيام الأسبوع لمساعدتك وإرشادك وضمان حصولك على تجربة خالية من العيوب.', 'Because your satisfaction matters, our after-sales support team is available 24/7 to help and guide you.')),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 22),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    AspectRatio(aspectRatio: 1.5, child: img(f.$1, w: 800)),
                    const SizedBox(height: 10),
                    Text(f.$2, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(f.$3, style: const TextStyle(color: Colors.black54, height: 1.6)),
                  ]),
                ),
            ]),
          ),
          SectionHeader(tr(context, 'يقول العملاء عنا', 'What customers say')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < 4; i++) const Icon(Icons.star, color: Color(0xFFF5A623)),
              const Icon(Icons.star_half, color: Color(0xFFF5A623)),
              const SizedBox(width: 8),
              Text(tr(context, '4.25 (16 تقييم)', '4.25 (16 reviews)')),
            ]),
          ),
          Container(
            margin: const EdgeInsets.only(top: 32),
            padding: const EdgeInsets.all(18),
            color: soft,
            child: Column(children: [
              Text(tr(context, 'اشترك في نشرتنا البريدية', 'Subscribe to our newsletter'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              TextField(controller: email, keyboardType: TextInputType.emailAddress, textDirection: TextDirection.ltr, decoration: InputDecoration(hintText: tr(context, 'البريد الإلكتروني', 'Email'), filled: true, fillColor: Colors.white)),
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, child: FilledButton(onPressed: _subscribe, child: Text(tr(context, 'اشترك', 'Subscribe')))),
            ]),
          ),
          const Footer(),
        ]),
      ),
    );
  }
}

class Slideshow extends StatefulWidget {
  const Slideshow({super.key});
  @override
  State<Slideshow> createState() => _SlideshowState();
}

class _SlideshowState extends State<Slideshow> {
  final pc = PageController();
  int i = 0;
  Timer? t;
  @override
  void initState() {
    super.initState();
    t = Timer.periodic(const Duration(seconds: 5), (_) => _go((i + 1) % slideUrls.length));
  }

  void _go(int n) {
    if (pc.hasClients) pc.animateToPage(n, duration: const Duration(milliseconds: 450), curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    t?.cancel();
    pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ar = isAr(context);
    return AspectRatio(
      aspectRatio: 1.24,
      child: Stack(children: [
        PageView.builder(
          controller: pc,
          itemCount: slideUrls.length,
          onPageChanged: (n) => setState(() => i = n),
          itemBuilder: (_, n) => img(slideUrls[n], w: 1000),
        ),
        PositionedDirectional(start: 4, top: 0, bottom: 0, child: Center(child: _arrow(ar ? Icons.chevron_right : Icons.chevron_left, () => _go((i - 1 + slideUrls.length) % slideUrls.length)))),
        PositionedDirectional(end: 4, top: 0, bottom: 0, child: Center(child: _arrow(ar ? Icons.chevron_left : Icons.chevron_right, () => _go((i + 1) % slideUrls.length)))),
        Positioned(
          left: 0,
          right: 0,
          bottom: 8,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var n = 0; n < slideUrls.length; n++)
              GestureDetector(
                onTap: () => _go(n),
                child: Container(margin: const EdgeInsets.all(3), width: 9, height: 9, decoration: BoxDecoration(shape: BoxShape.circle, color: n == i ? ink : Colors.white70, border: Border.all(color: Colors.white, width: .5))),
              ),
          ]),
        ),
      ]),
    );
  }
}

Widget _arrow(IconData ic, VoidCallback f) => Material(
      color: Colors.white70,
      shape: const CircleBorder(),
      child: InkWell(customBorder: const CircleBorder(), onTap: f, child: Padding(padding: const EdgeInsets.all(4), child: Icon(ic, color: ink))),
    );

class Footer extends StatelessWidget {
  const Footer({super.key});
  @override
  Widget build(BuildContext context) {
    Widget link(String t, String path) => InkWell(onTap: () => goWeb(context, t, path), child: Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Text(t, style: const TextStyle(color: Colors.white70))));
    Widget social(IconData i, String url) => IconButton(icon: Icon(i, color: Colors.white), onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication));
    return Container(
      color: ink,
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          social(Icons.facebook, 'https://www.facebook.com/share/15yeCKwLyu/'),
          social(Icons.camera_alt_outlined, 'https://www.instagram.com/nobacosmatics'),
          social(Icons.music_note, 'https://www.tiktok.com/@nobaeg25'),
        ]),
        const SizedBox(height: 8),
        link(tr(context, 'سياسة الخصوصية', 'Privacy policy'), '/policies/privacy-policy'),
        link(tr(context, 'سياسة الاسترجاع', 'Refund policy'), '/policies/refund-policy'),
        link(tr(context, 'سياسة الشحن', 'Shipping policy'), '/policies/shipping-policy'),
        link(tr(context, 'معلومات الاتصال', 'Contact information'), '/policies/contact-information'),
        link(tr(context, 'شروط الخدمة', 'Terms of service'), '/policies/terms-of-service'),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final t in ['American Express', 'Apple Pay', 'Mastercard', 'Visa'])
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(border: Border.all(color: Colors.white38)), child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 11))),
        ]),
        const SizedBox(height: 16),
        const Text('© 2026 NOBA', style: TextStyle(color: Colors.white54, fontSize: 12)),
      ]),
    );
  }
}

// ───────────────────────── collection ─────────────────────────

class _Sort {
  final String ar, en, key;
  final bool rev;
  const _Sort(this.ar, this.en, this.key, this.rev);
}

const _sorts = [
  _Sort('المميزة', 'Featured', 'COLLECTION_DEFAULT', false),
  _Sort('الأكثر مبيعًا', 'Best selling', 'BEST_SELLING', false),
  _Sort('أبجديًا، أ-ي', 'Alphabetically, A-Z', 'TITLE', false),
  _Sort('أبجديًا، ي-أ', 'Alphabetically, Z-A', 'TITLE', true),
  _Sort('السعر، من الأقل للأعلى', 'Price, low to high', 'PRICE', false),
  _Sort('السعر، من الأعلى للأقل', 'Price, high to low', 'PRICE', true),
  _Sort('التاريخ، من الأحدث للأقدم', 'Date, new to old', 'CREATED', true),
  _Sort('التاريخ، من الأقدم للأحدث', 'Date, old to new', 'CREATED', false),
];

class CollectionScreen extends StatefulWidget {
  final String handle;
  final String? title;
  const CollectionScreen({super.key, required this.handle, this.title});
  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  int si = 0;
  final items = <Map<String, dynamic>>[];
  String? cursor;
  bool hasNext = false, busy = true, failed = false;
  String title = '', desc = '';

  @override
  void initState() {
    super.initState();
    title = widget.title ?? '';
    _load();
  }

  Future<void> _load({bool more = false}) async {
    setState(() {
      busy = true;
      failed = false;
      if (!more) items.clear();
    });
    try {
      final s = _sorts[si];
      final p = await Shopify.collectionPage(widget.handle, sort: s.key, reverse: s.rev, after: more ? cursor : null);
      items.addAll(p.nodes);
      cursor = p.cursor;
      hasNext = p.hasNext;
      if (p.title.isNotEmpty) title = p.title;
      desc = p.description;
    } catch (_) {
      failed = true;
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final ar = isAr(context);
    return StorePage(
      body: ListView(padding: const EdgeInsets.fromLTRB(14, 18, 14, 90), children: [
        Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Row(children: [
          Text(tr(context, 'ترتيب حسب:', 'Sort by:')),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButton<int>(
              isExpanded: true,
              value: si,
              underline: Container(height: 1, color: line),
              items: [for (var i = 0; i < _sorts.length; i++) DropdownMenuItem(value: i, child: Text(ar ? _sorts[i].ar : _sorts[i].en, overflow: TextOverflow.ellipsis))],
              onChanged: (v) {
                if (v == null) return;
                si = v;
                _load();
              },
            ),
          ),
        ]),
        const SizedBox(height: 12),
        if (items.isNotEmpty) ProductGridList(items: items),
        if (busy) loading(),
        if (failed) Padding(padding: const EdgeInsets.all(20), child: Center(child: Text(tr(context, 'تعذّر تحميل المنتجات', 'Could not load products')))),
        if (!busy && !failed && items.isEmpty) Padding(padding: const EdgeInsets.all(30), child: Center(child: Text(tr(context, 'لا توجد منتجات', 'No products found')))),
        if (!busy && hasNext)
          Padding(padding: const EdgeInsets.only(top: 14), child: OutlinedButton(onPressed: () => _load(more: true), child: Text(tr(context, 'عرض المزيد', 'Load more')))),
        if (desc.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 20), child: ExpandText(desc)),
      ]),
    );
  }
}

// ───────────────────────── search ─────────────────────────

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final ctl = TextEditingController();
  Future<List<Map<String, dynamic>>>? results;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: ctl,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(hintText: tr(context, 'يبحث', 'Search'), border: InputBorder.none, enabledBorder: InputBorder.none),
          onSubmitted: (v) => setState(() => results = v.trim().isEmpty ? null : Shopify.search(v.trim())),
        ),
        actions: [IconButton(icon: const Icon(Icons.search), onPressed: () => setState(() => results = ctl.text.trim().isEmpty ? null : Shopify.search(ctl.text.trim())))],
      ),
      body: results == null
          ? const SizedBox.shrink()
          : FutureBuilder<List<Map<String, dynamic>>>(
              future: results,
              builder: (context, s) {
                if (s.connectionState != ConnectionState.done) return loading();
                if (s.hasError) return Center(child: Text(tr(context, 'تعذّر البحث', 'Search failed')));
                final l = s.data ?? [];
                if (l.isEmpty) return Center(child: Text(tr(context, 'لا توجد نتائج', 'No results')));
                return ListView(padding: const EdgeInsets.all(14), children: [ProductGridList(items: l)]);
              },
            ),
    );
  }
}

// ───────────────────────── product ─────────────────────────

class ProductStrip extends StatefulWidget {
  final Future<List<Map<String, dynamic>>> future;
  const ProductStrip({super.key, required this.future});
  @override
  State<ProductStrip> createState() => _ProductStripState();
}

class _ProductStripState extends State<ProductStrip> {
  final ctl = ScrollController();
  @override
  void dispose() {
    ctl.dispose();
    super.dispose();
  }

  void _scroll(int dir) {
    if (!ctl.hasClients) return;
    final to = (ctl.offset + dir * 376).clamp(0.0, ctl.position.maxScrollExtent).toDouble();
    ctl.animateTo(to, duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    final ar = isAr(context);
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: widget.future,
      builder: (context, s) {
        if (s.connectionState != ConnectionState.done) return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator(color: ink, strokeWidth: 2)));
        final l = s.data ?? [];
        if (l.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 360,
          child: Stack(children: [
            ListView.separated(
              controller: ctl,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: l.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => SizedBox(width: 178, child: ProductCard(p: l[i])),
            ),
            PositionedDirectional(start: 2, top: 120, child: _arrow(ar ? Icons.chevron_right : Icons.chevron_left, () => _scroll(ar ? 1 : -1))),
            PositionedDirectional(end: 2, top: 120, child: _arrow(ar ? Icons.chevron_left : Icons.chevron_right, () => _scroll(ar ? -1 : 1))),
          ]),
        );
      },
    );
  }
}

class ProductScreen extends StatefulWidget {
  final Map<String, dynamic> p;
  const ProductScreen({super.key, required this.p});
  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  late List<String> sel;
  final pc = PageController();
  int qty = 1, page = 0;
  late final Future<List<Map<String, dynamic>>> recs = Shopify.related(widget.p['id']);
  late final Future<List<Map<String, dynamic>>> same = Shopify.sameCollection(widget.p['handle']);

  List get vars => widget.p['variants']['nodes'] as List;
  List get opts => widget.p['options'] as List;
  String get url => 'https://${Config.shopDomain}/products/${widget.p['handle']}';

  @override
  void initState() {
    super.initState();
    final first = vars.firstWhere((v) => v['availableForSale'] == true, orElse: () => vars.first);
    sel = (first['title'] as String).split(' / ');
    _fix();
  }

  @override
  void dispose() {
    pc.dispose();
    super.dispose();
  }

  void _fix() {
    if (sel.length != opts.length) sel = [for (final o in opts) (o['values'] as List).first as String];
  }

  Map<String, dynamic>? get cur {
    final t = sel.join(' / ');
    for (final v in vars) {
      if (v['title'] == t) return Map<String, dynamic>.from(v);
    }
    return null;
  }

  bool _valueAvailable(int oi, String val) {
    for (final v in vars) {
      final parts = (v['title'] as String).split(' / ');
      if (parts.length == opts.length && parts[oi] == val && v['availableForSale'] == true) return true;
    }
    return false;
  }

  int _inCart(String? variantId) {
    var n = 0;
    for (final l in CartStore.i.lines) {
      if (l['merchandise']['id'] == variantId) n += (l['quantity'] as int);
    }
    return n;
  }

  void _zoom(List<String> imgs, int start) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(children: [
          PageView(controller: PageController(initialPage: start), children: [for (final u in imgs) InteractiveViewer(child: Center(child: Image.network(cdn(u, 1400), fit: BoxFit.contain)))]),
          SafeArea(child: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(ctx))),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final ar = isAr(context);
    final v = cur;
    final imgs = (p['images']['nodes'] as List).map((e) => e['url'] as String).toList();
    if (imgs.isEmpty && p['featuredImage']?['url'] != null) imgs.add(p['featuredImage']['url'] as String);
    final price = money(v?['price']?['amount'] ?? p['priceRange']['minVariantPrice']['amount']);
    final cmp = money(v?['compareAtPrice']?['amount']);
    final ok = v != null && v['availableForSale'] == true;
    final vendor = (p['vendor'] ?? '') as String;
    final title = p['title'] as String;

    Widget heading(String t) => Padding(padding: const EdgeInsets.fromLTRB(16, 26, 16, 12), child: Text(t, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)));

    return StorePage(
      waText: 'مرحباً نوبا، عندي استفسار عن المنتج: $title $url',
      body: ListView(padding: const EdgeInsets.only(bottom: 100), children: [
        SizedBox(
          height: 380,
          child: Stack(children: [
            PageView(controller: pc, onPageChanged: (i) => setState(() => page = i), children: [
              for (var i = 0; i < imgs.length; i++) GestureDetector(onTap: () => _zoom(imgs, i), child: img(imgs[i], fit: BoxFit.contain, w: 900)),
              if (imgs.isEmpty) img(null),
            ]),
            if (imgs.length > 1)
              PositionedDirectional(end: 10, bottom: 10, child: Container(color: Colors.black54, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), child: Text('${page + 1} / ${imgs.length}', style: const TextStyle(color: Colors.white, fontSize: 12)))),
          ]),
        ),
        if (imgs.length > 1)
          SizedBox(
            height: 70,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              itemCount: imgs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => pc.animateToPage(i, duration: const Duration(milliseconds: 250), curve: Curves.easeInOut),
                child: Container(width: 58, decoration: BoxDecoration(border: Border.all(color: i == page ? ink : line, width: i == page ? 1.5 : 1)), child: img(imgs[i], w: 200)),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (vendor.isNotEmpty) Text(tr(context, 'بواسطة $vendor', 'By $vendor'), style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 1.3)),
            const SizedBox(height: 10),
            Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 10, children: [
              Text(egp(price, ar), textDirection: TextDirection.ltr, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: cmp > price ? const Color(0xFFB3261E) : ink)),
              if (cmp > price) Text(egp(cmp, ar), textDirection: TextDirection.ltr, style: const TextStyle(color: Colors.black45, decoration: TextDecoration.lineThrough)),
              if (cmp > price && ok) Container(color: ink, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), child: Text(tr(context, 'خصم', 'Sale'), style: const TextStyle(color: Colors.white, fontSize: 12))),
              if (!ok) Container(color: Colors.black87, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), child: Text(tr(context, 'نفذ', 'Sold out'), style: const TextStyle(color: Colors.white, fontSize: 12))),
            ]),
            const SizedBox(height: 6),
            Text(tr(context, 'يتم احتساب الشحن عند الخروج.', 'Shipping calculated at checkout.'), style: const TextStyle(color: Colors.black54, fontSize: 12.5)),
            if (vars.length > 1)
              for (var oi = 0; oi < opts.length; oi++) ...[
                const SizedBox(height: 16),
                Text('${opts[oi]['name']}:', style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final val in (opts[oi]['values'] as List))
                    ChoiceChip(
                      label: Text('$val', style: TextStyle(color: sel[oi] == val ? Colors.white : (_valueAvailable(oi, '$val') ? ink : Colors.black38), decoration: _valueAvailable(oi, '$val') ? null : TextDecoration.lineThrough)),
                      selected: sel[oi] == val,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => sel[oi] = '$val'),
                    ),
                ]),
              ],
            const SizedBox(height: 18),
            ListenableBuilder(
              listenable: CartStore.i,
              builder: (context, _) => Row(children: [
                Text(tr(context, 'الكمية', 'Quantity')),
                const SizedBox(width: 8),
                Text('(${_inCart(v?['id'])} ${tr(context, 'في سلة التسوق', 'in cart')})', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                const Spacer(),
                Container(
                  decoration: BoxDecoration(border: Border.all(color: line)),
                  child: Row(children: [
                    IconButton(icon: const Icon(Icons.remove), onPressed: qty > 1 ? () => setState(() => qty--) : null),
                    SizedBox(width: 28, child: Text('$qty', textAlign: TextAlign.center)),
                    IconButton(icon: const Icon(Icons.add), onPressed: () => setState(() => qty++)),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            ListenableBuilder(
              listenable: CartStore.i,
              builder: (context, _) => Column(children: [
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: !ok || CartStore.i.busy
                        ? null
                        : () async {
                            await CartStore.i.add(v!['id'], qty);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(tr(context, 'تمت الإضافة إلى السلة', 'Added to cart')),
                                action: SnackBarAction(label: tr(context, 'عرض السلة', 'View cart'), onPressed: () => goCart(context)),
                              ));
                            }
                          },
                    child: Text(ok ? tr(context, 'أضف إلى السلة', 'Add to cart') : tr(context, 'نفذ', 'Sold out')),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: !ok || CartStore.i.busy
                        ? null
                        : () async {
                            await CartStore.i.add(v!['id'], qty);
                            final u = CartStore.i.checkoutUrl;
                            if (u != null && context.mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => WebPage(title: tr(context, 'إتمام الطلب', 'Checkout'), url: u, checkout: true)));
                          },
                    child: Text(tr(context, 'شراء الآن', 'Buy it now')),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: soft, border: Border.all(color: line)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr(context, 'عروض نوبا لك', 'NOBA offers for you'), style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(tr(context, '🎁 افتح بوكس هدايا في الصفحة الرئيسية لتربح خصماً أو شحناً مجانياً.', '🎁 Open a gift box on the home page to win a discount or free shipping.'), style: const TextStyle(height: 1.5)),
                InkWell(onTap: () => Navigator.popUntil(context, (r) => r.isFirst), child: Text(tr(context, 'الصفحة الرئيسية', 'Home page'), style: const TextStyle(decoration: TextDecoration.underline))),
                const SizedBox(height: 8),
                Text(tr(context, '🚚 هدية الشحن المجاني للطلبات من 1000 جنيه فأكثر', '🚚 Free shipping gift on orders of 1000 EGP or more'), style: const TextStyle(height: 1.5)),
                const SizedBox(height: 8),
                Text(tr(context, '🌿 عروض الجمعة الخضراء', '🌿 Green Friday offers')),
                InkWell(onTap: () => goCollection(context, 'green-friday'), child: Text(tr(context, 'شاهد كل العروض', 'See all offers'), style: const TextStyle(decoration: TextDecoration.underline))),
              ]),
            ),
          ]),
        ),
        heading(tr(context, 'منتجات تناسب هذا المنتج', 'Products that go with this')),
        ProductStrip(future: recs),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
          child: Wrap(runSpacing: 14, children: [
            for (final t in [
              (Icons.verified_outlined, tr(context, 'منتج أصلي 100%', '100% original'), tr(context, 'مباشرة من نوبا', 'Direct from NOBA')),
              (Icons.assignment_return_outlined, tr(context, 'إرجاع سهل', 'Easy returns'), tr(context, 'للمنتج التالف أو الخاطئ', 'For damaged or wrong items')),
              (Icons.local_shipping_outlined, tr(context, 'شحن سريع', 'Fast shipping'), tr(context, 'القاهرة والجيزة: 1–3 أيام عمل', 'Cairo & Giza: 1–3 business days')),
              (Icons.local_offer_outlined, tr(context, 'عروض مميزة', 'Special offers'), tr(context, 'خصومات على منتجات مختارة', 'Discounts on selected products')),
              (Icons.support_agent, tr(context, 'خدمة ما بعد البيع', 'After-sales service'), tr(context, 'عبر واتساب أو البريد', 'Via WhatsApp or email')),
              (Icons.lock_outline, tr(context, 'شراء آمن', 'Secure checkout'), tr(context, 'دفع وبيانات محمية', 'Protected payment & data')),
            ])
              FractionallySizedBox(
                widthFactor: .5,
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(t.$1, size: 26),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t.$2, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)), Text(t.$3, style: const TextStyle(color: Colors.black54, fontSize: 11.5))])),
                ]),
              ),
          ]),
        ),
        if ('${p['description']}'.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(16, 24, 16, 0), child: ExpandText('${p['description']}')),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(children: [
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: url));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(context, 'تم نسخ الرابط', 'Link copied'))));
              },
              icon: const Icon(Icons.share_outlined, color: ink),
              label: Text(tr(context, 'شارك', 'Share'), style: const TextStyle(color: ink)),
            ),
            TextButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WebPage(title: title, url: url))),
              icon: const Icon(Icons.open_in_new, color: ink),
              label: Text(tr(context, 'عرض التفاصيل الكاملة', 'View full details'), style: const TextStyle(color: ink)),
            ),
          ]),
        ),
        heading(tr(context, 'قد يعجبك أيضاً', 'You may also like')),
        ProductStrip(future: same),
        heading(tr(context, 'مراجعات العملاء', 'Customer reviews')),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: OutlinedButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WebPage(title: tr(context, 'المراجعات', 'Reviews'), url: '$url#judgeme_product_reviews'))),
            child: Text(tr(context, 'عرض المراجعات / كتابة مراجعة', 'View reviews / Write a review')),
          ),
        ),
      ]),
    );
  }
}

// ───────────────────────── cart ─────────────────────────

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final ar = isAr(context);
    return StorePage(
      body: ListenableBuilder(
        listenable: CartStore.i,
        builder: (context, _) {
          final c = CartStore.i;
          final left = (Config.freeShipAt - c.total).clamp(0, Config.freeShipAt).toDouble();
          if (c.lines.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(tr(context, 'سلة التسوق فارغة', 'Your cart is empty'), style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 14),
                FilledButton(onPressed: () => Navigator.popUntil(context, (r) => r.isFirst), child: Text(tr(context, 'متابعة التسوق', 'Continue shopping'))),
              ]),
            );
          }
          return ListView(padding: const EdgeInsets.fromLTRB(14, 16, 14, 90), children: [
            Text(tr(context, 'سلة التسوق', 'Cart'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              color: soft,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(left > 0 ? tr(context, 'أنت على بعد ${left.toStringAsFixed(2)} EGP من الحصول على شحن مجاني', 'You are ${left.toStringAsFixed(2)} EGP away from free shipping') : tr(context, '🎉 حصلت على شحن مجاني', '🎉 You get free shipping')),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: (c.total / Config.freeShipAt).clamp(0, 1).toDouble(), minHeight: 6, color: ink, backgroundColor: Colors.white),
              ]),
            ),
            const SizedBox(height: 10),
            for (final l in c.lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 74, height: 74, child: img(l['merchandise']['image']?['url'], w: 200)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l['merchandise']['product']['title'], maxLines: 2, overflow: TextOverflow.ellipsis),
                      if (l['merchandise']['title'] != 'Default Title') Text(l['merchandise']['title'], style: const TextStyle(color: Colors.black54, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(egp(l['cost']['totalAmount']['amount'], ar), textDirection: TextDirection.ltr, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Row(children: [
                        Container(
                          decoration: BoxDecoration(border: Border.all(color: line)),
                          child: Row(children: [
                            IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.remove, size: 18), onPressed: () => c.setQty(l['id'], (l['quantity'] as int) - 1)),
                            Text('${l['quantity']}'),
                            IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.add, size: 18), onPressed: () => c.setQty(l['id'], (l['quantity'] as int) + 1)),
                          ]),
                        ),
                        const Spacer(),
                        IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => c.setQty(l['id'], 0)),
                      ]),
                    ]),
                  ),
                ]),
              ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tr(context, 'كود الخصم', 'Discount code')),
              trailing: Text(c.code ?? '—', textDirection: TextDirection.ltr, style: const TextStyle(fontWeight: FontWeight.w700)),
              onTap: () => _codeDialog(context),
            ),
            ListTile(contentPadding: EdgeInsets.zero, title: Text(tr(context, 'الإجمالي', 'Total'), style: const TextStyle(fontWeight: FontWeight.w700)), trailing: Text(egp(c.total, ar), textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
            Text(tr(context, 'الضرائب والشحن يتم احتسابهما عند إتمام الطلب', 'Taxes and shipping calculated at checkout'), style: const TextStyle(color: Colors.black54, fontSize: 12)),
            if (c.error != null) Text(c.error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
                onPressed: c.checkoutUrl == null ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => WebPage(title: tr(context, 'إتمام الطلب', 'Checkout'), url: c.checkoutUrl!, checkout: true))),
                child: Text(tr(context, 'إتمام الطلب', 'Check out')),
              ),
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
        shape: const RoundedRectangleBorder(),
        title: Text(tr(ctx, 'كود الخصم', 'Discount code')),
        content: TextField(controller: t, textDirection: TextDirection.ltr, textCapitalization: TextCapitalization.characters),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr(ctx, 'إلغاء', 'Cancel'), style: const TextStyle(color: ink))),
          FilledButton(
            onPressed: () {
              CartStore.i.applyCode(t.text.trim());
              Navigator.pop(ctx);
            },
            child: Text(tr(ctx, 'تطبيق', 'Apply')),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── web pages (account, checkout, policies) ─────────────────────────

class WebPage extends StatefulWidget {
  final String title, url;
  final bool checkout;
  const WebPage({super.key, required this.title, required this.url, this.checkout = false});
  @override
  State<WebPage> createState() => _WebPageState();
}

class _WebPageState extends State<WebPage> {
  bool done = false; // order completed (thank-you page seen)

  late final WebViewController c = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setNavigationDelegate(NavigationDelegate(
      onPageStarted: (url) {
        if (url.contains('thank_you') || url.contains('/orders/')) done = true;
      },
      onNavigationRequest: (r) {
        final u = Uri.tryParse(r.url);
        if (u == null) return NavigationDecision.prevent;
        // block dangerous schemes (intent:, file:, javascript:, ...)
        if (!['http', 'https', 'about', 'tel', 'mailto'].contains(u.scheme)) return NavigationDecision.prevent;
        // non-checkout pages: stay on the store (+ Shopify / review widgets); anything else opens outside the app
        if (!widget.checkout && u.scheme.startsWith('http')) {
          final h = u.host;
          final trusted = h == Config.shopDomain || h.endsWith('.${Config.shopDomain}') || h.endsWith('shopify.com') || h.endsWith('shopifycs.com') || h.endsWith('shop.app') || h.endsWith('judge.me');
          final social = ['wa.me', 'api.whatsapp.com', 'www.facebook.com', 'www.instagram.com', 'www.tiktok.com'].contains(h);
          if (!trusted && !social) {
            launchUrl(u, mode: LaunchMode.externalApplication);
            return NavigationDecision.prevent;
          }
        }
        final ext = u.scheme == 'tel' || u.scheme == 'mailto' || ['wa.me', 'api.whatsapp.com', 'www.facebook.com', 'www.instagram.com', 'www.tiktok.com'].contains(u.host);
        if (ext) {
          launchUrl(u, mode: LaunchMode.externalApplication);
          return NavigationDecision.prevent;
        }
        // "Continue shopping" on the checkout / thank-you page -> back into the app
        if (widget.checkout && (u.host == Config.shopDomain || u.host == 'www.${Config.shopDomain}')) {
          final p = u.path;
          final leave = p.isEmpty || p == '/' || p == '/en' || p == '/en/' || p.startsWith('/collections') || p.startsWith('/products') || p.startsWith('/pages');
          if (leave) {
            if (done) CartStore.i.reset();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) Navigator.popUntil(context, (r) => r.isFirst);
            });
            return NavigationDecision.prevent;
          }
        }
        return NavigationDecision.navigate;
      },
    ))
    ..loadRequest(Uri.parse(widget.url));

  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(widget.title, style: const TextStyle(fontSize: 16))), body: WebViewWidget(controller: c));
}
