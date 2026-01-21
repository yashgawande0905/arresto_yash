import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:arresto/networks/ApisRequests.dart';
import '../new_dropdown/parameter_selector.dart'; // ADD THIS


/// =======================
/// SHARED SELECTED STYLE (OPTION 2 – SOFT GREEN)
/// =======================
const Color kSelectedChipBg = Color(0xFFEFF6F0);
const Color kSelectedChipBorder = Color(0xFF9BC9A3);
const Color kSelectedChipText = Color(0xFF1E3B2B);


/// =======================
/// GENERIC API FETCH
/// =======================
Future<Map<String, dynamic>> fetchPaginatedData({
  required String url,
  required int page,
  required String search,
  required String listKey,
  required String lastPageKey,
}) async {
  final uri = Uri.parse(url).replace(queryParameters: {
    "page": page.toString(),
    "per_page": "20",
    "search": search,
  });

  final response = await ApisRequests().makeGetRequest(uri.toString());
  final decoded = jsonDecode(response.body);

  return {
    "items": List<Map<String, dynamic>>.from(decoded[listKey]),
    "lastPage": decoded[lastPageKey],
  };
}


/// =======================
/// TASK LIST PAGE
/// =======================
class TaskListPage extends StatefulWidget {
  const TaskListPage({super.key});

  @override
  State<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends State<TaskListPage> {
  List<Map<String, dynamic>> selectedItems = [];

  /// ✅ PASTE THIS METHOD HERE
  void openSelector() async {
    final result = await showParameterSelector(
      context,
      apiUrl: "https://uatapi.arresto.in/api/sa/parameter_types/list",
      listKey: "data",
      idKey: "type_id",
      labelKey: "type_name",
      lastPageKey: "last_page",
      initialSelected: selectedItems,
    );

    setState(() {
      selectedItems = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Task List",
          style: TextStyle(
            fontFamilyFallback: ['Arial Narrow', 'Roboto Condensed', 'Arial'],
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            /// OPEN SELECTOR
            LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 600;

                return InkWell(
                  onTap: openSelector,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: isMobile
                        ? double.infinity            // mobile = full width
                        : constraints.maxWidth * 0.5, // web = half width
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Select Parameters",
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Icon(Icons.expand_more),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            /// SELECTED DISPLAY (MATCHES PANEL STYLE)
            if (selectedItems.isNotEmpty)
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: selectedItems.map((item) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: kSelectedChipBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: kSelectedChipBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item['type_name'],
                          style: const TextStyle(
                            color: kSelectedChipText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedItems.removeWhere(
                                    (e) =>
                                e['type_id'] == item['type_id'],
                              );
                            });
                          },
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: kSelectedChipText,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}


/// =======================
/// MULTI-SELECT PANEL
/// =======================
class ApiMultiSelectPanel extends StatefulWidget {
  final String apiUrl;
  final String listKey;
  final String idKey;
  final String labelKey;
  final String lastPageKey;
  final List<Map<String, dynamic>> selectedItems;
  final ValueChanged<List<Map<String, dynamic>>> onChanged;

  const ApiMultiSelectPanel({
    super.key,
    required this.apiUrl,
    required this.listKey,
    required this.idKey,
    required this.labelKey,
    required this.lastPageKey,
    required this.selectedItems,
    required this.onChanged,
  });

  @override
  State<ApiMultiSelectPanel> createState() => _ApiMultiSelectPanelState();
}

class _ApiMultiSelectPanelState extends State<ApiMultiSelectPanel> {
  final ScrollController controller = ScrollController();
  final TextEditingController searchCtrl = TextEditingController();

  List<Map<String, dynamic>> items = [];
  int page = 1;
  bool loading = false;
  Timer? debounce;

  @override
  void initState() {
    super.initState();
    load();

    controller.addListener(() {
      if (controller.position.pixels >
          controller.position.maxScrollExtent - 200) {
        load();
      }
    });

    HardwareKeyboard.instance.addHandler(_handleEsc);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleEsc);
    debounce?.cancel();
    controller.dispose();
    searchCtrl.dispose();
    super.dispose();
  }

  bool _handleEsc(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return true;
    }
    return false;
  }

  Future<void> load({bool reset = false}) async {
    if (loading) return;
    loading = true;

    if (reset) {
      page = 1;
      items.clear();
    }

    final res = await fetchPaginatedData(
      url: widget.apiUrl,
      page: page,
      search: searchCtrl.text,
      listKey: widget.listKey,
      lastPageKey: widget.lastPageKey,
    );

    setState(() {
      items.addAll(res['items']);
      page++;
      loading = false;
    });
  }

  void toggle(Map<String, dynamic> item) {
    setState(() {
      final exists = widget.selectedItems.any(
            (e) => e[widget.idKey] == item[widget.idKey],
      );

      if (exists) {
        widget.selectedItems.removeWhere(
              (e) => e[widget.idKey] == item[widget.idKey],
        );
      } else {
        widget.selectedItems.add(item);
      }

      widget.onChanged(widget.selectedItems);
    });
  }

  void selectAllVisible() {
    setState(() {
      for (final item in items) {
        if (!widget.selectedItems.any(
                (e) => e[widget.idKey] == item[widget.idKey])) {
          widget.selectedItems.add(item);
        }
      }
      widget.onChanged(widget.selectedItems);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Material(
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [

          /// HEADER
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [

                /// LEFT SIDE — TITLE
                Text(
                  "Selected (${widget.selectedItems.length})",
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),

                /// RIGHT SIDE — ACTIONS
                Row(
                  children: [

                    /// SELECT ALL
                    TextButton(
                      onPressed: selectAllVisible,
                      child: const Text("Select All"),
                    ),

                    /// CLEAR ALL
                    TextButton(
                      onPressed: () {
                        setState(() {
                          widget.selectedItems.clear();
                          widget.onChanged(widget.selectedItems);
                        });
                      },
                      child: const Text("Clear All"),
                    ),

                    /// DONE  ✅ THIS IS THE IMPORTANT ONE
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context, widget.selectedItems);
                      },
                      child: const Text(
                        "Done",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),


          /// SEARCH
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              height: isMobile ? 42 : null,
              child: TextField(
                controller: searchCtrl,
                onChanged: (_) {
                  debounce?.cancel();
                  debounce = Timer(
                    const Duration(milliseconds: 300),
                        () => load(reset: true),
                  );
                },
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: "Search parameter...",
                ),
              ),
            ),
          ),

          /// LIST
          Expanded(
            child: ListView.builder(
              controller: controller,
              itemCount: items.length,
              itemBuilder: (_, i) {
                final item = items[i];
                final checked = widget.selectedItems.any(
                      (e) => e[widget.idKey] == item[widget.idKey],
                );

                return Container(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: checked ? kSelectedChipBg : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    border: checked
                        ? Border.all(color: kSelectedChipBorder)
                        : null,
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    hoverColor: checked
                        ? kSelectedChipBg
                        : Colors.black.withOpacity(0.03),
                    onTap: () => toggle(item),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 8 : 12,
                        vertical: isMobile ? 6 : 10,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Transform.scale(
                            scale: isMobile ? 0.9 : 1,
                            child: Checkbox(
                              value: checked,
                              onChanged: (_) => toggle(item),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item[widget.labelKey],
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: isMobile ? 14 : 16,
                                    color: kSelectedChipText,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "ID: ${item[widget.idKey]}",
                                  style: TextStyle(
                                    fontSize: isMobile ? 11 : 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
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
    );
  }
}
