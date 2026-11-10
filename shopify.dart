import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';

String apiLang = 'AR';

const _p = '''
id handle title description
featuredImage{url}
images(first:6){nodes{url}}
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

class Shopify {
  static Future<List<Map<String, dynamic>>> collections() async {
    final d = await _raw('query(\$lang:LanguageCode!) @inContext(language:\$lang,country:EG){collections(first:30){nodes{id handle title image{url}}}}');
    return List<Map<String, dynamic>>.from(d['collections']['nodes']);
  }

  static Future<List<Map<String, dynamic>>> products({String? collection, String? search, bool best = false}) async {
    return _prods(collection, search, best);
  }

  static Future<List<Map<String, dynamic>>> _prods(String? col, String? search, bool best) async {
    if (col != null) {
      final d = await _raw('query(\$h:String!,\$lang:LanguageCode!) @inContext(language:\$lang,country:EG){collection(handle:\$h){products(first:40){nodes{$_p}}}}', {'h': col});
      return List<Map<String, dynamic>>.from(d['collection']?['products']['nodes'] ?? []);
    }
    final d = await _raw('query(\$s:String,\$lang:LanguageCode!) @inContext(language:\$lang,country:EG){products(first:40,query:\$s${best ? ',sortKey:BEST_SELLING' : ''}){nodes{$_p}}}', {'s': search});
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
    final r = d[field] as Map<String, dynamic>;
    final errs = r['userErrors'] as List;
    if (errs.isNotEmpty) throw Exception(errs.first['message']);
    return r['cart'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> cartCreate(String variantId, int q) =>
      _cartMut('cartCreate', '\$v:ID!,\$q:Int!', 'input:{lines:[{merchandiseId:\$v,quantity:\$q}]}', {'v': variantId, 'q': q});
  static Future<Map<String, dynamic>> cartAdd(String cartId, String variantId, int q) =>
      _cartMut('cartLinesAdd', '\$c:ID!,\$v:ID!,\$q:Int!', 'cartId:\$c,lines:[{merchandiseId:\$v,quantity:\$q}]', {'c': cartId, 'v': variantId, 'q': q});
  static Future<Map<String, dynamic>> cartSetQty(String cartId, String lineId, int q) =>
      _cartMut('cartLinesUpdate', '\$c:ID!,\$l:ID!,\$q:Int!', 'cartId:\$c,lines:[{id:\$l,quantity:\$q}]', {'c': cartId, 'l': lineId, 'q': q});
  static Future<Map<String, dynamic>> cartRemove(String cartId, String lineId) =>
      _cartMut('cartLinesRemove', '\$c:ID!,\$l:[ID!]!', 'cartId:\$c,lineIds:\$l', {'c': cartId, 'l': [lineId]});
  static Future<Map<String, dynamic>> cartCodes(String cartId, List<String> codes) =>
      _cartMut('cartDiscountCodesUpdate', '\$c:ID!,\$d:[String!]', 'cartId:\$c,discountCodes:\$d', {'c': cartId, 'd': codes});
}
