import 'dart:async';
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;

import 'package:auto_image_sequencer/auto_image_sequencer_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AutoImageSequencer extends StatefulWidget {
  const AutoImageSequencer({
    super.key,
    required this.imageUrls,
    this.onCreate,
    this.speed = 200,
  });

  final List<String> imageUrls;
  final int speed;
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAndDecodeImages());
    controller = AutoImageSequencerController(_play, _pause, _reset, _jumpTo);
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
        throw Exception("Nessuna immagine è stata caricata.");
      }
    } catch (e) {
      if (kDebugMode) {
        print("Errore nel caricamento delle immagini: ${e.toString()}");
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
      throw Exception('Errore: ${response.statusCode}\n${response.body}');
    }

    final codec = await ui.instantiateImageCodec(response.bodyBytes);
    final frame = await codec.getNextFrame();
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
      controller.notifyImageChange?.call(_currentIndex, _images[_currentIndex]);
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
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text("Error", style: const TextStyle(color: Colors.red)),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: _images[_currentIndex].width / _images[_currentIndex].height,
      child: CustomPaint(
        painter: _ImagePainter(image: _images[_currentIndex]),
        child: SizedBox(),
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
