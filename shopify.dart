import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'config.dart';

String apiLang = 'AR';

const _p = '''
id handle title description vendor availableForSale
featuredImage{url}
images(first:8){nodes{url}}
options{name values}
priceRange{minVariantPrice{amount}}
variants(first:30){nodes{id title availableForSale price{amount} compareAtPrice{amount}}}
''';

const _c = '''
id checkoutUrl totalQuantity
cost{subtotalAmount{amount} totalAmount{amount}}
discountCodes{code applicable}
lines(first:50){nodes{id quantity cost{totalAmount{amount}}
 merchandise{... on ProductVariant{id title product{title} image{url}}}}}
''';

class AppBanner {
  final String url, link;
  AppBanner(this.url, this.link);
}

class AppAnn {
  final String ar, en, link;
  AppAnn(this.ar, this.en, this.link);
}

class AppContent {
  final List<AppBanner> banners;
  final List<AppAnn> anns;
  AppContent(this.banners, this.anns);
}

/// محتوى يُدار من Shopify (Metaobjects: app_banner / app_announcement)
final appContent = ValueNotifier<AppContent?>(null);

class ProdPage {
  final String title, description;
  final List<Map<String, dynamic>> nodes;
  final bool hasNext;
  final String? cursor;
  ProdPage(this.title, this.description, this.nodes, this.hasNext, this.cursor);
}

class Shopify {
  static Future<List<Map<String, dynamic>>> collections() async {
    final d = await _raw('query(\$lang:LanguageCode!) @inContext(language:\$lang,country:EG){collections(first:30){nodes{id handle title image{url}}}}');
    return List<Map<String, dynamic>>.from(d['collections']['nodes']);
  }

  static Future<List<Map<String, dynamic>>> collectionsByHandles(List<String> hs) async {
    final f = [for (var i = 0; i < hs.length; i++) 'c$i:collection(handle:"${hs[i]}"){handle title description image{url}}'].join(' ');
    final d = await _raw('query(\$lang:LanguageCode!) @inContext(language:\$lang,country:EG){$f}');
    return [for (var i = 0; i < hs.length; i++) if (d['c$i'] != null) Map<String, dynamic>.from(d['c$i'])];
  }

  /// Products of a collection. sort: COLLECTION_DEFAULT, BEST_SELLING, CREATED, PRICE, TITLE
  static Future<ProdPage> collectionPage(String handle, {String sort = 'COLLECTION_DEFAULT', bool reverse = false, String? after, int n = 24}) async {
    final d = await _raw('query(\$h:String!,\$a:String,\$lang:LanguageCode!) @inContext(language:\$lang,country:EG){collection(handle:\$h){title description products(first:$n,after:\$a,sortKey:$sort,reverse:$reverse){pageInfo{hasNextPage endCursor} nodes{$_p}}}}', {'h': handle, 'a': after});
    final c = d['collection'];
    if (c == null) return ProdPage('', '', [], false, null);
    final pr = c['products'];
    return ProdPage(c['title'] ?? '', c['description'] ?? '', List<Map<String, dynamic>>.from(pr['nodes']), pr['pageInfo']['hasNextPage'] == true, pr['pageInfo']['endCursor']);
  }

  static Future<List<Map<String, dynamic>>> related(String id) async {
    final d = await _raw('query(\$id:ID!,\$lang:LanguageCode!) @inContext(language:\$lang,country:EG){productRecommendations(productId:\$id){$_p}}', {'id': id});
    return List<Map<String, dynamic>>.from(d['productRecommendations'] ?? []);
  }

  static Future<List<Map<String, dynamic>>> sameCollection(String handle) async {
    final d = await _raw('query(\$h:String!,\$lang:LanguageCode!) @inContext(language:\$lang,country:EG){product(handle:\$h){collections(first:1){nodes{handle}}}}', {'h': handle});
    final n = d['product']?['collections']?['nodes'] as List?;
    if (n == null || n.isEmpty) return [];
    final p = await collectionPage(n.first['handle'], n: 12);
    return p.nodes.where((e) => e['handle'] != handle).toList();
  }

  static Future<List<Map<String, dynamic>>> search(String q) async {
    final d = await _raw('query(\$s:String!,\$lang:LanguageCode!) @inContext(language:\$lang,country:EG){products(first:40,query:\$s){nodes{$_p}}}', {'s': q});
    return List<Map<String, dynamic>>.from(d['products']['nodes']);
  }

