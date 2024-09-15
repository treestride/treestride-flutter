import 'dart:io';
import 'dart:ui' as ui;
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
      final watermarkedImage = await _addWatermark(File(pickedFile.path));
      setState(() {
        _image = watermarkedImage;
      });
    }
  }

  Future<File> _addWatermark(File image) async {
    final ui.Image originalImage = await _loadImage(image);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawImage(originalImage, Offset.zero, Paint());

    final textPainter = TextPainter(
      text: TextSpan(
        text: 'TreeStride/${widget.username}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          shadows: [
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
      (originalImage.width - textPainter.width) / 2,
      originalImage.height - textPainter.height - 10,
    );
    textPainter.paint(canvas, position);

    final picture = recorder.endRecording();
    final img =
        await picture.toImage(originalImage.width, originalImage.height);
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
                          hintText: 'Post an update about your tree',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey[200],
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (_image != null)
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
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
                            const SizedBox(height: 14)
                          ],
                        )
                      else if (widget.initialImageUrl != null)
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.network(
                                widget.initialImageUrl!,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(height: 14)
                          ],
                        ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.check),
                        label: const Text('Post'),
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
