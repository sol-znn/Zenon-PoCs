import 'dart:isolate';
import 'dart:io';

import 'package:synchronized/synchronized.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

int queueSize = 10;
int jobs = 47;
int addressesPerMnemonic = 5;

final filename = 'results.txt';

// regex: (.)\1{2}$

generateAddresses(port) async {
  var store = await KeyStore.newRandom();
  String result = '${store.mnemonic}\n';

  for (var l in await store.deriveAddressesByRange(0, addressesPerMnemonic)) {
    result += '${l.toString()}\n';
  }
  Isolate.exit(port, ('$result\n'));
}

main() async {
  var receivePort = new ReceivePort();
  var lock = new Lock();
  int complete = 0;
  String resultCache = '';

  List<Future<Isolate>> spawns = [];
  for (var i = 0; i++ < queueSize;) {
    spawns.add(Isolate.spawn(generateAddresses, receivePort.sendPort));
  }

  await for (var result in receivePort) {
    stdout.write(result);
    resultCache += result;
    complete++;

    if (complete % 10 == 0) {
      lock.synchronized(() async => await File(filename)
          .writeAsString(resultCache, mode: FileMode.append));
      resultCache = '';
    }

    if (complete >= jobs) {
      if (complete % 10 != 0) {
        lock.synchronized(() async => await File(filename)
            .writeAsString(resultCache, mode: FileMode.append));
      }
      return;
    }
    spawns.add(Isolate.spawn(generateAddresses, receivePort.sendPort));
  }
}
