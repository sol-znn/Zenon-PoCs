// znn_decay_calculator.dart
// -- Output --
// Total genesis ZNN: 5729700.63474459
// Total genesis QSR: 26584972.03213085 (not counting PP -> QSR)
// Burned ZNN: 673503.03113354
// Burned QSR: 798660.84048049

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

var ws = 'wss://node.zenon.fun:35998';
var swapContract = 'z1qxemdeddedxswapxxxxxxxxxxxxxxxxxxl4yww';
var genesisFile =
    'https://raw.githubusercontent.com/zenon-network/go-zenon/master/chain/genesis/embedded_genesis_string.go';
final Zenon znnClient = Zenon();

double decimals(int value) => value / pow(10, 8);

Future<List<int>> parseGenesisFile() async {
  String swapConfigJson = '';
  var httpClient = new HttpClient();
  await httpClient
      .getUrl(Uri.parse(genesisFile))
      .then((HttpClientRequest request) {
    return request.close();
  }).then((HttpClientResponse response) async {
    await response.transform(new Utf8Decoder()).toList().then((data) {
      var body = data.join('');
      var start = body.indexOf('"Entries": ');
      var end = body.indexOf('"GenesisBlocks"');
      body = body.substring(start, end).replaceFirst('"Entries": ', '');
      swapConfigJson = body.replaceRange(body.length - 5, body.length, '');
    });
  });
  int totalGenesisZnn = 0;
  int totalGenesisQsr = 0;
  jsonDecode(swapConfigJson).forEach((element) {
    totalGenesisZnn += element['znn']!.toString().toNum().toInt();
    totalGenesisQsr += element['qsr']!.toString().toNum().toInt();
  });
  return [totalGenesisZnn, totalGenesisQsr];
}

Future<List<int>> parseSwapContractBlocks(
    int totalGenesisZnn, int totalGenesisQsr) async {
  var swapContractFrontierBlock = await znnClient.ledger
      .getFrontierAccountBlock(Address.parse(swapContract));
  var swapContractAddress = Address.parse(swapContract);
  await znnClient.ledger.getFrontierAccountBlock(swapContractAddress);
  var swapContractFrontierHeight = swapContractFrontierBlock?.height;

  for (int i = 2; i <= swapContractFrontierHeight!; i++) {
    var block = (await znnClient.ledger
            .getAccountBlocksByHeight(swapContractAddress, i, 1))
        .list![0];
    if (block.blockType == 4) {
      var amount = block.pairedAccountBlock?.descendantBlocks[0].amount;
      var token = block.pairedAccountBlock?.descendantBlocks[0].tokenStandard
                  .toString() ==
              'zts1znnxxxxxxxxxxxxx9z4ulx'
          ? 'znn'
          : 'qsr';

      if (token == 'znn') {
        totalGenesisZnn -= amount!;
      } else {
        totalGenesisQsr -= amount!;
      }
    }
  }
  return [totalGenesisZnn, totalGenesisQsr];
}

Future<void> main(List<String> args) async {
  await znnClient.wsClient.initialize(ws, retry: false);

  List<int> genesisCoins = await parseGenesisFile();
  print('Total genesis ZNN: ${decimals(genesisCoins[0])}');
  print(
      'Total genesis QSR: ${decimals(genesisCoins[1])} (not counting PP -> QSR)');

  List<int> burnedCoins =
      await parseSwapContractBlocks(genesisCoins[0], genesisCoins[1]);
  print('Burned ZNN: ${decimals(burnedCoins[0])}');
  print('Burned QSR: ${decimals(burnedCoins[1])}');

  znnClient.wsClient.stop();
}
