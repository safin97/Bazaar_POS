import 'package:Bazaar_POS/core/strings.dart';
import 'package:Bazaar_POS/data/models.dart';
import 'package:Bazaar_POS/data/pos_store.dart';
import 'package:flutter_test/flutter_test.dart';

const logo =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/l1sAAAAASUVORK5CYII=';

Future<PosStore> createStore() async {
  final store = PosStore.memory(provisionAdmin: false);
  await store.setup(
    storeName: 'Original',
    name: 'Owner',
    username: 'owner',
    password: 'test-password',
    currency: 'USD',
    sampleProducts: false,
  );
  return store;
}

void main() {
  test('converts USD and IQD for display and rounds to hundredths', () {
    const usd = StoreSettings(currency: 'USD', usdToIqdRate: 131000);
    const iqd = StoreSettings(currency: 'IQD', usdToIqdRate: 131000);
    expect(usd.secondaryAmount(250), 327500);
    expect(iqd.secondaryAmount(327500), 250);
    expect(secondaryMoney(250, usd), '≈ 3,275 IQD');
    expect(secondaryMoney(327500, iqd), '≈ \$2.50 USD');
    expect(
      const StoreSettings(
        currency: 'USD',
        usdToIqdRate: 130050,
      ).secondaryAmount(1),
      1301,
    );
    expect(usd.secondaryAmount(-250), -327500);
    expect(const StoreSettings().secondaryAmount(100), isNull);
  });

  test('old settings remain single currency and new settings round trip', () {
    final old = const StoreSettings(currency: 'USD').toJson()
      ..remove('usdToIqdRate');
    expect(StoreSettings.fromJson(old).secondaryCurrency, isNull);
    final settings = StoreSettings.fromJson(
      const StoreSettings(
        currency: 'IQD',
        usdToIqdRate: 145050,
        logo: logo,
      ).toJson(),
    );
    expect(settings.secondaryCurrency, 'USD');
    expect(settings.usdToIqdRate, 145050);
    expect(settings.logo, logo);
  });

  test(
    'market creation stores logo and optional currency rate atomically',
    () async {
      final store = await createStore();
      addTearDown(store.dispose);
      final id = store.createMarket(
        name: 'Both currencies',
        currency: 'USD',
        logo: logo,
        usdToIqdRate: 131000,
      );
      final market = store.markets.firstWhere((market) => market.id == id);
      expect(market.settings.logo, logo);
      expect(market.settings.secondaryCurrency, 'IQD');
      expect(store.settings.name, 'Original');
      expect(store.settings.usdToIqdRate, isNull);
      for (final rate in [0, -1]) {
        expect(
          () => store.createMarket(
            name: 'Bad rate',
            currency: 'USD',
            usdToIqdRate: rate,
          ),
          throwsA(isA<PosException>()),
        );
      }
      expect(
        () => store.createMarket(
          name: 'Bad pair',
          currency: 'EUR',
          usdToIqdRate: 131000,
        ),
        throwsA(isA<PosException>()),
      );
      expect(
        () => store.createMarket(
          name: 'Bad logo',
          currency: 'USD',
          logo: 'not an image',
        ),
        throwsA(isA<PosException>()),
      );
      expect(store.markets, hasLength(2));
    },
  );

  test(
    'display rate never changes payment, stock, profit or old receipts',
    () async {
      final store = await createStore();
      addTearDown(store.dispose);
      store.saveSettings(
        StoreSettings.fromJson({
          ...store.settings.toJson(),
          'usdToIqdRate': 131000,
          'logo': logo,
        }),
      );
      store.saveProduct(
        Product(
          id: 'milk',
          name: 'Milk',
          barcode: '123',
          category: store.categories.first.id,
          price: 250,
          cost: 100,
          stock: 4,
        ),
      );
      final sale = store.checkout(
        {'milk': 2},
        paymentMethod: 'cash',
        tendered: 600,
      );
      expect(sale.total, 500);
      expect(sale.change, 100);
      expect(sale.cost, 200);
      expect(sale.settings.secondaryAmount(sale.total), 655000);
      expect(store.products.single.stock, 2);
      store.saveSettings(
        StoreSettings.fromJson({
          ...store.settings.toJson(),
          'usdToIqdRate': 145000,
        }),
      );
      expect(store.sales.single.settings.usdToIqdRate, 131000);
      expect(store.sales.single.settings.logo, logo);
      expect(store.products.single.price, 250);
      expect(
        () => store.saveSettings(
          StoreSettings.fromJson({
            ...store.settings.toJson(),
            'currency': 'IQD',
          }),
        ),
        throwsA(isA<PosException>()),
      );
      store.saveSettings(
        StoreSettings.fromJson({
          ...store.settings.toJson(),
          'usdToIqdRate': null,
        }),
      );
      expect(store.settings.secondaryCurrency, isNull);
    },
  );
}
