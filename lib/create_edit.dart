import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
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
  bool _isProcessingImage = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialText);
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _imagePicker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _isProcessingImage = true;
      });
      final compressedImage = await compressImage(File(pickedFile.path));
      final watermarkedImage = await _addWatermark(compressedImage);
      setState(() {
        _image = watermarkedImage;
        _isProcessingImage = false;
      });
    }
  }

  Future<File> compressImage(File file) async {
    final dir = await getTemporaryDirectory();
    final targetPath = '${dir.absolute.path}/temp_compressed.jpg';

    var result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 88,
      minWidth: 1024,
      minHeight: 1024,
    );

    return File(result!.path);
  }

  Future<File> _addWatermark(File image) async {
    final ui.Image originalImage = await _loadImage(image);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawImage(originalImage, Offset.zero, Paint());

    final watermarkText = 'treestride/${widget.username}';
    final imageWidth = originalImage.width.toDouble();
    final imageHeight = originalImage.height.toDouble();

    // Calculate font size based on image dimensions
    final baseFontSize = (imageWidth + imageHeight) / 100;
    final fontSize = baseFontSize.clamp(16.0, 48.0); // Min 16, Max 48

    final textPainter = TextPainter(
      text: TextSpan(
        text: watermarkText,
        style: GoogleFonts.exo2(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          shadows: const [
            Shadow(
              blurRadius: 2,
              color: Colors.black,
              offset: Offset(1, 1),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final position = Offset(
      (imageWidth - textPainter.width) / 2,
      // 5% padding from bottom
      imageHeight - textPainter.height - (imageHeight * 0.05),
    );
    textPainter.paint(canvas, position);

    final picture = recorder.endRecording();
    final img = await picture.toImage(imageWidth.toInt(), imageHeight.toInt());
    final pngBytes = await img.toByteData(format: ui.ImageByteFormat.png);

    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/watermarked_image.png');
    await tempFile.writeAsBytes(pngBytes!.buffer.asUint8List());

    return tempFile;
  }

  Future<ui.Image> _loadImage(File file) async {
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frameInfo = await codec.getNextFrame();
    return frameInfo.image;
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFEFEFE),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Choose Image Source',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
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
                margin: const EdgeInsets.all(14),
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
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _textController,
                        maxLines: 5,
                        cursorColor: const Color(0xFF08DAD6),
                        decoration: InputDecoration(
                          hintText: 'Have an update?',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey[200],
                        ),
                      ),
                      const SizedBox(height: 14),
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
                          'CONFIRM POST',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (_isProcessingImage)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14.0),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF08DAD6),
                              strokeWidth: 6,
                            ),
                          ),
                        )
                      else if (_image != null)
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 14),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Stack(
                                alignment: Alignment.topRight,
                                children: [
                                  Image.file(
                                    _image!,
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
                          ],
                        )
                      else if (widget.initialImageUrl != null)
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 14),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.network(
                                widget.initialImageUrl!,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ],
                        ),
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
