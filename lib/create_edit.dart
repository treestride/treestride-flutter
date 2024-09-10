import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class CreateEditPostPage extends StatefulWidget {
  final String? initialText;
  final String? initialImageUrl;
  final Function(String, File?, String) onSave;
  final String username;

  const CreateEditPostPage({
    super.key,
    this.initialText,
    this.initialImageUrl,
    required this.username,
    required this.onSave,
  });

  @override
  CreateEditPostPageState createState() => CreateEditPostPageState();
}

class CreateEditPostPageState extends State<CreateEditPostPage> {
  late TextEditingController _textController;
  File? _image;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialText);
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _imagePicker.pickImage(source: source);
    if (pickedFile != null) {
      File imageFile = File(pickedFile.path);
      File watermarkedImage = await _addWatermark(imageFile, widget.username);
      setState(() {
        _image = watermarkedImage;
      });
    }
  }

  Future<File> _addWatermark(File imageFile, String username) async {
    // Read the image file
    img.Image? image = img.decodeImage(await imageFile.readAsBytes());

    if (image == null) return imageFile;

    // Prepare the watermark text
    String watermarkText = 'treestride/@$username';

    // Create a new transparent image for the watermark
    img.Image watermark = img.Image(
      width: 250,
      height: 24,
      backgroundColor: img.ColorUint8.rgba(0, 0, 0, 0),
    );

    // Draw the text onto the transparent image
    img.drawString(
      watermark,
      watermarkText,
      font: img.arial24,
      color: img.ColorRgba8(255, 255, 255, 200),
    );

    // Calculate position (bottom-right corner)
    int x = image.width - watermark.width - 10;
    int y = image.height - watermark.height - 10;

    // Composite the watermark onto the main image
    img.compositeImage(
      image,
      watermark,
      dstX: x,
      dstY: y,
      blend: img.BlendMode.overlay,
    );

    // Get temporary directory
    final tempDir = await getTemporaryDirectory();
    final tempPath = tempDir.path;
    final watermarkedFile = File('$tempPath/watermarked_image.png');

    // Save the watermarked image
    await watermarkedFile.writeAsBytes(img.encodePng(image));

    return watermarkedFile;
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFEFEFE),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Choose Image Source',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildImageSourceOption(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.gallery);
                    },
                  ),
                  _buildImageSourceOption(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.camera);
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(icon, size: 32, color: Colors.black),
          ),
          const SizedBox(height: 10),
          Text(label),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFEFEF),
      appBar: AppBar(
        elevation: 2.0,
        backgroundColor: const Color(0xFFFEFEFE),
        shadowColor: Colors.grey.withOpacity(0.5),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.black),
        ),
        centerTitle: true,
        title: Text(
          widget.initialText == null || widget.initialImageUrl != null
              ? 'CREATE POST'
              : 'EDIT POST',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _showImageSourceDialog,
            icon: const Icon(Icons.add_photo_alternate),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                margin: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEFEFE),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0xFFD4D4D4),
                      blurRadius: 2,
                      blurStyle: BlurStyle.outer,
                    )
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.only(top: 24, left: 24, right: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _textController,
                        maxLines: 6,
                        cursorColor: const Color(0xFF08DAD6),
                        decoration: InputDecoration(
                          hintText: 'What\'s on your mind?',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey[200],
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (_image != null)
                        Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Stack(
                                alignment: Alignment.topRight,
                                children: [
                                  Image.file(
                                    _image!,
                                    height: 250,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                      ),
                                      onPressed: () =>
                                          setState(() => _image = null),
                                      style: IconButton.styleFrom(
                                        backgroundColor:
                                            const Color(0x88F1B6B6),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24)
                          ],
                        )
                      else if (widget.initialImageUrl != null)
                        Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.network(
                                widget.initialImageUrl!,
                                height: 250,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(height: 24)
                          ],
                        ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF08DAD6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        onPressed: () {
                          if (_textController.text.trim().isNotEmpty ||
                              _image != null) {
                            widget.onSave(_textController.text.trim(), _image,
                                widget.username);
                            Navigator.pop(context);
                          } else {
                            // Show an error message
                            Fluttertoast.showToast(
                              msg: "Post is Blank!",
                              toastLength: Toast.LENGTH_SHORT,
                              gravity: ToastGravity.BOTTOM,
                              backgroundColor: Colors.black,
                              textColor: Colors.white,
                            );
                          }
                        },
                        child: const Text(
                          "Confirm Post",
                          style: TextStyle(
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
