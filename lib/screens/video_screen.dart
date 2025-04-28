import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/services.dart'; // important for orientation

class VideoScreen extends StatefulWidget {
  final File file;

  const VideoScreen({Key? key, required this.file}) : super(key: key);

  @override
  _VideoScreenState createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  late VideoPlayerController _controller;
  bool _isFullScreen = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(widget.file)
      ..initialize().then((_) {
        setState(() {}); // Refresh after initialization
        _controller.play();
      });
    _controller.addListener(_onFullScreen);
  }

  void _onFullScreen() {
    if (_controller.value.isPlaying) {
      // Force landscape if playing
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeRight,
        DeviceOrientation.landscapeLeft,
      ]);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onFullScreen);
    _controller.dispose();
    // Reset orientation when leaving
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  void _toggleOrientation() {
    if (_isFullScreen) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeRight,
        DeviceOrientation.landscapeLeft,
      ]);
    }
    setState(() {
      _isFullScreen = !_isFullScreen;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _controller.value.isInitialized
          ? Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Center(
                  child: AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  ),
                ),
                _ControlsOverlay(
                  controller: _controller,
                  onFullScreenPressed: _toggleOrientation,
                ),
                const SizedBox(height: 20),
              ],
            )
          : const Center(child: CircularProgressIndicator(color: Colors.redAccent)),
    );
  }
}

class _ControlsOverlay extends StatelessWidget {
  final VideoPlayerController controller;
  final VoidCallback onFullScreenPressed;

  const _ControlsOverlay({Key? key, required this.controller, required this.onFullScreenPressed}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        GestureDetector(
          onTap: () {
            controller.value.isPlaying ? controller.pause() : controller.play();
          },
          child: Center(
            child: controller.value.isPlaying
                ? const SizedBox.shrink()
                : Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(12),
                    child: const Icon(Icons.play_arrow, color: Colors.white, size: 60),
                  ),
          ),
        ),
        Positioned(
          right: 16,
          bottom: 30,
          child: IconButton(
            icon: const Icon(Icons.fullscreen, color: Colors.white, size: 30),
            onPressed: onFullScreenPressed,
          ),
        ),
        VideoProgressIndicator(
          controller,
          allowScrubbing: true,
          colors: VideoProgressColors(
            playedColor: Colors.redAccent,
            backgroundColor: Colors.grey,
            bufferedColor: Colors.white70,
          ),
          padding: const EdgeInsets.only(bottom: 50),
        ),
      ],
    );
  }
}
