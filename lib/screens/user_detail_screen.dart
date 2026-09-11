import 'package:flutter/material.dart';

class UserDetailScreen extends StatelessWidget {
  final String userId;
  final String name;
  final String email;
  final String? avatarUrl;
  final bool isOnline;
  final VoidCallback onAudioCall;
  final VoidCallback onVideoCall;

  const UserDetailScreen({
    super.key,
    required this.userId,
    required this.name,
    required this.email,
    this.avatarUrl,
    required this.isOnline,
    required this.onAudioCall,
    required this.onVideoCall,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,

      appBar: AppBar(
        title: const Text('Contact Details'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),

          child: Column(
            children: [
              const SizedBox(height: 30),

              // PROFILE IMAGE
              CircleAvatar(
                radius: 70,
                backgroundColor: Colors.blue.shade100,

                backgroundImage:
                    avatarUrl != null &&
                            avatarUrl!.isNotEmpty
                        ? NetworkImage(avatarUrl!)
                        : null,

                child: avatarUrl == null ||
                        avatarUrl!.isEmpty
                    ? const Icon(
                        Icons.person,
                        size: 80,
                        color: Colors.blue,
                      )
                    : null,
              ),

              const SizedBox(height: 20),

              // USER NAME
              Text(
                name,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              // ONLINE STATUS
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: isOnline
                          ? Colors.green
                          : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),

                  const SizedBox(width: 7),

                  Text(
                    isOnline
                        ? 'Online'
                        : 'Offline',
                    style: TextStyle(
                      color: isOnline
                          ? Colors.green
                          : Colors.grey,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // CONTACT INFORMATION CARD
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),

                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),

                child: Column(
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.contact_page,
                          color: Colors.blue,
                        ),

                        SizedBox(width: 10),

                        Text(
                          'Contact Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 25),

                    Row(
                      children: [
                        const Icon(
                          Icons.email_outlined,
                          color: Colors.grey,
                        ),

                        const SizedBox(width: 15),

                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Email',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),

                              const SizedBox(height: 3),

                              Text(
                                email.isEmpty
                                    ? 'No email available'
                                    : email,
                                style: const TextStyle(
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // AUDIO AND VIDEO BUTTONS
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isOnline
                          ? onAudioCall
                          : null,

                      icon: const Icon(Icons.call),

                      label: const Text(
                        'Audio Call',
                      ),

                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Colors.green,
                        foregroundColor:
                            Colors.white,

                        padding:
                            const EdgeInsets.symmetric(
                          vertical: 16,
                        ),

                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(
                            15,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 15),

                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isOnline
                          ? onVideoCall
                          : null,

                      icon: const Icon(
                        Icons.videocam,
                      ),

                      label: const Text(
                        'Video Call',
                      ),

                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Colors.blue,
                        foregroundColor:
                            Colors.white,

                        padding:
                            const EdgeInsets.symmetric(
                          vertical: 16,
                        ),

                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(
                            15,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              if (!isOnline) ...[
                const SizedBox(height: 15),

                const Text(
                  'This user is currently offline',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}