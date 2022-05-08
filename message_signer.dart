// message_signer.dat
// Dart PoC to sign an arbitrary message with a Zenon private key
// Output can be reversed to extract source address

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:hex/hex.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

var node = "ws://127.0.0.1:35998";
final Zenon znnClient = Zenon();

var msg = "Test";
var pass = ""; // Password for your address/keystore


Future<int> main(List<String> args) async {

  await znnClient.wsClient.initialize(node, retry: false);

  List<File> allKeyStores = await znnClient.keyStoreManager.listAllKeyStores();
  File keyStoreFile = allKeyStores[2];   // <----- select correct KeyStore, default is 0

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




