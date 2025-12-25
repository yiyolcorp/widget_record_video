import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class Ultis {
  static Future<double> _getVideoDuration(String filepath) async {
    double originalDuration = 0;
    final data = await FFprobeKit.getMediaInformation(filepath);
    final media = data.getMediaInformation();
    final secondsStr = media?.getDuration();
    originalDuration = double.parse(secondsStr ?? "0");
    return originalDuration;
  }

  static Future<int> _getVideoFrameCount(String filepath) async {
    final data = await FFprobeKit.getMediaInformation(filepath);
    final streams = data.getMediaInformation()?.getStreams();
    if (streams != null && streams.isNotEmpty) {
      final frameCountStr = streams[0].getProperty('nb_frames');
      if (frameCountStr != null) {
        return int.tryParse(frameCountStr) ?? 0;
      }
    }
    return 0;
  }

  static Future<double> _calculateSpeedRatio(String filepath, double targetDuration) async {
    double originalDuration = await _getVideoDuration(filepath);
    debugPrint("originalDuration: $originalDuration");
    if (originalDuration == 0.0) {
      return 1.0;
    }
    return targetDuration / originalDuration;
  }

  // adjust Video Speed
  static Future<String> adjustVideoSpeed(String filepath, double targetDuration, String? outputPath) async {
    Directory? appDir = await getApplicationCacheDirectory();
    outputPath ??= '${appDir.path}/result.mp4';

    // 프레임 수 기반으로 정확한 fps 계산
    final frameCount = await _getVideoFrameCount(filepath);
    debugPrint("frameCount: $frameCount, targetDuration: $targetDuration");

    String command;
    if (frameCount > 0) {
      // 프레임 수를 목표 duration으로 나누어 정확한 fps 계산
      final targetFps = frameCount / targetDuration;
      debugPrint("targetFps: $targetFps");
      // setpts=N/(fps*TB): N번째 프레임을 정확히 N/fps 초에 배치 (균등 간격)
      // -r 옵션으로 출력 fps 설정
      command = '-y -i $filepath -vf "setpts=N/($targetFps*TB)" -r $targetFps -c:v libx264 -pix_fmt yuv420p $outputPath';
    } else {
      // 프레임 수를 가져올 수 없는 경우 기존 방식 fallback
      final speedRatio = await _calculateSpeedRatio(filepath, targetDuration);
      debugPrint("fallback speedRatio: $speedRatio");
      command = '-y -i $filepath -filter:v "setpts=$speedRatio*PTS" $outputPath';
    }

    debugPrint("ffmpeg command: $command");
    final result = await FFmpegKit.execute(command);
    final returnCode = await result.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      return outputPath;
    } else {
      return "";
    }
  }
}
