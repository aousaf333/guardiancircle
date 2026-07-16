import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:guardiancircle/models/profile_model.dart';

/// Global in-memory profile state.
/// Updated after every profile save so all screens reflect changes immediately.
final ValueNotifier<ProfileModel?> profileNotifier = ValueNotifier(null);

/// Update the global profile and clear the image cache so
/// Image.network widgets refetch fresh photos.
void updateProfile(ProfileModel? profile) {
  profileNotifier.value = profile;
  PaintingBinding.instance.imageCache.clear();
}
