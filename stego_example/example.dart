import 'dart:io';
import 'dart:convert';
// https://hexed.it/

Future<void> append_stego_payload(File input) async {
  var extension = input.path.toString().split('.')[2];
  var output = new File(".\\output\\output.${extension}");

  var bytes = await input.readAsBytes(); // Uint8List

  /*
  var s = bytes.buffer
      .asUint8List()
      .map((e) => e.toRadixString(16).padLeft(2, '0'))
      .join();
  print(s);
   */

  String foo = 'ZNN_NFT_STANDARD\nNFT METADATA HERE\n321_ZENON';
  List<int> appendBytes = utf8.encode(foo);

  print('Saving .\\output\\output.${extension}');
  await output.writeAsBytes(bytes, mode:FileMode.writeOnly);
  await output.writeAsBytes(appendBytes, mode:FileMode.append);
}

Future<void> main() async {
  var list = ["docx", "pdf", "rtf", "txt", "gif", "png", "rar", "zip", "jpg", "ogg", "mp3", "mp4"];
  for(var ext in list){
    await append_stego_payload(new File (".\\input\\input.${ext}"));
  }
}
