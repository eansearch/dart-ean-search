import 'dart:io';

import 'package:eansearch/eansearch.dart';

Future<void> main() async {
  // get a token from https://www.ean-search.org/ean-database-api.html
  final token = Platform.environment['EAN_SEARCH_API_TOKEN'] ?? '';
  if (token.isEmpty) {
    stderr.writeln('Please set EAN_SEARCH_API_TOKEN to your API token');
    exitCode = 1;
    return;
  }
  final eansearch = EANSearch(token);

  try {
    const ean = '5099750442227'; // Thriller

    final name = await eansearch.barcodeLookup(ean);
    print('$ean is $name');

    // more detailed result, preferably in English
    final product = await eansearch.barcodeSearch(
      ean,
      language: Language.english,
    );
    print(
      '$ean is ${product.name} from category ${product.categoryName} '
      '(Google ID ${product.googleCategoryId}) issued in ${product.issuingCountry}',
    );

    // ISBN-10 or ISBN-13
    print('1119578884 is ${await eansearch.isbnLookup('1119578884')}');

    final ok = await eansearch.verifyChecksum(ean);
    print('$ean is ${ok ? 'OK' : 'not OK'}');

    // search for product name "iPod", first page of the results,
    // preferably English names
    final result = await eansearch.productSearch('iPod');
    for (final p in result.products) {
      print('${p.ean} is ${p.name}');
    }
    if (result.moreProducts) print('more results on page 1');

    // similar product names, in any language
    final similar = await eansearch.similarProductSearch(
      'iPod with extra features',
      language: Language.any,
    );
    for (final p in similar.products) {
      print('${p.ean} is ${p.name}');
    }

    final thrillers = await eansearch.categorySearch(45, 'thriller');
    for (final p in thrillers.products) {
      print('${p.ean} is ${p.name}');
    }

    final prefixed = await eansearch.barcodePrefixSearch('4007249146');
    for (final p in prefixed.products) {
      print('${p.ean} is ${p.name}');
    }

    print(
      'ASIN B00000J1V5 is EAN ${await eansearch.findEanForAsin('B00000J1V5')}',
    );
    print(
      'EAN 0722868396643 is ASIN ${await eansearch.findAsinForEan('0722868396643')}',
    );
    print(
      'ISBN-13 9780815346333 is LCCN ${await eansearch.findLccnForEan('9780815346333')}',
    );
    print(
      'LCCN 2020691629 is EAN ${await eansearch.findEanForLccn('2020691629')}',
    );

    print('$ean was issued in ${await eansearch.issuingCountryLookup(ean)}');

    // save a PNG image of the barcode in the current directory
    final png = await eansearch.barcodeImage(ean, width: 300, height: 200);
    await File('barcode.png').writeAsBytes(png);

    print('${await eansearch.creditsRemaining()} credits remaining');
  } on EANSearchException catch (e) {
    print('API error: ${e.message}');
    if (e.statusCode == 402) print('Usage limit reached');
  } finally {
    eansearch.close();
  }
}
