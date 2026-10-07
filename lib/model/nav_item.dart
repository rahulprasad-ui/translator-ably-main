import 'package:flutter/material.dart';

import 'home.dart';

//for representing single item data of nav drawer
class NavItem {
  final HomeType homeType;
  final VoidCallback onTap;

  NavItem({required this.homeType, required this.onTap});
}

class BottomNavItem {
  final String name;
  final VoidCallback onTap;

  BottomNavItem({required this.name, required this.onTap});
}
