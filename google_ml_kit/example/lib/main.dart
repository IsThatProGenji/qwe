import 'dart:async';
import 'dart:collection';
import 'dart:io' as io;
import 'dart:ui';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'data/data.dart';
import 'vision_detector_views/camera_view.dart';

import 'vision_detector_views/painters/coordinates_translator.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

import '../activity_indicator/activity_indicator.dart';

List<CameraDescription> cameras = [];

var speechslist = Queue<String>();
var speechslistTranslate = Queue<String>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  cameras = await availableCameras();

  runApp(ChangeNotifierProvider(create: (context) => Data(), child: MyApp()));
}

Data datas = Data();
FlutterTts flutterTts = FlutterTts();

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Home(),
    );
  }
}

bool state = false;

class Home extends StatefulWidget {
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  Timer? timer;

  @override
  void initState() {
    super.initState();

    flutterTts.setSpeechRate(0.8);
    flutterTts.awaitSpeakCompletion(true);
    flutterTts.setLanguage("id-ID");
    timer = Timer.periodic(Duration(milliseconds: 1400), (Timer t) {
      if (speechslist.isNotEmpty && speechslist.length != 0) {
        pepeja();
      }
      print(speechslist);
    }

        // print(speech2);
        );
  }

  void pepeja() async {
    state
        ? await flutterTts.speak(speechslist.first)
        : await flutterTts.speak(speechslistTranslate.first);
    speechslist.removeFirst();
    speechslistTranslate.removeFirst();
    flutterTts.stop();
    // print("done");
    // if (speechslist.isEmpty) {
    //   flutterTts.speak("done");
    // }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Widget build(BuildContext context) {
    return Scaffold(body: ObjectDetectorView());
  }
}

class ObjectDetectorView extends StatefulWidget {
  @override
  State<ObjectDetectorView> createState() => _ObjectDetectorView();
}

toggle(value) {
  state = value;
}

class _ObjectDetectorView extends State<ObjectDetectorView> {
  late ObjectDetector _objectDetector;
  bool _canProcess = false;
  bool _isBusy = false;
  CustomPaint? _customPaint;
  String? _text;

  @override
  void initState() {
    super.initState();

    _initializeDetector(DetectionMode.stream);
  }

  @override
  void dispose() {
    _canProcess = false;
    _objectDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CameraView(
      toggle: toggle,
      title: state
          ? speechslist.toList().toString()
          : speechslistTranslate.toList().toString(),
      customPaint: _customPaint,
      text: _text,
      onImage: (inputImage) {
        processImage(inputImage);
      },
      onScreenModeChanged: _onScreenModeChanged,
      initialDirection: CameraLensDirection.back,
    );
  }

  void _onScreenModeChanged(ScreenMode mode) {
    switch (mode) {
      case ScreenMode.gallery:
        _initializeDetector(DetectionMode.single);
        return;

      case ScreenMode.liveFeed:
        _initializeDetector(DetectionMode.stream);
        return;
    }
  }

  void _initializeDetector(DetectionMode mode) async {
    print('Set detector in mode: $mode');
    final path = 'assets/ml/object_labeler.tflite';
    final modelPath = await _getModel(path);
    final options = LocalObjectDetectorOptions(
        mode: mode,
        modelPath: modelPath,
        classifyObjects: true,
        multipleObjects: true,
        confidenceThreshold: 0.8);
    _objectDetector = ObjectDetector(
      options: options,
    );
    _canProcess = true;
    print('pawg');
    print(modelPath);
  }

  Future<void> processImage(InputImage inputImage) async {
    if (!_canProcess) return;
    if (_isBusy) return;
    _isBusy = true;
    setState(() {
      _text = '';
    });
    final objects = await _objectDetector.processImage(inputImage);
    if (inputImage.inputImageData?.size != null &&
        inputImage.inputImageData?.imageRotation != null) {
      final painter = ObjectDetectorPainter(
          objects,
          inputImage.inputImageData!.imageRotation,
          inputImage.inputImageData!.size);
      _customPaint = CustomPaint(painter: painter);
    } else {
      String text = 'Objects found: ${objects.length}\n\n';
      for (final object in objects) {
        text +=
            'Object:  trackingId: ${object.trackingId} - ${object.labels.map((e) => e.text)}\n\n';
      }
      _text = text;

      // TODO: set _customPaint to draw boundingRect on top of image
      _customPaint = null;
    }
    _isBusy = false;
    if (mounted) {
      setState(() {});
    }
  }

  Future<String> _getModel(String assetPath) async {
    if (io.Platform.isAndroid) {
      return 'flutter_assets/$assetPath';
    }
    final path = '${(await getApplicationSupportDirectory()).path}/$assetPath';
    await io.Directory(dirname(path)).create(recursive: true);
    final file = io.File(path);
    if (!await file.exists()) {
      final byteData = await rootBundle.load(assetPath);
      await file.writeAsBytes(byteData.buffer
          .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
    }
    return file.path;
  }
}

class ObjectDetectorPainter extends CustomPainter {
  ObjectDetectorPainter(this._objects, this.rotation, this.absoluteSize);
  final _sourceLanguage = TranslateLanguage.english;
  final _targetLanguage = TranslateLanguage.indonesian;
  late final _onDeviceTranslator = OnDeviceTranslator(
      sourceLanguage: _sourceLanguage, targetLanguage: _targetLanguage);
  final _modelManager = OnDeviceTranslatorModelManager();
  _translate(text) async {
    final result = await _onDeviceTranslator
        .translateText(text)
        .then((value) => speechslistTranslate.add(value));

    return result;
  }

  final List<DetectedObject> _objects;
  final Size absoluteSize;
  final InputImageRotation rotation;
  Data datas = Data();
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.lightGreenAccent;

    final Paint background = Paint()..color = Color(0x99000000);

    for (final DetectedObject detectedObject in _objects) {
      final ParagraphBuilder builder = ParagraphBuilder(
        ParagraphStyle(
            textAlign: TextAlign.left,
            fontSize: 16,
            textDirection: TextDirection.ltr),
      );
      builder.pushStyle(
          ui.TextStyle(color: Colors.lightGreenAccent, background: background));

      for (final Label label in detectedObject.labels) {
        builder.addText('${label.text} ${label.confidence}\n');

        if (speech != label.text && speechslist.contains(label.text) == false) {
          //
          //
          //Provider.of<Data>(context).light
          speechslist.add(label.text);
          _translate(label.text);
          speech = label.text;
          print(speechslistTranslate);
          print(speechslist);
        }
      }

      builder.pop();

      final left = translateX(
          detectedObject.boundingBox.left, rotation, size, absoluteSize);
      final top = translateY(
          detectedObject.boundingBox.top, rotation, size, absoluteSize);
      final right = translateX(
          detectedObject.boundingBox.right, rotation, size, absoluteSize);
      final bottom = translateY(
          detectedObject.boundingBox.bottom, rotation, size, absoluteSize);

      canvas.drawRect(
        Rect.fromLTRB(left, top, right, bottom),
        paint,
      );

      canvas.drawParagraph(
        builder.build()
          ..layout(ParagraphConstraints(
            width: right - left,
          )),
        Offset(left, top),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
