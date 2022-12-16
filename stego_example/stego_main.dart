import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
//import 'dart:ui' as ui;
import 'package:image/image.dart' as Imagi;
// Attempt to implement Magic LSB Substitution Method (M-LSB-SM)
// Source: https://arxiv.org/ftp/arxiv/papers/1506/1506.02100.pdf

// https://pub.dev/documentation/image/latest/image/Image/numberOfChannels.html
// numberOfChannels
// The number of channels used by this Image.
// While all images are stored internally with 4 bytes, some images, such as
// those loaded from a Jpeg, don't use the 4th (alpha) channel.



void readImage(File imageTemp) async{
  List<List<int>> imgArray = [];
  final bytes = await imageTemp.readAsBytesSync();
  final decoder = Imagi.JpegDecoder();
  final decodedImg = Imagi.decodeJpg(bytes);

  final width = decodedImg?.width;
  final height = decodedImg?.height;
  final length = decodedImg?.length;
  final data = decodedImg?.data; // Pixels are encoded into 4-byte Uint32 integers in #AABBGGRR channel order.
  final textData = decodedImg?.textData; // Empty string?
  final channels = decodedImg?.channels; // jpeg == rbg, png == argb

  //print("W: ${width} x H: ${height} || Length: ${length} || Data: ${data} || textData: ${textData} || channels: ${channels}");
  final decodedBytes = decodedImg!.getBytes(format: Imagi.Format.rgb);
  print("Number of RGB bytes: ${decodedBytes.length}");
  final decodedBytesRGBA = decodedImg.getBytes(format: Imagi.Format.rgba);
  print("Number of RGBA bytes: ${decodedBytesRGBA.length}");
  final decodedBytesLuminance = decodedImg.getBytes(format: Imagi.Format.luminance);
  print("Number of Luminance bytes: ${decodedBytesLuminance.length}");

  for(int x = 0; x < 3; x++) {
    for(int y = 0; y < height!; y++) {

      var pixel = decodedImg.getPixelSafe(x, y); //Uint32 as #AABBGGRR

      Uint32List list = new Uint32List.fromList([pixel]);
      Uint8List byte_data = list.buffer.asUint8List();
      //print("x: ${x} || y: ${y} || ${byte_data}");


      //int red = Imagi.getColor(byte_data[0], byte_data[1], byte_data[2], byte_data[3]);
      //int green = decodedBytes[x*3 + 1];
      //int blue = decodedBytes[x*3 + 2];
      //int alpha =
      //imgArray.add(pixel);
    }
  }
  //print("RBG array: ${imgArray}");
  writeImage(width!, height!, decodedBytes);
}

void writeImage(int width, int height, List<int> bytes,) async{
  //var img = Imagi.Image.fromBytes(width, height, bytes);
  //var out = new File('temp.jpg')..writeAsBytes(Imagi.encodeJpg(img, quality: 85));
  //await tempFile.writeAsBytes(out);
  //await File(".test.jpg").writeAsBytes(image.buffer.asUint8List(image.offsetInBytes, image.lengthInBytes));
}

Future<void> main() async {
  final imageTemp = File('./example.jpg'); //275x184
  readImage(imageTemp);

}
