// znn_correlator.dart

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:dcli/dcli.dart';
import 'package:collection/collection.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

var ws = 'wss://node.zenon.fun:35998';
var startingMomentum = 1; //3000000;
var endingMomentum = null;
Map mints = Map<String, double>();

List extractMomentumData(DetailedMomentumList getDetailedMomentumsByHeight) {
  List messages = [];

  getDetailedMomentumsByHeight.list!.forEach((element) {
    if (element.momentum.content.length > 0) {
      //print("${element.momentum.height} has ${element.momentum.content.length} transactions");
      try {
        element.blocks.forEach((block) {
          try {
            if (block.data.isNotEmpty &&
                block.token!.symbol.toString() == "ZNN") {
              var f = _getAbiFunction(block);
              if (_isMint(f)) {
                var data = f.decode(block.data);
                var tokenStandard = data[0].toString();
                double amount = double.parse(data[1].toString()) /
                    pow(10, 8); //lazy znn calc
                var receiveAddress = data[2].toString();
                var mechanism = block.address.toString();
                if (block.address.toString() ==
                    'z1qxemdeddedxpyllarxxxxxxxxxxxxxxxsy3fmg') {
                  mechanism = 'pillar';
                } else if (block.address.toString() ==
                    'z1qxemdeddedxstakexxxxxxxxxxxxxxxxjv8v62') {
                  mechanism = 'stake';
                } else if (block.address.toString() ==
                    'z1qxemdeddedxsentynelxxxxxxxxxxxxxwy0r2r') {
                  mechanism = 'sentinel';
                } else if (block.address.toString() ==
                    'z1qxemdeddedxswapxxxxxxxxxxxxxxxxxxl4yww') {
                  mechanism = 'swap';
                }

                var token = 'unknown';
                if (tokenStandard.toString() == znnTokenStandard) {
                  token = 'ZNN';
                } else if (tokenStandard.toString() == qsrTokenStandard) {
                  token = 'QSR';
                }
                if (token == 'ZNN' || token == 'QSR') {
                  // && mechanism != 'swap') {
                  cprint(
                      '$receiveAddress minted ${amount} $token via $mechanism',
                      element.momentum.height);
                  new File('mints.txt').writeAsStringSync(
                      '[${element.momentum.height}] $receiveAddress minted ${amount} $token via $mechanism\n',
                      mode: FileMode.append);
                  //addMint(receiveAddress, amount);
                }
              } else if (_isBurn(f)) {
                print(red(
                    '[${element.momentum.height}] ${block.address} burned ${block.amount} ${block.token!.symbol} to ${block.toAddress} with data: ${block.data}'));
              }
            }
          } catch (e) {}
        });
      } catch (e) {
        print("Exception was caught while trying to read data: ${e}");
      }
    }
  });
  return messages;
}

void addMint(String address, double amount) {
  if (mints.containsKey(address)) {
    mints[address] = mints[address]! + amount;
  } else {
    mints[address] = amount;
  }
}

AbiFunction _getAbiFunction(AccountBlock block) {
  late AbiFunction f;
  Function eq = const ListEquality().equals;
  try {
    for (var entry in Definitions.token.entries) {
      if (eq(AbiFunction.extractSignature(entry.encodeSignature()),
          AbiFunction.extractSignature(block.data))) {
        f = AbiFunction(entry.name!, entry.inputs!);
      }
    }
  } catch (e) {
    print('Failed to parse block ${block.hash}: $e');
  }
  return f;
}

// :)
void cprint(String s, int momentum) {
  switch (momentum % 6) {
    case 0:
      {
        print('[${red(momentum.toString())}] $s');
      }
      break;
    case 1:
      {
        print('[${green(momentum.toString())}] $s');
      }
      break;
    case 2:
      {
        print('[${orange(momentum.toString())}] $s');
      }
      break;
    case 3:
      {
        print('[${yellow(momentum.toString())}] $s');
      }
      break;
    case 4:
      {
        print('[${cyan(momentum.toString())}] $s');
      }
      break;

    case 5:
      {
        print('[${magenta(momentum.toString())}] $s');
      }
      break;

    default:
      print(s);
  }
}

bool _isMint(AbiFunction f) => f.name.toString() == 'Mint';
bool _isBurn(AbiFunction f) => f.name.toString() == 'Burn';

Future<int> main(List<String> args) async {
  final Zenon znnClient = Zenon();
  await znnClient.wsClient.initialize(ws, retry: false);

  var currentHeight = startingMomentum;

  while (true) {
    //Get Current Momentum
    Momentum currentFrontierMomentum =
        await znnClient.ledger.getFrontierMomentum();
    print(
        'Current Momentum height: ${currentFrontierMomentum.height.toString()} || timestamp: ${DateTime.fromMillisecondsSinceEpoch(currentFrontierMomentum.timestamp * 1000)}');
    int height = endingMomentum != null
        ? endingMomentum
        : currentFrontierMomentum.height;

    var difference = height - currentHeight;
    print("Last Momentum:${currentHeight} (behind by ${difference})");

    //Due to retrieval limitation with ledger.getDetailedMomentumsByHeight() or client,
    // limit queries to 200 momentums (max ~250)
    if (difference <= 200) {
      DetailedMomentumList getDetailedMomentumsByHeight = await znnClient.ledger
          .getDetailedMomentumsByHeight(currentHeight + 1, difference);
      await extractMomentumData(getDetailedMomentumsByHeight);
      currentHeight = height;
    } else {
      var start = currentHeight + 1;
      var loops = (difference / 200).floor();
      var remainder = start % 200;

      for (var i = 0; i < loops; i++) {
        if ((loops - i) % 1000 == 0) {
          print(
              "checking momentums ${start} - ${start + 200}, ${loops - i} loops remaining");
        }
        DetailedMomentumList getDetailedMomentumsByHeight =
            await znnClient.ledger.getDetailedMomentumsByHeight(start, 200);
        await extractMomentumData(getDetailedMomentumsByHeight);
        start += 200;
      }
      DetailedMomentumList getDetailedMomentumsByHeight =
          await znnClient.ledger.getDetailedMomentumsByHeight(start, remainder);
      await extractMomentumData(getDetailedMomentumsByHeight);
      currentHeight = height;
    }

    //print(mints);
    print("[-] Sleeping 120 seconds...");
    await new Future.delayed(const Duration(seconds: 120));
  }

  znnClient.wsClient.stop();
}
