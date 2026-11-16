/// Language codes for the preferred language of product names.
abstract final class Language {
  /// English.
  static const int english = 1;

  /// Danish.
  static const int danish = 2;

  /// German.
  static const int german = 3;

  /// Spanish.
  static const int spanish = 4;

  /// Finnish.
  static const int finnish = 5;

  /// French.
  static const int french = 6;

  /// Hungarian.
  static const int hungarian = 7;

  /// Italian.
  static const int italian = 8;

  /// Japanese.
  static const int japanese = 9;

  /// Dutch.
  static const int dutch = 10;

  /// Norwegian.
  static const int norwegian = 11;

  /// Polish.
  static const int polish = 12;

  /// Portuguese.
  static const int portuguese = 13;

  /// Swedish.
  static const int swedish = 15;

  /// Czech.
  static const int czech = 16;

  /// Croatian.
  static const int croatian = 18;

  /// Romanian.
  static const int romanian = 19;

  /// Bulgarian.
  static const int bulgarian = 20;

  /// Greek.
  static const int greek = 21;

  /// Accept product names in any language.
  static const int any = 99;
}

/// A product as returned by the API.
class Product {
  /// The EAN (or ISBN-13) of the product.
  final String ean;

  /// The product name.
  final String name;

  /// The ean-search.org category ID.
  final int categoryId;

  /// The ean-search.org category name.
  final String categoryName;

  /// The Google product category ID, only set by `EANSearch.barcodeSearch()`.
  final int? googleCategoryId;

  /// The country where the EAN was issued (2-letter ISO code).
  final String issuingCountry;

  /// Creates a product.
  const Product({
    required this.ean,
    required this.name,
    this.categoryId = 0,
    this.categoryName = '',
    this.googleCategoryId,
    this.issuingCountry = '',
  });

  /// Creates a product from an API JSON object.
  ///
  /// Numbers may be sent as strings or numbers, missing fields get defaults.
  factory Product.fromJson(Map<String, dynamic> json) => Product(
    ean: _string(json['ean']),
    name: _string(json['name']),
    categoryId: parseInt(json['categoryId']) ?? 0,
    categoryName: _string(json['categoryName']),
    googleCategoryId: parseInt(json['googleCategoryId']),
    issuingCountry: _string(json['issuingCountry']),
  );

  /// Converts the product to a JSON object.
  Map<String, dynamic> toJson() => {
    'ean': ean,
    'name': name,
    'categoryId': categoryId,
    'categoryName': categoryName,
    if (googleCategoryId != null) 'googleCategoryId': googleCategoryId,
    'issuingCountry': issuingCountry,
  };

  @override
  String toString() => 'Product($ean, $name)';
}

/// One page of results of a product search.
class SearchResult {
  /// The products on this page.
  final List<Product> products;

  /// The page number (starting with 0).
  final int page;

  /// Whether more results are available on following pages.
  final bool moreProducts;

  /// Total number of products found, if reported by the API.
  final int? totalProducts;

  /// Creates a page of search results.
  const SearchResult({
    required this.products,
    this.page = 0,
    this.moreProducts = false,
    this.totalProducts,
  });
}

/// Thrown when the API reports an error or can't be reached.
class EANSearchException implements Exception {
  /// The error message, e.g. "Barcode not found" or "HTTP Error 402".
  final String message;

  /// The HTTP status code, if the error came from a non-200 response.
  final int? statusCode;

  /// Creates an exception with a [message] and an optional [statusCode].
  const EANSearchException(this.message, {this.statusCode});

  @override
  String toString() => 'EANSearchException: $message';
}

String _string(Object? v) => v == null ? '' : v.toString();

/// Parses a number the API may send as 15, "15", "" or null.
int? parseInt(Object? v) => switch (v) {
  int i => i,
  num n => n.toInt(),
  String s => int.tryParse(s.trim()),
  _ => null,
};

/// Parses a flag the API may send as true, 1, "1" or "true".
bool parseBool(Object? v) => switch (v) {
  bool b => b,
  num n => n != 0,
  String s => s.toLowerCase() == 'true' || s == '1',
  _ => false,
};
