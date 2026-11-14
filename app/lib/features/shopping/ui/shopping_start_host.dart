import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/logging/log.dart';
import 'package:wuselwall/core/notifications/notification_scheduler.dart';
import 'package:wuselwall/core/notifications/notification_scheduler_provider.dart';
import 'package:wuselwall/features/home/application/home_tab.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/reminders/application/reminder_providers.dart';
import 'package:wuselwall/features/settings/application/app_locale_provider.dart';
import 'package:wuselwall/features/shopping/application/shopping_providers.dart';
import 'package:wuselwall/features/today/application/today_providers.dart';
import 'package:wuselwall/features/today/domain/notice.dart';

/// The notices this host listens to: none on a server without the feature and none
/// outside the adult register (the server shows a trip to adults only), so a child's
/// device and the wall fetch nothing for it.
final _tripNoticesProvider = Provider.autoDispose<AsyncValue<List<AppNotice>>>((
  ref,
) {
  if (!ref.watch(shoppingStartSupportedProvider) ||
      ref.watch(uiRegisterProvider) != UiRegister.adult) {
    return const AsyncData([]);
  }
  return ref.watch(noticesProvider);
});

/// Opens the Shopping tab on [listId] (the default list for null or a list that is gone).
void openShoppingList(WidgetRef ref, String? listId) {
  ref.read(selectedListIdProvider.notifier).select(listId);
  ref.read(homeTabProvider.notifier).select(HomeTab.shopping);
}

/// Says "Sabine geht einkaufen" the moment the server's notice arrives (specs/07 "Telling
/// the others"): a banner with *Zur Liste* while the app is in front, a local
/// notification on a personal phone while it runs out of sight. No push exists (specs/14
/// Q47), so a closed app learns it from the notice on Today when it is opened.
///
/// The notices already on Today when the app starts, or when another person takes the
/// device, are not announced: the card says it. Each trip is announced once.
class ShoppingStartHost extends ConsumerStatefulWidget {
  const ShoppingStartHost({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<ShoppingStartHost> createState() => _ShoppingStartHostState();
}

class _ShoppingStartHostState extends ConsumerState<ShoppingStartHost>
    with WidgetsBindingObserver {
  /// The trips this device has shown or announced, by notice key.
  final _known = <String>{};

  /// False until the first list of notices for the person at the device has arrived.
  bool _listening = false;

  /// What arrived while the app was out of sight and could not be shown as a
  /// notification: said in the banner when the app comes back.
  AppNotice? _waiting;

  bool _front =
      WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _front = state == AppLifecycleState.resumed;
    // What waited is said once the notices have been fetched again, and only if the
    // trip still runs then (see [_onNotices]).
    if (_front && _waiting != null) ref.invalidate(noticesProvider);
  }

  void _onNotices(List<AppNotice> notices) {
    final trips = [
      for (final n in notices)
        if (n.kind == NoticeKind.shopping) n,
    ];
    if (!_listening) {
      _listening = true;
      _known.addAll(trips.map((n) => n.key));
      return;
    }
    final waiting = _waiting;
    if (_front && waiting != null) {
      _waiting = null;
      if (trips.any((n) => n.key == waiting.key)) _banner(waiting);
    }
    for (final trip in trips) {
      if (!_known.add(trip.key)) continue;
      if (_front) {
        _banner(trip);
      } else {
        unawaited(_notify(trip));
      }
    }
  }

  void _banner(AppNotice trip) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final l10n = context.l10n;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: ValueKey('shopping-start-${trip.key}'),
          // Long enough to read and reach for, and it goes by itself.
          duration: const Duration(seconds: 10),
          persist: false,
          content: Text(
            l10n.todayNoticeShopping(trip.name, trip.listName ?? ''),
          ),
          action: SnackBarAction(
            label: l10n.todayNoticeShoppingList,
            onPressed: () {
              // Whatever page is open, the list is on the home shell's Shopping tab.
              ref.read(routerProvider).go(Routes.home);
              openShoppingList(ref, trip.listId);
            },
          ),
        ),
      );
  }

  /// A local notification, where the phone may show one; else the banner waits for the
  /// app to come back.
  Future<void> _notify(AppNotice trip) async {
    final NotificationScheduler scheduler = ref.read(
      notificationSchedulerProvider,
    );
    final personal =
        ref.read(deviceProvider).value?.deviceClass == DeviceClass.personal;
    try {
      if (personal && scheduler.available) {
        final l10n = reminderL10n(ref.read(appLocaleProvider));
        await scheduler.init(channelName: l10n.reminderChannelName);
        if (await scheduler.permissionGranted()) {
          await scheduler.show(
            id: shoppingStartNotificationId(trip.key),
            title: l10n.shoppingStartNotifyTitle(trip.name),
            body: l10n.shoppingStartNotifyBody(trip.listName ?? ''),
          );
          return;
        }
      }
    } on Object catch (error, stack) {
      logError('Shopping notification failed', error: error, stackTrace: stack);
    }
    _waiting = trip;
  }

  @override
  Widget build(BuildContext context) {
    // Another person at a shared device: their notices are a new start.
    ref
      ..listen(actingProfileProvider, (_, _) {
        _listening = false;
        _known.clear();
        _waiting = null;
      })
      ..listen(_tripNoticesProvider, (_, next) {
        // Not while a refetch is on its way: that state still carries the old list,
        // and a trip that ended meanwhile would be announced from it.
        if (next case AsyncData(:final value) when !next.isLoading) {
          _onNotices(value);
        }
      });
    return widget.child;
  }
}

/// A notification id for a trip, in a range of its own above the planned reminders'.
int shoppingStartNotificationId(String key) => 900000 + (key.hashCode & 0xFFFF);
