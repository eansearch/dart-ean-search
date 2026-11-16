/// EAN, GTIN and ISBN name lookup and validation using the API on
/// https://www.ean-search.org
///
/// ```dart
/// final eansearch = EANSearch(token);
/// final name = await eansearch.barcodeLookup('5099750442227');
/// ```
library;

export 'src/client.dart';
export 'src/models.dart' hide parseBool, parseInt;
