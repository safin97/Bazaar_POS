import 'dart:convert';
import 'dart:typed_data';

const defaultMarketId = 'default';

enum UserRole { cashier, admin, marketOwner, superManager }

enum CashierPermission { viewReports, manageCatalog, applyDiscounts, voidSales }

class StaffUser {
  const StaffUser({
    required this.id,
    required this.name,
    required this.username,
    required this.role,
    required this.passwordHash,
    required this.salt,
    this.active = true,
    this.marketId = defaultMarketId,
    this.extraPermissions = const {},
  });
  final String id, name, username, passwordHash, salt, marketId;
  final UserRole role;
  final bool active;
  final Set<CashierPermission> extraPermissions;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'username': username,
    'role': role.name,
    'passwordHash': passwordHash,
    'salt': salt,
    'active': active,
    'marketId': marketId,
    'extraPermissions': extraPermissions.map((p) => p.name).toList(),
  };
  factory StaffUser.fromJson(Map<String, dynamic> j) => StaffUser(
    id: j['id'],
    name: j['name'],
    username: j['username'],
    role: UserRole.values.byName(j['role']),
    passwordHash: j['passwordHash'],
    salt: j['salt'],
    active: j['active'],
    marketId: j['marketId'] ?? defaultMarketId,
    extraPermissions: Set.unmodifiable(
      CashierPermission.values.where(
        (p) => (j['extraPermissions'] as List? ?? const []).contains(p.name),
      ),
    ),
  );
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.barcode,
    required this.category,
    required this.price,
    required this.cost,
    required this.stock,
    this.unit = 'piece',
    this.emoji = '🛒',
    this.lowStock = 10,
    this.arabicName = '',
    this.kurdishName = '',
    this.marketId = defaultMarketId,
    this.photo,
    this.useCategoryIcon = true,
  });
  final String id,
      name,
      barcode,
      category,
      unit,
      emoji,
      arabicName,
      kurdishName;
  final String marketId;
  final String? photo;
  final bool useCategoryIcon;
  // Money is stored in hundredths; quantities are whole retail units.
  final int price, cost, stock, lowStock;
  String localizedName(String language) => switch (language) {
    'ar' when arabicName.isNotEmpty => arabicName,
    'ku' when kurdishName.isNotEmpty => kurdishName,
    _ => name,
  };
  Product withStock(int value) => Product(
    id: id,
    name: name,
    barcode: barcode,
    category: category,
    price: price,
    cost: cost,
    stock: value,
    unit: unit,
    emoji: emoji,
    lowStock: lowStock,
    arabicName: arabicName,
    kurdishName: kurdishName,
    marketId: marketId,
    photo: photo,
    useCategoryIcon: useCategoryIcon,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'barcode': barcode,
    'category': category,
    'price': price,
    'cost': cost,
    'stock': stock,
    'unit': unit,
    'emoji': emoji,
    'lowStock': lowStock,
    'arabicName': arabicName,
    'kurdishName': kurdishName,
    'marketId': marketId,
    'photo': photo,
    'useCategoryIcon': useCategoryIcon,
  };
  factory Product.fromJson(Map<String, dynamic> j) => Product(
    id: j['id'],
    name: j['name'],
    barcode: j['barcode'],
    category: j['category'],
    price: j['price'],
    cost: j['cost'],
    stock: j['stock'],
    unit: j['unit'],
    emoji: j['emoji'],
    lowStock: j['lowStock'],
    arabicName: j['arabicName'] ?? '',
    kurdishName: j['kurdishName'] ?? '',
    marketId: j['marketId'] ?? defaultMarketId,
    photo: j['photo'],
    useCategoryIcon: j['useCategoryIcon'] ?? true,
  );
}

class ProductCategory {
  const ProductCategory({
    required this.id,
    required this.name,
    this.marketId = defaultMarketId,
    this.arabicName = '',
    this.kurdishName = '',
    this.emoji = '🛒',
    this.photo,
  });
  final String id, marketId, name, arabicName, kurdishName, emoji;
  final String? photo;
  String localizedName(String language) => switch (language) {
    'ar' when arabicName.isNotEmpty => arabicName,
    'ku' when kurdishName.isNotEmpty => kurdishName,
    _ => name,
  };
  Map<String, dynamic> toJson() => {
    'id': id,
    'marketId': marketId,
    'name': name,
    'arabicName': arabicName,
    'kurdishName': kurdishName,
    'emoji': emoji,
    'photo': photo,
  };
  factory ProductCategory.fromJson(Map<String, dynamic> j) => ProductCategory(
    id: j['id'],
    name: j['name'],
    marketId: j['marketId'] ?? defaultMarketId,
    arabicName: j['arabicName'] ?? '',
    kurdishName: j['kurdishName'] ?? '',
    emoji: j['emoji'] ?? '🛒',
    photo: j['photo'],
  );
}

