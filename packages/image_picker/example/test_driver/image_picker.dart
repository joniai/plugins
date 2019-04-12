import 'dart:async';
import 'dart:io';
import 'package:flutter_driver/driver_extension.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  final Completer<String> completer = Completer<String>();
  enableFlutterDriverExtension(handler: (_) => completer.future);
  tearDownAll(() => completer.complete(null));

  group('pickImage', () {
    test('test pick image with camera source', () async {
      expect(await ImagePicker.pickImage(source: ImageSource.camera), completes);
      expect(await ImagePicker.pickImage(source: ImageSource.camera, maxWidth: 100, maxHeight: 100), completes);
    });

    test('test pick image with gallery source', () async {
      expect(await ImagePicker.pickImage(source: ImageSource.gallery), completes);
      expect(await ImagePicker.pickImage(source: ImageSource.gallery, maxWidth: 100, maxHeight: 100), completes);
      expect(await ImagePicker.pickImage(source: ImageSource.gallery, maxWidth: -1, maxHeight: 100), throwsAssertionError);
      expect(await ImagePicker.pickImage(source: ImageSource.gallery, maxWidth: 100, maxHeight: -1), throwsAssertionError);
    });
  });

  group('pickVideo', () {
    test('test pick video with camera source', () async {
      expect(await ImagePicker.pickVideo(source: ImageSource.camera), completes);
    });

    test('test pick video with gallery source', () async {
      expect(await ImagePicker.pickVideo(source: ImageSource.gallery), completes);
    });
  });
}
