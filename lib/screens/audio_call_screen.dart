import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AudioCallScreen extends StatefulWidget {
  final String callId;
  final String channelName;
  final String otherUserName;
  final String token;

  const AudioCallScreen({
    super.key,
    required this.callId,
    required this.channelName,
    required this.otherUserName,
    required this.token,
  });

  @override
  State<AudioCallScreen> createState() =>
      _AudioCallScreenState();
}

class _AudioCallScreenState
    extends State<AudioCallScreen> {
  final SupabaseClient supabase =
      Supabase.instance.client;

  RtcEngine? engine;

  RealtimeChannel? callStatusChannel;

  bool isJoined = false;
  bool isMuted = false;
  bool isSpeakerOn = true;
  bool remoteUserJoined = false;

  bool isEndingCall = false;
  bool callAccepted = false;
  bool screenClosed = false;

  Timer? durationTimer;
  int durationSeconds = 0;

  @override
  void initState() {
    super.initState();

    // Listen for changes to this call.
    setupCallStatusListener();

    // Initialize Agora.
    initializeAgora();
  }

  // ============================================================
  // SUPABASE CALL STATUS LISTENER
  // ============================================================

  void setupCallStatusListener() {
    callStatusChannel = supabase
        .channel(
          'call-status-${widget.callId}',
        )
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
            final updatedCall =
                payload.newRecord;

            final status =
                updatedCall['status']?.toString();

            debugPrint(
              'Call status updated: $status',
            );

            if (status == 'accepted') {
              if (!mounted) return;

              setState(() {
                callAccepted = true;
              });

              return;
            }

            // Other user ended or rejected the call.
            if (status == 'ended' ||
                status == 'rejected' ||
                status == 'missed' ||
                status == 'cancelled') {
              closeCallFromRemote();
            }
          },
        )
        .subscribe();
  }

  // ============================================================
  // CLOSE CALL WHEN OTHER USER ENDS IT
  // ============================================================

  Future<void> closeCallFromRemote() async {
    if (screenClosed) return;

    screenClosed = true;

    durationTimer?.cancel();

    try {
      if (engine != null) {
        await engine!.leaveChannel();
        await engine!.release();
        engine = null;
      }
    } catch (e) {
      debugPrint(
        'Remote call close error: $e',
      );
    }

    if (!mounted) return;

    showMessage(
      'Call ended by the other user',
    );

    await Future.delayed(
      const Duration(milliseconds: 500),
    );

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  // ============================================================
  // INITIALIZE AGORA
  // ============================================================

  Future<void> initializeAgora() async {
    try {
      final agora = createAgoraRtcEngine();

      engine = agora;

      await agora.initialize(
        const RtcEngineContext(
          appId:
              'e7d3d9d55c00404aadd73b8434861f56',
          channelProfile:
              ChannelProfileType
                  .channelProfileCommunication,
        ),
      );

      agora.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess:
              (
            RtcConnection connection,
            int elapsed,
          ) {
            debugPrint(
              'Joined Agora channel',
            );

            if (!mounted) return;

            setState(() {
              isJoined = true;
            });
          },

          onUserJoined:
              (
            RtcConnection connection,
            int remoteUid,
            int elapsed,
          ) async {
            debugPrint(
              'Remote user joined: $remoteUid',
            );

            if (!mounted) return;

            setState(() {
              remoteUserJoined = true;
              callAccepted = true;
            });

            // Update Supabase call status.
            try {
              await supabase
                  .from('calls')
                  .update({
                'status': 'accepted',
                'started_at':
                    DateTime.now()
                        .toIso8601String(),
              })
                  .eq(
                'id',
                widget.callId,
              );
            } catch (e) {
              debugPrint(
                'Accept status update error: $e',
              );
            }

            startDurationTimer();
          },

          onUserOffline:
              (
            RtcConnection connection,
            int remoteUid,
            UserOfflineReasonType reason,
          ) async {
            debugPrint(
              'Remote user left: $remoteUid',
            );

            if (!mounted) return;

            setState(() {
              remoteUserJoined = false;
            });

            // Update call status if the remote user
            // disconnects from Agora.
            if (!screenClosed) {
              await closeCallFromRemote();
            }
          },

          onLeaveChannel:
              (
            RtcConnection connection,
            RtcStats stats,
          ) {
            debugPrint(
              'Left Agora channel',
            );
          },

          onError:
              (
            ErrorCodeType err,
            String msg,
          ) {
            debugPrint(
              'Agora error: $err - $msg',
            );
          },
        ),
      );

      await agora.enableAudio();

      await agora.setEnableSpeakerphone(
        true,
      );

      await agora.joinChannel(
        token: widget.token,
        channelId: widget.channelName,
        uid: 0,
        options: const ChannelMediaOptions(
          channelProfile:
              ChannelProfileType
                  .channelProfileCommunication,
          publishMicrophoneTrack: true,
          autoSubscribeAudio: true,
        ),
      );
    } catch (e) {
      debugPrint(
        'Agora initialization error: $e',
      );

      if (!mounted) return;

      showMessage(
        'Unable to connect to audio call',
      );
    }
  }

  // ============================================================
  // TIMER
  // ============================================================

  void startDurationTimer() {
    durationTimer?.cancel();

    durationTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (!mounted || screenClosed) return;

        setState(() {
          durationSeconds++;
        });
      },
    );
  }

  String formatDuration() {
    final minutes =
        durationSeconds ~/ 60;

    final seconds =
        durationSeconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // MUTE / UNMUTE
  // ============================================================

  Future<void> toggleMute() async {
    if (engine == null) return;

    try {
      final newMuteState = !isMuted;

      await engine!
          .muteLocalAudioStream(
        newMuteState,
      );

      if (!mounted) return;

      setState(() {
        isMuted = newMuteState;
      });

      debugPrint(
        newMuteState
            ? 'Microphone muted'
            : 'Microphone unmuted',
      );
    } catch (e) {
      debugPrint(
        'Mute error: $e',
      );
    }
  }

  // ============================================================
  // SPEAKER ON / OFF
  // ============================================================

  Future<void> toggleSpeaker() async {
    if (engine == null) return;

    try {
      final newSpeakerState =
          !isSpeakerOn;

      await engine!
          .setEnableSpeakerphone(
        newSpeakerState,
      );

      if (!mounted) return;

      setState(() {
        isSpeakerOn =
            newSpeakerState;
      });

      debugPrint(
        newSpeakerState
            ? 'Speaker enabled'
            : 'Speaker disabled',
      );
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
    if (isEndingCall ||
        screenClosed) {
      return;
    }

    isEndingCall = true;
    screenClosed = true;

    durationTimer?.cancel();

    try {
      // First update Supabase.
      // This automatically notifies the other user.
      await supabase
          .from('calls')
          .update({
        'status': 'ended',
        'ended_at':
            DateTime.now()
                .toIso8601String(),
        'duration_seconds':
            durationSeconds,
      })
          .eq(
            'id',
            widget.callId,
          );

      // Leave Agora.
      if (engine != null) {
        await engine!.leaveChannel();
        await engine!.release();
        engine = null;
      }

      if (!mounted) return;

      Navigator.of(context).pop();
    } catch (e) {
      debugPrint(
        'End call error: $e',
      );

      // Close screen even if Supabase update fails.
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void showMessage(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
          ),
        ),
      );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    durationTimer?.cancel();

    if (callStatusChannel != null) {
      supabase.removeChannel(
        callStatusChannel!,
      );
    }

    engine?.leaveChannel();
    engine?.release();
    engine = null;

    super.dispose();
  }

  // ============================================================
  // CALL STATUS TEXT
  // ============================================================

  String getCallStatusText() {
    if (!isJoined) {
      return 'Connecting...';
    }

    if (remoteUserJoined) {
      return formatDuration();
    }

    if (callAccepted) {
      return 'Waiting for connection...';
    }

    return 'Calling...';
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return WillPopScope (
      onWillPop: () async {
        await endCall();
        return false;
      },

      child: Scaffold(
        backgroundColor:
            Colors.black,

        appBar: AppBar(
          backgroundColor:
              Colors.black,
          foregroundColor:
              Colors.white,
          elevation: 0,

          automaticallyImplyLeading:
              false,

          title: const Text(
            'Audio Call',
          ),
        ),

        body: SafeArea(
          child: Column(
            children: [
              const Spacer(),

              CircleAvatar(
                radius: 60,

                backgroundColor:
                    Colors.blue.shade100,

                child: Text(
                  widget.otherUserName
                          .isNotEmpty
                      ? widget
                          .otherUserName[0]
                          .toUpperCase()
                      : '?',

                  style:
                      const TextStyle(
                    fontSize: 45,
                    fontWeight:
                        FontWeight.bold,
                    color:
                        Colors.blue,
                  ),
                ),
              ),

              const SizedBox(
                height: 25,
              ),

              Text(
                widget.otherUserName,

                style:
                    const TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 12,
              ),

              Text(
                getCallStatusText(),

                style:
                    const TextStyle(
                  color: Colors.white70,
                  fontSize: 17,
                ),
              ),

              const Spacer(),

              Padding(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 35,
                  vertical: 30,
                ),

                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .spaceEvenly,

                  children: [
                    // ============================
                    // MUTE
                    // ============================

                    Column(
                      mainAxisSize:
                          MainAxisSize.min,

                      children: [
                        CircleAvatar(
                          radius: 30,

                          backgroundColor:
                              isMuted
                                  ? Colors.white
                                  : Colors.white24,

                          child: IconButton(
                            onPressed:
                                toggleMute,

                            icon: Icon(
                              isMuted
                                  ? Icons
                                      .mic_off
                                  : Icons.mic,

                              color: isMuted
                                  ? Colors.black
                                  : Colors.white,
                            ),
                          ),
                        ),

                        const SizedBox(
                          height: 8,
                        ),

                        Text(
                          isMuted
                              ? 'Unmute'
                              : 'Mute',

                          style:
                              const TextStyle(
                            color:
                                Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),

                    // ============================
                    // SPEAKER
                    // ============================

                    Column(
                      mainAxisSize:
                          MainAxisSize.min,

                      children: [
                        CircleAvatar(
                          radius: 30,

                          backgroundColor:
                              isSpeakerOn
                                  ? Colors.blue
                                  : Colors.white24,

                          child: IconButton(
                            onPressed:
                                toggleSpeaker,

                            icon: Icon(
                              isSpeakerOn
                                  ? Icons
                                      .volume_up
                                  : Icons
                                      .volume_off,

                              color:
                                  Colors.white,
                            ),
                          ),
                        ),

                        const SizedBox(
                          height: 8,
                        ),

                        Text(
                          isSpeakerOn
                              ? 'Speaker'
                              : 'Earpiece',

                          style:
                              const TextStyle(
                            color:
                                Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),

                    // ============================
                    // END CALL
                    // ============================

                    Column(
                      mainAxisSize:
                          MainAxisSize.min,

                      children: [
                        CircleAvatar(
                          radius: 32,

                          backgroundColor:
                              Colors.red,

                          child: IconButton(
                            onPressed:
                                isEndingCall
                                    ? null
                                    : endCall,

                            icon: const Icon(
                              Icons.call_end,
                              color:
                                  Colors.white,
                              size: 28,
                            ),
                          ),
                        ),

                        const SizedBox(
                          height: 8,
                        ),

                        const Text(
                          'End',

                          style: TextStyle(
                            color:
                                Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
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
}