class Market {
  const Market({required this.id, required this.settings});
  final String id;
  final StoreSettings settings;
  Map<String, dynamic> toJson() => {'id': id, 'settings': settings.toJson()};
  factory Market.fromJson(Map<String, dynamic> j) =>
      Market(id: j['id'], settings: StoreSettings.fromJson(j['settings']));
}

class StoreSettings {
  const StoreSettings({
    this.name = 'Bazaar Market',
    this.tagline = 'Fresh goods. Better days.',
    this.address = '',
    this.phone = '',
    this.currency = 'IQD',
    this.taxBasisPoints = 0,
    this.receiptHeader = '',
    this.receiptFooter = 'Thank you for shopping with us!',
    this.logo,
    this.showCashier = true,
    this.receiptWidth = 80,
  });
  final String name,
      tagline,
      address,
      phone,
      currency,
      receiptHeader,
      receiptFooter;
  final int taxBasisPoints, receiptWidth;
  final bool showCashier;
  final String? logo;
  Uint8List? get logoBytes => logo == null ? null : base64Decode(logo!);
  Map<String, dynamic> toJson() => {
    'name': name,
    'tagline': tagline,
    'address': address,
    'phone': phone,
    'currency': currency,
    'taxBasisPoints': taxBasisPoints,
    'receiptHeader': receiptHeader,
    'receiptFooter': receiptFooter,
    'logo': logo,
    'showCashier': showCashier,
    'receiptWidth': receiptWidth,
  };
  factory StoreSettings.fromJson(Map<String, dynamic> j) => StoreSettings(
    name: j['name'],
    tagline: j['tagline'],
    address: j['address'],
    phone: j['phone'],
    currency: j['currency'],
    taxBasisPoints: j['taxBasisPoints'],
    receiptHeader: j['receiptHeader'],
    receiptFooter: j['receiptFooter'],
    logo: j['logo'],
    showCashier: j['showCashier'],
    receiptWidth: j['receiptWidth'] ?? 80,
  );
}

class SaleLine {
  const SaleLine({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.price,
    required this.cost,
  });
  final String productId, name;
  final int quantity, price, cost;
  int get total => price * quantity;
  Map<String, dynamic> toJson() => {
    'productId': productId,
    'name': name,
    'quantity': quantity,
    'price': price,
    'cost': cost,
  };
  factory SaleLine.fromJson(Map<String, dynamic> j) => SaleLine(
    productId: j['productId'],
    name: j['name'],
    quantity: j['quantity'],
    price: j['price'],
    cost: j['cost'],
  );
}

class Sale {
  const Sale({
    required this.id,
    required this.number,
    required this.createdAt,
    required this.cashierId,
    required this.cashierName,
    required this.lines,
    required this.discount,
    required this.tax,
    required this.paymentMethod,
    required this.tendered,
    required this.settings,
    required this.language,
    this.voided = false,
    this.voidReason = '',
    this.marketId = defaultMarketId,
  });
  final String id,
      number,
      cashierId,
      cashierName,
      paymentMethod,
      language,
      voidReason;
  final String marketId;
  final DateTime createdAt;
  final List<SaleLine> lines;
  final int discount, tax, tendered;
  final bool voided;
  final StoreSettings settings;
  int get subtotal => lines.fold(0, (sum, line) => sum + line.total);
  int get total => subtotal - discount + tax;
  int get change => tendered - total;
  int get cost => lines.fold(0, (sum, line) => sum + line.cost * line.quantity);
  Map<String, dynamic> toJson() => {
    'id': id,
    'number': number,
    'createdAt': createdAt.toIso8601String(),
    'cashierId': cashierId,
    'cashierName': cashierName,
    'lines': lines.map((e) => e.toJson()).toList(),
    'discount': discount,
    'tax': tax,
    'paymentMethod': paymentMethod,
    'tendered': tendered,
    'settings': settings.toJson(),
    'language': language,
    'voided': voided,
    'voidReason': voidReason,
    'marketId': marketId,
  };
  factory Sale.fromJson(Map<String, dynamic> j) => Sale(
    id: j['id'],
    number: j['number'],
    createdAt: DateTime.parse(j['createdAt']),
    cashierId: j['cashierId'],
    cashierName: j['cashierName'],
    lines: (j['lines'] as List).map((e) => SaleLine.fromJson(e)).toList(),
    discount: j['discount'],
    tax: j['tax'],
    paymentMethod: j['paymentMethod'],
    tendered: j['tendered'],
    settings: StoreSettings.fromJson(j['settings']),
    language: j['language'],
    voided: j['voided'],
    voidReason: j['voidReason'],
    marketId: j['marketId'] ?? defaultMarketId,
  );
}

