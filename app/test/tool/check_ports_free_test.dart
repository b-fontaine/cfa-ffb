import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `scripts/check_ports_free.sh` : `check.sh --full` échoue **tôt** et
/// clairement quand un émulateur résiduel tient déjà un port, au lieu de
/// laisser l'étape « Règles Firestore » mourir sur « port taken ».
ProcessResult _run(List<String> ports) =>
    Process.runSync('bash', ['../scripts/check_ports_free.sh', ...ports]);

void main() {
  test('a port held by another process fails with its number', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);

    final result = _run(['${server.port}']);

    expect(result.exitCode, 1);
    expect(result.stderr, contains('${server.port}'));
    expect(result.stderr, contains('émulateur'));
  });

  test('a port held on the IPv6 loopback only fails too', () async {
    // Un émulateur qui n'écoute que sur ::1 échappe à une sonde 127.0.0.1.
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv6, 0);
    addTearDown(server.close);

    final result = _run(['${server.port}']);

    expect(result.exitCode, 1);
    expect(result.stderr, contains('${server.port}'));
  });

  test('a port held on all IPv4 interfaces fails', () async {
    final server = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    addTearDown(server.close);

    expect(_run(['${server.port}']).exitCode, 1);
  });

  test('free ports pass', () async {
    final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = probe.port;
    await probe.close();

    expect(_run(['$port']).exitCode, 0);
  });

  test('without argument, the ports of firebase.json are checked', () {
    final script = File('../scripts/check_ports_free.sh').readAsStringSync();

    expect(script, contains('firebase.json'));
  });

  test('check.sh --full runs it before anything else', () {
    final check = File('../scripts/check.sh').readAsStringSync();

    final ports = check.indexOf('check_ports_free.sh');
    expect(ports, greaterThan(0));
    expect(ports, lessThan(check.indexOf('Génération de code')));
  });
}
