import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pi_task_watch/theme/app_theme.dart';

class SearchableDropdown<T> extends StatefulWidget {
  final T? value;
  final List<T> items;
  final String hint;
  final Function(T?) onChanged;
  final bool isRequired;
  final double height;
  final TextEditingController searchController;
  final String Function(T) itemToString;
  final Widget Function(T item, bool isSelected)? itemWidgetBuilder;

  const SearchableDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.hint,
    required this.onChanged,
    required this.searchController,
    this.isRequired = false,
    this.height = 40,
    required this.itemToString,
    this.itemWidgetBuilder,
  });

  @override
  State<SearchableDropdown<T>> createState() => _SearchableDropdownState<T>();
}

class _SearchableDropdownState<T> extends State<SearchableDropdown<T>> {
  @override
  Widget build(BuildContext context) {
    String? stage;
    if (widget.value != null) {
      try {
        final dynamic v = widget.value;
        if (v.stageName != null && v.stageName.toString().isNotEmpty) {
          stage = v.stageName.toString();
        }
      } catch (_) {}
    }

    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (BuildContext context) {
            return _SearchableDropdownDialog<T>(
              items: widget.items,
              currentValue: widget.value,
              hint: widget.hint,
              searchController: widget.searchController,
              onChanged: widget.onChanged,
              itemToString: widget.itemToString,
              itemWidgetBuilder: widget.itemWidgetBuilder,
            );
          },
        );
      },
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          color: Colors.white,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Icon(Icons.storage_outlined, size: 16, color: Colors.grey.shade400),
            const SizedBox(width: 8),
            Expanded(
              child: widget.value != null
                  ? Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.itemToString(widget.value as T),
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (stage != null) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00A09D).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                    color: const Color(0xFF00A09D).withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                stage,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF00A09D),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ],
                    )
                  : Text(
                      widget.hint,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.grey.shade400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
            Icon(Icons.unfold_more, color: Colors.grey.shade400, size: 18),
          ],
        ),
      ),
    );
  }
}

class _SearchableDropdownDialog<T> extends StatefulWidget {
  final List<T> items;
  final T? currentValue;
  final String hint;
  final TextEditingController searchController;
  final Function(T?) onChanged;
  final String Function(T) itemToString;
  final Widget Function(T item, bool isSelected)? itemWidgetBuilder;

  const _SearchableDropdownDialog({
    required this.items,
    required this.currentValue,
    required this.hint,
    required this.searchController,
    required this.onChanged,
    required this.itemToString,
    this.itemWidgetBuilder,
  });

  @override
  State<_SearchableDropdownDialog<T>> createState() =>
      _SearchableDropdownDialogState<T>();
}

class _SearchableDropdownDialogState<T>
    extends State<_SearchableDropdownDialog<T>> {
  late List<T> _filteredItems;
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.searchController.text = '';
    _filteredItems = [...widget.items];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  String? _getStageFromItem(T item) {
    try {
      final dynamic v = item;
      if (v.stageName != null && v.stageName.toString().isNotEmpty) {
        return v.stageName.toString();
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    List<T> displayItems = [];
    List<T> currentFiltered = [..._filteredItems];

    if (widget.currentValue != null) {
      displayItems.add(widget.currentValue as T);
      currentFiltered.removeWhere((item) => item == widget.currentValue);
    }
    displayItems.addAll(currentFiltered);

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 320, // Explicitly set width to avoid layout issues
        height: 500, // Explicitly set height or use constraints
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.hint,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child:
                          const Icon(Icons.close, size: 16, color: Colors.grey),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: widget.searchController,
                focusNode: _searchFocusNode,
                decoration: InputDecoration(
                  hintText: 'Search...',
                  hintStyle:
                      GoogleFonts.inter(fontSize: 13, color: Colors.grey),
                  isDense: true,
                  prefixIcon:
                      const Icon(Icons.search, size: 20, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                ),
                cursorColor: AppTheme.primary,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.black87,
                ),
                onChanged: (value) {
                  setState(() {
                    _filteredItems = widget.items
                        .where((element) => widget
                            .itemToString(element)
                            .toLowerCase()
                            .contains(value.toLowerCase()))
                        .toList();
                  });
                },
              ),
              const SizedBox(height: 16),
              Expanded(
                child: displayItems.isEmpty
                    ? Center(
                        child: Text(
                          'No results found',
                          style: GoogleFonts.inter(
                              fontSize: 13, color: Colors.grey),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.zero,
                        itemCount: displayItems.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 4),
                        itemBuilder: (BuildContext context, int index) {
                          final item = displayItems[index];
                          final isSelected = widget.currentValue == item;

                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                widget.onChanged(item);
                                Navigator.of(context).pop();
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppTheme.primary.withOpacity(0.05)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppTheme.primary.withOpacity(0.1)
                                        : Colors.transparent,
                                  ),
                                ),
                                child: widget.itemWidgetBuilder != null
                                    ? widget.itemWidgetBuilder!(item, isSelected)
                                    : Row(
                                        children: [
                                          if (isSelected)
                                            const Icon(Icons.check_circle,
                                                size: 18, color: AppTheme.primary),
                                          if (isSelected)
                                            const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              widget.itemToString(item),
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                fontWeight: isSelected
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                                color: isSelected
                                                    ? AppTheme.primary
                                                    : Colors.black87,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (_getStageFromItem(item) != null) ...[
                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF00A09D).withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(
                                                    color: const Color(0xFF00A09D).withValues(alpha: 0.3),
                                                  ),
                                                ),
                                                child: Text(
                                                  _getStageFromItem(item)!,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: const Color(0xFF00A09D),
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
