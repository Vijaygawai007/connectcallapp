import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VideoCallScreen extends StatefulWidget {
  final String callId;
  final String channelName;
  final String otherUserName;
  final String token;

  const VideoCallScreen({
    super.key,
    required this.callId,
    required this.channelName,
    required this.otherUserName,
    required this.token,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  late RtcEngine engine;

  int? remoteUid;

  bool isMuted = false;
  bool isCameraOff = false;
  bool isSpeakerOn = true;
  bool isJoined = false;

  bool isEnding = false;
  bool engineInitialized = false;
  bool isRemoteDisconnecting = false;

  int callDuration = 0;
  Timer? durationTimer;

  RealtimeChannel? callStatusChannel;

  @override
  void initState() {
    super.initState();

    setupCallStatusListener();
    initializeAgora();
  }

  // ============================================================
  // SUPABASE CALL STATUS LISTENER
  // ============================================================

  void setupCallStatusListener() {
    callStatusChannel = supabase
        .channel('video_call_${widget.callId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'calls',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.callId,
          ),
          callback: (payload) {
            final Map<String, dynamic> record =
                Map<String, dynamic>.from(payload.newRecord);

            final String status =
                record['status']?.toString().toLowerCase() ?? '';

            debugPrint(
              'VIDEO CALL STATUS: $status',
            );

            if (status == 'ended' ||
                status == 'rejected' ||
                status == 'busy' ||
                status == 'failed') {
              closeBecauseRemoteEnded(status);
            }
          },
        )
        .subscribe((status, error) {
      debugPrint(
        'Video call realtime status: $status',
      );

      if (error != null) {
        debugPrint(
          'Video call realtime error: $error',
        );
      }
    });
  }

  // ============================================================
  // REMOTE CALL ENDED FROM SUPABASE
  // ============================================================

  Future<void> closeBecauseRemoteEnded(String status) async {
    if (isEnding || isRemoteDisconnecting) {
      return;
    }

    isRemoteDisconnecting = true;
    isEnding = true;

    durationTimer?.cancel();

    debugPrint(
      'Remote call ended. Closing video screen.',
    );

    try {
      if (engineInitialized) {
        await engine.leaveChannel();
      }
    } catch (e) {
      debugPrint(
        'Remote leave error: $e',
      );
    }

    if (!mounted) {
      return;
    }

    String message = 'Call ended';

    if (status == 'rejected') {
      message = 'Call rejected';
    } else if (status == 'busy') {
      message = '${widget.otherUserName} is busy';
    } else if (status == 'failed') {
      message = 'Call failed';
    } else {
      message = '${widget.otherUserName} ended the call';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 800),
      ),
    );

    await Future.delayed(
      const Duration(milliseconds: 500),
    );

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  // ============================================================
  // AGORA INITIALIZATION
  // ============================================================

  Future<void> initializeAgora() async {
    try {
      engine = createAgoraRtcEngine();

      await engine.initialize(
        const RtcEngineContext(
          appId: 'e7d3d9d55c00404aadd73b8434861f56',
          channelProfile:
              ChannelProfileType.channelProfileCommunication,
        ),
      );

      engineInitialized = true;

      engine.registerEventHandler(
        RtcEngineEventHandler(
          // ======================================================
          // LOCAL USER JOINED
          // ======================================================

          onJoinChannelSuccess: (
            RtcConnection connection,
            int elapsed,
          ) {
            if (!mounted || isEnding) {
              return;
            }

            debugPrint(
              'Joined video channel: ${connection.channelId}',
            );

            setState(() {
              isJoined = true;
            });

            startDurationTimer();
          },

          // ======================================================
          // REMOTE USER JOINED
          // ======================================================

          onUserJoined: (
            RtcConnection connection,
            int uid,
            int elapsed,
          ) {
            if (!mounted || isEnding) {
              return;
            }

            debugPrint(
              'Remote user joined: $uid',
            );

            setState(() {
              remoteUid = uid;
            });
          },

          // ======================================================
          // REMOTE USER LEFT
          // ======================================================

          onUserOffline: (
            RtcConnection connection,
            int uid,
            UserOfflineReasonType reason,
          ) {
            debugPrint(
              'Remote user disconnected: $uid',
            );

            debugPrint(
              'Reason: $reason',
            );

            if (!mounted || isEnding) {
              return;
            }

            setState(() {
              remoteUid = null;
            });

            // IMPORTANT:
            // Automatically close this video screen.
            handleRemoteUserOffline();
          },

          // ======================================================
          // AGORA ERROR
          // ======================================================

          onError: (
            ErrorCodeType err,
            String msg,
          ) {
            debugPrint(
              'Agora Error: $err - $msg',
            );
          },
        ),
      );

      // ==========================================================
      // ENABLE AUDIO
      // ==========================================================

      await engine.enableAudio();

      // ==========================================================
      // ENABLE VIDEO
      // ==========================================================

      await engine.enableVideo();

      // ==========================================================
      // CAMERA PREVIEW
      // ==========================================================

      await engine.startPreview();

      // ==========================================================
      // SPEAKER
      // ==========================================================

      await engine.setEnableSpeakerphone(true);

      // ==========================================================
      // JOIN CHANNEL
      // ==========================================================

      await engine.joinChannel(
        token: widget.token,
        channelId: widget.channelName,
        uid: 0,
        options: const ChannelMediaOptions(
          channelProfile:
              ChannelProfileType.channelProfileCommunication,
          clientRoleType:
              ClientRoleType.clientRoleBroadcaster,
          publishCameraTrack: true,
          publishMicrophoneTrack: true,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
        ),
      );
    } catch (e) {
      debugPrint(
        'Agora initialization error: $e',
      );

      if (!mounted || isEnding) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to start video call: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // REMOTE USER OFFLINE
  // ============================================================

  Future<void> handleRemoteUserOffline() async {
    if (isEnding || isRemoteDisconnecting) {
      return;
    }

    isRemoteDisconnecting = true;
    isEnding = true;

    durationTimer?.cancel();

    debugPrint(
      'Other user disconnected. Ending local video call.',
    );

    // ----------------------------------------------------------
    // Update Supabase
    // ----------------------------------------------------------

    try {
      await supabase
          .from('calls')
          .update({
            'status': 'ended',
            'ended_at': DateTime.now().toIso8601String(),
            'duration_seconds': callDuration,
          })
          .eq('id', widget.callId)
          .neq('status', 'ended');
    } catch (e) {
      debugPrint(
        'Could not update call status: $e',
      );
    }

    // ----------------------------------------------------------
    // Leave Agora
    // ----------------------------------------------------------

    try {
      if (engineInitialized) {
        await engine.leaveChannel();
      }
    } catch (e) {
      debugPrint(
        'Leave channel error: $e',
      );
    }

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${widget.otherUserName} disconnected',
        ),
        duration: const Duration(milliseconds: 800),
      ),
    );

    await Future.delayed(
      const Duration(milliseconds: 500),
    );

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  // ============================================================
  // TIMER
  // ============================================================

  void startDurationTimer() {
    durationTimer?.cancel();

    durationTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!mounted || isEnding) {
          timer.cancel();
          return;
        }

        setState(() {
          callDuration++;
        });
      },
    );
  }

  // ============================================================
  // FORMAT DURATION
  // ============================================================

  String formatDuration(int seconds) {
    final int minutes = seconds ~/ 60;
    final int remainingSeconds = seconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${remainingSeconds.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // MUTE
  // ============================================================

  Future<void> toggleMute() async {
    if (!engineInitialized || isEnding) {
      return;
    }

    try {
      isMuted = !isMuted;

      await engine.muteLocalAudioStream(
        isMuted,
      );

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint(
        'Mute error: $e',
      );
    }
  }

  // ============================================================
  // CAMERA
  // ============================================================

  Future<void> toggleCamera() async {
    if (!engineInitialized || isEnding) {
      return;
    }

    try {
      isCameraOff = !isCameraOff;

      await engine.muteLocalVideoStream(
        isCameraOff,
      );

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint(
        'Camera error: $e',
      );
    }
  }

  // ============================================================
  // SWITCH CAMERA
  // ============================================================

  Future<void> switchCamera() async {
    if (!engineInitialized || isEnding) {
      return;
    }

    try {
      await engine.switchCamera();
    } catch (e) {
      debugPrint(
        'Switch camera error: $e',
      );
    }
  }

  // ============================================================
  // SPEAKER
  // ============================================================

  Future<void> toggleSpeaker() async {
    if (!engineInitialized || isEnding) {
      return;
    }

    try {
      isSpeakerOn = !isSpeakerOn;

      await engine.setEnableSpeakerphone(
        isSpeakerOn,
      );

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint(
        'Speaker error: $e',
      );
    }
  }

  // ============================================================
  // END CALL
  // ============================================================

  Future<void> endCall() async {
    if (isEnding) {
      return;
    }

    isEnding = true;

    if (mounted) {
      setState(() {});
    }

    durationTimer?.cancel();

    debugPrint(
      'User manually ended video call.',
    );

    // ----------------------------------------------------------
    // Update Supabase first
    // ----------------------------------------------------------

    try {
      await supabase
          .from('calls')
          .update({
            'status': 'ended',
            'ended_at': DateTime.now().toIso8601String(),
            'duration_seconds': callDuration,
          })
          .eq('id', widget.callId);
    } catch (e) {
      debugPrint(
        'End call database error: $e',
      );
    }

    // ----------------------------------------------------------
    // Leave Agora
    // ----------------------------------------------------------

    try {
      if (engineInitialized) {
        await engine.leaveChannel();
      }
    } catch (e) {
      debugPrint(
        'End call leave error: $e',
      );
    }

    // ----------------------------------------------------------
    // Release Agora
    // ----------------------------------------------------------

    try {
      if (engineInitialized) {
        await engine.release();
        engineInitialized = false;
      }
    } catch (e) {
      debugPrint(
        'End call release error: $e',
      );
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  // ============================================================
  // REMOTE VIDEO
  // ============================================================

  Widget buildRemoteVideo() {
    if (remoteUid != null && engineInitialized) {
      return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: engine,
          canvas: VideoCanvas(
            uid: remoteUid,
          ),
          connection: RtcConnection(
            channelId: widget.channelName,
          ),
        ),
      );
    }

    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            const CircleAvatar(
              radius: 45,
              child: Icon(
                Icons.person,
                size: 50,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.otherUserName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isJoined
                  ? 'Waiting for ${widget.otherUserName}...'
                  : 'Connecting...',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // LOCAL VIDEO
  // ============================================================

  Widget buildLocalVideo() {
    if (!engineInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
          ),
        ),
      );
    }

    if (isCameraOff) {
      return Container(
        color: Colors.grey.shade900,
        child: const Center(
          child: Icon(
            Icons.videocam_off,
            color: Colors.white,
            size: 30,
          ),
        ),
      );
    }

    return AgoraVideoView(
      controller: VideoViewController(
        rtcEngine: engine,
        canvas: const VideoCanvas(
          uid: 0,
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (
        bool didPop,
        dynamic result,
      ) {
        if (!didPop && !isEnding) {
          endCall();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              // ==================================================
              // REMOTE VIDEO
              // ==================================================

              Positioned.fill(
                child: buildRemoteVideo(),
              ),

              // ==================================================
              // TOP INFORMATION
              // ==================================================

              Positioned(
                top: 20,
                left: 20,
                right: 20,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.white24,
                      child: Text(
                        widget.otherUserName.isNotEmpty
                            ? widget.otherUserName[0]
                                .toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.otherUserName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            isJoined
                                ? formatDuration(
                                    callDuration,
                                  )
                                : 'Connecting...',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ==================================================
              // LOCAL VIDEO
              // ==================================================

              Positioned(
                top: 90,
                right: 15,
                child: Container(
                  width: 120,
                  height: 170,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius:
                        BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white54,
                      width: 1.5,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: buildLocalVideo(),
                ),
              ),

              // ==================================================
              // CONNECTING
              // ==================================================

              if (!isJoined)
                Positioned(
                  top: 60,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius:
                            BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Connecting...',
                            style: TextStyle(
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // ==================================================
              // BOTTOM CONTROLS
              // ==================================================

              Positioned(
                left: 15,
                right: 15,
                bottom: 20,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceEvenly,
                      children: [
                        callButton(
                          icon: isMuted
                              ? Icons.mic_off
                              : Icons.mic,
                          label: isMuted
                              ? 'Unmute'
                              : 'Mute',
                          onTap: toggleMute,
                        ),
                        callButton(
                          icon: isCameraOff
                              ? Icons.videocam_off
                              : Icons.videocam,
                          label: isCameraOff
                              ? 'Camera On'
                              : 'Camera Off',
                          onTap: toggleCamera,
                        ),
                        callButton(
                          icon: isSpeakerOn
                              ? Icons.volume_up
                              : Icons.volume_off,
                          label: isSpeakerOn
                              ? 'Speaker'
                              : 'Earpiece',
                          onTap: toggleSpeaker,
                        ),
                        callButton(
                          icon:
                              Icons.flip_camera_ios,
                          label: 'Flip',
                          onTap: switchCamera,
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ==================================================
                    // END CALL
                    // ==================================================

                    GestureDetector(
                      onTap: isEnding
                          ? null
                          : endCall,
                      child: Container(
                        width: 65,
                        height: 65,
                        decoration:
                            const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.call_end,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CALL BUTTON
  // ============================================================

  Widget callButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: isEnding ? null : onTap,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white24,
              ),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    durationTimer?.cancel();

    // Remove Supabase realtime listener.
    if (callStatusChannel != null) {
      supabase.removeChannel(
        callStatusChannel!,
      );

      callStatusChannel = null;
    }

    // Safely leave Agora.
    if (engineInitialized) {
      try {
        engine.leaveChannel();
      } catch (e) {
        debugPrint(
          'Dispose leave error: $e',
        );
      }

      try {
        engine.release();
      } catch (e) {
        debugPrint(
          'Dispose release error: $e',
        );
      }

      engineInitialized = false;
    }

    super.dispose();
  }
}