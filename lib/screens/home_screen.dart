import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'audio_call_screen.dart';
import 'incoming_call_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'user_detail_screen.dart';
import 'video_call_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  int selectedIndex = 0;

  final TextEditingController searchController =
      TextEditingController();

  List<Map<String, dynamic>> users = [];
  List<Map<String, dynamic>> filteredUsers = [];
  List<Map<String, dynamic>> recentCalls = [];

  bool isLoadingUsers = true;
  bool isLoadingCalls = true;

  RealtimeChannel? presenceChannel;
  RealtimeChannel? callsChannel;
  RealtimeChannel? profilesChannel;

  final Set<String> onlineUsers = {};

  bool incomingCallScreenOpen = false;

  // ============================================================
  // CURRENT USER AVATAR
  // ============================================================

  String? currentUserAvatar;

  int avatarRefreshKey =
      DateTime.now().millisecondsSinceEpoch;

  // ============================================================
  // AGORA TOKEN
  // ============================================================

  static const String agoraToken =
      '007eJxTYLgaqKdy9PK++awrDpdOzNRqTV/0r2WvTN7q52mdAibemW4KDKnmKcYplimmpskGBiYGJomJKSnmxkkWJsYmFmaGaaZmS27Oz2oIZGSwU3rFzMgAgSA+N0NJanFJckZiXl5qDgMDAE25In4=';

  @override
  void initState() {
    super.initState();

    loadCurrentUser();
    loadCurrentUserAvatar();
    loadUsers();
    loadRecentCalls();

    setupPresence();
    setupIncomingCalls();
    setupProfileListener();

    searchController.addListener(searchUsers);
  }

  @override
  void dispose() {
    searchController.dispose();

    if (presenceChannel != null) {
      supabase.removeChannel(presenceChannel!);
    }

    if (callsChannel != null) {
      supabase.removeChannel(callsChannel!);
    }

    if (profilesChannel != null) {
      supabase.removeChannel(profilesChannel!);
    }

    super.dispose();
  }

  // ============================================================
  // CURRENT USER
  // ============================================================

  User? get currentUser =>
      supabase.auth.currentUser;

  String get currentUserName {
    final metadata = currentUser?.userMetadata;

    if (metadata != null &&
        metadata['name'] != null) {
      return metadata['name'].toString();
    }

    return currentUser?.email?.split('@').first ??
        'User';
  }

  void loadCurrentUser() {
    if (currentUser == null) return;

    if (!mounted) return;

    setState(() {});
  }

  // ============================================================
  // PROFILE REALTIME LISTENER
  // ============================================================

  void setupProfileListener() {
    final user = currentUser;

    if (user == null) return;

    profilesChannel = supabase
        .channel('profile-updates-${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'profiles',
          callback: (payload) async {
            debugPrint('PROFILE UPDATED');

            await handleProfileUpdate(
              payload.newRecord,
            );
          },
        )
        .subscribe();
  }

  // ============================================================
  // HANDLE PROFILE UPDATE
  // ============================================================

  Future<void> handleProfileUpdate(
    Map<String, dynamic> updatedProfile,
  ) async {
    final String updatedId =
        updatedProfile['id']?.toString() ?? '';

    final String? updatedAvatar =
        updatedProfile['avatar_url']?.toString();

    if (updatedId.isEmpty) {
      return;
    }

    if (updatedId == currentUser?.id) {
      if (mounted) {
        setState(() {
          currentUserAvatar = updatedAvatar;

          avatarRefreshKey =
              DateTime.now().millisecondsSinceEpoch;
        });
      }
    }

    for (final user in users) {
      if (user['id']?.toString() == updatedId) {
        user['avatar_url'] = updatedAvatar;

        if (updatedProfile['name'] != null) {
          user['name'] =
              updatedProfile['name'];
        }

        if (updatedProfile['email'] != null) {
          user['email'] =
              updatedProfile['email'];
        }
      }
    }

    for (final user in filteredUsers) {
      if (user['id']?.toString() == updatedId) {
        user['avatar_url'] = updatedAvatar;

        if (updatedProfile['name'] != null) {
          user['name'] =
              updatedProfile['name'];
        }

        if (updatedProfile['email'] != null) {
          user['email'] =
              updatedProfile['email'];
        }
      }
    }

    for (final call in recentCalls) {
      final String? otherUserId =
          call['other_user_id']?.toString();

      if (otherUserId == updatedId) {
        call['other_user_avatar'] =
            updatedAvatar;

        if (updatedProfile['name'] != null) {
          call['other_user_name'] =
              updatedProfile['name'];
        }

        if (updatedProfile['email'] != null) {
          call['other_user_email'] =
              updatedProfile['email'];
        }
      }
    }

    if (!mounted) return;

    setState(() {
      avatarRefreshKey =
          DateTime.now().millisecondsSinceEpoch;
    });
  }

  // ============================================================
  // LOAD CURRENT USER AVATAR
  // ============================================================

  Future<void> loadCurrentUserAvatar() async {
    final user = currentUser;

    if (user == null) {
      return;
    }

    try {
      final response = await supabase
          .from('profiles')
          .select('avatar_url')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        currentUserAvatar =
            response?['avatar_url']?.toString();

        avatarRefreshKey =
            DateTime.now().millisecondsSinceEpoch;
      });
    } catch (e) {
      debugPrint(
        'Unable to load current user avatar: $e',
      );
    }
  }

  // ============================================================
  // LOAD USERS
  // ============================================================

  Future<void> loadUsers() async {
    try {
      final user = currentUser;

      if (user == null) {
        if (mounted) {
          setState(() {
            isLoadingUsers = false;
          });
        }

        return;
      }

      final response = await supabase
          .from('profiles')
          .select(
            'id, name, email, avatar_url, created_at',
          )
          .neq('id', user.id)
          .order('name');

      if (!mounted) return;

      setState(() {
        users =
            List<Map<String, dynamic>>.from(
          response,
        );

        filteredUsers =
            List<Map<String, dynamic>>.from(
          response,
        );

        isLoadingUsers = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoadingUsers = false;
      });

      showMessage(
        'Unable to load users: $e',
      );
    }
  }

  // ============================================================
  // SEARCH USERS
  // ============================================================

  void searchUsers() {
    final query =
        searchController.text
            .trim()
            .toLowerCase();

    if (query.isEmpty) {
      if (!mounted) return;

      setState(() {
        filteredUsers =
            List<Map<String, dynamic>>.from(
          users,
        );
      });

      return;
    }

    final results = users.where((user) {
      final name =
          (user['name'] ?? '')
              .toString()
              .toLowerCase();

      final email =
          (user['email'] ?? '')
              .toString()
              .toLowerCase();

      return name.contains(query) ||
          email.contains(query);
    }).toList();

    if (!mounted) return;

    setState(() {
      filteredUsers = results;
    });
  }

  // ============================================================
  // OPEN USER DETAILS
  // ============================================================

  void openUserDetails(
    Map<String, dynamic> user,
  ) {
    final String userId =
        user['id']?.toString() ?? '';

    final String name =
        user['name']?.toString() ?? 'User';

    final String email =
        user['email']?.toString() ?? '';

    final String? avatarUrl =
        user['avatar_url']?.toString();

    final bool online =
        isUserOnline(userId);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            UserDetailScreen(
          userId: userId,
          name: name,
          email: email,
          avatarUrl: avatarUrl,
          isOnline: online,
          onAudioCall: () {
            startAudioCall(
              userId,
              name,
            );
          },
          onVideoCall: () {
            startVideoCall(
              userId,
              name,
            );
          },
        ),
      ),
    ).then((_) async {
      await loadUsers();
      await loadRecentCalls();
    });
  }

  // ============================================================
  // PRESENCE
  // ============================================================

  Future<void> setupPresence() async {
    final user = currentUser;

    if (user == null) return;

    presenceChannel =
        supabase.channel('online-users');

    presenceChannel!
        .onPresenceSync((payload) {
          updateOnlineUsers();
        })
        .onPresenceJoin((payload) {
          updateOnlineUsers();
        })
        .onPresenceLeave((payload) {
          updateOnlineUsers();
        })
        .subscribe((status, error) async {
          if (status ==
              RealtimeSubscribeStatus.subscribed) {
            await presenceChannel!.track({
              'user_id': user.id,
              'online_at':
                  DateTime.now()
                      .toIso8601String(),
            });

            updateOnlineUsers();
          }
        });
  }

  // ============================================================
  // INCOMING CALL LISTENER
  // ============================================================

  void setupIncomingCalls() {
    final user = currentUser;

    if (user == null) {
      return;
    }

    callsChannel = supabase
        .channel(
          'incoming-calls-${user.id}',
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'calls',
          filter: PostgresChangeFilter(
            type:
                PostgresChangeFilterType.eq,
            column: 'callee_id',
            value: user.id,
          ),
          callback: (payload) {
            final call =
                payload.newRecord;

            final String status =
                call['status']
                        ?.toString()
                        .toLowerCase() ??
                    '';

            if (status == 'ringing') {
              handleIncomingCall(call);
            }
          },
        )
        .subscribe();
  }

  // ============================================================
  // HANDLE INCOMING CALL
  // ============================================================

  Future<void> handleIncomingCall(
    Map<String, dynamic> call,
  ) async {
    if (incomingCallScreenOpen) {
      return;
    }

    try {
      final String? callerId =
          call['caller_id']?.toString();

      if (callerId == null ||
          callerId.isEmpty) {
        return;
      }

      final String callId =
          call['id']?.toString() ?? '';

      final String channelName =
          call['channel_name']
                  ?.toString() ??
              '';

      String callType =
          call['call_type']
                  ?.toString()
                  .toLowerCase() ??
              'audio';

      if (callType != 'audio' &&
          callType != 'video') {
        callType = 'audio';
      }

      final profile = await supabase
          .from('profiles')
          .select('name')
          .eq('id', callerId)
          .maybeSingle();

      if (!mounted) return;

      final String callerName =
          profile?['name']?.toString() ??
              'User';

      incomingCallScreenOpen = true;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              IncomingCallScreen(
            callId: callId,
            callerId: callerId,
            callerName: callerName,
            callType: callType,
            channelName: channelName,
            token: agoraToken,
          ),
        ),
      );

      incomingCallScreenOpen = false;

      await loadRecentCalls();
    } catch (e) {
      incomingCallScreenOpen = false;

      debugPrint(
        'Incoming call error: $e',
      );

      showMessage(
        'Incoming call error: $e',
      );
    }
  }

  // ============================================================
  // UPDATE ONLINE USERS
  // ============================================================

  void updateOnlineUsers() {
    if (presenceChannel == null) {
      return;
    }

    final Set<String> ids = {};

    final state =
        presenceChannel!.presenceState();

    for (final entry in state) {
      for (final presence
          in entry.presences) {
        final payload =
            presence.payload;

        final id =
            payload['user_id'];

        if (id != null) {
          ids.add(id.toString());
        }
      }
    }

    if (!mounted) return;

    setState(() {
      onlineUsers
        ..clear()
        ..addAll(ids);
    });
  }

  bool isUserOnline(String userId) {
    return onlineUsers.contains(userId);
  }

  // ============================================================
  // LOAD RECENT CALLS
  // ============================================================

  Future<void> loadRecentCalls() async {
    try {
      final user = currentUser;

      if (user == null) {
        if (mounted) {
          setState(() {
            isLoadingCalls = false;
          });
        }

        return;
      }

      if (mounted) {
        setState(() {
          isLoadingCalls = true;
        });
      }

      final response = await supabase
          .from('calls')
          .select(
            '''
            id,
            caller_id,
            callee_id,
            call_type,
            status,
            started_at,
            ended_at,
            duration_seconds,
            created_at
            ''',
          )
          .or(
            'caller_id.eq.${user.id},callee_id.eq.${user.id}',
          )
          .order(
            'created_at',
            ascending: false,
          )
          .limit(20);

      final List<Map<String, dynamic>> calls =
          List<Map<String, dynamic>>.from(
        response,
      );

      // ========================================================
      // GET OTHER USER IDS
      // ========================================================

      final Set<String> otherUserIds = {};

      for (final call in calls) {
        final String? callerId =
            call['caller_id']?.toString();

        final String? calleeId =
            call['callee_id']?.toString();

        String? otherUserId;

        if (callerId == user.id) {
          otherUserId = calleeId;
        } else {
          otherUserId = callerId;
        }

        if (otherUserId != null &&
            otherUserId.isNotEmpty) {
          otherUserIds.add(otherUserId);
        }
      }

      // ========================================================
      // LOAD PROFILE DATA
      // ========================================================

      Map<String, Map<String, dynamic>>
          profileMap = {};

      if (otherUserIds.isNotEmpty) {
        final profileResponse =
            await supabase
                .from('profiles')
                .select(
                  'id, name, email, avatar_url',
                )
                .inFilter(
                  'id',
                  otherUserIds.toList(),
                );

        final profiles =
            List<Map<String, dynamic>>.from(
          profileResponse,
        );

        profileMap = {
          for (final profile in profiles)
            profile['id'].toString():
                profile,
        };
      }

      // ========================================================
      // ADD PROFILE DATA TO CALLS
      // ========================================================

      for (final call in calls) {
        final String? callerId =
            call['caller_id']?.toString();

        final String? calleeId =
            call['callee_id']?.toString();

        String? otherUserId;

        if (callerId == user.id) {
          otherUserId = calleeId;
        } else {
          otherUserId = callerId;
        }

        final profile =
            otherUserId != null
                ? profileMap[otherUserId]
                : null;

        call['other_user_id'] =
            otherUserId;

        call['other_user_name'] =
            profile?['name'] ?? 'User';

        call['other_user_email'] =
            profile?['email'] ?? '';

        call['other_user_avatar'] =
            profile?['avatar_url'];
      }

      if (!mounted) return;

      setState(() {
        recentCalls = calls;
        isLoadingCalls = false;

        avatarRefreshKey =
            DateTime.now().millisecondsSinceEpoch;
      });

      debugPrint(
        'Recent calls loaded: ${recentCalls.length}',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoadingCalls = false;
      });

      debugPrint(
        'Unable to load call history: $e',
      );

      showMessage(
        'Unable to load call history',
      );
    }
  }

  // ============================================================
  // GET CALL USER NAME
  // ============================================================

  String getCallUserName(
    Map<String, dynamic> call,
  ) {
    final String? savedName =
        call['other_user_name']?.toString();

    if (savedName != null &&
        savedName.isNotEmpty &&
        savedName != 'null') {
      return savedName;
    }

    final user = currentUser;

    if (user == null) {
      return 'Unknown';
    }

    final callerId =
        call['caller_id']?.toString();

    final calleeId =
        call['callee_id']?.toString();

    final otherUserId =
        callerId == user.id
            ? calleeId
            : callerId;

    for (final profile in users) {
      if (profile['id'].toString() ==
          otherUserId) {
        return profile['name'] ??
            'Unknown';
      }
    }

    return 'User';
  }

  // ============================================================
  // GET CALL USER AVATAR
  // ============================================================

  String? getCallUserAvatar(
    Map<String, dynamic> call,
  ) {
    final String? avatar =
        call['other_user_avatar']
            ?.toString();

    if (avatar != null &&
        avatar.isNotEmpty &&
        avatar != 'null') {
      return avatar;
    }

    final user = currentUser;

    if (user == null) {
      return null;
    }

    final callerId =
        call['caller_id']?.toString();

    final calleeId =
        call['callee_id']?.toString();

    final otherUserId =
        callerId == user.id
            ? calleeId
            : callerId;

    for (final profile in users) {
      if (profile['id'].toString() ==
          otherUserId) {
        final fallbackAvatar =
            profile['avatar_url']
                ?.toString();

        if (fallbackAvatar != null &&
            fallbackAvatar.isNotEmpty &&
            fallbackAvatar != 'null') {
          return fallbackAvatar;
        }
      }
    }

    return null;
  }

  // ============================================================
  // START AUDIO CALL
  // ============================================================

  Future<void> startAudioCall(
    String userId,
    String name,
  ) async {
    try {
      final user = currentUser;

      if (user == null) {
        showMessage(
          'Please login again',
        );
        return;
      }

      if (userId == user.id) {
        showMessage(
          'You cannot call yourself',
        );
        return;
      }

      if (!isUserOnline(userId)) {
        showMessage(
          '$name is offline',
        );
        return;
      }

      final String channelName =
          '${user.id}_${userId}_${DateTime.now().millisecondsSinceEpoch}';

      final response = await supabase
          .from('calls')
          .insert({
            'caller_id': user.id,
            'callee_id': userId,
            'call_type': 'audio',
            'status': 'ringing',
            'channel_name': channelName,
          })
          .select()
          .single();

      final String callId =
          response['id'].toString();

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              AudioCallScreen(
            callId: callId,
            channelName: channelName,
            otherUserName: name,
            token: agoraToken,
          ),
        ),
      );

      await loadRecentCalls();
    } on PostgrestException catch (error) {
      showMessage(
        'Call error: ${error.message}',
      );
    } catch (e) {
      showMessage(
        'Unable to start audio call: $e',
      );
    }
  }

  // ============================================================
  // START VIDEO CALL
  // ============================================================

  Future<void> startVideoCall(
    String userId,
    String name,
  ) async {
    try {
      final user = currentUser;

      if (user == null) {
        showMessage(
          'Please login again',
        );
        return;
      }

      if (userId == user.id) {
        showMessage(
          'You cannot call yourself',
        );
        return;
      }

      if (!isUserOnline(userId)) {
        showMessage(
          '$name is offline',
        );
        return;
      }

      final String channelName =
          '${user.id}_${userId}_${DateTime.now().millisecondsSinceEpoch}';

      final response = await supabase
          .from('calls')
          .insert({
            'caller_id': user.id,
            'callee_id': userId,
            'call_type': 'video',
            'status': 'ringing',
            'channel_name': channelName,
          })
          .select()
          .single();

      final String callId =
          response['id'].toString();

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              VideoCallScreen(
            callId: callId,
            channelName: channelName,
            otherUserName: name,
            token: agoraToken,
          ),
        ),
      );

      await loadRecentCalls();
    } on PostgrestException catch (error) {
      showMessage(
        'Video call error: ${error.message}',
      );
    } catch (e) {
      showMessage(
        'Unable to start video call: $e',
      );
    }
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> logout() async {
    try {
      await supabase.auth.signOut();

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) =>
              const LoginScreen(),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      showMessage(
        'Logout failed: $e',
      );
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          Colors.grey.shade50,

      body: SafeArea(
        child: _buildSelectedPage(),
      ),

      bottomNavigationBar:
          BottomNavigationBar(
        currentIndex:
            selectedIndex,

        type:
            BottomNavigationBarType.fixed,

        selectedItemColor:
            Colors.blue,

        unselectedItemColor:
            Colors.grey,

        onTap: (index) async {
          setState(() {
            selectedIndex = index;
          });

          if (index == 1) {
            await loadUsers();
          }

          if (index == 2) {
            await loadRecentCalls();
          }

          if (index == 3) {
            await loadCurrentUserAvatar();
          }
        },

        items: const [
          BottomNavigationBarItem(
            icon:
                Icon(Icons.home_outlined),
            activeIcon:
                Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon:
                Icon(Icons.people_outline),
            activeIcon:
                Icon(Icons.people),
            label: 'Contacts',
          ),
          BottomNavigationBarItem(
            icon:
                Icon(Icons.call_outlined),
            activeIcon:
                Icon(Icons.call),
            label: 'Calls',
          ),
          BottomNavigationBarItem(
            icon:
                Icon(Icons.person_outline),
            activeIcon:
                Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SELECT PAGE
  // ============================================================

  Widget _buildSelectedPage() {
    switch (selectedIndex) {
      case 0:
        return buildHome();

      case 1:
        return buildContacts();

      case 2:
        return buildCalls();

      case 3:
        return buildProfile();

      default:
        return buildHome();
    }
  }

  // ============================================================
  // HOME
  // ============================================================

  Widget buildHome() {
    return RefreshIndicator(
      onRefresh: () async {
        await loadCurrentUserAvatar();
        await loadUsers();
        await loadRecentCalls();
      },
      child: SingleChildScrollView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            buildHeader(),

            const SizedBox(height: 25),

            buildSearch(),

            const SizedBox(height: 30),

            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Contacts',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      selectedIndex = 1;
                    });

                    loadUsers();
                  },
                  child:
                      const Text('See all'),
                ),
              ],
            ),

            const SizedBox(height: 15),

            buildHomeContacts(),

            const SizedBox(height: 30),

            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Calls',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    setState(() {
                      selectedIndex = 2;
                    });

                    await loadRecentCalls();
                  },
                  child:
                      const Text('See all'),
                ),
              ],
            ),

            const SizedBox(height: 10),

            buildRecentCalls(
              limit: 3,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                '$currentUserName 👋',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(height: 5),

              const Text(
                'Bio of user',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),

        GestureDetector(
          onTap: () async {
            setState(() {
              selectedIndex = 3;
            });

            await loadCurrentUserAvatar();
          },
          child: CircleAvatar(
            key: ValueKey(
              '${currentUserAvatar}_$avatarRefreshKey',
            ),
            radius: 25,
            backgroundColor:
                Colors.blue.shade50,
            backgroundImage:
                currentUserAvatar != null &&
                        currentUserAvatar!
                            .isNotEmpty
                    ? NetworkImage(
                        '$currentUserAvatar?v=$avatarRefreshKey',
                      )
                    : null,
            child:
                currentUserAvatar == null ||
                        currentUserAvatar!
                            .isEmpty
                    ? const Icon(
                        Icons.person,
                        color:
                            Colors.blue,
                        size: 28,
                      )
                    : null,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SEARCH
  // ============================================================

  Widget buildSearch() {
    return TextField(
      controller:
          searchController,
      decoration:
          InputDecoration(
        hintText:
            'Search people...',
        prefixIcon:
            const Icon(Icons.search),
        suffixIcon:
            searchController.text
                    .isNotEmpty
                ? IconButton(
                    icon:
                        const Icon(
                      Icons.clear,
                    ),
                    onPressed: () {
                      searchController
                          .clear();
                    },
                  )
                : null,
        filled: true,
        fillColor:
            Colors.white,
        border:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(15),
          borderSide:
              BorderSide.none,
        ),
        focusedBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(15),
          borderSide:
              const BorderSide(
            color: Colors.blue,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HOME CONTACTS
  // ============================================================

  Widget buildHomeContacts() {
    if (isLoadingUsers) {
      return const SizedBox(
        height: 100,
        child: Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    if (filteredUsers.isEmpty) {
      return const SizedBox(
        height: 100,
        child: Center(
          child:
              Text('No users found'),
        ),
      );
    }

    final displayUsers =
        filteredUsers.take(6).toList();

    return SizedBox(
      height: 105,
      child:
          ListView.builder(
        scrollDirection:
            Axis.horizontal,
        itemCount:
            displayUsers.length,
        itemBuilder:
            (context, index) {
          return contactItem(
            displayUsers[index],
          );
        },
      ),
    );
  }

  // ============================================================
  // CONTACT ITEM
  // ============================================================

  Widget contactItem(
    Map<String, dynamic> user,
  ) {
    final name =
        user['name'] ?? 'User';

    final userId =
        user['id'].toString();

    final avatarUrl =
        user['avatar_url']?.toString();

    final online =
        isUserOnline(userId);

    return GestureDetector(
      onTap: () {
        openUserDetails(user);
      },
      child: Container(
        width: 80,
        margin:
            const EdgeInsets.only(
          right: 15,
        ),
        child: Column(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  key: ValueKey(
                    '${userId}_${avatarUrl}_$avatarRefreshKey',
                  ),
                  radius: 28,
                  backgroundColor:
                      Colors.blue.shade50,
                  backgroundImage:
                      avatarUrl != null &&
                              avatarUrl.isNotEmpty
                          ? NetworkImage(
                              '$avatarUrl?v=$avatarRefreshKey',
                            )
                          : null,
                  child:
                      avatarUrl == null ||
                              avatarUrl.isEmpty
                          ? const Icon(
                              Icons.person,
                              color:
                                  Colors.blue,
                              size: 28,
                            )
                          : null,
                ),

                Positioned(
                  right: 0,
                  bottom: 0,
                  child:
                      Container(
                    height: 15,
                    width: 15,
                    decoration:
                        BoxDecoration(
                      color: online
                          ? Colors.green
                          : Colors.grey,
                      shape:
                          BoxShape.circle,
                      border:
                          Border.all(
                        color:
                            Colors.white,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 7),

            Text(
              name,
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  const TextStyle(
                fontSize: 13,
                fontWeight:
                    FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CONTACTS PAGE
  // ============================================================

  Widget buildContacts() {
    return Column(
      children: [
        Padding(
          padding:
              const EdgeInsets.fromLTRB(
            20,
            20,
            20,
            10,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Text(
                'Contacts',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(height: 15),

              buildSearch(),
            ],
          ),
        ),

        Expanded(
          child:
              isLoadingUsers
                  ? const Center(
                      child:
                          CircularProgressIndicator(),
                    )
                  : filteredUsers.isEmpty
                      ? const Center(
                          child:
                              Text(
                            'No users found',
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh:
                              loadUsers,
                          child:
                              ListView.builder(
                            padding:
                                const EdgeInsets
                                    .all(20),
                            itemCount:
                                filteredUsers
                                    .length,
                            itemBuilder:
                                (context, index) {
                              return buildUserTile(
                                filteredUsers[
                                    index],
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  // ============================================================
  // USER TILE
  // ============================================================

  Widget buildUserTile(
    Map<String, dynamic> user,
  ) {
    final String userId =
        user['id'].toString();

    final String name =
        user['name'] ?? 'User';

    final String email =
        user['email'] ?? '';

    final String? avatarUrl =
        user['avatar_url']?.toString();

    final bool online =
        isUserOnline(userId);

    return GestureDetector(
      onTap: () {
        openUserDetails(user);
      },
      child: Container(
        margin:
            const EdgeInsets.only(
          bottom: 12,
        ),
        padding:
            const EdgeInsets.all(14),
        decoration:
            BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  key: ValueKey(
                    '${userId}_${avatarUrl}_$avatarRefreshKey',
                  ),
                  radius: 27,
                  backgroundColor:
                      Colors.blue.shade50,
                  backgroundImage:
                      avatarUrl != null &&
                              avatarUrl.isNotEmpty
                          ? NetworkImage(
                              '$avatarUrl?v=$avatarRefreshKey',
                            )
                          : null,
                  child:
                      avatarUrl == null ||
                              avatarUrl.isEmpty
                          ? const Icon(
                              Icons.person,
                              color:
                                  Colors.blue,
                              size: 28,
                            )
                          : null,
                ),

                Positioned(
                  right: 0,
                  bottom: 0,
                  child:
                      Container(
                    height: 15,
                    width: 15,
                    decoration:
                        BoxDecoration(
                      color: online
                          ? Colors.green
                          : Colors.grey,
                      shape:
                          BoxShape.circle,
                      border:
                          Border.all(
                        color:
                            Colors.white,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style:
                        const TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    online
                        ? 'Online'
                        : 'Offline',
                    style:
                        TextStyle(
                      color: online
                          ? Colors.green
                          : Colors.grey,
                      fontSize: 13,
                    ),
                  ),

                  if (email.isNotEmpty)
                    Text(
                      email,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          const TextStyle(
                        color:
                            Colors.grey,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),

            IconButton(
              onPressed: online
                  ? () {
                      startAudioCall(
                        userId,
                        name,
                      );
                    }
                  : null,
              icon:
                  const Icon(Icons.call),
              color:
                  Colors.green,
              tooltip:
                  'Audio Call',
            ),

            IconButton(
              onPressed: online
                  ? () {
                      startVideoCall(
                        userId,
                        name,
                      );
                    }
                  : null,
              icon:
                  const Icon(
                Icons.videocam,
              ),
              color:
                  Colors.blue,
              tooltip:
                  'Video Call',
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CALLS PAGE
  // ============================================================

  Widget buildCalls() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Padding(
          padding:
              EdgeInsets.fromLTRB(
            20,
            20,
            20,
            10,
          ),
          child: Text(
            'Recent Calls',
            style: TextStyle(
              fontSize: 28,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ),

        Expanded(
          child:
              isLoadingCalls
                  ? const Center(
                      child:
                          CircularProgressIndicator(),
                    )
                  : recentCalls.isEmpty
                      ? const Center(
                          child:
                              Text(
                            'No call history',
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh:
                              loadRecentCalls,
                          child:
                              ListView.builder(
                            padding:
                                const EdgeInsets
                                    .fromLTRB(
                              20,
                              10,
                              20,
                              20,
                            ),
                            itemCount:
                                recentCalls
                                    .length,
                            itemBuilder:
                                (context, index) {
                              return buildCallItem(
                                recentCalls[
                                    index],
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  // ============================================================
  // RECENT CALLS
  // ============================================================

  Widget buildRecentCalls({
    int? limit,
  }) {
    if (isLoadingCalls) {
      return const Center(
        child:
            CircularProgressIndicator(),
      );
    }

    if (recentCalls.isEmpty) {
      return const Padding(
        padding:
            EdgeInsets.all(20),
        child:
            Text(
          'No recent calls',
        ),
      );
    }

    final calls =
        limit == null
            ? recentCalls
            : recentCalls
                .take(limit)
                .toList();

    return ListView.builder(
      shrinkWrap:
          true,
      physics:
          limit != null
              ? const NeverScrollableScrollPhysics()
              : const AlwaysScrollableScrollPhysics(),
      itemCount:
          calls.length,
      itemBuilder:
          (context, index) {
        return buildCallItem(
          calls[index],
        );
      },
    );
  }

  // ============================================================
  // GET REAL CALL DURATION
  // ============================================================
  //
  // Priority:
  // 1. duration_seconds from Supabase
  // 2. Calculate ended_at - started_at
  // 3. Return 0 if neither is available
  //
  // ============================================================

  int getCallDurationSeconds(
    Map<String, dynamic> call,
  ) {
    // ----------------------------------------------------------
    // FIRST: USE duration_seconds
    // ----------------------------------------------------------

    final dynamic savedDuration =
        call['duration_seconds'];

    final int parsedDuration =
        int.tryParse(
              savedDuration?.toString() ?? '',
            ) ??
            0;

    if (parsedDuration > 0) {
      return parsedDuration;
    }

    // ----------------------------------------------------------
    // SECOND: CALCULATE FROM started_at AND ended_at
    // ----------------------------------------------------------

    final String? startedAt =
        call['started_at']?.toString();

    final String? endedAt =
        call['ended_at']?.toString();

    if (startedAt != null &&
        startedAt.isNotEmpty &&
        endedAt != null &&
        endedAt.isNotEmpty) {
      final DateTime? start =
          DateTime.tryParse(startedAt);

      final DateTime? end =
          DateTime.tryParse(endedAt);

      if (start != null && end != null) {
        final int seconds =
            end.difference(start).inSeconds;

        if (seconds > 0) {
          return seconds;
        }
      }
    }

    return 0;
  }

  // ============================================================
  // CALL ITEM
  // ============================================================

  Widget buildCallItem(
    Map<String, dynamic> call,
  ) {
    final String type =
        call['call_type']
                ?.toString()
                .toLowerCase() ??
            'audio';

    final String status =
        call['status']
                ?.toString()
                .toLowerCase() ??
            'ended';

    final bool video =
        type == 'video';

    final bool incoming =
        call['callee_id']?.toString() ==
            currentUser?.id;

    final bool missed =
        status == 'missed';

    final String name =
        getCallUserName(call);

    final String? avatarUrl =
        getCallUserAvatar(call);

    final String otherUserId =
        call['other_user_id']
                ?.toString() ??
            '';

    // ==========================================================
    // IMPORTANT:
    // Get actual duration instead of directly using
    // call['duration_seconds']
    // ==========================================================

    final int durationSeconds =
        getCallDurationSeconds(call);

    final String dateTime =
        formatCallDateTime(call);

    // ------------------------------------------------------------
    // CALL ICON
    // ------------------------------------------------------------

    IconData callIcon;

    if (video) {
      callIcon = Icons.videocam;
    } else if (incoming) {
      callIcon = Icons.call_received;
    } else {
      callIcon = Icons.call_made;
    }

    // ------------------------------------------------------------
    // CALL TYPE TEXT
    // ------------------------------------------------------------

    final String callTypeText =
        video
            ? 'Video Call'
            : 'Audio Call';

    // ------------------------------------------------------------
    // DIRECTION TEXT
    // ------------------------------------------------------------

    final String directionText =
        incoming
            ? 'Incoming'
            : 'Outgoing';

    // ------------------------------------------------------------
    // DIRECTION ICON
    // ------------------------------------------------------------

    final IconData directionIcon =
        incoming
            ? Icons.call_received
            : Icons.call_made;

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),
      padding:
          const EdgeInsets.all(15),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withOpacity(0.04),
            blurRadius: 8,
            offset:
                const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.center,
        children: [
          // ======================================================
          // PROFILE PHOTO
          // ======================================================

          CircleAvatar(
            key: ValueKey(
              '${otherUserId}_${avatarUrl}_$avatarRefreshKey',
            ),
            radius: 27,
            backgroundColor:
                Colors.blue.shade50,
            backgroundImage:
                avatarUrl != null &&
                        avatarUrl.isNotEmpty
                    ? NetworkImage(
                        '$avatarUrl?v=$avatarRefreshKey',
                      )
                    : null,
            child:
                avatarUrl == null ||
                        avatarUrl.isEmpty
                    ? Icon(
                        video
                            ? Icons.videocam
                            : Icons.person,
                        color:
                            Colors.blue,
                        size: 28,
                      )
                    : null,
          ),

          const SizedBox(width: 14),

          // ======================================================
          // CALL INFORMATION
          // ======================================================

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                // ------------------------------------------------
                // USER NAME
                // ------------------------------------------------

                Text(
                  name,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                // ------------------------------------------------
                // AUDIO / VIDEO
                // ------------------------------------------------

                Row(
                  children: [
                    Icon(
                      callIcon,
                      size: 17,
                      color: missed
                          ? Colors.red
                          : Colors.blue,
                    ),

                    const SizedBox(
                      width: 6,
                    ),

                    Text(
                      callTypeText,
                      style:
                          TextStyle(
                        fontSize: 13,
                        fontWeight:
                            FontWeight.w500,
                        color: missed
                            ? Colors.red
                            : Colors.grey
                                .shade700,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 5),

                // ------------------------------------------------
                // DATE AND TIME
                // ------------------------------------------------

                Text(
                  dateTime,
                  style:
                      const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),

                const SizedBox(height: 5),

                // ------------------------------------------------
                // INCOMING / OUTGOING
                // ------------------------------------------------

                Row(
                  children: [
                    Icon(
                      directionIcon,
                      size: 14,
                      color: incoming
                          ? Colors.green
                          : Colors.blue,
                    ),

                    const SizedBox(
                      width: 4,
                    ),

                    Text(
                      directionText,
                      style:
                          TextStyle(
                        fontSize: 12,
                        color: incoming
                            ? Colors.green
                            : Colors.blue,
                        fontWeight:
                            FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // ======================================================
          // DURATION / MISSED
          // ======================================================

          Column(
            crossAxisAlignment:
                CrossAxisAlignment.end,
            children: [
              if (missed)
                Container(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration:
                      BoxDecoration(
                    color: Colors.red
                        .withOpacity(0.10),
                    borderRadius:
                        BorderRadius.circular(
                      8,
                    ),
                  ),
                  child: const Text(
                    'Missed',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                )
              else if (durationSeconds > 0)
                Text(
                  formatDuration(
                    durationSeconds,
                  ),
                  style:
                      const TextStyle(
                    fontSize: 13,
                    fontWeight:
                        FontWeight.bold,
                    color: Colors.grey,
                  ),
                )
              else
                const Text(
                  '--:--',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FORMAT CALL DATE AND TIME
  // ============================================================

  String formatCallDateTime(
    Map<String, dynamic> call,
  ) {
    final String? dateString =
        call['started_at']?.toString() ??
            call['created_at']?.toString();

    if (dateString == null ||
        dateString.isEmpty) {
      return 'Unknown time';
    }

    final DateTime? date =
        DateTime.tryParse(dateString);

    if (date == null) {
      return 'Unknown time';
    }

    final DateTime localDate =
        date.toLocal();

    final DateTime now =
        DateTime.now();

    final DateTime today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final DateTime callDay = DateTime(
      localDate.year,
      localDate.month,
      localDate.day,
    );

    final int difference =
        today
            .difference(callDay)
            .inDays;

    final String time =
        formatTime(localDate);

    if (difference == 0) {
      return 'Today, $time';
    }

    if (difference == 1) {
      return 'Yesterday, $time';
    }

    return '${localDate.day.toString().padLeft(2, '0')}/'
        '${localDate.month.toString().padLeft(2, '0')}/'
        '${localDate.year}, $time';
  }

  // ============================================================
  // FORMAT TIME
  // ============================================================

  String formatTime(
    DateTime date,
  ) {
    int hour = date.hour;

    final int minute =
        date.minute;

    final String period =
        hour >= 12 ? 'PM' : 'AM';

    if (hour == 0) {
      hour = 12;
    } else if (hour > 12) {
      hour -= 12;
    }

    return '$hour:${minute.toString().padLeft(2, '0')} $period';
  }

  // ============================================================
  // FORMAT DURATION
  // ============================================================

  String formatDuration(
    dynamic seconds,
  ) {
    final int totalSeconds =
        int.tryParse(
              seconds.toString(),
            ) ??
            0;

    final int minutes =
        totalSeconds ~/ 60;

    final int remaining =
        totalSeconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${remaining.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // PROFILE
  // ============================================================

  Widget buildProfile() {
    return const ProfileScreen();
  }
}