import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'models.dart';

/// Client for the EAN and ISBN lookup and validation API on ean-search.org.
///
/// Get an API token at https://www.ean-search.org/ean-database-api.html
///
/// All methods throw an [EANSearchException] when the API reports an error
/// (e.g. "Barcode not found" or an invalid token) or can't be reached.
class EANSearch {
  /// Default API endpoint.
  static final Uri defaultBaseUri = Uri.parse('https://api.ean-search.org/api');

  /// Maximum number of requests per API call (retries on 429 responses).
  static const int maxApiTries = 3;

  final String _token;
  final Uri _baseUri;
  final HttpClient _client;
  final bool _ownsClient;

  /// HTTP timeout for each request.
  Duration timeout;

  /// HTTP user agent.
  String userAgent;

  /// Pause before retrying after a 429 (Too Many Requests) response.
  Duration retryDelay;

  int _remaining = -1;

  /// Creates a client with your API [token].
  ///
  /// [baseUri] and [httpClient] are mainly useful for testing.
  EANSearch(
    String token, {
    this.timeout = const Duration(seconds: 30),
    this.userAgent = 'dart-eansearch/1.0',
    this.retryDelay = const Duration(seconds: 1),
    Uri? baseUri,
    HttpClient? httpClient,
  }) : _token = token,
       _baseUri = baseUri ?? defaultBaseUri,
       _client = httpClient ?? HttpClient(),
       _ownsClient = httpClient == null {
    if (token.isEmpty) {
      throw ArgumentError.value(token, 'token', 'must not be empty');
    }
  }

  /// Lookup the product name for an EAN barcode (or ISBN-13).
  Future<String> barcodeLookup(
    String ean, {
    int language = Language.english,
  }) async => (await barcodeSearch(ean, language: language)).name;

  /// Lookup the product info for an EAN barcode (or ISBN-13),
  /// including the Google category ID.
  Future<Product> barcodeSearch(
    String ean, {
    int language = Language.english,
  }) async {
    final json = await _first({
      'op': 'barcode-lookup',
      'ean': ean,
      'language': '$language',
    });
    return Product.fromJson(json);
  }

  /// Lookup the book title for an ISBN-10 or ISBN-13.
  ///
  /// Hyphens and spaces are removed.
  Future<String> isbnLookup(String isbn) async {
    final clean = isbn.toUpperCase().replaceAll(RegExp(r'[^0-9X]'), '');
    final json = await _first({
      'op': 'barcode-lookup',
      // an ISBN-13 is looked up as EAN
      if (clean.length == 13) 'ean': clean else 'isbn': clean,
    });
    return Product.fromJson(json).name;
  }

  /// Lookup the EAN barcode for an ASIN (Amazon Standard Identification Number).
  Future<String> findEanForAsin(String asin) async =>
      _field(await _first({'op': 'ean-for-asin-lookup', 'asin': asin}), 'ean');

  /// Lookup the ASIN (Amazon Standard Identification Number) for an EAN barcode.
  Future<String> findAsinForEan(String ean) async =>
      _field(await _first({'op': 'asin-for-ean-lookup', 'ean': ean}), 'asin');

  /// Lookup the EAN barcode for an LCCN (Library of Congress Control Number).
  ///
  /// There can be multiple EANs for one LCCN, this returns the first one.
  Future<String> findEanForLccn(String lccn) async =>
      _field(await _first({'op': 'ean-for-lccn-lookup', 'lccn': lccn}), 'ean');

  /// Lookup the LCCN (Library of Congress Control Number) for an EAN barcode.
  Future<String> findLccnForEan(String ean) async =>
      _field(await _first({'op': 'lccn-for-ean-lookup', 'ean': ean}), 'lccn');

  /// Verify the checksum of an EAN barcode.
  Future<bool> verifyChecksum(String ean) async =>
      parseBool((await _first({'op': 'verify-checksum', 'ean': ean}))['valid']);

  /// Search for products by name (exact search).
  Future<SearchResult> productSearch(
    String name, {
    int page = 0,
    int language = Language.english,
  }) => _list({'op': 'product-search', 'name': name}, page, language);

  /// Search for products by name (similar names are also found).
  Future<SearchResult> similarProductSearch(
    String name, {
    int page = 0,
    int language = Language.english,
  }) => _list({'op': 'similar-product-search', 'name': name}, page, language);

  /// Search for products by name within a category.
  Future<SearchResult> categorySearch(
    int category,
    String name, {
    int page = 0,
    int language = Language.english,
  }) => _list(
    {'op': 'category-search', 'category': '$category', 'name': name},
    page,
    language,
  );

