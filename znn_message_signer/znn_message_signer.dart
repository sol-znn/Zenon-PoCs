// znn_message_signer.dart
// Dart PoC to sign an arbitrary message with a Zenon private key
// Output can be reversed to derive source address

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:hex/hex.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';
import 'package:path/path.dart' as p;
import "package:os_detect/os_detect.dart" as Platform;

var node = "wss://node.zenon.fun:35998";
final Zenon znnClient = Zenon();

var msg = "Test"; // <----- Type your message here
var pass = "";    // <----- Password for your address/keystore
var keyStore = 0; // <----- Select correct KeyStore, default is 0

Future<void> getArgon2() async {
  var fileExists = false;
  var lib;
  if (Platform.isWindows) { lib = 'argon2_ffi_plugin.dll'; }
  if (Platform.isLinux)   { lib = 'libargon2_ffi_plugin.so'; }
  if (Platform.isMacOS)   { lib = 'libargon2_ffi.dylib'; }
  fileExists = await File(p.join(Directory.current.path, lib)).exists();

  if (fileExists == false) {
    var packageConfigPath = p.join(
        Directory.current.path, '.dart_tool', 'package_config.json');
    File packageConfig = File(packageConfigPath);
    var packageConfigContent = await packageConfig.readAsLines();
    var match;
    packageConfigContent.forEach((line) {
      if (line.contains("znn_sdk_dart")) {
        match = line;
      }
    });

    if (match
        .toString()
        .isNotEmpty) {
      var startIndex, endIndex;
      if (Platform.isWindows) {
        startIndex = match.toString().indexOf("C:/");
        endIndex = match.toString().lastIndexOf("/");
      }
      if (Platform.isLinux) { //to be tested
        startIndex = match.toString().indexOf("//");
        endIndex = match.toString().lastIndexOf("/");
      }
      if (Platform.isMacOS) { //to be tested
        startIndex = match.toString().indexOf("//");
        endIndex = match.toString().lastIndexOf("/");
      }
      match = match.toString().substring(startIndex, endIndex) +
          "/lib/src/argon2/blobs/" + lib;
      await File(match).copy(p.join(Directory.current.path, lib));
    }
    else {
      print(
          "Could not find a path to " + lib + ". Try downloading it from znn_sdk_dart and copying it to this directory.");
    }
  }
  else {
    print("Found argon2 library!");
  }
}

Future<int> main(List<String> args) async {

  await znnClient.wsClient.initialize(node, retry: false);
  await getArgon2();

  List<File> allKeyStores = await znnClient.keyStoreManager.listAllKeyStores();
  File keyStoreFile = allKeyStores[keyStore];

  znnClient.defaultKeyStore = await znnClient.keyStoreManager.readKeyStore(pass, keyStoreFile);
  znnClient.defaultKeyStorePath = keyStoreFile;
  znnClient.defaultKeyPair = znnClient.defaultKeyStore!.getKeyPair(0);
  var address = await znnClient.defaultKeyPair!.address;

  List<int> signature = await znnClient.defaultKeyPair!.sign(msg.codeUnits);
  var sig = BytesUtils.bytesToHex(signature);
  List<int> getPK = await znnClient.defaultKeyPair!.getPublicKey();
  var pk = BytesUtils.bytesToHex(getPK);

  print ("add=${address}");
  print ("msg=${msg}");
  print ("sig=${sig}");
  print ("pk=${pk}");
  List<int> decodeHexString(String input) => HEX.decode(input);

  bool verified = await Crypto.verify(
    decodeHexString(sig),
    Uint8List.fromList(msg.codeUnits),
    decodeHexString(pk),
  );

  print("Verified=${verified}");
  print("Address.fromPublicKey(publicKey!) = ${Address.fromPublicKey(getPK)}");

  znnClient.wsClient.stop();
  return 0;
}




