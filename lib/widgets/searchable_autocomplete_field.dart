import 'package:flutter/material.dart';

class SearchableAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final List<String> options;
  final IconData? prefixIcon;

  const SearchableAutocompleteField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.options,
    this.prefixIcon,
  });

  @override
  State<SearchableAutocompleteField> createState() =>
      _SearchableAutocompleteFieldState();
}

class _SearchableAutocompleteFieldState
    extends State<SearchableAutocompleteField> {
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  List<String> _filteredOptions = [];

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _updateFilteredOptions();
        _showOverlay();
      } else {
        _hideOverlay();
      }
    });

    widget.controller.addListener(() {
      if (_focusNode.hasFocus) {
        _updateFilteredOptions();
        _overlayEntry?.markNeedsBuild();
      }
    });
  }

  void _updateFilteredOptions() {
    final query = widget.controller.text.trim().toLowerCase();
    if (query.isEmpty) {
      _filteredOptions = widget.options;
    } else {
      _filteredOptions = widget.options
          .where((item) => item.toLowerCase().contains(query))
          .toList();
    }
  }

  void _showOverlay() {
    _hideOverlay();
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final size = renderBox.size;

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 4),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDarkMode ? Colors.white12 : const Color(0xFFE2E8F0),
                ),
              ),
              child: _filteredOptions.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.edit_note_rounded,
                            size: 18,
                            color: isDarkMode
                                ? Colors.white38
                                : Colors.grey[500],
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Nhập tên mới: "${widget.controller.text.trim()}"',
                              style: TextStyle(
                                fontFamily: 'Encode Sans Expanded',
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                                color: isDarkMode
                                    ? Colors.white60
                                    : Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: _filteredOptions.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        thickness: 0.5,
                        color: isDarkMode
                            ? Colors.white10
                            : const Color(0xFFF1F5F9),
                      ),
                      itemBuilder: (context, index) {
                        final option = _filteredOptions[index];
                        return InkWell(
                          onTap: () {
                            widget.controller.text = option;
                            widget.controller.selection =
                                TextSelection.fromPosition(
                                  TextPosition(offset: option.length),
                                );
                            _focusNode.unfocus();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 11,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  widget.prefixIcon ?? Icons.bookmarks_rounded,
                                  size: 15,
                                  color: isDarkMode
                                      ? const Color(0xFF5893D8)
                                      : const Color(0xFF457EC0),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    option,
                                    style: TextStyle(
                                      fontFamily: 'Encode Sans Expanded',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: isDarkMode
                                          ? Colors.white
                                          : const Color(0xFF1F2937),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _hideOverlay();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        style: TextStyle(
          fontFamily: 'Encode Sans Expanded',
          fontSize: 15,
          color: isDarkMode ? Colors.white : const Color(0xFF1E1E1E),
        ),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: TextStyle(
            fontFamily: 'Encode Sans Expanded',
            fontSize: 14,
            color: isDarkMode ? Colors.white30 : const Color(0xFF8E8E93),
          ),
          prefixIcon: widget.prefixIcon != null
              ? Icon(
                  widget.prefixIcon,
                  size: 18,
                  color: isDarkMode ? Colors.white54 : const Color(0xFF457EC0),
                )
              : null,
          suffixIcon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: isDarkMode ? Colors.white38 : Colors.grey[400],
          ),
          filled: true,
          fillColor: isDarkMode
              ? const Color(0xFF1E1E1E)
              : const Color(0xFFF8FAFC),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: isDarkMode ? Colors.white10 : const Color(0xFFE2E8F0),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: isDarkMode ? Colors.white10 : const Color(0xFFE2E8F0),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF457EC0), width: 1.5),
          ),
        ),
      ),
    );
  }
}
