import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/bootstrap.dart';
import 'package:wuselwall/app/server_session.dart';
import 'package:wuselwall/core/config/app_config.dart';
import 'package:wuselwall/core/config/config_providers.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/server/server_discovery.dart';
import 'package:wuselwall/core/server/server_info.dart';
import 'package:wuselwall/core/server/server_store.dart';

const _store = AppConfig(
  environment: 'store',
  supabaseUrl: '',
  supabasePublishableKey: '',
);

ServerInfo _server({
  int api = 1,
  String min = '1.0.0',
  String host = 'api.example.org',
}) => ServerInfo(
  supabaseUrl: Uri.parse('https://$host'),
  publishableKey: 'sb_publishable_$host',
  apiVersion: api,
  minAppVersion: min,
);

class _Discovery extends ServerDiscovery {
  _Discovery(this.answers);

  final Map<String, Result<ServerInfo>> answers;
  final asked = <Uri>[];

  @override
  Future<Result<ServerInfo>> discover(Uri origin) async {
    asked.add(origin);
    return answers[origin.host] ?? const Err(NetworkFailure());
  }
}

class _Store extends ServerStore {
  _Store() : super(storage: const FlutterSecureStorage());

  ServerInfo? kept;

  @override
  Future<ServerInfo?> read() async => kept;

  @override
  Future<void> write(ServerInfo server) async => kept = server;

  @override
  Future<void> clear() async => kept = null;
}

/// Stands in for the app: shows which server it runs on, and offers the way out.
class _App extends ConsumerWidget {
  const _App();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final leave = ref.watch(serverSessionProvider).leave;
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            Text('running on ${config.supabaseUrl}'),
            if (leave != null)
              TextButton(onPressed: leave, child: const Text('leave')),
          ],
        ),
      ),
    );
  }
}

void main() {
  late List<AppConfig> connected;
  late _Store store;

  setUp(() {
    connected = [];
    store = _Store();
  });

  Future<_Discovery> pump(
    WidgetTester t, {
    Map<String, Result<ServerInfo>> answers = const {},
    AppConfig build = _store,
    String appVersion = '1.0.0',
    bool hasSession = false,
  }) async {
    final discovery = _Discovery(answers);
    // German, the default language (specs/09).
    t.platformDispatcher.localesTestValue = const [Locale('de')];
    addTearDown(t.platformDispatcher.clearLocalesTestValue);
    await t.pumpWidget(
      Bootstrap(
        build: build,
        store: store,
        discovery: discovery,
        appVersion: () async => appVersion,
        connect: (c) async => connected.add(c),
        disconnect: () async {},
        hasSession: () async => hasSession,
        signOutLocally: () async {},
        app: const _App(),
      ),
    );
    await t.pumpAndSettle();
    return discovery;
  }

  testWidgets('a store build asks which server, then runs on it', (t) async {
    await pump(t, answers: {'api.example.org': Ok(_server())});
    expect(find.text('Mit welchem Server?'), findsOneWidget);

    await t.enterText(
      find.byKey(const ValueKey('server-address')),
      'api.example.org',
    );
    await t.tap(find.byKey(const ValueKey('server-connect')));
    await t.pumpAndSettle();

    expect(find.text('running on https://api.example.org'), findsOneWidget);
    expect(
      connected.single.supabasePublishableKey,
      'sb_publishable_api.example.org',
    );
    expect(store.kept?.supabaseUrl.host, 'api.example.org');
  });

  testWidgets('a hosted Supabase project ID is enough', (t) async {
    final discovery = await pump(
      t,
      answers: {
        'abcdefghijklmnopqrst.supabase.co': Ok(
          _server(host: 'abcdefghijklmnopqrst.supabase.co'),
        ),
      },
    );
    await t.enterText(
      find.byKey(const ValueKey('server-address')),
      'abcdefghijklmnopqrst',
    );
    await t.tap(find.byKey(const ValueKey('server-connect')));
    await t.pumpAndSettle();
    expect(discovery.asked.single.host, 'abcdefghijklmnopqrst.supabase.co');
    expect(find.textContaining('running on'), findsOneWidget);
  });

  testWidgets('the server chosen before starts at once and is checked again', (
    t,
  ) async {
    store.kept = _server();
    final discovery = await pump(
      t,
      answers: {'api.example.org': Ok(_server())},
    );
    expect(find.text('running on https://api.example.org'), findsOneWidget);
    expect(discovery.asked, [Uri.parse('https://api.example.org')]);
  });

  testWidgets('a server this app no longer fits stops the app', (t) async {
    store.kept = _server();
    await pump(t, answers: {'api.example.org': Ok(_server(min: '9.0.0'))});
    expect(find.text('Server und App passen nicht zusammen'), findsOneWidget);
    expect(find.textContaining('neuere Version der App'), findsOneWidget);

    await t.tap(find.text('Anderen Server wählen'));
    await t.pumpAndSettle();
    expect(find.text('Mit welchem Server?'), findsOneWidget);
    expect(store.kept, isNull);
  });

  testWidgets('problems are said in words, and nothing is kept', (t) async {
    await pump(
      t,
      answers: {
        'old.example.org': Ok(_server(api: -5, host: 'old.example.org')),
        'blog.example.org': const Err(NotFoundFailure(code: 'not_wuselwall')),
      },
    );
    Future<void> tryAddress(String a) async {
      await t.enterText(find.byKey(const ValueKey('server-address')), a);
      await t.tap(find.byKey(const ValueKey('server-connect')));
      await t.pumpAndSettle();
    }

    await tryAddress('not an address');
    expect(find.text('Das ist keine Serveradresse.'), findsOneWidget);
    await tryAddress('blog.example.org');
    expect(
      find.text('Unter dieser Adresse läuft kein WuselWall-Server.'),
      findsOneWidget,
    );
    await tryAddress('old.example.org');
    expect(
      find.textContaining('Dieser Server braucht ein Update'),
      findsOneWidget,
    );
    await tryAddress('offline.example.org');
    expect(find.textContaining('Der Server antwortet nicht'), findsOneWidget);
    expect(store.kept, isNull);
    expect(connected, isEmpty);
  });

  testWidgets('leaving a server forgets it and asks again', (t) async {
    store.kept = _server();
    await pump(t, answers: {'api.example.org': Ok(_server())});
    await t.tap(find.text('leave'));
    await t.pumpAndSettle();
    expect(find.text('Mit welchem Server?'), findsOneWidget);
    expect(store.kept, isNull);
  });

  testWidgets('a build that names its server never asks and cannot leave', (
    t,
  ) async {
    await pump(
      t,
      build: const AppConfig(
        environment: 'dev',
        supabaseUrl: 'https://api.example.org',
        supabasePublishableKey: 'key',
      ),
    );
    expect(find.text('running on https://api.example.org'), findsOneWidget);
    expect(find.text('leave'), findsNothing);
  });

  testWidgets('the demo household runs without a server, and has a way out', (
    t,
  ) async {
    await pump(t);
    await t.tap(find.byKey(const ValueKey('server-demo')));
    await t.pumpAndSettle();
    expect(
      find.text('Beispielfamilie: nichts wird gespeichert'),
      findsOneWidget,
    );
    expect(connected, isEmpty, reason: 'no server is contacted');

    await t.tap(find.byKey(const ValueKey('demo-exit')));
    await t.pumpAndSettle();
    expect(find.text('Mit welchem Server?'), findsOneWidget);
  });
}
