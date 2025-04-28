import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:yt_downloader/screens/video_screen.dart';

class DownloadedVideosPage extends StatefulWidget {
  const DownloadedVideosPage({super.key});

  @override
  State<DownloadedVideosPage> createState() => _DownloadedVideosPageState();
}

class _DownloadedVideosPageState extends State<DownloadedVideosPage> {
  List<File> _downloadedVideos = [];

  @override
  void initState() {
    super.initState();
    _loadDownloadedVideos();
  }

  Future<void> _loadDownloadedVideos() async {
    final directory = await getDownloadsDirectory();
    final files = directory!.listSync();
    setState(() {
      _downloadedVideos = files
          .whereType<File>()
          .where((file) => file.path.endsWith('.mp4'))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Downloaded Videos',
          style: TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 2,
        iconTheme: const IconThemeData(color: Colors.redAccent),
      ),
      body: _downloadedVideos.isEmpty
          ? const Center(
              child: Text(
                'No videos downloaded yet.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _downloadedVideos.length,
              itemBuilder: (context, index) {
                final file = _downloadedVideos[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: const Icon(Icons.video_file, size: 40, color: Colors.blueAccent),
                    title: Text(
                      file.path.split('/').last,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.play_circle_fill, size: 36, color: Colors.redAccent),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => VideoScreen(file: file),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
