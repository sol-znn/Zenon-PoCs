// znn_momentum_parser.dart
// Purpose: to determine what happened to the Treasure Hunt's QSR rewards
// Problem: we can see the QSR was sent to the "token" embedded contract address, but that address has a 0 QSR balance.
//          where did the funds go?
// Solution: scrape all transactions to determine if the funds were moved out of the embedded contract.
// Conclusion: the funds were sent to the embedded contract and its burn() function was called
//             "data": "M5WrlA==",
// https://explorer.zenon.network/transaction/ac3fb28796c0aec1c512396e54f23fe5882246c44372cc23897d455cfe88f7eb

import 'dart:async';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

var ws = 'wss://node.zenon.fun:35998';
var address = 'z1qxemdeddedxt0kenxxxxxxxxxxxxxxxxh9amk0';
var startingMomentum = 237100; //237105; let's start a few momentums back

List extractMomentumData(DetailedMomentumList getDetailedMomentumsByHeight) {
  List messages = [];

  getDetailedMomentumsByHeight.list!.forEach((element) {
    if (element.momentum.content.length > 0) {
      //print("${element.momentum.height} has ${element.momentum.content.length} transactions");
      try {
        element.blocks.forEach((block) {
          try {
            if ((block.address.toString() == address || block.toAddress.toString() == address) && block.token!.symbol.toString() == "QSR") {
              if ((block.amount == 474513400000 || block.blockType == 2 || block.blockType == 3) || (block.blockType == 4 && block.amount == 474513400000)) {
                print('[${block.height}] ${block.address} sent ${block
                    .amount} ${block.token!.symbol} to ${block.toAddress}');
              }
              if (block.data.isNotEmpty) {
                print('[${block.height}] ${block.address} sent ${block
                    .amount} ${block.token!.symbol} to ${block.toAddress} with data: ${block.data}');
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
    int height = currentFrontierMomentum.height;

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
        if ((loops - i) % 1000 == 0) {print("checking momentums ${start} - ${start + 200}, ${loops - i} loops remaining"); }
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

    print("[-] Sleeping 120 seconds...");
    await new Future.delayed(const Duration(seconds: 120));
  }

  znnClient.wsClient.stop();
}
