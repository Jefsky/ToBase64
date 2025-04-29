import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:cross_file/cross_file.dart';

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
  List<FileItem> _files = [];
  bool _isLoading = false;
  bool _isDragging = false;

  Future<void> _pickFiles() async {
    setState(() {
      _isLoading = true;
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
      );
      
      if (result != null) {
        final newFiles = <FileItem>[];
        
        for (var file in result.files) {
          if (file.path != null) {
            final fileObj = File(file.path!);
            final bytes = await fileObj.readAsBytes();
            final base64String = base64Encode(bytes);
            
            newFiles.add(FileItem(
              name: file.name,
              path: file.path!,
              size: file.size,
              base64: base64String,
            ));
          }
        }
        
        setState(() {
          _files.addAll(newFiles);
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

  Future<void> _handleFileDrop(List<XFile> files) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final newFiles = <FileItem>[];
      
      for (var xFile in files) {
        final file = File(xFile.path);
        final bytes = await file.readAsBytes();
        final base64String = base64Encode(bytes);
        
        newFiles.add(FileItem(
          name: xFile.name,
          path: xFile.path,
          size: await file.length(),
          base64: base64String,
        ));
      }
      
      setState(() {
        _files.addAll(newFiles);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('处理拖放文件时发生错误: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
        _isDragging = false;
      });
    }
  }

  Future<void> _saveBase64ToFile(FileItem file) async {
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
      
      final filePath = '$outputDirectory/${file.name}_base64.txt';
      final outputFile = File(filePath);
      await outputFile.writeAsString(file.base64);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Base64文件已保存到: $filePath')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存文件时发生错误: $e')),
      );
    }
  }

  Future<void> _copyToClipboard(String base64) async {
    await Clipboard.setData(ClipboardData(text: base64));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Base64已复制到剪贴板')),
    );
  }

  void _removeFile(int index) {
    setState(() {
      _files.removeAt(index);
    });
  }

  void _clearAllFiles() {
    setState(() {
      _files.clear();
    });
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ToBase64'),
        centerTitle: true,
        actions: [
          if (_files.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: '清除所有文件',
              onPressed: _clearAllFiles,
            ),
        ],
      ),
      body: DropTarget(
        onDragDone: (detail) => _handleFileDrop(detail.files),
        onDragEntered: (detail) {
          setState(() {
            _isDragging = true;
          });
        },
        onDragExited: (detail) {
          setState(() {
            _isDragging = false;
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Expanded(
                child: _files.isEmpty
                    ? _buildDropZone()
                    : _buildFilesList(),
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickFiles,
        tooltip: '选择文件',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildDropZone() {
    return Center(
      child: Container(
        width: double.infinity,
        height: 300,
        decoration: BoxDecoration(
          color: _isDragging ? Colors.blue.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isDragging ? Colors.blue : Colors.grey.withOpacity(0.3),
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.file_upload_outlined,
              size: 80,
              color: Colors.blue,
            ),
            const SizedBox(height: 20),
            Text(
              _isDragging ? '松开以添加文件' : '拖拽文件到此处或点击下方按钮选择文件',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            if (_isLoading)
              const CircularProgressIndicator()
            else
              ElevatedButton.icon(
                onPressed: _pickFiles,
                icon: const Icon(Icons.file_open),
                label: const Text('选择文件'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilesList() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '已添加 ${_files.length} 个文件${_isDragging ? " - 松开以添加更多文件" : ""}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: _files.length,
                  itemBuilder: (context, index) {
                    final file = _files[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ExpansionTile(
                        title: Text(file.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('大小: ${_formatFileSize(file.size)}'),
                        leading: const Icon(Icons.insert_drive_file),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.copy, color: Colors.blue),
                              tooltip: '复制Base64',
                              onPressed: () => _copyToClipboard(file.base64),
                            ),
                            IconButton(
                              icon: const Icon(Icons.save, color: Colors.green),
                              tooltip: '保存Base64',
                              onPressed: () => _saveBase64ToFile(file),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              tooltip: '移除文件',
                              onPressed: () => _removeFile(index),
                            ),
                          ],
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Base64编码:', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  height: 100,
                                  child: SingleChildScrollView(
                                    child: SelectableText(
                                      file.base64.length > 100
                                          ? '${file.base64.substring(0, 100)}...'
                                          : file.base64,
                                      style: const TextStyle(fontFamily: 'monospace'),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class FileItem {
  final String name;
  final String path;
  final int size;
  final String base64;

  FileItem({
    required this.name,
    required this.path,
    required this.size,
    required this.base64,
  });
}
