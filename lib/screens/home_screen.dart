import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:yt_downloader/screens/downloaded_video_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _urlController = TextEditingController();
  Video? _video;
  List<File> _downloadedVideos = [];
  double _downloadProgress = 0.0;
  bool _isLoading = false;

  Future<void> _fetchVideoData() async {
    setState(() => _isLoading = true);
    final yt = YoutubeExplode();
    
    try {
      final videoId = VideoId(_urlController.text);
      final video = await yt.videos.get(videoId);
      setState(() => _video = video);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      yt.close();
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _checkPermissions() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        return await Permission.videos.isGranted;
      } else {
        return await Permission.storage.isGranted;
      }
    }
    return true;
  }

 

Future<void> _downloadVideo(String quality) async {
  if (!await _checkPermissions()) {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        await Permission.videos.request();
      } else {
        await Permission.storage.request();
      }
    }
    if (!await _checkPermissions()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permission denied')),
      );
      return;
    }
  }

  final yt = YoutubeExplode();
  try {
    final videoId = VideoId(_urlController.text);
    final manifest = await yt.videos.streamsClient.getManifest(videoId);

    final videoStreamInfo = manifest.videoOnly.sortByVideoQuality().firstWhere(
      (element) => element.qualityLabel == quality,
      orElse: () => manifest.videoOnly.first,
    );

    final audioStreamInfo = manifest.audioOnly.withHighestBitrate();

    final directory = await getDownloadsDirectory();
    final videoFilePath = '${directory!.path}/temp_video.mp4';
    final audioFilePath = '${directory.path}/temp_audio.mp4';
    final outputFilePath = '${directory.path}/${_video!.title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.mp4';

    // Download video-only stream
    final videoStream = yt.videos.streamsClient.get(videoStreamInfo);
    final videoFile = File(videoFilePath);
    final videoSink = videoFile.openWrite();

    int downloadedVideoBytes = 0;
    final totalVideoSize = videoStreamInfo.size.totalBytes;

    await for (final data in videoStream) {
      downloadedVideoBytes += data.length;
      videoSink.add(data);
      setState(() {
        _downloadProgress = (downloadedVideoBytes / totalVideoSize) * 0.5; // 50% weight for video
      });
    }
    await videoSink.close();

    // Download audio-only stream
    final audioStream = yt.videos.streamsClient.get(audioStreamInfo);
    final audioFile = File(audioFilePath);
    final audioSink = audioFile.openWrite();

    int downloadedAudioBytes = 0;
    final totalAudioSize = audioStreamInfo.size.totalBytes;

    await for (final data in audioStream) {
      downloadedAudioBytes += data.length;
      audioSink.add(data);
      setState(() {
        _downloadProgress = 0.5 + (downloadedAudioBytes / totalAudioSize) * 0.4; // next 40% for audio
      });
    }
    await audioSink.close();

    // Merge video + audio (simulate progress for merge)
    setState(() {
      _downloadProgress = 0.9; // Merge starts
    });
    await FFmpegKit.execute(
      '-i "$videoFilePath" -i "$audioFilePath" -c:v copy -c:a aac "$outputFilePath"',
    );

    setState(() {
      _downloadProgress = 1.0; // Done!
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Download and Merge Complete!')),
    );

    // Cleanup: Delete temp files
    await videoFile.delete();
    await audioFile.delete();

    _loadDownloadedVideos(); // Refresh list
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {
      _downloadProgress = 0.0;
    });

  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Download failed: ${e.toString()}')),
    );
    setState(() {
      _downloadProgress = 0.0;
    });
  } finally {
    yt.close();
  }
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
  void initState() {
    super.initState();
    _loadDownloadedVideos();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [Padding(
          padding: const EdgeInsets.all(8.0),
          child: IconButton(onPressed: (){Navigator.push(context, MaterialPageRoute(builder: (context) => DownloadedVideosPage(),));}, icon: Icon(Icons.video_library,color: Colors.red,)),
        )],
        title: Center(child: const Text('YouTube Downloader',style:TextStyle(color: Colors.red,fontWeight: FontWeight.bold,),))),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      labelText: 'YouTube URL',
                      hintText: 'Paste URL here',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.paste,color:Colors.blueAccent,),
                  onPressed: () async {
                    final data = await Clipboard.getData('text/plain');
                    _urlController.text = data?.text ?? '';
                  },
                ),
              ],
            ),
            SizedBox(height: 20,),
            ElevatedButton(
               
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                fixedSize: Size(170, 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _isLoading ? null : _fetchVideoData,
              child: _isLoading 
                  ? const CircularProgressIndicator()
                  : const Text('Fetch Video Info'),
            ),
            if (_video != null) ...[
              Image.network(_video!.thumbnails.mediumResUrl),
              Text(_video!.title),
              DropdownButton<String>(
                hint: const Text('Select Quality to Download'),
                items: ['144p', '240p', '360p', '480p', '720p', '1080p']
                    .map((q) => DropdownMenuItem(
                          child: Text(q),
                          value: q,
                        ))
                    .toList(),
                onChanged: (value) => _downloadVideo(value!),
              ),
            ],
           Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
  child: ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: LinearProgressIndicator(
      value: _downloadProgress,
      minHeight: 12,
      backgroundColor: Colors.grey.shade300,
      valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
    ),
  ),
),

    
          ],
        ),
      ),
    );
  }
}

