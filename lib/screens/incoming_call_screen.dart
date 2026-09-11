
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'audio_call_screen.dart';
import 'video_call_screen.dart';

class IncomingCallScreen extends StatefulWidget {
  final String callId;
  final String callerId;
  final String callerName;
  final String callType;
  final String channelName;
  final String token;

  const IncomingCallScreen({
    super.key,
    required this.callId,
    required this.callerId,
    required this.callerName,
    required this.callType,
    required this.channelName,
    required this.token,
  });

  @override
  State<IncomingCallScreen> createState() =>
      _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  bool isProcessing = false;

  RealtimeChannel? callStatusChannel;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    listenForCallStatus();
  }

  // ============================================================
  // LISTEN FOR CALL STATUS
  // ============================================================

  void listenForCallStatus() {
    callStatusChannel = supabase
        .channel('incoming-call-status-${widget.callId}')
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
            final call = payload.newRecord;

            final String? status =
                call['status']?.toString();

            debugPrint(
              'Incoming call status changed: $status',
            );

            // ====================================================
            // CALLER CANCELLED / ENDED CALL
            // ====================================================

            if (status == 'ended' ||
                status == 'rejected' ||
                status == 'busy' ||
                status == 'failed') {
              if (!mounted) return;

              // If the receiver is currently processing
              // accept/reject, don't pop unexpectedly.
              if (isProcessing) return;

              Navigator.pop(context);
            }
          },
        )
        .subscribe();

    debugPrint(
      'Listening for call status: ${widget.callId}',
    );
  }

  // ============================================================
  // ACCEPT CALL
  // ============================================================

  Future<void> acceptCall() async {
    if (isProcessing) return;

    setState(() {
      isProcessing = true;
    });

    try {
      // First check the current call status.
      final callResponse = await supabase
          .from('calls')
          .select('status')
          .eq('id', widget.callId)
          .maybeSingle();

      if (callResponse == null) {
        throw Exception('Call no longer exists.');
      }

      final currentStatus =
          callResponse['status']?.toString();

      // Caller already cancelled.
      if (currentStatus != 'ringing') {
        if (!mounted) return;

        setState(() {
          isProcessing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This call is no longer available.',
            ),
          ),
        );

        Navigator.pop(context);
        return;
      }

      // Accept the call.
      await supabase
          .from('calls')
          .update({
            'status': 'accepted',
            'started_at':
                DateTime.now().toIso8601String(),
          })
          .eq('id', widget.callId);

      if (!mounted) return;

      // ========================================================
      // VIDEO CALL
      // ========================================================

      if (widget.callType == 'video') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => VideoCallScreen(
              callId: widget.callId,
              channelName: widget.channelName,
              otherUserName: widget.callerName,
              token: widget.token,
            ),
          ),
        );
      }

      // ========================================================
      // AUDIO CALL
      // ========================================================

      else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AudioCallScreen(
              callId: widget.callId,
              channelName: widget.channelName,
              otherUserName: widget.callerName,
              token: widget.token,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint(
        'Accept call error: $e',
      );

      if (!mounted) return;

      setState(() {
        isProcessing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to accept call: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // REJECT CALL
  // ============================================================

  Future<void> rejectCall() async {
    if (isProcessing) return;

    setState(() {
      isProcessing = true;
    });

    try {
      await supabase
          .from('calls')
          .update({
            'status': 'rejected',
            'ended_at':
                DateTime.now().toIso8601String(),
          })
          .eq('id', widget.callId);

      if (!mounted) return;

      Navigator.pop(context);
    } catch (e) {
      debugPrint(
        'Reject call error: $e',
      );

      if (!mounted) return;

      setState(() {
        isProcessing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to reject call: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    if (callStatusChannel != null) {
      supabase.removeChannel(callStatusChannel!);
      callStatusChannel = null;
    }

    super.dispose();
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final bool isVideo =
        widget.callType == 'video';

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 30,
            ),
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                const Text(
                  'Incoming Call',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 40),

                CircleAvatar(
                  radius: 65,
                  backgroundColor:
                      Colors.blue.shade100,
                  child: const Icon(
                    Icons.person,
                    size: 70,
                    color: Colors.blue,
                  ),
                ),

                const SizedBox(height: 25),

                Text(
                  widget.callerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  isVideo
                      ? 'Incoming video call'
                      : 'Incoming audio call',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 60),

                if (isProcessing)
                  const CircularProgressIndicator(
                    color: Colors.white,
                  )
                else
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceEvenly,
                    children: [
                      // ==================================================
                      // REJECT
                      // ==================================================

                      Column(
                        children: [
                          FloatingActionButton(
                            heroTag: 'reject_call',
                            backgroundColor: Colors.red,
                            onPressed: rejectCall,
                            child: const Icon(
                              Icons.call_end,
                              color: Colors.white,
                            ),
                          ),

                          const SizedBox(height: 10),

                          const Text(
                            'Reject',
                            style: TextStyle(
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),

                      // ==================================================
                      // ACCEPT
                      // ==================================================

                      Column(
                        children: [
                          FloatingActionButton(
                            heroTag: 'accept_call',
                            backgroundColor:
                                Colors.green,
                            onPressed: acceptCall,
                            child: Icon(
                              isVideo
                                  ? Icons.videocam
                                  : Icons.call,
                              color: Colors.white,
                            ),
                          ),

                          const SizedBox(height: 10),

                          const Text(
                            'Accept',
                            style: TextStyle(
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}