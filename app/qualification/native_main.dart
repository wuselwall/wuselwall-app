// Separate synthetic-data entry point. Never compiled by a store build.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/router.dart';

import 'fixture.dart';
import 'inventory.g.dart';

const _port = 18765;
final _mountKey = GlobalKey();
final _results = <Map<String, dynamic>>[];
final _errors = <String>[];
final _input = TextEditingController();
var _index = -1;
var _ready = false;
var _busy = false;
var _textScale = 1.0;
late List<Map<String, dynamic>> _cases;

Map<String, dynamic> _state() => {
  'schemaVersion': 1,
  'candidateSha': const String.fromEnvironment('QUALIFY_CANDIDATE_SHA'),
  'index': _index,
  'expected': _cases.length,
  'done': _index >= _cases.length,
  'ready': _ready,
  if (_index >= 0 && _index < _cases.length) ..._cases[_index],
  'input': _input.text,
  'textScale': _textScale,
  'physicalWidth':
      WidgetsBinding.instance.platformDispatcher.views.first.physicalSize.width,
  'physicalHeight': WidgetsBinding
      .instance
      .platformDispatcher
      .views
      .first
      .physicalSize
      .height,
  'devicePixelRatio':
      WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio,
  'frameworkErrors': [..._errors],
  'results': _results,
};

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    _errors.add(details.exceptionAsString());
    previous?.call(details);
  };
  const tablet = bool.fromEnvironment('QUALIFY_TABLET');
  const smoke = bool.fromEnvironment('QUALIFY_SMOKE');
  final states = (jsonDecode(nativeStatesJson) as List)
      .cast<Map<String, dynamic>>()
      .where((s) => tablet || !['kid', 'kiosk'].contains(s['scenario']));
  _cases = [
    {'id': 'detector-bad', 'control': 'bad'},
    {'id': 'detector-keyboard', 'control': 'keyboard'},
    for (final locale in smoke ? ['de'] : ['de', 'en', 'fr', 'es'])
      for (final shade in smoke ? ['light'] : ['light', 'dark'])
        for (final sample in states)
          {
            ...sample,
            'id': '${sample['id']}-$locale-$shade',
            'stateId': sample['id'],
            'locale': locale,
            'shade': shade,
          },
  ];
  runApp(const SizedBox.shrink());
  _saveReport();
  // Only the simulator/emulator loopback interface; no LAN access or server data.
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, _port);
  await for (final request in server) {
    request.response.headers.contentType = ContentType.json;
    try {
      if (request.method == 'GET' && request.uri.path == '/state') {
        request.response.write(jsonEncode(_state()));
      } else if (request.method == 'POST' &&
          request.uri.path == '/next' &&
          !_busy) {
        _busy = true;
        _ready = false;
        _index++;
        _saveReport();
        request.response.write(jsonEncode({'accepted': true}));
        unawaited(
          _showCase()
              .catchError((Object error, StackTrace stack) {
                _errors.add('$error');
                _ready = true;
              })
              .whenComplete(() => _busy = false),
        );
      } else if (request.method == 'POST' &&
          request.uri.path == '/result' &&
          _ready) {
        final body = await utf8.decoder.bind(request).join();
        if (body.length > 1024 * 1024) {
          throw const FormatException('Result too large');
        }
        final result = jsonDecode(body) as Map<String, dynamic>;
        if (result['id'] != _cases[_index]['id']) {
          throw const FormatException('Case mismatch');
        }
        _results.add({
          ...result,
          'frameworkErrors': [..._errors],
          'textScale': _textScale,
        });
        _saveReport();
        request.response.write('{"accepted":true}');
      } else {
        request.response.statusCode = HttpStatus.conflict;
        request.response.write('{"error":"Unexpected audit request"}');
      }
    } catch (error) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write(jsonEncode({'error': '$error'}));
    }
    await request.response.close();
  }
}

void _saveReport() {
  File('${Directory.systemTemp.path}/native-audit.json')
      .writeAsStringSync(jsonEncode(_state()));
}

Future<void> _showCase() async {
  runApp(const SizedBox.shrink());
  await WidgetsBinding.instance.endOfFrame;
  _errors.clear();
  if (_index >= _cases.length) return;
  final sample = _cases[_index];
  if (sample['control'] != null) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: sample['control'] == 'bad'
                ? Semantics(
                    identifier: 'native-bad-action',
                    button: true,
                    onTap: () {},
                    child: const SizedBox(width: 12, height: 12),
                  )
                : SizedBox(
                    width: 260,
                    child: Semantics(
                      identifier: 'native-keyboard-field',
                      child: TextField(
                        controller: _input,
                        decoration: const InputDecoration(
                          labelText: 'Native audit input',
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  } else {
    runApp(
      KeyedSubtree(
        key: _mountKey,
        child: qualificationApp(
          stateId: sample['stateId'] as String,
          scenario: sample['scenario'] as String,
          locale: Locale(sample['locale'] as String),
          shade: sample['shade'] as String,
          tab: sample['tab'] as String? ?? 'today',
        ),
      ),
    );
    await WidgetsBinding.instance.endOfFrame;
    if (sample['route'] != '/') {
      // The fixture's root router is found below the keyed scope.
      ProviderContainer? container;
      void visit(Element element) {
        if (element.widget is UncontrolledProviderScope) {
          container ??= (element.widget as UncontrolledProviderScope).container;
        }
        element.visitChildren(visit);
      }

      (_mountKey.currentContext! as Element).visitChildren(visit);
      container!.read(routerProvider).go(sample['route'] as String);
    }
  }
  for (var attempt = 0; attempt < 100; attempt++) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    var found = sample['control'] != null;
    void visit(Element element) {
      if (sample['widget'] != null &&
          isQualificationDestination(
            element.widget,
            sample['widget'] as String,
          )) {
        found = true;
      }
      _textScale = MediaQuery.maybeTextScalerOf(element)?.scale(16) != null
          ? MediaQuery.textScalerOf(element).scale(16) / 16
          : _textScale;
      element.visitChildren(visit);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(visit);
    if (found) {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      _ready = true;
      return;
    }
  }
  _errors.add('Destination failed to appear');
  _ready = true; // Auditor records and fails the case; never silently drops it.
}
