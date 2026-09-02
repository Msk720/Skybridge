import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:dotted_border/dotted_border.dart';
import 'package:skybridge02/Services/app_config.dart';
import 'package:skybridge02/Theme/app_color.dart';


class ImagePickerUploader extends StatefulWidget {
  final String? initialImage;
  final Function(String?) onChanged;
  final bool hasError;

  const ImagePickerUploader({
    super.key,
    this.initialImage,
    required this.onChanged,
    this.hasError = false,
  });

  @override
  State<ImagePickerUploader> createState() => ImagePickerUploaderState();
}

class ImagePickerUploaderState extends State<ImagePickerUploader> {
  final picker = ImagePicker();

  XFile? file;
  String? url;
  Uint8List? webBytes;

  bool get hasImage => file != null || (url != null && url!.isNotEmpty);

  @override
  void initState() {
    super.initState();
    url = widget.initialImage;
  }

  @override
  void didUpdateWidget(covariant ImagePickerUploader oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.initialImage != oldWidget.initialImage) {
      setState(() {
        url = widget.initialImage;
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> pickImage() async {
    final img =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);

    if (img == null) return;

    if (kIsWeb) {
      webBytes = await img.readAsBytes();
    }

    setState(() {
      file = img;
      url = null;
    });
  }

  void removeImage() {
    setState(() {
      file = null;
      url = null;
    });
  }

  Future<String> upload(Uint8List bytes) async {
    final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudinarycloudname/auto/upload');

    final req = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = cloudinaryuploadpreset
      ..files.add(
          http.MultipartFile.fromBytes('file', bytes, filename: 'img.jpg'));

    final res = await http.Response.fromStream(await req.send());
    return jsonDecode(res.body)['secure_url'];
  }

  Future<String?> uploadAndReturn() async {
    if (file == null) return url;

    final bytes = await file!.readAsBytes();
    final uploadedUrl = await upload(bytes);

    url = uploadedUrl;
    widget.onChanged(uploadedUrl);

    return uploadedUrl;
  }

  Widget imageWidget() {
    if (url != null) {
      return Image.network(url!, fit: BoxFit.contain);
    }

    if (kIsWeb && webBytes != null) {
      return Image.memory(webBytes!, fit: BoxFit.contain); // ✅ FIX
    }

    if (!kIsWeb && file != null) {
      return Image.file(File(file!.path), fit: BoxFit.contain);
    }

    return const SizedBox();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
        autofocus: false,
        child: Builder(builder: (context) {
          final hasFocus = Focus.of(context).hasFocus;

          final borderColor = widget.hasError
              ? Colors.red
              : (hasFocus ? AppColors.primary : AppColors.dotcolor);

          return GestureDetector(
            onTap: () {
              FocusScope.of(context).unfocus();
              FocusScope.of(context).requestFocus(Focus.of(context));
            },
            child: DottedBorder(
              borderType: BorderType.RRect,
              radius: const Radius.circular(16),
              dashPattern: const [6, 4],
              color: borderColor,
              strokeWidth: hasFocus ? 2.3 : 1.5,
              child: Container(
                height: 115,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 6), // reduced
                child: hasImage
                    ? Stack(
                        alignment: Alignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              height: 110,
                              width: 110,
                              child: imageWidget(),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: removeImage,
                              child: const CircleAvatar(
                                radius: 12,
                                backgroundColor: Colors.black54,
                                child: Icon(Icons.close,
                                    size: 16, color: Colors.white),
                              ),
                            ),
                          )
                        ],
                      )
                    : InkWell(
                        onTap: pickImage,
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.camera_alt_outlined,
                                    size: 22),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment:
                                    CrossAxisAlignment.start, // important
                                children: [
                                  const Text(
                                    "Select Images",
                                    style:
                                        TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    "No images selected",
                                    style: TextStyle(
                                      color: widget.hasError
                                          ? Colors.red
                                          : Colors.grey,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
          );
        }));
  }
}
