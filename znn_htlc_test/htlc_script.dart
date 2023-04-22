import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:convert/convert.dart';
import 'package:path/path.dart' as path;
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

var ws = 'wss://secure.deeznnodez.com:35998';

String address1 = 'z1qr3uww8uqh75qnsuxqajegvwaesqynfglrare2';
String address2 = 'z1qpusrlw26lly6cfwwjcrug5nnw4mkq5rr5h000';
String passphrase1 = 'pass';
String passphrase2 = 'pass';

Hash htlcSpork = Hash.parse(
    'ceb7e3808ef17ea910adda2f3ab547be4cdfb54de8400ce3683258d06be1354b');

TokenStandard token1 = znnZts;
TokenStandard token2 = TokenStandard.parse('zts1gs8cvx7z8dsglk8srtu0nm');

double amount1 = 3.21;
double amount2 = 1;

int totalRuns = 1;

Future<void> unlockWallet(
    Zenon znnClient, String address, String passphrase) async {
  File keyStoreFile = File(path.join(znnDefaultWalletDirectory.path, address));

  int index = 0;
  znnClient.defaultKeyStore =
      await znnClient.keyStoreManager.readKeyStore(passphrase, keyStoreFile);
  znnClient.defaultKeyStorePath = keyStoreFile;
  znnClient.defaultKeyPair = znnClient.defaultKeyStore!.getKeyPair(index);
  var add = await znnClient.defaultKeyPair!.address;
  print('[!] Unlocked address: $add');
}

Future<Map> createHtlc(
    znnClient, timeLockedAddress, hashLockedAddress, tokenStandard, amountInput,
    [String _hashLock = '']) async {
  int expirationTime = 1337;
  int keyMaxSize = htlcPreimageMaxLength;
  int hashType = 0;
  late Hash hashLock;
  Token? token = await znnClient.embedded.token.getByZts(tokenStandard);
  int amount = (amountInput * pow(10, token!.decimals)).toInt();

  List<int> preimage = List<int>.generate(
      htlcPreimageDefaultLength, (i) => Random.secure().nextInt(256));
  if (_hashLock != '') {
    hashLock = Hash.parse(_hashLock);
  } else {
    hashLock = Hash.digest(preimage);
  }

  final duration = Duration(seconds: expirationTime);
  format(Duration d) => d.toString().split('.').first.padLeft(8, '0');
  Momentum currentFrontierMomentum =
      await znnClient.ledger.getFrontierMomentum();
  int currentTime = currentFrontierMomentum.timestamp;
  expirationTime += currentTime;

  if (_hashLock == '') {
    print(
        'Creating htlc with amount $amountInput ${token.symbol} using preimage ${hex.encode(preimage)}');
  } else {
    print('Creating htlc with amount $amountInput ${token.symbol}');
  }
  print('  Can be reclaimed in ${format(duration)} by $timeLockedAddress');
  print(
      '  Can be unlocked by $hashLockedAddress with hashlock $hashLock hashtype $hashType');

  AccountBlockTemplate block = await znnClient.send(znnClient.embedded.htlc
      .create(token, amount, hashLockedAddress, expirationTime, hashType,
          keyMaxSize, hashLock.getBytes()));

  print('Submitted htlc with id ${block.hash.toString()}');
  print('Done');

  Map results = {
    'preimage': hex.encode(preimage),
    'hashLock': hashLock,
    'hash': block.hash
  };
  return results;
}

Future<void> unlockHtlc(znnClient, id, preimage) async {
  HtlcInfo htlc = await znnClient.embedded.htlc.getById(id);

  await znnClient.embedded.token.getByZts(htlc.tokenStandard).then((token) => print(
      'Unlocking htlc id ${htlc.id} with amount ${(htlc.amount / pow(10, token.decimals)).toStringAsFixed(token.decimals)} ${token.symbol}'));

  AccountBlockTemplate block = await znnClient
      .send(znnClient.embedded.htlc.unlock(id, hex.decode(preimage)));
  print('Unlocked htlc $id || tx hash: ${block.hash.toString()}');
  await confirmTransaction(znnClient, block.hash);

  print('Done');
}

Future<void> receiveAll(znnClient, address) async {
  var unreceived = (await znnClient.ledger
      .getUnreceivedBlocksByAddress(address, pageIndex: 0, pageSize: 5));
  if (unreceived.count == 0) {
    print('Nothing to receive');
    return;
  } else {
    print('You have ${unreceived.count.toString()} transaction(s) to receive');
  }

  print('Please wait ...');
  while (unreceived.count! > 0) {
    for (var block in unreceived.list!) {
      await znnClient.send(AccountBlockTemplate.receive(block.hash));
    }
    unreceived = (await znnClient.ledger
        .getUnreceivedBlocksByAddress(address, pageIndex: 0, pageSize: 5));
  }
  print('Done');
}

Future<void> confirmTransaction(znnClient, id) async {
  var confirmed = false;
  stdout.write('Waiting for confirmation...');
  while (!confirmed) {
    stdout.write(".");
    AccountBlock? block = await znnClient.ledger.getAccountBlockByHash(id);
    if (block != null) {
      if (block.pairedAccountBlock?.confirmationDetail?.numConfirmations !=
          null) {
        print('Confirmed!');
        confirmed = true;
      }
    }
    await Future.delayed(const Duration(seconds: 1));
  }
}

Future<void> main(List<String> args) async {
  final Zenon znnClient = Zenon();
  await znnClient.wsClient.initialize(ws, retry: false);
  await znnClient.ledger.getFrontierMomentum().then((value) {
    netId = value.chainIdentifier.toInt();
  });

  var runsExecuted = 0;
  while (runsExecuted < totalRuns) {
    SporkList sporks = await znnClient.embedded.spork
        .getAll(pageIndex: 0, pageSize: rpcMaxPageSize);
    if (sporks.list.isNotEmpty) {
      print('Sporks:');
      for (Spork spork in sporks.list) {
        if (spork.id == htlcSpork) {
          if (spork.activated) {
            print('  HTLC Spork $htlcSpork is activated');

            unlockWallet(znnClient, address1, passphrase1);
            Map htlc1 = await createHtlc(
                znnClient, address1, Address.parse(address2), token1, amount1);
            await confirmTransaction(znnClient, htlc1['hash']);

            unlockWallet(znnClient, address2, passphrase2);
            Map htlc2 = await createHtlc(
                znnClient,
                address2,
                Address.parse(address1),
                token2,
                amount2,
                htlc1['hashLock'].toString());
            await confirmTransaction(znnClient, htlc2['hash']);

            unlockWallet(znnClient, address1, passphrase1);
            await unlockHtlc(znnClient, htlc2['hash'], htlc1['preimage']);
            await receiveAll(znnClient, Address.parse(address1));

            unlockWallet(znnClient, address2, passphrase2);
            await unlockHtlc(znnClient, htlc1['hash'], htlc1['preimage']);
            await receiveAll(znnClient, Address.parse(address2));

            runsExecuted += 1;
          } else {
            print('  HTLC Spork $htlcSpork is not activated');
          }
        }
      }
    }

    print("[-] Sleeping 10 seconds...");
    await Future.delayed(const Duration(seconds: 10));
  }

  znnClient.wsClient.stop();
}
