import 'package:flutter/material.dart';

/// The items of the getting-started card (specs/20 "The getting-started card"). The
/// server derives each one from the household's data; the wire names are its keys.
enum StartItem {
  invitePartner('invite_partner', Icons.person_add_alt_1),
  connectTablet('connect_tablet', Icons.tablet_mac),
  wallDisplay('wall_display', Icons.dashboard_outlined),
  setPin('set_pin', Icons.pin_outlined),
  subscribeFeed('subscribe_feed', Icons.rss_feed),
  school('school', Icons.school_outlined);

  const StartItem(this.wire, this.icon);

  final String wire;
  final IconData icon;

  /// Null for an item this app does not know yet (a newer server): it is not shown.
  static StartItem? parse(String wire) {
    for (final item in values) {
      if (item.wire == wire) return item;
    }
    return null;
  }
}

/// One row of the card: the item, and whether the server considers it done.
class GettingStartedItem {
  const GettingStartedItem({required this.item, required this.done});

  final StartItem item;
  final bool done;

  /// Null for an item this app does not know.
  static GettingStartedItem? fromJson(Map<String, dynamic> json) {
    final item = StartItem.parse(json['item'] as String);
    if (item == null) return null;
    return GettingStartedItem(item: item, done: json['done'] as bool? ?? false);
  }
}
