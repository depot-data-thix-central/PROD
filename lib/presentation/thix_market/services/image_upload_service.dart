import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;

class ImageUploadService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();
  final _uuid = const Uuid();

  // Pick image from gallery or camera
  Future<File?> pickImage({ImageSource source = ImageSource.gallery}) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Pick multiple images
  Future<List<File>> pickMultipleImages({int maxCount = 5}) async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      return images.take(maxCount).map((x) => File(x.path)).toList();
    } catch (e) {
      return [];
    }
  }

  // Upload single image
  Future<String?> uploadImage({
    required File image,
    required String bucket,
    String? folder,
  }) async {
    try {
      final fileExt = path.extension(image.path);
      final fileName = '${_uuid.v4()}$fileExt';
      final filePath = folder != null ? '$folder/$fileName' : fileName;

      await _supabase.storage.from(bucket).upload(filePath, image);
      final publicUrl = _supabase.storage.from(bucket).getPublicUrl(filePath);
      return publicUrl;
    } catch (e) {
      return null;
    }
  }

  // Upload multiple images
  Future<List<String>> uploadMultipleImages({
    required List<File> images,
    required String bucket,
    String? folder,
  }) async {
    final List<String> urls = [];
    for (final image in images) {
      final url = await uploadImage(image: image, bucket: bucket, folder: folder);
      if (url != null) urls.add(url);
    }
    return urls;
  }

  // Upload product images
  Future<List<String>> uploadProductImages(List<File> images) async {
    return uploadMultipleImages(
      images: images,
      bucket: 'product_images',
      folder: 'products',
    );
  }

  // Upload shop logo/cover
  Future<String?> uploadShopImage(File image, {bool isLogo = true}) async {
    return uploadImage(
      image: image,
      bucket: 'shop_images',
      folder: isLogo ? 'logos' : 'covers',
    );
  }

  // Upload avatar
  Future<String?> uploadAvatar(File image) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;
    return uploadImage(
      image: image,
      bucket: 'avatars',
      folder: userId,
    );
  }

  // Upload live thumbnail
  Future<String?> uploadLiveThumbnail(File image) async {
    return uploadImage(
      image: image,
      bucket: 'live_images',
      folder: 'thumbnails',
    );
  }

  // Upload message image
  Future<String?> uploadMessageImage(File image) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;
    return uploadImage(
      image: image,
      bucket: 'message_images',
      folder: userId,
    );
  }

  // Delete image
  Future<bool> deleteImage(String url, String bucket) async {
    try {
      // Extract path from URL
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      final filePath = pathSegments.sublist(pathSegments.indexOf(bucket) + 1).join('/');
      await _supabase.storage.from(bucket).remove([filePath]);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Compress image (using image package - simplified version)
  Future<File> compressImage(File image, {int quality = 85}) async {
    // In production, use flutter_image_compress package
    // For now, return original file
    return image;
  }

  // Get image dimensions
  Future<ImageDimensions> getImageDimensions(File image) async {
    // In production, use image package to get width/height
    // For now, return default
    return const ImageDimensions(0, 0);
  }
}

class ImageDimensions {
  final int width;
  final int height;
  const ImageDimensions(this.width, this.height);
}