  /// Search for all EANs starting with a prefix.
  Future<SearchResult> barcodePrefixSearch(
    String prefix, {
    int page = 0,
    int language = Language.english,
  }) =>
      _list({'op': 'barcode-prefix-search', 'prefix': prefix}, page, language);

  /// Get the issuing country of an EAN barcode (2-letter ISO code).
  Future<String> issuingCountryLookup(String ean) async => _field(
    await _first({'op': 'issuing-country', 'ean': ean}),
    'issuingCountry',
  );

  /// Get a PNG image of the EAN barcode.
  Future<Uint8List> barcodeImage(
    String ean, {
    int width = 102,
    int height = 50,
  }) async => base64.decode(
    await barcodeImageBase64(ean, width: width, height: height),
  );

  /// Get a PNG image of the EAN barcode as base64 string,
  /// e.g. for an HTML `<img src="data:image/png;base64,...">` tag.
  Future<String> barcodeImageBase64(
    String ean, {
    int width = 102,
    int height = 50,
  }) async => _field(
    await _first({
      'op': 'barcode-image',
      'ean': ean,
      'width': '$width',
      'height': '$height',
    }),
    'barcode',
  );

  /// Get the number of API requests remaining this month.
  ///
  /// The number is updated with every API response, an extra request is
  /// only made if it isn't known yet.
  Future<int> creditsRemaining() async {
    if (_remaining < 0) {
      await _call({'op': 'account-status'});
    }
    if (_remaining < 0) {
      throw const EANSearchException('credits remaining not reported by API');
    }
    return _remaining;
  }

  /// Closes the HTTP client, if it was created by this instance.
  void close() {
    if (_ownsClient) _client.close(force: true);
  }

  // calls an API operation, retrying on 429 responses, returns the decoded JSON
  Future<Object?> _call(Map<String, String> params) async {
    final uri = _baseUri.replace(
      queryParameters: {
        ..._baseUri.queryParameters,
        'token': _token,
        'format': 'json',
        ...params,
      },
    );
    for (var tries = 1; ; tries++) {
      final String body;
      final int status;
      try {
        final request = await _client.getUrl(uri).timeout(timeout);
        request.headers.set(HttpHeaders.userAgentHeader, userAgent);
        final response = await request.close().timeout(timeout);
        final credits = parseInt(response.headers.value('X-Credits-Remaining'));
        if (credits != null) _remaining = credits;
        status = response.statusCode;
        body = await response.transform(utf8.decoder).join().timeout(timeout);
      } on TimeoutException {
        throw const EANSearchException('Timeout');
      } on IOException catch (e) {
        throw EANSearchException('Connection error: $e');
      }
      if (status == HttpStatus.tooManyRequests && tries < maxApiTries) {
        await Future<void>.delayed(retryDelay);
        continue;
      }
      if (status != HttpStatus.ok) {
        throw EANSearchException('HTTP Error $status', statusCode: status);
      }
      try {
        return jsonDecode(body);
      } on FormatException {
        throw const EANSearchException('Invalid JSON in API response');
      }
    }
  }

  // calls an operation that returns a list with a single result object
  Future<Map<String, dynamic>> _first(Map<String, String> params) async {
    final data = await _call(params);
    _checkError(data);
    if (data is List && data.isNotEmpty && data.first is Map<String, dynamic>) {
      return data.first as Map<String, dynamic>;
    }
    throw const EANSearchException('No result from API');
  }

  // calls a search operation that returns one page of a product list
  Future<SearchResult> _list(
    Map<String, String> params,
    int page,
    int language,
  ) async {
    final data = await _call({
      ...params,
      'page': '$page',
      'language': '$language',
    });
    _checkError(data);
    if (data is! Map<String, dynamic>) {
      throw const EANSearchException('Unexpected API response');
    }
    final list = data['productlist'];
    return SearchResult(
      products: [
        if (list is List)
          for (final p in list.whereType<Map<String, dynamic>>())
            Product.fromJson(p),
      ],
      page: parseInt(data['page']) ?? page,
      moreProducts: parseBool(data['moreproducts']),
      totalProducts: parseInt(data['totalproducts']),
    );
  }

  // errors are reported as a list with a single error object, or as object
  static void _checkError(Object? data) {
    final obj = data is List && data.isNotEmpty ? data.first : data;
    if (obj is Map && obj['error'] != null) {
      throw EANSearchException(obj['error'].toString());
    }
  }

  static String _field(Map<String, dynamic> json, String key) =>
      json[key]?.toString() ?? '';
}
