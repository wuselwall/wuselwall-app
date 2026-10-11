import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/register_labels.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/config/config_providers.dart';
import 'package:wuselwall/core/connectivity/connectivity_provider.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/system/data/system_repository.dart';
import 'package:wuselwall/features/system/domain/health_status.dart';

/// Debug-only diagnostics: build configuration, connectivity, and the round trip to the
/// database through `api.health()` — the first proof that a device reaches the backend.
class SystemPage extends ConsumerWidget {
  const SystemPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final config = ref.watch(appConfigProvider);
    final online = ref.watch(connectivityProvider);
    final health = ref.watch(healthProvider);
    final register = ref.watch(uiRegisterProvider);
    final enrolled = ref.watch(isEnrolledProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.systemTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.home),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(Tokens.space4),
        children: [
          _Section(
            title: l10n.systemBuild,
            children: [
              _Row(l10n.systemEnvironment, config.environment),
              _Row(l10n.systemBackendUrl, config.supabaseUrl),
            ],
          ),
          _Section(
            title: l10n.systemConnectivity,
            children: [
              _Row(
                l10n.systemNetwork,
                online.when(
                  data: (v) => v ? l10n.systemOnline : l10n.systemOffline,
                  loading: () => '…',
                  error: (_, _) => l10n.systemUnknown,
                ),
              ),
            ],
          ),
          _Section(
            title: l10n.systemBackend,
            trailing: IconButton(
              tooltip: l10n.retry,
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.invalidate(healthProvider),
            ),
            children: [
              AsyncValueView<HealthStatus>(
                value: health,
                onRetry: () => ref.invalidate(healthProvider),
                data: (h) => Column(
                  children: [
                    _Row(
                      l10n.systemStatus,
                      h.isOk ? l10n.systemStatusOk : h.status,
                    ),
                    _Row(l10n.systemDbVersion, h.dbVersion),
                    _Row(
                      l10n.systemServerTime,
                      h.serverTime.toLocal().toIso8601String(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          _Section(
            title: l10n.systemDevice,
            children: [
              _Row(l10n.systemRegister, register.label(l10n)),
              _Row(l10n.systemEnrolled, enrolled ? l10n.yes : l10n.no),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children, this.trailing});

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: Tokens.space4),
    child: Padding(
      padding: const EdgeInsets.all(Tokens.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: Tokens.space2),
          ...children,
        ],
      ),
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Tokens.space1),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 2, child: Text(label)),
        Expanded(flex: 3, child: SelectableText(value)),
      ],
    ),
  );
}
