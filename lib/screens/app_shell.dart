import 'panel_settings_screen.dart';

import 'package:flutter/material.dart';

import '../core/strings.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'register_screen.dart';
import 'overview_screen.dart';
import 'inventory_screen.dart';
import 'sales_screen.dart';
import 'team_screen.dart';
import 'settings_screen.dart';
import 'categories_screen.dart';
import 'markets_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  String _page = 'register';
  final _scaffold = GlobalKey<ScaffoldState>();
  void _navigate(String page) {
    setState(() => _page = page);
    _scaffold.currentState?.closeDrawer();
  }

  Future<void> _logout() async {
    if (await confirmAction(
          context,
          title: 'signOut',
          message: 'signOutHint',
          action: 'signOut',
        ) &&
        mounted) {
      context.store.logout();
    }
  }

  List<(String, IconData)> get _destinations => [
    if (context.store.canCheckout) ('register', Icons.grid_view_rounded),
    if (context.store.canViewReports)
      ('overview', Icons.space_dashboard_outlined),
    ('sales', Icons.receipt_long_outlined),
    ('panelSettings', Icons.settings_outlined),
    if (context.store.canViewInventory)
      ('inventory', Icons.inventory_2_outlined),
    if (context.store.canManageCatalog) ('categories', Icons.category_outlined),
    if (context.store.isManager) ('team', Icons.group_outlined),
    if (context.store.isOwner) ('markets', Icons.storefront_outlined),
    if (context.store.canManageBrand) ...[
      ('settings', Icons.tune_rounded),
      ('audit', Icons.history_rounded),
    ],
  ];
  Widget _sidebar() {
    final store = context.store;
    return Container(
      width: 226,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: BorderDirectional(end: BorderSide(color: line)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 30, 20, 34),
              child: Row(
                children: [
                  const BrandMark(size: 38),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          store.settings.name,
                          maxLines: 2,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -.6,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          context.tr('appSubtitle'),
                          style: const TextStyle(
                            color: muted,
                            fontSize: 7,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Text(
                      context.tr('workspace'),
                      style: const TextStyle(
                        fontSize: 9,
                        color: muted,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  for (final destination in _destinations) ...[
                    if (destination.$1 == 'inventory')
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 30, 14, 14),
                        child: Text(
                          context.tr('management'),
                          style: const TextStyle(
                            fontSize: 9,
                            color: muted,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: Material(
                        color: _page == destination.$1
                            ? sage
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        child: ListTile(
                          key: ValueKey('nav-${destination.$1}'),
                          dense: true,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 15,
                          ),
                          leading: Icon(
                            destination.$2,
                            size: 19,
                            color: _page == destination.$1 ? forest : muted,
                          ),
                          horizontalTitleGap: 12,
                          title: Text(
                            context.tr(destination.$1),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: _page == destination.$1
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: _page == destination.$1 ? forest : muted,
                            ),
                          ),
                          onTap: () => _navigate(destination.$1),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.all(19),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: canvas,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.offline_bolt_outlined,
                    color: forest,
                    size: 23,
                  ),
                  const SizedBox(height: 9),
                  Text(
                    context.tr('localOnly'),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    context.tr('localNote'),
                    style: const TextStyle(fontSize: 9, color: muted),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: sage,
                    child: Text(
                      store.currentUser!.name.characters.first.toUpperCase(),
                      style: const TextStyle(
                        color: forest,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          store.currentUser!.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          context.tr(store.currentUser!.role.name),
                          style: const TextStyle(fontSize: 9, color: muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: context.tr('signOut'),
                    onPressed: _logout,
                    icon: const Icon(
                      Icons.logout_rounded,
                      size: 17,
                      color: muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final wide = MediaQuery.sizeOf(context).width >= 1050;
    final pages = <String, Widget>{
      if (store.canCheckout) 'register': const RegisterScreen(),
      'sales': const SalesScreen(),
      'panelSettings': const PanelSettingsScreen(),
      if (store.canViewReports) 'overview': OverviewScreen(navigate: _navigate),
      if (store.canViewInventory) 'inventory': const InventoryScreen(),
      if (store.canManageCatalog) 'categories': const CategoriesScreen(),
      if (store.isManager) 'team': const TeamScreen(),
      if (store.isOwner)
        'markets': MarketsScreen(
          onOpen: (id) {
            store.switchMarket(id);
            _navigate('settings');
          },
        ),
      if (store.canManageBrand) ...{
        'settings': const SettingsScreen(),
        'audit': const AuditScreen(),
      },
    };
    if (!pages.containsKey(_page)) {
      _page = store.canCheckout ? 'register' : 'overview';
    }
    return Scaffold(
      key: _scaffold,
      drawer: wide ? null : Drawer(width: 260, child: _sidebar()),
      body: SafeArea(
        child: Row(
          children: [
            if (wide) _sidebar(),
            Expanded(
              child: Column(
                children: [
                  Container(
                    height: 76,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(bottom: BorderSide(color: line)),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: wide ? 28 : 14),
                    child: Row(
                      children: [
                        if (!wide)
                          IconButton(
                            tooltip: context.tr('menu'),
                            onPressed: () =>
                                _scaffold.currentState!.openDrawer(),
                            icon: const Icon(Icons.menu_rounded),
                          ),
                        Expanded(
                          child: Row(
                            children: [
                              if (wide) ...[
                                const Icon(
                                  Icons.storefront_outlined,
                                  size: 17,
                                  color: muted,
                                ),
                                const SizedBox(width: 9),
                                const Icon(
                                  Icons.chevron_right,
                                  size: 14,
                                  color: muted,
                                ),
                                const SizedBox(width: 9),
                              ],
                              Flexible(
                                child: Text(
                                  context.tr(_page),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (MediaQuery.sizeOf(context).width > 680) ...[
                          const Icon(Icons.circle, color: forest, size: 6),
                          const SizedBox(width: 6),
                          Text(
                            context.tr('localOnly'),
                            style: const TextStyle(fontSize: 10, color: muted),
                          ),
                          const SizedBox(width: 24),
                        ],
                        const LanguageMenu(),
                        if (!wide)
                          IconButton(
                            tooltip: context.tr('signOut'),
                            onPressed: _logout,
                            icon: const Icon(Icons.logout, size: 18),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: IndexedStack(
                      index: pages.keys.toList().indexOf(_page),
                      children: pages.entries
                          .map(
                            (e) => KeyedSubtree(
                              key: ValueKey('${store.activeMarketId}:${e.key}'),
                              child: e.value,
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
