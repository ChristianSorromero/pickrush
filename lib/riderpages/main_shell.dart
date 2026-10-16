import 'package:flutter/material.dart';

import 'package:rider_app/riderpages/rider_dashboard.dart';
import 'package:rider_app/riderpages/placeholder_page.dart';
import 'package:rider_app/riderpages/account_screen.dart';
import 'package:rider_app/widgets/app_bottom_nav.dart';

/// Hosts the bottom navigation and keeps each tab alive.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _items = [
    AppNavItem(label: 'Home', icon: Icons.home_outlined, activeIcon: Icons.home_rounded, showBadge: true),
    AppNavItem(label: 'Pickups', icon: Icons.inventory_2_outlined, activeIcon: Icons.inventory_2_rounded),
    AppNavItem(label: 'Deliveries', icon: Icons.local_shipping_outlined, activeIcon: Icons.local_shipping_rounded),
    AppNavItem(label: 'Earnings', icon: Icons.account_balance_wallet_outlined, activeIcon: Icons.account_balance_wallet_rounded),
    AppNavItem(label: 'Account', icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          DashboardScreen(),
          PlaceholderScreen(title: 'Pickups'),
          PlaceholderScreen(title: 'Deliveries'),
          PlaceholderScreen(title: 'Earnings'),
          AccountScreen(),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        items: _items,
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}
