class ProductTranslation {
  final String? name;
  final String? reason;
  final String? store;
  final String? discountInfo;

  const ProductTranslation({
    this.name,
    this.reason,
    this.store,
    this.discountInfo,
  });

  factory ProductTranslation.fromJson(Map<String, dynamic> json) =>
      ProductTranslation(
        name: json['name'] as String?,
        reason: json['reason'] as String?,
        store: json['store'] as String?,
        discountInfo: json['discountInfo'] as String?,
      );
}

class Product {
  final String id;
  final String name;
  final int price;
  final String store;
  final String category;
  final String? reason;
  final String? discountInfo;
  final String? imageUrl;
  final Map<String, Map<String, String>> translations;

  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.store,
    required this.category,
    this.reason,
    this.discountInfo,
    this.imageUrl,
    this.translations = const {},
  });

  static Map<String, Map<String, String>> _parseTranslations(dynamic value) {
    if (value is! Map) return const {};
    return value.map((language, fields) {
      final localizedFields = fields is Map
          ? fields.map(
              (field, text) => MapEntry(field.toString(), text.toString()),
            )
          : <String, String>{};
      return MapEntry(language.toString(), localizedFields);
    });
  }

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['itemId'] as String,
    name: json['name'] as String,
    price: json['price'] as int,
    store: json['store'] as String,
    category: json['category'] as String,
    reason: json['reason'] as String?,
    discountInfo: json['discountInfo'] as String?,
    imageUrl: json['imageUrl'] as String?,
    translations: _parseTranslations(json['translations']),
  );

  String _localizedField(String field, String fallback, String languageCode) {
    if (languageCode == 'ko') return fallback;
    final translated = translations[languageCode]?[field]?.trim();
    return translated == null || translated.isEmpty ? fallback : translated;
  }

  String localizedName(String languageCode) =>
      _localizedField('name', name, languageCode);

  String? localizedReason(String languageCode) {
    if (reason == null) return null;
    return _localizedField('reason', reason!, languageCode);
  }

  String? localizedDiscountInfo(String languageCode) {
    if (discountInfo == null) return null;
    return _localizedField('discountInfo', discountInfo!, languageCode);
  }

  String get priceLabel {
    return localizedPriceLabel('ko');
  }

  String localizedPriceLabel(String languageCode) {
    final text = price.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    );
    return switch (languageCode) {
      'en' => '₩$text',
      'ja' => '$textウォン',
      'zh' => '$text韩元',
      _ => '$text원',
    };
  }

  String localizedStore(String languageCode) {
    final storedTranslation = translations[languageCode]?['store']?.trim();
    if (storedTranslation != null && storedTranslation.isNotEmpty) {
      return storedTranslation;
    }
    var localized = store;
    const translationsByLanguage = <String, Map<String, String>>{
      'en': {
        '명동hbaf': 'HBAF Myeongdong',
        'hbaf명동매장': 'HBAF Myeongdong Store',
        'hbaf매장': 'HBAF Store',
        '오프뷰티': 'OFF BEAUTY',
        '올리브영': 'Olive Young',
        '무탠다드': 'MUSINSA Standard',
        '편의점': 'Convenience stores',
        '약국': 'Pharmacies',
        '다이소': 'Daiso',
        '롯데': 'Lotte',
        'e마트': 'E-Mart',
      },
      'ja': {
        '명동hbaf': 'HBAF 明洞',
        'hbaf명동매장': 'HBAF 明洞店',
        'hbaf매장': 'HBAF 店舗',
        '오프뷰티': 'OFF BEAUTY',
        '올리브영': 'オリーブヤング',
        '무탠다드': 'MUSINSA Standard',
        '편의점': 'コンビニ',
        '약국': '薬局',
        '다이소': 'ダイソー',
        '롯데': 'ロッテ',
        'e마트': 'イーマート',
      },
      'zh': {
        '명동hbaf': 'HBAF 明洞',
        'hbaf명동매장': 'HBAF 明洞店',
        'hbaf매장': 'HBAF 门店',
        '오프뷰티': 'OFF BEAUTY',
        '올리브영': 'Olive Young',
        '무탠다드': 'MUSINSA Standard',
        '편의점': '便利店',
        '약국': '药店',
        '다이소': '大创',
        '롯데': '乐天',
        'e마트': '易买得',
      },
    };
    final fallbackTranslations = translationsByLanguage[languageCode];
    if (fallbackTranslations == null) return localized;
    for (final entry in fallbackTranslations.entries) {
      localized = localized.replaceAll(entry.key, entry.value);
    }
    return localized;
  }

  String nameFor(String lang) => localizedName(lang);
  String? reasonFor(String lang) => localizedReason(lang);
  String storeFor(String lang) => localizedStore(lang);
  String? discountInfoFor(String lang) => localizedDiscountInfo(lang);
}
