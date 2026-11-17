# EAN-Search for Dart

[![pub package](https://img.shields.io/pub/v/eansearch.svg)](https://pub.dev/packages/eansearch)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Turn a barcode into a product name with a single call. This package is the Dart
client for the [EAN-Search.org](https://www.ean-search.org) product database
API, which covers millions of EAN, UPC, GTIN and ISBN codes.

```dart
final eansearch = EANSearch(token);
print(await eansearch.barcodeLookup('5099750442227'));
```

It only depends on the Dart SDK and runs everywhere `dart:io` is available:
Dart on the server or command line, and Flutter apps on Android, iOS, Linux,
macOS and Windows.

## What you can do with it

- Look up product names and details (category, issuing country) for an EAN
- Look up book titles by ISBN-10 or ISBN-13
- Search products by name, by similar name, within a category or by barcode prefix
- Convert between EAN and Amazon ASIN, or between ISBN and Library of Congress LCCN
- Check whether a barcode has a valid checksum
- Generate a PNG image of a barcode
- Keep an eye on how many API credits you have left

## Getting started

You need an API token. You can get one on the
[EAN database API page](https://www.ean-search.org/ean-database-api.html).

Add the package to your project:

```sh
dart pub add eansearch      # Dart
flutter pub add eansearch   # Flutter
```

Then look up your first barcode:

```dart
import 'package:eansearch/eansearch.dart';

Future<void> main() async {
  final eansearch = EANSearch('your-api-token');
  try {
    final product = await eansearch.barcodeSearch('5099750442227');
    print('${product.name} (${product.categoryName}, '
        'issued in ${product.issuingCountry})');
  } on EANSearchException catch (e) {
    print('Lookup failed: ${e.message}');
  } finally {
    eansearch.close();
  }
}
```

Keep the token out of your source code, e.g. by reading it from an environment
variable like the [example](example/eansearch_example.dart) does.

## Examples

### Barcodes and books

```dart
// just the name
final name = await eansearch.barcodeLookup('5099750442227');

// name, category, Google category ID and issuing country,
// preferably in German
final product = await eansearch.barcodeSearch('5099750442227',
    language: Language.german);

// ISBN-10 or ISBN-13, hyphens are fine
final title = await eansearch.isbnLookup('1-119-57888-4');

// is the checksum valid?
final valid = await eansearch.verifyChecksum('5099750442227');

// where was the EAN issued? (2-letter ISO code)
final country = await eansearch.issuingCountryLookup('5099750442227');
```

### Searching

Searches return one page of results at a time. `moreProducts` tells you
whether it's worth asking for the next page.

```dart
var page = 0;
SearchResult result;
do {
  result = await eansearch.productSearch('iPod', page: page++);
  for (final p in result.products) {
    print('${p.ean}  ${p.name}');
  }
} while (result.moreProducts);
```

The other searches work the same way:

```dart
// also finds similar names, in any language
await eansearch.similarProductSearch('iPod with extra features',
    language: Language.any);

// search for a name within a category
await eansearch.categorySearch(45, 'thriller');

// all EANs starting with a prefix
await eansearch.barcodePrefixSearch('4007249146');
```

A search that finds nothing isn't an error, you just get an empty product list.

### ASIN and LCCN

```dart
final ean = await eansearch.findEanForAsin('B00000J1V5');
final asin = await eansearch.findAsinForEan('0722868396643');

final lccn = await eansearch.findLccnForEan('9780815346333');
final isbn = await eansearch.findEanForLccn('2020691629');
```

### Barcode images

```dart
// PNG bytes, e.g. for Image.memory() in Flutter or to save to a file
final png = await eansearch.barcodeImage('5099750442227',
    width: 300, height: 200);

// or base64, ready for an HTML <img> tag
final b64 = await eansearch.barcodeImageBase64('5099750442227');
print('<img src="data:image/png;base64,$b64">');
```

### Credits

```dart
print('${await eansearch.creditsRemaining()} API calls left this month');
```

The count is taken from the headers of your normal API calls, so checking it
usually doesn't cost an extra request.

## Product names in your language

Most methods take a `language` parameter for the preferred language of the
product names. Pass one of the `Language` constants, e.g. `Language.french`,
or `Language.any` if any language will do. The default is English.

## Errors

Every method throws an `EANSearchException` when something goes wrong: an
unknown barcode, an invalid token, an HTTP error or a network problem. For HTTP
errors, `statusCode` is set as well, so you can e.g. spot a 402 when your
monthly limit is used up.

When the API answers with 429 (Too Many Requests), the client waits a moment
and retries for you.

## Configuration

```dart
final eansearch = EANSearch(token,
    timeout: const Duration(seconds: 60), // per request, default 30s
    userAgent: 'my-app/1.0');
```

Call `close()` when you're done to release the underlying HTTP client.

## Other languages

EAN-Search API clients are also available for Perl, Python, PHP, Java,
JavaScript, C#, Go, Rust, Swift, Ruby and Lua. See
[github.com/eansearch](https://github.com/eansearch).

## License

MIT, see [LICENSE](LICENSE).