  static Future<Map<String, dynamic>> _raw(String q, [Map<String, dynamic>? vars]) async {
    final res = await http.post(
      Uri.https(Config.shopDomain, '/api/${Config.apiVersion}/graphql.json'),
      headers: {
        'Content-Type': 'application/json',
        'X-Shopify-Storefront-Access-Token': Config.storefrontToken,
      },
      body: jsonEncode({'query': q, 'variables': {'lang': apiLang, ...?vars}}),
    );
    final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (j['errors'] != null) throw Exception(j['errors'].toString());
    return j['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>?> cart(String id) async {
    final d = await _raw('query(\$id:ID!,\$lang:LanguageCode!) @inContext(language:\$lang,country:EG){cart(id:\$id){$_c}}', {'id': id});
    return d['cart'] as Map<String, dynamic>?;
  }

  static Future<Map<String, dynamic>> _cartMut(String field, String decl, String args, Map<String, dynamic> v) async {
    final d = await _raw('mutation($decl,\$lang:LanguageCode!) @inContext(language:\$lang,country:EG){$field($args){cart{$_c} userErrors{message}}}', v);
    final r = d[field] as Map<String, dynamic>?;
    if (r == null || r['cart'] == null) throw Exception('cart not found');
    final errs = r['userErrors'] as List;
    if (errs.isNotEmpty) throw Exception(errs.first['message']);
    return r['cart'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> cartCreate(String variantId, int q) => _cartMut(
      'cartCreate',
      '\$v:ID!,\$q:Int!',
      'input:{lines:[{merchandiseId:\$v,quantity:\$q}],attributes:[{key:"source",value:"app"},{key:"app_platform",value:"${defaultTargetPlatform.name}"}]}',
      {'v': variantId, 'q': q});

  static Future<void> loadContent() async {
    try {
      final d = await _raw('query(\$lang:LanguageCode!) @inContext(language:\$lang,country:EG){'
          'b:metaobjects(type:"app_banner",first:20){nodes{fields{key value reference{... on MediaImage{image{url}}}}}} '
          'a:metaobjects(type:"app_announcement",first:20){nodes{fields{key value}}}}').timeout(const Duration(seconds: 8));
      Map<String, String> f(dynamic n) {
        final m = <String, String>{};
        for (final x in (n['fields'] as List)) {
          m[x['key']] = (x['value'] ?? '').toString();
          final u = x['reference']?['image']?['url'];
          if (u != null) m['${x['key']}_url'] = u;
        }
        return m;
      }

      int so(Map<String, String> m) => int.tryParse(m['sort'] ?? '') ?? 99;
      bool on(Map<String, String> m) => m['active'] != 'false';
      final bs = ((d['b']['nodes'] as List).map(f).where((m) => on(m) && m['image_url'] != null).toList())..sort((a, b) => so(a).compareTo(so(b)));
      final an = ((d['a']['nodes'] as List).map(f).where((m) => on(m) && (m['text_ar'] ?? '').isNotEmpty).toList())..sort((a, b) => so(a).compareTo(so(b)));
      appContent.value = AppContent(
        bs.map((m) => AppBanner(m['image_url']!, m['link'] ?? '')).toList(),
        an.map((m) => AppAnn(m['text_ar']!, (m['text_en'] ?? '').isEmpty ? m['text_ar']! : m['text_en']!, m['link'] ?? '')).toList(),
      );
    } catch (_) {}
  }
  static Future<Map<String, dynamic>> cartAdd(String cartId, String variantId, int q) =>
      _cartMut('cartLinesAdd', '\$c:ID!,\$v:ID!,\$q:Int!', 'cartId:\$c,lines:[{merchandiseId:\$v,quantity:\$q}]', {'c': cartId, 'v': variantId, 'q': q});
  static Future<Map<String, dynamic>> cartSetQty(String cartId, String lineId, int q) =>
      _cartMut('cartLinesUpdate', '\$c:ID!,\$l:ID!,\$q:Int!', 'cartId:\$c,lines:[{id:\$l,quantity:\$q}]', {'c': cartId, 'l': lineId, 'q': q});
  static Future<Map<String, dynamic>> cartRemove(String cartId, String lineId) =>
      _cartMut('cartLinesRemove', '\$c:ID!,\$l:[ID!]!', 'cartId:\$c,lineIds:\$l', {'c': cartId, 'l': [lineId]});
  static Future<Map<String, dynamic>> cartCodes(String cartId, List<String> codes) =>
      _cartMut('cartDiscountCodesUpdate', '\$c:ID!,\$d:[String!]', 'cartId:\$c,discountCodes:\$d', {'c': cartId, 'd': codes});
}
