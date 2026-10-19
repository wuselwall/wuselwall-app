import 'dart:async';

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
import 'package:wuselwall/core/server/setup_link.dart';
import 'package:wuselwall/core/server/setup_store.dart';
import 'package:wuselwall/core/supabase/secure_session_storage.dart';

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
    final session = ref.watch(serverSessionProvider);
    final leave = session.leave;
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            ValueListenableBuilder<LinkEvent?>(
              valueListenable: session.inbox,
              builder: (_, event, _) => Text(
                event == null
                    ? 'no link'
                    : 'link ${event.link.kind.name} ${event.link.secret} '
                          '${event.verdict.name}',
              ),
            ),
            Text('setup ${session.setupPending.value}'),
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
    FlutterSecureStorage.setMockInitialValues({});
    connected = [];
    store = _Store();
  });

  Future<_Discovery> pump(
    WidgetTester t, {
    Map<String, Result<ServerInfo>> answers = const {},
    AppConfig build = _store,
    String appVersion = '1.0.0',
    bool hasSession = false,
    Stream<String>? links,
    SetupLink? initialSetup,
    Uri? webOrigin,
  }) async {
    final discovery = _Discovery(answers);
    // German, the default language (specs/09).
    t.platformDispatcher.localesTestValue = const [Locale('de')];
    addTearDown(t.platformDispatcher.clearLocalesTestValue);
    await t.pumpWidget(
      Bootstrap(
        build: build,
        initialSetup: initialSetup,
        webOrigin: webOrigin,
        store: store,
        discovery: discovery,
        appVersion: () async => appVersion,
        connect: (c) async => connected.add(c),
        disconnect: () async {},
        hasSession: () async => hasSession,
        signOutLocally: () async {},
        links: links,
        app: const _App(),
      ),
    );
    await t.pumpAndSettle();
    return discovery;
  }

  testWidgets(
    'web discovery replaces a retired cached backend before connecting',
    (t) async {
      store.kept = _server(host: 'retired.example.org');
      final discovery = await pump(
        t,
        webOrigin: Uri.parse('https://web.example.org'),
        answers: {'web.example.org': Ok(_server())},
      );

      expect(connected.single.supabaseUrl, 'https://api.example.org');
      expect(
        connected.single.supabasePublishableKey,
        'sb_publishable_api.example.org',
      );
      expect(discovery.asked, [Uri.parse('https://web.example.org')]);
      expect(store.kept?.supabaseUrl.host, 'api.example.org');
    },
  );

  testWidgets('web refreshes a rotated publishable key on the first reload', (
    t,
  ) async {
    store.kept = ServerInfo(
      supabaseUrl: Uri.parse('https://api.example.org'),
      publishableKey: 'retired-public-key',
      apiVersion: 1,
      minAppVersion: '1.0.0',
    );
    final sessions = SecureSessionStorage();
    await sessions.persistSession('same-server-session');
    await pump(
      t,
      webOrigin: Uri.parse('https://web.example.org'),
      answers: {'web.example.org': Ok(_server())},
    );
    expect(
      connected.single.supabasePublishableKey,
      'sb_publishable_api.example.org',
    );
    expect(await sessions.accessToken(), 'same-server-session');
  });

  testWidgets(
    'web backend migration cannot forward the retired session or setup',
    (t) async {
      store.kept = _server(host: 'retired.example.org');
      final retired = store.kept!.supabaseUrl;
      final sessions = SecureSessionStorage();
      await sessions.persistSession('retired-server-session');
      final setup = SetupStore();
      await setup.save(
        SetupLink(store.kept!.supabaseUrl, '0123456789abcdef01234567'),
      );
      await pump(
        t,
        webOrigin: Uri.parse('https://web.example.org'),
        answers: {'web.example.org': Ok(_server())},
      );
      expect(await sessions.hasAccessToken(), isFalse);
      expect(await setup.read(retired), isNull);
      expect(find.text('setup false'), findsOneWidget);
    },
  );

  testWidgets('web keeps the cached backend and session when offline', (
    t,
  ) async {
    store.kept = _server();
    final sessions = SecureSessionStorage();
    await sessions.persistSession('offline-session');
    await pump(t, webOrigin: Uri.parse('https://web.example.org'));
    expect(connected.single.supabaseUrl, 'https://api.example.org');
    expect(await sessions.accessToken(), 'offline-session');
  });

  testWidgets('web does not use stale cache for an incompatible installation', (
    t,
  ) async {
    store.kept = _server();
    await pump(
      t,
      webOrigin: Uri.parse('https://web.example.org'),
      answers: {'web.example.org': Ok(_server(min: '99.0.0'))},
    );
    expect(connected, isEmpty);
    expect(find.textContaining('braucht eine neuere Version'), findsOneWidget);
  });

  testWidgets(
    'web setup capability survives refreshing the old cached backend',
    (t) async {
      store.kept = _server(host: 'retired.example.org');
      final setup = SetupLink(
        _server().supabaseUrl,
        '0123456789abcdef01234567',
      );
      await pump(
        t,
        webOrigin: Uri.parse('https://web.example.org'),
        initialSetup: setup,
        answers: {'web.example.org': Ok(_server())},
      );
      expect(find.text('setup true'), findsOneWidget);
      expect(await SetupStore().read(setup.server), setup.token);
    },
  );

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

  testWidgets(
    'setup link chooses API and keeps capability without a link inbox secret',
    (t) async {
      const token = '0123456789abcdef01234567';
      await pump(t, answers: {'api.example.org': Ok(_server())});
      await t.enterText(
        find.byKey(const ValueKey('server-address')),
        'https://web.example.org/#setup=$token&server=https%3A%2F%2Fapi.example.org',
      );
      await t.tap(find.byKey(const ValueKey('server-connect')));
      await t.pumpAndSettle();
      expect(find.text('setup true'), findsOneWidget);
      expect(find.text('no link'), findsOneWidget);
      expect(
        await SetupStore().read(Uri.parse('https://api.example.org')),
        token,
      );
      await t.tap(find.text('leave'));
      await t.pumpAndSettle();
      expect(
        await SetupStore().read(Uri.parse('https://api.example.org')),
        isNull,
      );
    },
  );

  testWidgets('web setup reload restores only the chosen server capability', (
    t,
  ) async {
    final setup = SetupLink(
      Uri.parse('https://api.example.org'),
      '0123456789abcdef01234567',
    );
    await pump(
      t,
      answers: {'api.example.org': Ok(_server())},
      initialSetup: setup,
    );
    expect(find.text('setup true'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await pump(t, answers: {'api.example.org': Ok(_server())});
    expect(find.text('setup true'), findsOneWidget);
  });

  testWidgets(
    'a fixed-server web build captures only its own setup capability',
    (t) async {
      const build = AppConfig(
        environment: 'dev',
        supabaseUrl: 'https://api.example.org',
        supabasePublishableKey: 'key',
      );
      await pump(
        t,
        build: build,
        initialSetup: SetupLink(
          Uri.parse(build.supabaseUrl),
          '0123456789abcdef01234567',
        ),
      );
      expect(find.text('setup true'), findsOneWidget);
    },
  );

  testWidgets('setup link cannot silently replace a stored server', (t) async {
    store.kept = _server();
    await pump(
      t,
      answers: {'api.example.org': Ok(_server())},
      initialSetup: SetupLink(
        Uri.parse('https://other.example.org'),
        '0123456789abcdef01234567',
      ),
    );
    expect(find.text('setup false'), findsOneWidget);
    expect(find.text('running on https://api.example.org'), findsOneWidget);
  });

  testWidgets('a native opened setup link starts the same setup flow', (
    t,
  ) async {
    const token = '0123456789abcdef01234567';
    final links = StreamController<String>();
    addTearDown(links.close);
    await pump(
      t,
      answers: {'api.example.org': Ok(_server())},
      links: links.stream,
    );
    links.add(
      'https://web.example.org/#setup=$token&server=https://api.example.org',
    );
    await t.pumpAndSettle();
    expect(find.text('setup true'), findsOneWidget);
    expect(
      await SetupStore().read(Uri.parse('https://api.example.org')),
      token,
    );
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

  group('links', () {
    const code = 'K7QM3XRP';
    String invite(String host) => 'https://wuselwall.app/i/#$code@$host';

    testWidgets('an invitation link opened first skips the server question', (
      t,
    ) async {
      final links = StreamController<String>();
      addTearDown(links.close);
      await pump(
        t,
        answers: {'api.example.org': Ok(_server())},
        links: links.stream,
      );
      // The question is up while the app waits for a link.
      links.add(invite('api.example.org'));
      await t.pumpAndSettle();

      expect(find.text('Mit welchem Server?'), findsNothing);
      expect(find.text('running on https://api.example.org'), findsOneWidget);
      expect(find.text('link invitation $code proceed'), findsOneWidget);
      expect(store.kept?.supabaseUrl.host, 'api.example.org');
    });

    testWidgets(
      'the same checks as a typed address apply to the link\'s server',
      (t) async {
        final links = StreamController<String>();
        addTearDown(links.close);
        await pump(
          t,
          answers: {
            'old.example.org': Ok(_server(api: -5, host: 'old.example.org')),
          },
          links: links.stream,
        );
        links.add(invite('old.example.org'));
        await t.pumpAndSettle();

        expect(
          find.textContaining('Dieser Server braucht ein Update'),
          findsOneWidget,
        );
        expect(find.textContaining('running on'), findsNothing);
        expect(store.kept, isNull);
      },
    );

    testWidgets('a link of the server the app is on continues directly', (
      t,
    ) async {
      store.kept = _server();
      final links = StreamController<String>();
      addTearDown(links.close);
      await pump(
        t,
        answers: {'api.example.org': Ok(_server())},
        links: links.stream,
      );
      links.add('https://wuselwall.app/p/#$code@api.example.org');
      await t.pumpAndSettle();
      expect(find.text('link pairing $code proceed'), findsOneWidget);
    });

    testWidgets('a link of another server is handed over, not followed', (
      t,
    ) async {
      store.kept = _server();
      final links = StreamController<String>();
      addTearDown(links.close);
      await pump(
        t,
        answers: {
          'api.example.org': Ok(_server()),
          'other.example.org': Ok(_server(host: 'other.example.org')),
        },
        links: links.stream,
      );
      links.add(invite('other.example.org'));
      await t.pumpAndSettle();
      expect(find.text('link invitation $code offerSwitch'), findsOneWidget);
      expect(find.text('running on https://api.example.org'), findsOneWidget);
      expect(store.kept?.supabaseUrl.host, 'api.example.org');
    });

    testWidgets('signed in, another server\'s link is explained only', (
      t,
    ) async {
      store.kept = _server();
      final links = StreamController<String>();
      addTearDown(links.close);
      await pump(
        t,
        answers: {'api.example.org': Ok(_server())},
        hasSession: true,
        links: links.stream,
      );
      links.add(invite('other.example.org'));
      await t.pumpAndSettle();
      expect(find.text('link invitation $code otherServer'), findsOneWidget);
    });

    testWidgets('a link without a server, with none chosen, asks for one', (
      t,
    ) async {
      final links = StreamController<String>();
      addTearDown(links.close);
      await pump(t, links: links.stream);
      links.add('https://wuselwall.app/i/#$code');
      await t.pumpAndSettle();
      expect(find.text('Mit welchem Server?'), findsOneWidget);
      expect(
        find.textContaining('sagt nicht, zu welchem Server'),
        findsOneWidget,
      );
    });

    testWidgets('an invitation pasted as the server address carries on', (
      t,
    ) async {
      await pump(t, answers: {'api.example.org': Ok(_server())});
      await t.enterText(
        find.byKey(const ValueKey('server-address')),
        invite('api.example.org'),
      );
      await t.tap(find.byKey(const ValueKey('server-connect')));
      await t.pumpAndSettle();
      expect(find.text('link invitation $code proceed'), findsOneWidget);
    });
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
