import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/server/server_providers.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/core/ui/content_width.dart';
import 'package:wuselwall/core/ui/empty_view.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/ui/guardian_gate.dart';
import 'package:wuselwall/features/services/application/service_actions.dart';
import 'package:wuselwall/features/services/application/service_providers.dart';
import 'package:wuselwall/features/services/domain/service_models.dart';
import 'package:wuselwall/features/services/ui/service_provider_card.dart';
import 'package:wuselwall/features/services/ui/trip_home_editor.dart';
import 'package:wuselwall/features/settings/application/settings_view.dart';
import 'package:wuselwall/features/settings/ui/settings_view_switch.dart';

/// Wetter und Karten (`Routes.servicesSettings`): a guardian switches providers on and
/// off, stores their keys and sets the home place (ADR-023, specs/30 "Services"). Others
/// see the same state read-only.
class ServicesPage extends ConsumerWidget {
  const ServicesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final available =
        ref.watch(servicesSupportedProvider) &&
        ref.watch(uiRegisterProvider) == UiRegister.adult;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.serviceTitle),
        leading: BackButton(onPressed: () => context.go(Routes.settings)),
        actions: const [SettingsViewSwitch()],
      ),
      body: ContentWidth(
        child: !available
            ? EmptyView(illustrated: false, message: l10n.serviceUnavailable)
            : AsyncValueView<List<ServiceProviderView>>(
                value: ref.watch(serviceSetupProvider),
                onRetry: () {
                  ref
                    ..invalidate(serviceCatalogueProvider)
                    ..invalidate(serviceStatesProvider);
                },
                data: (views) => _content(context, ref, views),
              ),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    WidgetRef ref,
    List<ServiceProviderView> views,
  ) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final canEdit = ref.watch(actingGuardianProvider);
    final advanced = ref.watch(showAdvancedSettingsProvider);
    final enabled = [
      for (final v in views)
        if (v.enabled) v,
    ];
    final lastPosition = [
      for (final v in views)
        if (v.state != null) v.state!.position,
    ].fold<int>(-1, (a, b) => a > b ? a : b);
    return ListView(
      padding: const EdgeInsets.all(Tokens.space4),
      children: [
        Text(l10n.serviceIntro),
        if (!canEdit)
          Padding(
            padding: const EdgeInsets.only(top: Tokens.space2),
            child: Text(
              l10n.serviceReadOnly,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.ww.ink2,
              ),
            ),
          ),
        const SizedBox(height: Tokens.space4),
        TripHomeEditor(canEdit: canEdit),
        const SizedBox(height: Tokens.space4),
        Semantics(
          header: true,
          child: Text(
            l10n.serviceProvidersHeading,
            style: theme.textTheme.titleMedium,
          ),
        ),
        if (advanced && canEdit)
          Padding(
            padding: const EdgeInsets.only(top: Tokens.space1),
            child: Text(
              l10n.serviceOrderHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.ww.ink2,
              ),
            ),
          ),
        const SizedBox(height: Tokens.space2),
        if (views.isEmpty)
          Text(l10n.serviceNoProviders)
        else
          for (final v in views)
            ServiceProviderCard(
              key: ValueKey('service-${v.info.id}'),
              view: v,
              canEdit: canEdit,
              advanced: advanced,
              nextPosition: lastPosition + 1,
              onMoveUp: _canMove(enabled, v, -1)
                  ? () => _move(context, ref, enabled, v, -1)
                  : null,
              onMoveDown: _canMove(enabled, v, 1)
                  ? () => _move(context, ref, enabled, v, 1)
                  : null,
            ),
        const SizedBox(height: Tokens.space2),
        Text(
          l10n.serviceClosing,
          style: theme.textTheme.bodySmall?.copyWith(color: context.ww.ink2),
        ),
      ],
    );
  }

  bool _canMove(
    List<ServiceProviderView> enabled,
    ServiceProviderView v,
    int by,
  ) {
    final i = enabled.indexOf(v);
    return i >= 0 && i + by >= 0 && i + by < enabled.length;
  }

  /// Moves [v] by one place in the order the enabled providers are asked in and writes the
  /// positions that changed, so equal or gapped positions end up 0, 1, 2 ...
  Future<void> _move(
    BuildContext context,
    WidgetRef ref,
    List<ServiceProviderView> enabled,
    ServiceProviderView v,
    int by,
  ) async {
    if (!await ensureGuardian(context, ref) || !context.mounted) return;
    final order = [...enabled];
    final i = order.indexOf(v);
    order.insert(i + by, order.removeAt(i));
    for (final (position, view) in order.indexed) {
      if (view.state?.position == position) continue;
      final result = await ref
          .read(serviceActionsProvider)
          .setProvider(view.info.id, position: position);
      if (!context.mounted) return;
      if (result case Err(:final failure)) {
        context.showFailure(failure);
        return;
      }
    }
  }
}
