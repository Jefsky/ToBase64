import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:cross_file/cross_file.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

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
  String? _defaultSavePath; // 默认保存路径
  bool _isInitializing = true; // 添加初始化标志

  @override
  void initState() {
    super.initState();
    // 使用Future.microtask确保不会阻塞UI初始化
    Future.microtask(() => _loadSavedPath());
  }

  // 加载保存的路径
  Future<void> _loadSavedPath() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPath = prefs.getString('defaultSavePath');
      
      // 检查路径是否存在
      if (savedPath != null) {
        final directory = Directory(savedPath);
        final exists = await directory.exists();
        
        setState(() {
          _defaultSavePath = exists ? savedPath : null;
          _isInitializing = false;
        });
      } else {
        setState(() {
          _defaultSavePath = null;
          _isInitializing = false;
        });
      }
    } catch (e) {
      // 忽略错误，使用null作为默认值
      setState(() {
        _defaultSavePath = null;
        _isInitializing = false;
      });
      print('加载保存路径时发生错误: $e');
    }
  }

  // 保存路径到本地存储
  Future<void> _saveDefaultPath(String path) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('defaultSavePath', path);
      setState(() {
        _defaultSavePath = path;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存默认路径时发生错误: $e')),
      );
    }
  }

  // 设置默认保存路径
  Future<void> _setDefaultSavePath() async {
    try {
      String? outputDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择默认保存位置',
      );
      
      if (outputDirectory == null) {
        // 用户取消了选择
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已取消设置默认保存位置')),
        );
        return;
      }
      
      await _saveDefaultPath(outputDirectory);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('默认保存位置已设置为: $outputDirectory')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('设置默认保存位置时发生错误: $e')),
      );
    }
  }

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
              isSelected: true, // 默认选中新添加的文件
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
          isSelected: true, // 默认选中新添加的文件
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

  // 打开保存路径文件夹
  Future<void> _openSaveDirectory() async {
    if (_isInitializing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('应用正在初始化，请稍后再试')),
      );
      return;
    }
    
    if (_defaultSavePath == null) {
      // 如果没有设置默认路径，先设置
      await _setDefaultSavePath();
      if (_defaultSavePath == null) {
        // 用户取消了设置
        return;
      }
    }

    try {
      final Uri uri = Uri.file(_defaultSavePath!);
      if (!await launchUrl(uri)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法打开文件夹')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('打开文件夹时发生错误: $e')),
      );
    }
  }

  // 打开单个文件所在的文件夹
  Future<void> _openFileDirectory(String filePath) async {
    try {
      final directory = File(filePath).parent.path;
      final Uri uri = Uri.file(directory);
      if (!await launchUrl(uri)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法打开文件夹')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('打开文件夹时发生错误: $e')),
      );
    }
  }

  Future<void> _saveBase64ToFile(FileItem file, {bool useDefaultPath = true}) async {
    try {
      String? outputDirectory;
      
      if (useDefaultPath && _defaultSavePath != null) {
        // 使用默认保存路径
        outputDirectory = _defaultSavePath;
      } else {
        // 使用FilePicker让用户选择保存位置
        outputDirectory = await FilePicker.platform.getDirectoryPath(
          dialogTitle: '选择保存位置',
        );
        
        // 注意：这里不会更新默认保存路径，单独保存时选择的路径只用于当前操作
      }
      
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
        SnackBar(
          content: Text('Base64文件已保存到: $filePath'),
          action: SnackBarAction(
            label: '打开文件夹',
            onPressed: () => _openFileDirectory(filePath),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存文件时发生错误: $e')),
      );
    }
  }

  // 批量下载所有文件
  Future<void> _batchDownloadAllFiles() async {
    if (_isInitializing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('应用正在初始化，请稍后再试')),
      );
      return;
    }
    
    // 获取选中的文件
    final selectedFiles = _files.where((file) => file.isSelected).toList();
    
    if (selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择要下载的文件')),
      );
      return;
    }

    if (_defaultSavePath == null) {
      // 如果没有设置默认路径，先设置
      await _setDefaultSavePath();
      if (_defaultSavePath == null) {
        // 用户取消了设置
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      int successCount = 0;
      
      for (var file in selectedFiles) {
        try {
          final filePath = '$_defaultSavePath/${file.name}_base64.txt';
          final outputFile = File(filePath);
          await outputFile.writeAsString(file.base64);
          successCount++;
        } catch (e) {
          // 继续处理下一个文件
          print('保存文件 ${file.name} 时发生错误: $e');
        }
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已成功保存 $successCount/${selectedFiles.length} 个文件到: $_defaultSavePath'),
          action: SnackBarAction(
            label: '打开文件夹',
            onPressed: _openSaveDirectory,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('批量下载文件时发生错误: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
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

  bool _isAllSelected() {
    if (_files.isEmpty) return false;
    return _files.every((file) => file.isSelected);
  }

  void _toggleSelectAll() {
    final shouldSelect = !_isAllSelected();
    setState(() {
      for (var file in _files) {
        file.isSelected = shouldSelect;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 计算选中的文件数量
    final selectedCount = _files.where((file) => file.isSelected).length;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('ToBase64'),
        centerTitle: true,
        actions: [
          if (_files.isNotEmpty)
            Badge(
              label: selectedCount > 0 ? Text('$selectedCount') : null,
              isLabelVisible: selectedCount > 0,
              child: IconButton(
                icon: const Icon(Icons.download),
                tooltip: '批量下载选中的文件',
                onPressed: _isInitializing ? null : _batchDownloadAllFiles,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.folder),
            tooltip: '设置默认保存路径',
            onPressed: _isInitializing ? null : _setDefaultSavePath,
          ),
          if (_defaultSavePath != null && !_isInitializing)
            IconButton(
              icon: const Icon(Icons.folder_open),
              tooltip: '打开保存路径文件夹',
              onPressed: _openSaveDirectory,
            ),
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
              if (_files.isNotEmpty && !_isInitializing)
                TextButton.icon(
                  icon: const Icon(Icons.select_all, size: 18),
                  label: Text(_isAllSelected() ? '取消全选' : '全选'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: _toggleSelectAll,
                ),
              if (_isInitializing)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
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
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: file.isSelected,
                              onChanged: (value) {
                                setState(() {
                                  file.isSelected = value ?? false;
                                });
                              },
                            ),
                            const Icon(Icons.insert_drive_file),
                          ],
                        ),
                        title: Text(file.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('大小: ${_formatFileSize(file.size)}'),
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
                              onPressed: _isInitializing 
                                  ? null 
                                  : () => _saveBase64ToFile(file, useDefaultPath: false),
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
  bool isSelected;

  FileItem({
    required this.name,
    required this.path,
    required this.size,
    required this.base64,
    this.isSelected = false,
  });
}
