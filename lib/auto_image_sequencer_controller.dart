import 'dart:ui';

import 'package:flutter/foundation.dart';

class AutoImageSequencerController extends ChangeNotifier {
  void Function(int index, Image image)? _onImageChange;
  bool isPlaying = false;
  late final void Function() _play;
  late final void Function() _pause;
  late final void Function() _stop;
  late void Function(int) jumpTo;

  AutoImageSequencerController(
    this._play,
    this._pause,
    this._stop,
    this.jumpTo,
  );

  void toggle() {
    if (isPlaying) {
      return pause();
    }

    play();
  }

  void play() {
    if (isPlaying) return;
    _play();
    isPlaying = true;
    notifyListeners();
  }

  void pause() {
    if (!isPlaying) return;
    _pause();
    isPlaying = false;
    notifyListeners();
  }

  void stop() {
    if (isPlaying) {
      _pause();
    }
    _stop();
  }

  void Function(int index, Image image)? get notifyImageChange =>
      _onImageChange;

  set onImageChange(void Function(int index, Image image)? value) {
    _onImageChange = value;
  }
}
