# eansearch

A Dart library for EAN, GTIN, UPC and ISBN name lookup and validation using the API on https://www.ean-search.org

No dependencies besides the Dart SDK. Works on all native platforms (Dart VM, Flutter on Android, iOS, Linux, macOS and Windows).

## Installation

```sh
dart pub add eansearch
```

or for Flutter:

```sh
flutter pub add eansearch
```

## Usage

```dart
import 'package:eansearch/eansearch.dart';

Future<void> main() async {
  // get a token from https://www.ean-search.org/ean-database-api.html
  final eansearch = EANSearch('secret');

  try {
    const ean = '5099750442227'; // Thriller

    final name = await eansearch.barcodeLookup(ean);
    print('$ean is $name');

    // more detailed result, preferably in English
    final product = await eansearch.barcodeSearch(ean, language: Language.english);
    print('$ean is ${product.name} from category ${product.categoryName} '
        '(Google ID ${product.googleCategoryId}) issued in ${product.issuingCountry}');

    // ISBN-10 or ISBN-13
    final title = await eansearch.isbnLookup('1119578884');
    print('1119578884 is $title');

    final ok = await eansearch.verifyChecksum(ean);
    print('$ean is ${ok ? 'OK' : 'not OK'}');

    // search for product name "iPod", get the first page of the results, only English results
    final result = await eansearch.productSearch('iPod');
    for (final p in result.products) {
      print('${p.ean} is ${p.name}');
    }
    if (result.moreProducts) {
      final page2 = await eansearch.productSearch('iPod', page: 1);
      print('${page2.products.length} more products');
    }

    // search for similar product names, in any language
    final similar = await eansearch.similarProductSearch('iPod with extra features',
        language: Language.any);

    final thrillers = await eansearch.categorySearch(45, 'thriller');

    final prefix = await eansearch.barcodePrefixSearch('4007249146');

    // ASIN (Amazon Standard Identification Number) lookups
    final eanForAsin = await eansearch.findEanForAsin('B00000J1V5');
    final asin = await eansearch.findAsinForEan('0722868396643');

    // LCCN (Library of Congress Control Number) lookups
    final lccn = await eansearch.findLccnForEan('9780815346333');
    final eanForLccn = await eansearch.findEanForLccn('2020691629');

    final country = await eansearch.issuingCountryLookup(ean);
    print('$ean was issued in $country');

    // PNG image of the barcode as bytes, or base64 for HTML
    final png = await eansearch.barcodeImage(ean, width: 300, height: 200);
    final b64 = await eansearch.barcodeImageBase64(ean, width: 300, height: 200);
    print('HTML: <img src="data:image/png;base64,$b64">');

    print('${await eansearch.creditsRemaining()} credits remaining');
  } on EANSearchException catch (e) {
    // e.g. "Barcode not found", "Invalid token" or "HTTP Error 402" (usage limit reached)
    print('API error: ${e.message}');
  } finally {
    eansearch.close();
  }
}
```

## Error handling

All methods throw an `EANSearchException` when the API reports an error (e.g. an unknown barcode or an invalid token), returns an HTTP error or can't be reached. `statusCode` is set for HTTP errors. Requests that get a 429 (Too Many Requests) response are retried automatically.

A search without results is not an error, it returns an empty product list.

## Languages

The `language` parameter selects the preferred language of product names. Use the constants in `Language`, e.g. `Language.german`, or `Language.any` to accept any language.

## Options

```dart
final eansearch = EANSearch(token,
    timeout: const Duration(seconds: 60),
    userAgent: 'my-app/1.0');
```

## License

MIT, see [LICENSE](LICENSE).
