import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:share_plus/share_plus.dart';

class LegalDocumentViewerPage extends StatefulWidget {
  final String title;
  final String markdownContent;
  final bool isAcceptanceRequired;
  final VoidCallback? onAccept;

  const LegalDocumentViewerPage({
    super.key,
    required this.title,
    required this.markdownContent,
    this.isAcceptanceRequired = false,
    this.onAccept,
  });

  @override
  State<LegalDocumentViewerPage> createState() => _LegalDocumentViewerPageState();
}

class _LegalDocumentViewerPageState extends State<LegalDocumentViewerPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  
  bool _showBackToTop = false;
  bool _isSearching = false;
  bool _hasReadToBottom = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.offset >= 400 && !_showBackToTop) {
        setState(() => _showBackToTop = true);
      } else if (_scrollController.offset < 400 && _showBackToTop) {
        setState(() => _showBackToTop = false);
      }

      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100) {
        if (!_hasReadToBottom) {
          setState(() => _hasReadToBottom = true);
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  void _shareDocument() {
    SharePlus.instance.share(ShareParams(text: widget.markdownContent, subject: widget.title));
  }

  String _getHighlightedContent() {
    if (_searchQuery.isEmpty) return widget.markdownContent;
    // Basic text highlighting by wrapping the match in bold + italic for distinct styling.
    // Note: This is a simplistic approach for markdown and may break if the search query matches markdown syntax.
    // In a production app with complex markdown, a custom AST builder is preferred.
    final pattern = RegExp(_searchQuery, caseSensitive: false);
    return widget.markdownContent.replaceAllMapped(pattern, (match) => '***\${match.group(0)}***');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search document...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                ),
                style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
              )
            : Text(
                widget.title,
                style: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  color: Color(0xFF0F172A),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchQuery = '';
                  _searchController.clear();
                } else {
                  _isSearching = true;
                }
              });
            },
            tooltip: 'Search',
          ),
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.share_rounded),
              onPressed: _shareDocument,
              tooltip: 'Share',
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Scrollbar(
                controller: _scrollController,
                thickness: 6,
                radius: const Radius.circular(10),
                child: Markdown(
                  controller: _scrollController,
                  data: _getHighlightedContent(),
                  selectable: true,
                  padding: const EdgeInsets.all(24),
                  styleSheet: MarkdownStyleSheet(
                    h1: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      height: 1.3,
                    ),
                    h2: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                      height: 1.4,
                    ),
                    h3: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF334155),
                    ),
                    p: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF475569),
                      height: 1.6,
                    ),
                    listBullet: const TextStyle(
                      color: Color(0xFFF05A4F),
                      fontSize: 16,
                    ),
                    strong: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                    em: const TextStyle(
                      backgroundColor: Color(0xFFFEF08A), // Highlight color for search
                      color: Color(0xFF0F172A),
                      fontStyle: FontStyle.normal,
                    ),
                    blockSpacing: 16,
                  ),
                ),
              ),
            ),
            if (widget.isAcceptanceRequired)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: const Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      offset: const Offset(0, -4),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: SafeArea(
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _hasReadToBottom
                          ? () {
                              if (widget.onAccept != null) {
                                widget.onAccept!();
                              }
                              Navigator.pop(context, true);
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF05A4F),
                        disabledBackgroundColor: const Color(0xFFCBD5E1),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _hasReadToBottom ? 'Accept & Continue' : 'Scroll to bottom to accept',
                        style: const TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: _showBackToTop
          ? FloatingActionButton(
              onPressed: _scrollToTop,
              backgroundColor: const Color(0xFFF05A4F),
              mini: true,
              child: const Icon(Icons.keyboard_arrow_up, color: Colors.white),
            )
          : null,
    );
  }
}
