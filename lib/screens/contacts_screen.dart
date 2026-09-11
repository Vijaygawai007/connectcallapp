
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  List<Map<String, dynamic>> users = [];

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadUsers();
  }

  // ============================================================
  // LOAD USERS
  // ============================================================

  Future<void> loadUsers() async {
    try {
      setState(() {
        isLoading = true;
      });

      final currentUser = supabase.auth.currentUser;

      if (currentUser == null) {
        setState(() {
          users = [];
          isLoading = false;
        });
        return;
      }

      final response = await supabase
          .from('profiles')
          .select()
          .neq('id', currentUser.id)
          .order('name');

      if (!mounted) return;

      setState(() {
        users = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      showMessage(error.message);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      showMessage('Unable to load contacts');
    }
  }

  // ============================================================
  // AUDIO CALL
  // ============================================================

  Future<void> startAudioCall(
    Map<String, dynamic> user,
  ) async {
    final currentUser = supabase.auth.currentUser;

    if (currentUser == null) {
      showMessage('Please login again');
      return;
    }

    final receiverId = user['id'];

    try {
      final channelName =
          'call_${currentUser.id}_${receiverId}_${DateTime.now().millisecondsSinceEpoch}';

      await supabase.from('calls').insert({
        'caller_id': currentUser.id,
        'callee_id': receiverId,
        'call_type': 'audio',
        'status': 'ringing',
        'channel_name': channelName,
      });

      if (!mounted) return;

      showMessage('Calling ${user['name'] ?? 'User'}...');
      
      // Agora audio call screen will be connected here.
      //
      // Example later:
      //
      // Navigator.push(
      //   context,
      //   MaterialPageRoute(
      //     builder: (_) => AudioCallScreen(
      //       channelName: channelName,
      //       callerName: user['name'] ?? 'User',
      //     ),
      //   ),
      // );
    } on PostgrestException catch (error) {
      showMessage(error.message);
    } catch (error) {
      showMessage('Unable to start audio call');
    }
  }

  // ============================================================
  // VIDEO CALL
  // ============================================================

  Future<void> startVideoCall(
    Map<String, dynamic> user,
  ) async {
    final currentUser = supabase.auth.currentUser;

    if (currentUser == null) {
      showMessage('Please login again');
      return;
    }

    final receiverId = user['id'];

    try {
      final channelName =
          'call_${currentUser.id}_${receiverId}_${DateTime.now().millisecondsSinceEpoch}';

      await supabase.from('calls').insert({
        'caller_id': currentUser.id,
        'callee_id': receiverId,
        'call_type': 'video',
        'status': 'ringing',
        'channel_name': channelName,
      });

      if (!mounted) return;

      showMessage('Video calling ${user['name'] ?? 'User'}...');

      // Agora video call screen will be connected here.
      //
      // Example later:
      //
      // Navigator.push(
      //   context,
      //   MaterialPageRoute(
      //     builder: (_) => VideoCallScreen(
      //       channelName: channelName,
      //       callerName: user['name'] ?? 'User',
      //     ),
      //   ),
      // );
    } on PostgrestException catch (error) {
      showMessage(error.message);
    } catch (error) {
      showMessage('Unable to start video call');
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // GET USER NAME
  // ============================================================

  String getUserName(Map<String, dynamic> user) {
    final name = user['name'];

    if (name != null &&
        name.toString().trim().isNotEmpty) {
      return name.toString();
    }

    final email = user['email'];

    if (email != null &&
        email.toString().trim().isNotEmpty) {
      return email.toString().split('@').first;
    }

    return 'Unknown User';
  }

  // ============================================================
  // GET AVATAR
  // ============================================================

  Widget buildAvatar(Map<String, dynamic> user) {
    final name = getUserName(user);

    final avatarUrl = user['avatar_url'];

    if (avatarUrl != null &&
        avatarUrl.toString().trim().isNotEmpty) {
      return CircleAvatar(
        radius: 28,
        backgroundImage:
            NetworkImage(avatarUrl.toString()),
      );
    }

    return CircleAvatar(
      radius: 28,
      backgroundColor: Colors.blue.shade100,
      child: Text(
        name.isNotEmpty
            ? name[0].toUpperCase()
            : '?',
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
    );
  }

  // ============================================================
  // ONLINE STATUS
  // ============================================================

  bool isUserOnline(Map<String, dynamic> user) {
    /*
      Currently this returns false because your profiles table
      does not have an online_status column.

      We will connect real-time online/offline presence next.
    */

    return false;
  }

  // ============================================================
  // CONTACT CARD
  // ============================================================

  Widget buildContactCard(
    Map<String, dynamic> user,
  ) {
    final name = getUserName(user);
    final online = isUserOnline(user);

    return Card(
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [

            // =========================
            // AVATAR
            // =========================

            Stack(
              children: [

                buildAvatar(user),

                // ONLINE DOT
                Positioned(
                  right: 0,
                  bottom: 1,
                  child: Container(
                    width: 15,
                    height: 15,
                    decoration: BoxDecoration(
                      color: online
                          ? Colors.green
                          : Colors.grey,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(width: 14),

            // =========================
            // NAME + STATUS
            // =========================

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [

                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Row(
                    children: [

                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: online
                              ? Colors.green
                              : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),

                      const SizedBox(width: 6),

                      Text(
                        online
                            ? 'Online'
                            : 'Offline',
                        style: TextStyle(
                          fontSize: 13,
                          color: online
                              ? Colors.green
                              : Colors.grey,
                          fontWeight:
                              FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // =========================
            // AUDIO BUTTON
            // =========================

            IconButton(
              onPressed: () {
                startAudioCall(user);
              },
              tooltip: 'Audio Call',
              style: IconButton.styleFrom(
                backgroundColor:
                    Colors.green.shade50,
              ),
              icon: const Icon(
                Icons.call,
                color: Colors.green,
              ),
            ),

            const SizedBox(width: 5),

            // =========================
            // VIDEO BUTTON
            // =========================

            IconButton(
              onPressed: () {
                startVideoCall(user);
              },
              tooltip: 'Video Call',
              style: IconButton.styleFrom(
                backgroundColor:
                    Colors.blue.shade50,
              ),
              icon: const Icon(
                Icons.videocam,
                color: Colors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [

          Icon(
            Icons.people_outline,
            size: 80,
            color: Colors.grey.shade400,
          ),

          const SizedBox(height: 20),

          const Text(
            'No contacts found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Create another account to see users here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 20),

          ElevatedButton.icon(
            onPressed: loadUsers,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,

      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,

        title: const Text(
          'Contacts',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),

        actions: [
          IconButton(
            onPressed: loadUsers,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),

      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : users.isEmpty
              ? buildEmptyState()
              : RefreshIndicator(
                  onRefresh: loadUsers,

                  child: ListView.builder(
                    physics:
                        const AlwaysScrollableScrollPhysics(),

                    padding: const EdgeInsets.all(16),

                    itemCount: users.length,

                    itemBuilder: (context, index) {
                      return buildContactCard(
                        users[index],
                      );
                    },
                  ),
                ),
    );
  }
}