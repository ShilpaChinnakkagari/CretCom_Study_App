import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';

class PDFViewerScreen extends StatefulWidget {
  final File file;
  final String fileName;

  const PDFViewerScreen({
    super.key,
    required this.file,
    required this.fileName,
  });

  @override
  State<PDFViewerScreen> createState() => _PDFViewerScreenState();
}

class _PDFViewerScreenState extends State<PDFViewerScreen> {
  bool _isLoading = true;
  int _totalPages = 0;
  int _currentPage = 0;
  PDFViewController? _pdfViewController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        bottom: _totalPages > 0
            ? PreferredSize(
                preferredSize: const Size.fromHeight(30),
                child: Container(
                  color: Colors.red.shade100,
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Text(
                    'Page ${_currentPage + 1} of $_totalPages',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black87),
                  ),
                ),
              )
            : null,
      ),
      body: Stack(
        children: [
          PDFView(
            filePath: widget.file.path,
            enableSwipe: true,
            swipeHorizontal: true,
            autoSpacing: true,
            pageFling: true,
            onRender: (pages) {
              setState(() {
                _totalPages = pages!;
                _isLoading = false;
              });
            },
            onViewCreated: (controller) {
              _pdfViewController = controller;
            },
            onPageChanged: (page, total) {
              setState(() {
                _currentPage = page ?? 0;
              });
            },
            onError: (error) {
              setState(() {
                _isLoading = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $error'), backgroundColor: Colors.red),
              );
            },
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
