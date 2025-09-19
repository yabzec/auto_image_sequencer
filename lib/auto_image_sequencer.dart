import 'dart:async';
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Image;
import 'package:http/http.dart' as http;

class AutoImageSequencer extends StatefulWidget {
  const AutoImageSequencer({
    super.key,
    required this.imageUrls,
    this.onCreate,
    this.speed = 200,
    this.loadingBuilder,
  });

  final List<String> imageUrls;
  final int speed;
  final Widget Function(double status)? loadingBuilder;
  final void Function(AutoImageSequencerController)? onCreate;

  @override
  State<AutoImageSequencer> createState() => _AutoImageSequencerState();
}

class _AutoImageSequencerState extends State<AutoImageSequencer> {
  late final AutoImageSequencerController controller;
  bool _isLoading = true;
  bool _error = false;
  List<ui.Image> _images = [];
  Timer? _timer;
  int _currentIndex = 0;

  static const Map<String, String> _browserHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36',
    'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
  };

  @override
  void initState() {
    super.initState();
    controller = AutoImageSequencerController._(
      _play,
      _pause,
      _reset,
      _jumpTo,
      widget.imageUrls.length,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAndDecodeImages());
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var image in _images) {
      image.dispose();
    }
    super.dispose();
  }

  Future<void> _loadAndDecodeImages() async {
    try {
      final imageFutures = widget.imageUrls.map(_fetchAndDecodeImage);
      _images = await Future.wait(imageFutures);

      if (_images.isEmpty) {
        throw Exception("No image loaded.");
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error during image loading: ${e.toString()}");
      }
      if (mounted) {
        setState(() {
          _error = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        widget.onCreate?.call(controller);
      }
    }
  }

  Future<ui.Image> _fetchAndDecodeImage(String url) async {
    final response = await http.get(Uri.parse(url), headers: _browserHeaders);

    if (response.statusCode != 200) {
      throw Exception('Error: ${response.statusCode}\n${response.body}');
    }

    final codec = await ui.instantiateImageCodec(response.bodyBytes);
    final frame = await codec.getNextFrame();
    controller._increaseDownloadedImageCount();
    return frame.image;
  }

  void _play() {
    if (_timer?.isActive ?? false) {
      return;
    }

    _timer = Timer.periodic(Duration(milliseconds: widget.speed), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _currentIndex = (_currentIndex + 1) % _images.length;
      });
      controller._onImageChange?.call(_currentIndex, _images[_currentIndex]);
    });
  }

  void _pause() {
    _timer?.cancel();
  }

  void _reset() {
    _jumpTo(0);
  }

  void _jumpTo(int i) {
    if (i >= _images.length || i < 0) {
      throw ArgumentError("Image index out of bound.");
    }
    setState(() {
      _currentIndex = i;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.width,
        child: Center(
          child: widget.loadingBuilder != null
              ? widget.loadingBuilder!.call(controller.downloadStatus)
              : CircularProgressIndicator(),
        ),
      );
    }

    if (_error) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text("Error", style: TextStyle(color: Colors.red)),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: _images[_currentIndex].width / _images[_currentIndex].height,
      child: CustomPaint(
        painter: _ImagePainter(image: _images[_currentIndex]),
        child: const SizedBox(),
      ),
    );
  }
}

class _ImagePainter extends CustomPainter {
  final ui.Image image;

  _ImagePainter({required this.image});

  @override
  void paint(Canvas canvas, Size size) {
    paintImage(
      canvas: canvas,
      rect: Offset.zero & size,
      image: image,
      fit: BoxFit.contain,
    );
  }

  @override
  bool shouldRepaint(covariant _ImagePainter oldDelegate) {
    return image != oldDelegate.image;
  }
}

class AutoImageSequencerController extends ChangeNotifier {
  void Function(int index, Image image)? _onImageChange;
  bool isPlaying = false;
  final void Function() _play;
  final void Function() _pause;
  final void Function() _stop;
  void Function(int) jumpTo;
  final int _imageCount;
  int _downloadedImageCount = 0;

  AutoImageSequencerController._(
    this._play,
    this._pause,
    this._stop,
    this.jumpTo,
    this._imageCount,
  );

  get downloadStatus => _downloadedImageCount / _imageCount;

  void _increaseDownloadedImageCount() {
    _downloadedImageCount++;
    notifyListeners();
  }

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

  set onImageChange(void Function(int index, Image image)? value) {
    _onImageChange = value;
  }
}