class AuditEntry {
  const AuditEntry(this.time, this.actor, this.action, this.detail);
  final DateTime time;
  final String actor, action, detail;
}

const categories = [
  'produce',
  'dairy',
  'bakery',
  'meat',
  'pantry',
  'drinks',
  'household',
];
const categoryEmoji = {
  'produce': '🥬',
  'dairy': '🥛',
  'bakery': '🥐',
  'meat': '🥩',
  'pantry': '🍚',
  'drinks': '🧃',
  'household': '🧴',
};

List<ProductCategory> starterCategories([String marketId = defaultMarketId]) {
  const names = [
    ['Produce', 'الخضار والفواكه', 'سەوزە و فێکی'],
    ['Dairy', 'الألبان', 'شیر و بەرهەمێن شیری'],
    ['Bakery', 'المخبوزات', 'نان و پێخوارن'],
    ['Meat', 'اللحوم', 'گۆشت'],
    ['Pantry', 'المواد الغذائية', 'خوارن'],
    ['Drinks', 'المشروبات', 'ڤەخوارن'],
    ['Household', 'مستلزمات المنزل', 'پێدڤیێن مالێ'],
  ];
  return [
    for (var i = 0; i < categories.length; i++)
      ProductCategory(
        id: marketId == defaultMarketId
            ? categories[i]
            : '$marketId-${categories[i]}',
        marketId: marketId,
        name: names[i][0],
        arabicName: names[i][1],
        kurdishName: names[i][2],
        emoji: categoryEmoji[categories[i]]!,
      ),
  ];
}

List<Product> starterProducts() {
  final data = <(String, String, String, String, String, int, int, String)>[
    ('Red apples', 'تفاح أحمر', 'سێڤێن سۆر', 'produce', '🍎', 2500, 48, '1 kg'),
    (
      'Fresh bananas',
      'موز طازج',
      'مۆزێ تازە',
      'produce',
      '🍌',
      2000,
      36,
      '1 kg',
    ),
    (
      'Garden tomatoes',
      'طماطم',
      'باجانێن سۆر',
      'produce',
      '🍅',
      1500,
      60,
      '1 kg',
    ),
    ('Fresh milk', 'حليب طازج', 'شیرێ تازە', 'dairy', '🥛', 2000, 24, '1 L'),
    (
      'Farm eggs',
      'بيض المزرعة',
      'هێکێن گوندی',
      'dairy',
      '🥚',
      6000,
      18,
      '12 pcs',
    ),
    (
      'Butter croissant',
      'كرواسون بالزبدة',
      'کروسان ب نڤیشکێ',
      'bakery',
      '🥐',
      1000,
      8,
      'piece',
    ),
    (
      'Sourdough bread',
      'خبز طازج',
      'نانێ تازە',
      'bakery',
      '🍞',
      1500,
      16,
      'piece',
    ),
    (
      'Chicken breast',
      'صدر دجاج',
      'سینگێ مریشکێ',
      'meat',
      '🍗',
      8000,
      20,
      '1 kg',
    ),
    (
      'Basmati rice',
      'أرز بسمتي',
      'برنجێ بەسمەتی',
      'pantry',
      '🍚',
      3500,
      42,
      '1 kg',
    ),
    (
      'Olive oil',
      'زيت زيتون',
      'زەیتێ زەیتوونێ',
      'pantry',
      '🫒',
      7500,
      7,
      '750 ml',
    ),
    (
      'Orange juice',
      'عصير البرتقال',
      'ئاڤا پرتەقاڵێ',
      'drinks',
      '🍊',
      2500,
      30,
      '1 L',
    ),
    (
      'Mineral water',
      'مياه معدنية',
      'ئاڤا کانزایی',
      'drinks',
      '💧',
      500,
      96,
      '500 ml',
    ),
  ];
  return [
    for (var i = 0; i < data.length; i++)
      Product(
        id: 'seed-$i',
        name: data[i].$1,
        arabicName: data[i].$2,
        kurdishName: data[i].$3,
        category: data[i].$4,
        emoji: data[i].$5,
        price: data[i].$6 * 100,
        cost: data[i].$6 * 65,
        stock: data[i].$7,
        unit: data[i].$8,
        barcode: '200000000${i.toString().padLeft(4, '0')}',
      ),
  ];
}
