import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  final TextEditingController nameController =
      TextEditingController();

  User? get currentUser => supabase.auth.currentUser;

  bool isLoading = true;
  bool isSaving = false;
  bool isUploading = false;

  String name = 'User';
  String email = '';
  String? avatarUrl;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD PROFILE
  // ============================================================

  Future<void> loadProfile() async {
    try {
      final user = currentUser;

      if (user == null) {
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
        return;
      }

      final response = await supabase
          .from('profiles')
          .select('name, email, avatar_url')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      final profileName =
          response?['name']?.toString();

      final profileEmail =
          response?['email']?.toString();

      final profileAvatar =
          response?['avatar_url']?.toString();

      setState(() {
        name = profileName != null &&
                profileName.trim().isNotEmpty
            ? profileName
            : user.email?.split('@').first ?? 'User';

        email = profileEmail != null &&
                profileEmail.trim().isNotEmpty
            ? profileEmail
            : user.email ?? user.phone ?? '';

        avatarUrl =
            profileAvatar != null &&
                    profileAvatar.isNotEmpty
                ? profileAvatar
                : null;

        nameController.text = name;

        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      showMessage(
        'Unable to load profile: $e',
      );
    }
  }

  // ============================================================
  // EDIT PROFILE
  // ============================================================

  Future<void> editProfile() async {
    nameController.text = name;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(25),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 25,
            bottom:
                MediaQuery.of(context).viewInsets.bottom +
                    25,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Text(
                'Edit Profile',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

              TextField(
                controller: nameController,
                textCapitalization:
                    TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Display Name',
                  hintText: 'Enter your name',
                  prefixIcon:
                      const Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(15),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed:
                      isSaving
                          ? null
                          : saveProfile,
                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        Colors.blue,
                    foregroundColor:
                        Colors.white,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        15,
                      ),
                    ),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child:
                              CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Save Changes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // SAVE PROFILE
  // ============================================================

  Future<void> saveProfile() async {
    try {
      final user = currentUser;

      if (user == null) {
        showMessage(
          'Please login again',
        );
        return;
      }

      final newName =
          nameController.text.trim();

      if (newName.isEmpty) {
        showMessage(
          'Please enter your name',
        );
        return;
      }

      setState(() {
        isSaving = true;
      });

      await supabase
          .from('profiles')
          .upsert({
        'id': user.id,
        'name': newName,
        'email': email.isNotEmpty
            ? email
            : user.email ?? user.phone,
      });

      // Also update Supabase Auth metadata.
      await supabase.auth.updateUser(
        UserAttributes(
          data: {
            'name': newName,
          },
        ),
      );

      if (!mounted) return;

      setState(() {
        name = newName;
        isSaving = false;
      });

      Navigator.pop(context);

      showMessage(
        'Profile updated successfully',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      showMessage(
        'Unable to update profile: $e',
      );
    }
  }

  // ============================================================
  // CHANGE PROFILE PICTURE
  // ============================================================

  Future<void> changeProfilePicture() async {
    final ImagePicker picker =
        ImagePicker();

    try {
      final XFile? image =
          await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1000,
        maxHeight: 1000,
      );

      if (image == null) {
        return;
      }

      await uploadProfilePicture(
        File(image.path),
      );
    } catch (e) {
      showMessage(
        'Unable to select image: $e',
      );
    }
  }

  // ============================================================
  // UPLOAD PROFILE PICTURE
  // ============================================================

  Future<void> uploadProfilePicture(File imageFile) async {
  try {
    final user = currentUser;

    if (user == null) {
      showMessage('Please login again');
      return;
    }

    setState(() {
      isUploading = true;
    });

    // Unique file name
    final String fileName =
        '${DateTime.now().millisecondsSinceEpoch}.jpg';

    // Store inside user's own folder
    final String filePath =
        '${user.id}/$fileName';

    debugPrint('Uploading image...');
    debugPrint('Bucket: avatars');
    debugPrint('Path: $filePath');

    // Upload
    await supabase.storage
        .from('avatars')
        .upload(
          filePath,
          imageFile,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/jpeg',
          ),
        );

    debugPrint('Image uploaded successfully');

    // Get public URL
    final String publicUrl =
        supabase.storage
            .from('avatars')
            .getPublicUrl(filePath);

    debugPrint('Public URL: $publicUrl');

    // Save URL into profiles table
    await supabase
        .from('profiles')
        .update({
          'avatar_url': publicUrl,
        })
        .eq('id', user.id);

    debugPrint(
      'avatar_url saved to profiles table',
    );

    if (!mounted) return;

    setState(() {
      avatarUrl = publicUrl;
      isUploading = false;
    });

    showMessage(
      'Profile picture updated successfully',
    );
  } catch (e) {
    debugPrint(
      'PROFILE IMAGE ERROR: $e',
    );

    if (!mounted) return;

    setState(() {
      isUploading = false;
    });

    showMessage(
      'Profile picture upload failed: $e',
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
  // PROFILE IMAGE
  // ============================================================

  Widget buildProfileImage() {
    return Stack(
      children: [
        CircleAvatar(
          radius: 65,
          backgroundColor:
              Colors.blue.shade50,
          backgroundImage:
              avatarUrl != null &&
                      avatarUrl!.isNotEmpty
                  ? NetworkImage(
                      avatarUrl!,
                    )
                  : null,
          child:
              avatarUrl == null ||
                      avatarUrl!.isEmpty
                  ? const Icon(
                      Icons.person,
                      size: 70,
                      color: Colors.blue,
                    )
                  : null,
        ),

        Positioned(
          right: 0,
          bottom: 0,
          child: GestureDetector(
            onTap:
                isUploading
                    ? null
                    : changeProfilePicture,
            child: Container(
              height: 42,
              width: 42,
              decoration:
                  BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 3,
                ),
              ),
              child: isUploading
                  ? const Padding(
                      padding:
                          EdgeInsets.all(10),
                      child:
                          CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 21,
                    ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // INFO CARD
  // ============================================================

  Widget buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(16),
      margin:
          const EdgeInsets.only(bottom: 12),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            height: 45,
            width: 45,
            decoration:
                BoxDecoration(
              color:
                  Colors.blue.shade50,
              borderRadius:
                  BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: Colors.blue,
            ),
          ),

          const SizedBox(width: 15),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      const TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  value.isEmpty
                      ? 'Not available'
                      : value,
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ACTION TILE
  // ============================================================

  Widget buildActionTile({
    required IconData icon,
    required String title,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      tileColor: Colors.white,
      shape:
          RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(16),
      ),
      leading: Container(
        height: 42,
        width: 42,
        decoration:
            BoxDecoration(
          color:
              iconColor.withOpacity(0.10),
          borderRadius:
              BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: iconColor,
        ),
      ),
      title: Text(
        title,
        style:
            const TextStyle(
          fontWeight:
              FontWeight.w500,
        ),
      ),
      trailing:
          const Icon(
        Icons.chevron_right,
      ),
      onTap: onTap,
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child:
            CircularProgressIndicator(),
      );
    }

    final user = currentUser;

    return SingleChildScrollView(
      padding:
          const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 15),

          // PROFILE PICTURE
          buildProfileImage(),

          const SizedBox(height: 20),

          // NAME
          Text(
            name,
            textAlign: TextAlign.center,
            style:
                const TextStyle(
              fontSize: 26,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          // ONLINE STATUS
          Row(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Container(
                height: 10,
                width: 10,
                decoration:
                    const BoxDecoration(
                  color: Colors.green,
                  shape:
                      BoxShape.circle,
                ),
              ),

              const SizedBox(width: 7),

              const Text(
                'Online',
                style:
                    TextStyle(
                  color: Colors.green,
                  fontSize: 15,
                  fontWeight:
                      FontWeight.w500,
                ),
              ),
            ],
          ),

          const SizedBox(height: 30),

          // ACCOUNT INFORMATION
          Align(
            alignment:
                Alignment.centerLeft,
            child: const Text(
              'Account Information',
              style:
                  TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 15),

          buildInfoCard(
            icon:
                Icons.person_outline,
            title: 'Display Name',
            value: name,
          ),

          buildInfoCard(
            icon:
                Icons.email_outlined,
            title:
                user?.email != null
                    ? 'Email'
                    : 'Phone',
            value: email.isNotEmpty
                ? email
                : user?.email ??
                    user?.phone ??
                    '',
          ),

          const SizedBox(height: 25),

          // ACTIONS
          Align(
            alignment:
                Alignment.centerLeft,
            child: const Text(
              'Actions',
              style:
                  TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 15),

          buildActionTile(
            icon: Icons.edit,
            title: 'Edit Profile',
            iconColor: Colors.blue,
            onTap: editProfile,
          ),

          const SizedBox(height: 12),

          buildActionTile(
            icon: Icons.camera_alt,
            title:
                'Change Profile Picture',
            iconColor: Colors.blue,
            onTap:
                isUploading
                    ? () {}
                    : changeProfilePicture,
          ),

          const SizedBox(height: 12),

          buildActionTile(
            icon: Icons.logout,
            title: 'Logout',
            iconColor: Colors.red,
            onTap: logout,
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }
}