import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

String speech = 'pepega';

class Data extends ChangeNotifier {
  bool light = true;
  void setSpeech(data) {
    speech = data;
    notifyListeners();
    print(speech);
  }

  get getSpeech {
    return speech;
  }

  toggledata() {
    light = !light;
  }
}
