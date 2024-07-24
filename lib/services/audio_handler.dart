import 'package:PiliPalaX/services/service_locator.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:hive/hive.dart';
import 'package:PiliPalaX/models/bangumi/info.dart';
import 'package:PiliPalaX/models/video_detail_res.dart';
import 'package:PiliPalaX/plugin/pl_player/index.dart';
import 'package:PiliPalaX/utils/storage.dart';
import 'dart:io';

Future<VideoPlayerServiceHandler> initAudioService() async {
  return await AudioService.init(
    builder: () => VideoPlayerServiceHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.orz12.PiliPalaX.audio',
      androidNotificationChannelName: 'Audio Service PiliPalaX',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      fastForwardInterval: Duration(seconds: 10),
      rewindInterval: Duration(seconds: 10),
      androidNotificationChannelDescription: 'Media notification channel',
      androidNotificationIcon: 'drawable/ic_notification_icon',
    ),
  );
}

class VideoPlayerServiceHandler extends BaseAudioHandler with SeekHandler {
  // static final List<MediaItem> _item = [];
  Box setting = GStorage.setting;
  bool enableBackgroundPlay = true;
  // PlPlayerController player = PlPlayerController.getInstance();

  VideoPlayerServiceHandler() {
    revalidateSetting();
  }

  revalidateSetting() {
    enableBackgroundPlay =
        setting.get(SettingBoxKey.enableBackgroundPlay, defaultValue: true);
  }

  @override
  Future<void> play() async {
    await PlPlayerController.playIfExists();
    // player.play();
  }

  @override
  Future<void> pause() async {
    await PlPlayerController.pauseIfExists();
    // player.pause();
  }

  seekToNotification(Duration position) {
    playbackState.add(playbackState.value.copyWith(
      updatePosition: position,
    ));
  }

  @override
  Future<void> seek(Duration position) async {
    SmartDialog.showNotify(
        msg: "跳转至${position.inSeconds}秒", notifyType: NotifyType.alert);
    playbackState.add(playbackState.value.copyWith(
      updatePosition: position,
    ));
    await PlPlayerController.seekToIfExists(position);
    // await player.seekTo(position);
  }

  Future<void> setMediaItem(MediaItem newMediaItem) async {
    if (!enableBackgroundPlay) return;
    // print("此时调用栈为：");
    // print(newMediaItem);
    // print(newMediaItem.title);
    // debugPrint(StackTrace.current.toString());
    if (!mediaItem.isClosed) mediaItem.add(newMediaItem);
  }

  Future<void> setPlaybackState(PlayerStatus status, bool isBuffering) async {
    if (!enableBackgroundPlay) return;

    final AudioProcessingState processingState;
    final playing = status == PlayerStatus.playing;
    if (status == PlayerStatus.completed) {
      processingState = AudioProcessingState.completed;
    } else if (isBuffering) {
      processingState = AudioProcessingState.buffering;
    } else {
      processingState = AudioProcessingState.ready;
    }

    playbackState.add(playbackState.value.copyWith(
      processingState:
          isBuffering ? AudioProcessingState.buffering : processingState,
      controls: [
        MediaControl.rewind
            .copyWith(androidIcon: 'drawable/ic_baseline_replay_10_24'),
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.fastForward
            .copyWith(androidIcon: 'drawable/ic_baseline_forward_10_24'),
      ],
      androidCompactActionIndices: const [0, 1, 2],
      playing: playing,
      systemActions: const {
        MediaAction.seek,
      },
    ));
  }

  onStatusChange(PlayerStatus status, bool isBuffering) {
    if (!enableBackgroundPlay) return;

    // if (_item.isEmpty) return;
    Future.delayed(const Duration(milliseconds: 500), () {
      setPlaybackState(status, isBuffering);
    });
  }

  onVideoDetailChange(dynamic data, int cid) {
    SmartDialog.showNotify(msg: data.toString(), notifyType: NotifyType.alert);
    if (!enableBackgroundPlay) return;
    // print('当前调用栈为：');
    // print(StackTrace.current);

    // SmartDialog.showToast(data.title+"a");
    if (!PlPlayerController.instanceExists()) {
      SmartDialog.showToast(data.title + "b");
      return;
    }
    if (data == null) {
      SmartDialog.showToast(data.title + "c");
      return;
    }

    late MediaItem? mediaItem;
    if (data is VideoDetailData) {
      // SmartDialog.showToast("${data.title}d");
      if ((data.pages?.length ?? 0) > 1) {
        // SmartDialog.showToast("${data.title}e");
        final current = data.pages?.firstWhere((element) => element.cid == cid);
        mediaItem = MediaItem(
          id: UniqueKey().toString(),
          title: current?.pagePart ?? "",
          artist: data.title ?? "",
          album: data.title ?? "",
          duration: Duration(seconds: current?.duration ?? 0),
          artUri: Uri.parse(data.pic ?? ""),
        );
      } else {
        // SmartDialog.showToast("${data.title}f");
        mediaItem = MediaItem(
          id: UniqueKey().toString(),
          title: data.title ?? "",
          artist: data.owner?.name ?? "",
          duration: Duration(seconds: data.duration ?? 0),
          artUri: Uri.parse(data.pic ?? ""),
        );
      }
    } else if (data is BangumiInfoModel) {
      final current =
          data.episodes?.firstWhere((element) => element.cid == cid);
      mediaItem = MediaItem(
        id: UniqueKey().toString(),
        title: current?.longTitle ?? "",
        artist: data.title ?? "",
        duration: Duration(milliseconds: current?.duration ?? 0),
        artUri: Uri.parse(data.cover ?? ""),
      );
    }

    // SmartDialog.showToast("${data.title}g");
    if (mediaItem == null) {
      SmartDialog.showToast("${data.title}h");
      return;
    }

    // SmartDialog.showToast("${data.title}h");
    // print("exist: ${PlPlayerController.instanceExists()}");
    if (!PlPlayerController.instanceExists()) {
      SmartDialog.showToast("${data.title}i");
      return;
    }

    SmartDialog.showToast(mediaItem.title ?? "无");
    // _item.add(mediaItem);
    setMediaItem(mediaItem);
  }

  onVideoDetailDispose() {
    if (!enableBackgroundPlay) return;

    playbackState.add(playbackState.value.copyWith(
      processingState: Platform.isIOS
          ? AudioProcessingState.ready
          : AudioProcessingState.idle,
      playing: false,
    ));
    // if (_item.isNotEmpty) {
    //   _item.removeLast();
    // }
    // if (_item.isNotEmpty) {
    //   setMediaItem(_item.last);
    //   // stop();
    // } else {
    //   clear();
    // }
  }

  clear() {
    if (!enableBackgroundPlay) return;
    mediaItem.add(null);
    playbackState.add(PlaybackState(
      processingState: Platform.isIOS
          ? AudioProcessingState.ready
          : AudioProcessingState.idle,
      playing: false,
    ));
    // _item.clear();
    // stop();
  }

  onPositionChange(Duration position) {
    if (!enableBackgroundPlay) return;

    playbackState.add(playbackState.value.copyWith(
      updatePosition: position,
    ));
  }
}
