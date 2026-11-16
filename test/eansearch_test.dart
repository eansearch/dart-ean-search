import 'dart:convert';
import 'dart:io';

import 'package:eansearch/eansearch.dart';
import 'package:test/test.dart';

/// A local HTTP server that replaces the API, so the tests run offline.
class FakeApi {
  late HttpServer _server;

  /// Status codes to return for consecutive requests, then 200.
  List<int> statuses = [];

  /// Response body.
  String body = '[]';

  /// Value for the X-Credits-Remaining header, if any.
  String? credits;

  int calls = 0;
  Uri? lastUri;
  String? userAgent;

  Uri get uri => Uri.parse('http://127.0.0.1:${_server.port}/api');

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen((req) async {
      calls++;
      lastUri = req.uri;
      userAgent = req.headers.value(HttpHeaders.userAgentHeader);
      final res = req.response;
      res.statusCode = calls <= statuses.length ? statuses[calls - 1] : 200;
      if (credits != null) res.headers.set('X-Credits-Remaining', credits!);
      res.headers.contentType = ContentType.json;
      res.write(body);
      await res.close();
    });
  }

  Future<void> stop() => _server.close(force: true);
}

void main() {
  late FakeApi api;
  late EANSearch eansearch;

  setUp(() async {
    api = FakeApi();
    await api.start();
    eansearch = EANSearch(
      'secret',
      baseUri: api.uri,
      retryDelay: Duration.zero,
    );
  });

  tearDown(() async {
    eansearch.close();
    await api.stop();
  });

  test('empty token is rejected', () {
    expect(() => EANSearch(''), throwsArgumentError);
  });

  test('barcodeSearch decodes product, numbers as strings', () async {
    api.body = jsonEncode([
      {
        'ean': '5099750442227',
        'name': 'Michael Jackson: Thriller',
        'categoryId': '45',
        'categoryName': 'Music',
        'googleCategoryId': '855',
        'issuingCountry': 'UK',
      },
    ]);
    final p = await eansearch.barcodeSearch('5099750442227');
    expect(p.ean, '5099750442227');
    expect(p.name, 'Michael Jackson: Thriller');
    expect(p.categoryId, 45);
    expect(p.categoryName, 'Music');
    expect(p.googleCategoryId, 855);
    expect(p.issuingCountry, 'UK');
    final q = api.lastUri!.queryParameters;
    expect(q['token'], 'secret');
    expect(q['format'], 'json');
    expect(q['op'], 'barcode-lookup');
    expect(q['ean'], '5099750442227');
    expect(q['language'], '1');
    expect(api.userAgent, 'dart-eansearch/1.0');
  });

  test('barcodeLookup returns the name, numbers as numbers', () async {
    api.body = '[{"ean":"1","name":"Foo","categoryId":45}]';
    expect(
      await eansearch.barcodeLookup('1', language: Language.german),
      'Foo',
    );
    expect(api.lastUri!.queryParameters['language'], '3');
  });

  test('API errors are thrown, as list or as object', () async {
    for (final body in [
      '[{"error":"Barcode not found"}]',
      '{"error":"Barcode not found"}',
    ]) {
      api.body = body;
      await expectLater(
        eansearch.barcodeLookup('5099750442228'),
        throwsA(
          isA<EANSearchException>().having(
            (e) => e.message,
            'message',
            'Barcode not found',
          ),
        ),
      );
    }
  });

  test('empty result list is an error', () async {
    api.body = '[]';
    await expectLater(
      eansearch.barcodeLookup('1'),
      throwsA(isA<EANSearchException>()),
    );
  });

  test('ISBN-10 and ISBN-13 lookups', () async {
    api.body = '[{"ean":"9781119578888","name":"Book"}]';
    expect(await eansearch.isbnLookup('1-119-57888-x'), 'Book');
    expect(api.lastUri!.queryParameters['isbn'], '111957888X');
    expect(await eansearch.isbnLookup('978-1-119-57888-8'), 'Book');
    expect(api.lastUri!.queryParameters['ean'], '9781119578888');
    expect(api.lastUri!.queryParameters.containsKey('isbn'), isFalse);
  });

  test('ASIN and LCCN lookups', () async {
    api.body = '[{"ean":"0722868396643","asin":"B00000J1V5"}]';
    expect(await eansearch.findAsinForEan('0722868396643'), 'B00000J1V5');
    expect(api.lastUri!.queryParameters['op'], 'asin-for-ean-lookup');
    expect(await eansearch.findEanForAsin('B00000J1V5'), '0722868396643');
    expect(api.lastUri!.queryParameters['asin'], 'B00000J1V5');

    api.body = '[{"ean":"9780815346333","lccn":"2020691629"}]';
    expect(await eansearch.findLccnForEan('9780815346333'), '2020691629');
    expect(api.lastUri!.queryParameters['op'], 'lccn-for-ean-lookup');
    expect(await eansearch.findEanForLccn('2020691629'), '9780815346333');
    expect(api.lastUri!.queryParameters['lccn'], '2020691629');
  });

  test('verifyChecksum accepts different encodings', () async {
    for (final (valid, expected) in [
      ('"1"', true),
      ('1', true),
      ('true', true),
      ('"true"', true),
      ('"0"', false),
      ('false', false),
    ]) {
      api.body = '[{"ean":"5099750442227","valid":$valid}]';
      expect(
        await eansearch.verifyChecksum('5099750442227'),
        expected,
        reason: 'valid: $valid',
      );
    }
  });

  test('product search returns one page', () async {
    api.body = jsonEncode({
      'page': 1,
      'moreproducts': true,
      'totalproducts': 150,
      'productlist': [
        {'ean': '1', 'name': 'iPod A', 'categoryId': '15'},
        {'ean': '2', 'name': 'iPod B', 'categoryId': '15'},
      ],
    });
    final r = await eansearch.productSearch(
      'iPod & more',
      page: 1,
      language: Language.any,
    );
    expect(r.products.map((p) => p.name), ['iPod A', 'iPod B']);
    expect(r.page, 1);
    expect(r.moreProducts, isTrue);
    expect(r.totalProducts, 150);
    final q = api.lastUri!.queryParameters;
    expect(q['op'], 'product-search');
    expect(q['name'], 'iPod & more'); // escaped correctly
    expect(q['page'], '1');
    expect(q['language'], '99');
  });

  test('other searches send the right parameters', () async {
    api.body = '{"page":"0","moreproducts":"0","productlist":[]}';
    await eansearch.similarProductSearch('iPod');
    expect(api.lastUri!.queryParameters['op'], 'similar-product-search');
    await eansearch.categorySearch(45, 'thriller');
    expect(api.lastUri!.queryParameters['op'], 'category-search');
    expect(api.lastUri!.queryParameters['category'], '45');
    final r = await eansearch.barcodePrefixSearch('4007249146');
    expect(api.lastUri!.queryParameters['prefix'], '4007249146');
    expect(r.products, isEmpty); // no results is not an error
    expect(r.moreProducts, isFalse);
  });

  test('search errors are thrown', () async {
    for (final body in [
      '[{"error":"Invalid token"}]',
      '{"error":"Invalid token"}',
    ]) {
      api.body = body;
      await expectLater(
        eansearch.productSearch('iPod'),
        throwsA(isA<EANSearchException>()),
      );
    }
  });

  test('issuing country and barcode image', () async {
    api.body = '[{"ean":"5099750442227","issuingCountry":"UK"}]';
    expect(await eansearch.issuingCountryLookup('5099750442227'), 'UK');

    final png = [0x89, 0x50, 0x4e, 0x47];
    api.body = jsonEncode([
      {'ean': '5099750442227', 'barcode': base64.encode(png)},
    ]);
    expect(
      await eansearch.barcodeImage('5099750442227', width: 300, height: 200),
      png,
    );
    final q = api.lastUri!.queryParameters;
    expect(q['op'], 'barcode-image');
    expect(q['width'], '300');
    expect(q['height'], '200');
    expect(
      await eansearch.barcodeImageBase64('5099750442227'),
      base64.encode(png),
    );
  });

  test('429 responses are retried', () async {
    api.statuses = [429, 429];
    api.body = '[{"ean":"1","name":"Foo"}]';
    expect(await eansearch.barcodeLookup('1'), 'Foo');
    expect(api.calls, 3);
  });

  test('retries are limited', () async {
    api.statuses = [429, 429, 429, 429];
    await expectLater(
      eansearch.barcodeLookup('1'),
      throwsA(
        isA<EANSearchException>().having(
          (e) => e.statusCode,
          'statusCode',
          429,
        ),
      ),
    );
    expect(api.calls, EANSearch.maxApiTries);
  });

  test('HTTP errors are thrown', () async {
    api.statuses = [402];
    await expectLater(
      eansearch.barcodeLookup('1'),
      throwsA(
        isA<EANSearchException>()
            .having((e) => e.statusCode, 'statusCode', 402)
            .having((e) => e.message, 'message', 'HTTP Error 402'),
      ),
    );
  });

  test('invalid JSON is thrown as EANSearchException', () async {
    api.body = '<html>';
    await expectLater(
      eansearch.barcodeLookup('1'),
      throwsA(isA<EANSearchException>()),
    );
  });

  test('network errors are thrown as EANSearchException', () async {
    await api.stop();
    await expectLater(
      eansearch.barcodeLookup('1'),
      throwsA(isA<EANSearchException>()),
    );
    await expectLater(
      eansearch.productSearch('iPod'),
      throwsA(isA<EANSearchException>()),
    );
  });

  test('creditsRemaining is tracked from response headers', () async {
    api.credits = '4711';
    api.body = '[{"ean":"1","name":"Foo"}]';
    await eansearch.barcodeLookup('1');
    expect(await eansearch.creditsRemaining(), 4711);
    expect(api.calls, 1); // no extra request needed
  });

  test('creditsRemaining queries account status if unknown', () async {
    api.credits = '42';
    api.body = '[{"remaining":"42"}]';
    expect(await eansearch.creditsRemaining(), 42);
    expect(api.lastUri!.queryParameters['op'], 'account-status');
  });

  test('live API', () async {
    final token = Platform.environment['EAN_SEARCH_API_TOKEN'];
    if (token == null || token.isEmpty) {
      markTestSkipped('EAN_SEARCH_API_TOKEN not set');
      return;
    }
    final live = EANSearch(token);
    try {
      final p = await live.barcodeSearch('5099750442227');
      expect(p.ean, '5099750442227');
      expect(p.name, isNotEmpty);
      expect(await live.verifyChecksum('5099750442227'), isTrue);
    } finally {
      live.close();
    }
  });
}
