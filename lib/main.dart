import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ToBase64',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const FileToBase64Page(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class FileToBase64Page extends StatefulWidget {
  const FileToBase64Page({Key? key}) : super(key: key);

  @override
  State<FileToBase64Page> createState() => _FileToBase64PageState();
}

class _FileToBase64PageState extends State<FileToBase64Page> {
  String? _fileName;
  String? _base64String;
  bool _isLoading = false;
  bool _isConverted = false;

  Future<void> _pickFile() async {
    setState(() {
      _isLoading = true;
      _isConverted = false;
      _base64String = null;
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      
      if (result != null) {
        File file = File(result.files.single.path!);
        final bytes = await file.readAsBytes();
        final base64String = base64Encode(bytes);
        
        setState(() {
          _fileName = result.files.single.name;
          _base64String = base64String;
          _isConverted = true;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发生错误: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveBase64ToFile() async {
    if (_base64String == null || _fileName == null) return;

    try {
      // 使用FilePicker让用户选择保存位置
      String? outputDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择保存位置',
      );
      
      if (outputDirectory == null) {
        // 用户取消了选择
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已取消保存')),
        );
        return;
      }
      
      final filePath = '$outputDirectory/${_fileName}_base64.txt';
      final file = File(filePath);
      await file.writeAsString(_base64String!);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Base64文件已保存到: $filePath')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存文件时发生错误: $e')),
      );
    }
  }

  Future<void> _copyToClipboard() async {
    if (_base64String == null) return;
    
    await Clipboard.setData(ClipboardData(text: _base64String!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Base64已复制到剪贴板')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ToBase64'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.file_upload_outlined,
                      size: 80,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      '选择一个文件将其转换为Base64编码',
                      style: TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30),
                    if (_isLoading)
                      const CircularProgressIndicator()
                    else
                      ElevatedButton.icon(
                        onPressed: _pickFile,
                        icon: const Icon(Icons.file_open),
                        label: const Text('选择文件'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
                    const SizedBox(height: 20),
                    if (_fileName != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '已选择文件: $_fileName',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    const SizedBox(height: 20),
                    if (_isConverted) ...[
                      const Text('转换完成!', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Container(
                        height: 100,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SingleChildScrollView(
                          child: Text(
                            _base64String!.length > 100
                                ? '${_base64String!.substring(0, 100)}...'
                                : _base64String!,
                            style: const TextStyle(fontFamily: 'monospace'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _copyToClipboard,
                            icon: const Icon(Icons.copy),
                            label: const Text('复制到剪贴板'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[400],
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _saveBase64ToFile,
                            icon: const Icon(Icons.save),
                            label: const Text('保存'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[600],
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text(
                  '\u00A9 2025 Jefsky | www.jefsky.com',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
