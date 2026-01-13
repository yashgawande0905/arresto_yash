import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:ui';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:arresto/networks/ApisRequests.dart';
import 'package:fluttertoast/fluttertoast.dart' show Fluttertoast;
import 'package:arresto/app_utility/app_colors.dart';
import 'package:flutter/services.dart';


// ===================== COLOR ROLES =====================

// Brand
final Color accent = AppColors.app_header_new_color; // orange

// Surfaces
final Color pageBg  = const Color(0xFFF5F6F8); // light grey (NOT white)
final Color surface = Colors.white;            // cards

// Structure
final Color border = const Color(0xFFE0E0E0);

// Text
final Color textMain  = const Color(0xFF2E2E2E);
final Color textMuted = const Color(0xFF7A7A7A);

// Sidebar
final Color sidebarBg = const Color(0xFFF9F4EA); // very soft warm tint

// Status
final Color success = const Color(0xFF2E7D32); // deep green
final Color warning = const Color(0xFFF9A825); // amber
final Color danger  = const Color(0xFFC62828); // deep red


enum CardPanel { none, info, actions }

class Task {
  final String id;
  final String name;
  final String uin;
  final String type;
  DateTime scheduledDate;
  final String assignedUser;
  final String imageUrl;
  String status;

  bool selected;
  bool isActive;
  bool enableWebHero = true; // 🔥 toggle anytime
  late final String heroTag;

  // 👇 SINGLE SOURCE OF TRUTH
  CardPanel panel;

  Task({
    required this.id,
    required this.name,
    required this.uin,
    required this.type,
    required this.scheduledDate,
    required this.assignedUser,
    required this.imageUrl,
    this.status = "pending",
    this.selected = false,
    this.isActive = true,
    CardPanel? panel,
  }) : panel = panel ?? CardPanel.none {
    // ✅ constructor body (THIS is the correct place)
    heroTag = "task-hero-$id";
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    DateTime scheduledDate = DateTime.now();

    final sd = json['schedule_date'];

    if (sd is String) {
      scheduledDate = DateTime.parse(sd);
    } else if (sd is Map &&
        sd['\$date'] != null &&
        sd['\$date']['\$numberLong'] != null) {
      scheduledDate = DateTime.fromMillisecondsSinceEpoch(
        int.parse(sd['\$date']['\$numberLong']),
      );
    }

    return Task(
      id: json['_id'].toString(),
      name: json['meta_data']?['component_name'] ?? 'Unknown Asset',
      uin: json['field_value'] ?? '',
      type: json['type'] ?? '',
      scheduledDate: scheduledDate,
      assignedUser: json['assigned_user']?['name'] ?? 'Unassigned',
      imageUrl:
      json['meta_data']?['component_imagepath'] ??
          'https://picsum.photos/200',
      status: json['status'] ?? 'pending',
      isActive: json['is_active'] ?? true,
    );
  }
}


class TaskListPage extends StatefulWidget {
  const TaskListPage({super.key});

  @override
  State<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends State<TaskListPage> {
  final ApisRequests _api = ApisRequests();
  final ScrollController _listCtrl = ScrollController();
  int get selectedCount =>
      filtered.where((t) => t.selected).length;

  // ===== SIDEBAR FILTER STATE =====
  Set<String> statusFilter = {};
  Set<String> typeFilter = {};
  Set<String> userFilter = {};

  DateTime? fromDateFilter;
  DateTime? toDateFilter;
  DateTime? exactDateFilter;

  bool isDarkMode = false;

  bool sidebarCollapsed = false;

  bool isDemoMode = true;
// 🔥 true = dummy cards
// 🔥 false = real API

  bool showSearch = false;
  final TextEditingController searchCtrl = TextEditingController();

  bool enableWebHero = true; // ✅ toggle hero on web


  bool _loading = true;
  List<Task> tasks = [];
  List<Task> filtered = [];

  bool get hasSelection => tasks.any((t) => t.selected);

  bool selectionMode = false;



  bool get isAllSelected =>
      filtered.isNotEmpty && filtered.every((t) => t.selected);

  bool get isPartiallySelected {
    final selectedCount = filtered.where((t) => t.selected).length;
    return selectedCount > 0 && selectedCount < filtered.length;
  }

  InputDecoration _outlinedInput({
    required String hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      isDense: true,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: surface,
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Colors.black.withOpacity(0.12),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Colors.black.withOpacity(0.12),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: accent,
          width: 1.4,
        ),
      ),
    );
  }



  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  void _viewTask(Task task) {
    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Task Details"),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailRow("Asset Name", task.name),
                _detailRow("UIN", task.uin),
                _detailRow("Type", task.type),
                _detailRow("Status", task.status),

                Divider(
                  color: border,
                  thickness: 0.8,
                ),

                _detailRow("Assigned To", task.assignedUser),
                _detailRow("Created On",
                    task.scheduledDate.toString().split(' ')[0]),

                _detailRow("Due Date",
                    task.scheduledDate.toString().split(' ')[0]),

                _detailRow("Task ID", task.id),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              "$label:",
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? "-" : value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }



  Future<void> _editTask(Task task) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: task.scheduledDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() => task.scheduledDate = picked);

      await _api.makePutRequest(
        "https://uatapi.arresto.in/api/client/1825/tasks/${task
            .id}/reschedule",
        jsonEncode({"scheduled_date": picked.toIso8601String()}),
      );

      Fluttertoast.showToast(msg: "Task rescheduled");
    }
  }

  Future<void> _deleteTask(Task task) async {
    final confirm = await showDialog<bool>(
      context: context,
      useRootNavigator: true, // ✅ IMPORTANT
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Delete Task"),
          content: const Text(
            "Are you sure you want to delete this task?",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false); // ✅ close dialog only
              },
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true); // ✅ confirm delete
              },
              child: const Text(
                "Delete",
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      if (!isDemoMode) {
        await _api.makeDeleteRequest(
          "https://uatapi.arresto.in/api/client/1825/tasks/${task.id}",
        );
      }

      setState(() {
        tasks.remove(task);
        filtered.remove(task);
      });

      Fluttertoast.showToast(
        msg: isDemoMode ? "Deleted (Demo)" : "Task deleted",
      );
    }
  }


  Future<void> _changeStatus(Task task) async {
    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Change Status"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _statusOption(
                label: "Pending",
                color: Colors.orange,
                task: task,
                dialogContext: dialogContext,
              ),
              _statusOption(
                label: "Approved",
                color: Colors.green,
                task: task,
                dialogContext: dialogContext,
              ),
              _statusOption(
                label: "Rejected",
                color: Colors.red,
                task: task,
                dialogContext: dialogContext,
              ),
            ],
          ),
        );
      },
    );
  }
  Widget _statusOption({
    required String label,
    required Color color,
    required Task task,
    required BuildContext dialogContext,
  }) {
    return ListTile(
      leading: Icon(Icons.circle, color: color),
      title: Text(label),
      onTap: () async {
        Navigator.of(dialogContext).pop(); // close dialog

        await _api.makePutRequest(
          "https://uatapi.arresto.in/api/client/1825/tasks/${task.id}/status",
          jsonEncode({"status": label}),
        );

        setState(() {
          task.status = label;
        });

        Fluttertoast.showToast(msg: "Status changed to $label");
      },
    );
  }


  Future<void> _loadTasks() async {
    setState(() => _loading = true);

    try {
      if (isDemoMode) {
        // 🧪 DEMO MODE
        final loadedTasks = mockTasks();

        setState(() {
          tasks = loadedTasks;
          filtered = List.from(loadedTasks);
          _loading = false;
        });
      } else {
        // 🌐 REAL API MODE
        final res = await _api.makeGetRequest(
          "https://uatapi.arresto.in/api/client/1825/tasks",
        );

        final decoded = jsonDecode(res.body);
        final List list = decoded['data'] ?? [];

        final loadedTasks =
        list.map((e) => Task.fromJson(e)).toList();

        loadedTasks.sort(
              (a, b) => b.scheduledDate.compareTo(a.scheduledDate),
        );

        setState(() {
          tasks = loadedTasks;
          filtered = List.from(loadedTasks);
          _loading = false;
        });
      }
    } catch (e) {
      // 🔥 SAFETY FALLBACK
      final fallback = mockTasks();
      setState(() {
        tasks = fallback;
        filtered = fallback;
        _loading = false;
      });
    }
  }



  void _searchTask(String value) {
    setState(() {
      filtered = tasks.where((t) {
        final q = value.toLowerCase();
        return t.name.toLowerCase().contains(q) ||
            t.uin.toLowerCase().contains(q) ||
            t.assignedUser.toLowerCase().contains(q);
      }).toList();
    });
  }

  /// ===================== EXPORT PDF (STUB) =====================
  Future<void> _exportPdf() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                "Task List",
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),

              pw.SizedBox(height: 12),

              ...filtered.map(
                    (task) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 6),
                  child: pw.Text(
                    "${task.name} | ${task.uin} | ${task.status}",
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }


  @override
  Widget build(BuildContext context) {
    final bool isWeb = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: pageBg,
      appBar: isWeb
          ? null
          : AppBar(
        backgroundColor: surface,
        elevation: 0,
        iconTheme: IconThemeData(color: textMain),
        titleTextStyle: TextStyle(
          color: textMain,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      body: isWeb ? _webBody(context) : _mobileBody(),
    );
  }

  Widget _swipeBg({
    required Color color,
    required IconData icon,
    required bool alignLeft,
  }) {
    return Container(
      alignment: alignLeft ? Alignment.centerLeft : Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: color.withOpacity(0.9),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(icon, color: Colors.white, size: 28),
    );
  }


  Widget _mobileBody() {
    return Column(
      children: [
        _topBar(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
            controller: _listCtrl,
            padding: const EdgeInsets.only(top: 8),
            itemCount: filtered.length,
            itemBuilder: (_, i) => _mobileRow(filtered[i]),
          ),
        ),
      ],
    );
  }

  void _applyFilters() {
    setState(() {
      filtered = tasks.where((t) {
        final status = t.status.toLowerCase();

        // ✅ STATUS
        if (statusFilter.isNotEmpty &&
            !statusFilter.map((e) => e.toLowerCase()).contains(status)) {
          return false;
        }

        // ✅ TYPE
        if (typeFilter.isNotEmpty && !typeFilter.contains(t.type)) {
          return false;
        }

        // ✅ ASSIGNED USER
        if (userFilter.isNotEmpty && !userFilter.contains(t.assignedUser)) {
          return false;
        }

        // ================= DATE FILTERING =================

        // 📅 EXACT DATE (HIGHEST PRIORITY)
        if (exactDateFilter != null) {
          final d = exactDateFilter!;
          final sameDay =
              t.scheduledDate.year == d.year &&
                  t.scheduledDate.month == d.month &&
                  t.scheduledDate.day == d.day;

          if (!sameDay) return false;
        } else {
          if (fromDateFilter != null &&
              toDateFilter != null &&
              fromDateFilter!.isAfter(toDateFilter!)) {
            return false;
          }

// 📅 FROM DATE
          if (fromDateFilter != null &&
              t.scheduledDate.isBefore(fromDateFilter!)) {
            return false;
          }

// 📅 TO DATE
          if (toDateFilter != null &&
              t.scheduledDate.isAfter(toDateFilter!)) {
            return false;
          }
        }

        // ✅ PASSED ALL FILTERS
        return true;
      }).toList();
    });
  }

  Widget _dateTile({
    required String label,
    required DateTime? date,
    required Function(DateTime) onPick,
    required VoidCallback onClear,
  }) {
    final bool disabled = exactDateFilter != null && label != "Exact";

    return InkWell(
      onTap: disabled
          ? null
          : () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (picked != null) onPick(picked);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: border.withOpacity(0.6),
            ),
          ),
        ),
        child: Row(
          children: [
            /// LABEL
            SizedBox(
              width: 46,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: disabled ? textMuted.withOpacity(0.5) : textMain,
                ),
              ),
            ),

            const SizedBox(width: 8),

            /// VALUE
            Expanded(
              child: Text(
                date == null
                    ? "Select date"
                    : date.toString().split(' ')[0],
                style: TextStyle(
                  fontSize: 13,
                  color: date == null
                      ? textMuted
                      : disabled
                      ? textMuted.withOpacity(0.5)
                      : textMain,
                ),
              ),
            ),

            /// CLEAR
            if (date != null && !disabled)
              InkWell(
                onTap: onClear,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.close,
                    size: 14,
                    color: textMuted,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }



  Widget _statusItem(String label, Color color) {
    final bool selected = statusFilter.contains(label);

    return InkWell(
      onTap: () {
        setState(() {
          selected
              ? statusFilter.remove(label)
              : statusFilter.add(label);
          _applyFilters();
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),

            Checkbox(
              value: selected,
              visualDensity: VisualDensity.compact,
              onChanged: (_) {
                setState(() {
                  selected
                      ? statusFilter.remove(label)
                      : statusFilter.add(label);
                  _applyFilters();
                });
              },
            ),

            const SizedBox(width: 6),

            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: selected ? textMain : textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _filterSection({
    required String title,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: textMuted,
            ),
          ),

          const SizedBox(height: 8),

          Divider(color: border, height: 1),

          const SizedBox(height: 6),

          child,
        ],
      ),
    );
  }




  Widget _sidebarFilterUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _filterSection(
          title: "STATUS",
          child: Column(
            children: [
              _statusItem("Pending", warning),
              _statusItem("Approved", success),
              _statusItem("Rejected", danger),
            ],
          ),
        ),

        _filterSection(
          title: "TYPE",
          child: Column(
            children: tasks
                .map((t) => t.type)
                .toSet()
                .map(_checkType)
                .toList(),
          ),
        ),

        _filterSection(
          title: "ASSIGNED TO",
          child: Column(
            children: tasks
                .map((t) => t.assignedUser)
                .toSet()
                .map(_checkUser)
                .toList(),
          ),
        ),

        _filterSection(
          title: "DATE",
          child: Column(
            children: [
              _dateTile(label: "Exact", date: exactDateFilter,
                onPick: (d) {
                  setState(() {
                    exactDateFilter = d;
                    fromDateFilter = null;
                    toDateFilter = null;
                    _applyFilters();
                  });
                },
                onClear: () {
                  setState(() {
                    exactDateFilter = null;
                    _applyFilters();
                  });
                },
              ),

              _dateTile(label: "From", date: fromDateFilter,
                onPick: (d) {
                  setState(() {
                    fromDateFilter = d;
                    exactDateFilter = null;
                    _applyFilters();
                  });
                },
                onClear: () {
                  setState(() {
                    fromDateFilter = null;
                    _applyFilters();
                  });
                },
              ),

              _dateTile(label: "To", date: toDateFilter,
                onPick: (d) {
                  setState(() {
                    toDateFilter = d;
                    exactDateFilter = null;
                    _applyFilters();
                  });
                },
                onClear: () {
                  setState(() {
                    toDateFilter = null;
                    _applyFilters();
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }





  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: textMuted,
        ),
      ),
    );
  }


  Widget _webBody(BuildContext context) {
    return Column(
      children: [
        _webTopBar(),
        Expanded(
          child: Row(
            children: [
              _InlineSideBar(
                collapsed: sidebarCollapsed,
                onAddScheduler: _addScheduler,
                onExportPdf: _exportPdf,
                filterSection: _sidebarFilterUI(),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _webDashboard(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _openAdvancedFilter() {
    final TextEditingController uinCtrl = TextEditingController();
    final TextEditingController typeCtrl = TextEditingController();

    DateTime? fromDate;
    DateTime? toDate;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setD) {
            return AlertDialog(
              title: const Text("Advanced Filter"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 🔎 UIN (EXACT)
                  TextField(
                    controller: uinCtrl,
                    decoration: const InputDecoration(
                      labelText: "UIN (Exact match)",
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 🧩 TYPE (EXACT)
                  TextField(
                    controller: typeCtrl,
                    decoration: const InputDecoration(
                      labelText: "Type (Exact match)",
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 📅 DATE RANGE
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: ctx,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (d != null) {
                              setD(() => fromDate = d);
                            }
                          },
                          child: Text(
                            fromDate == null
                                ? "From date"
                                : fromDate!.toString().split(' ')[0],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: ctx,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (d != null) {
                              setD(() => toDate = d);
                            }
                          },
                          child: Text(
                            toDate == null
                                ? "To date"
                                : toDate!.toString().split(' ')[0],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                // 🧹 CLEAR
                TextButton(
                  onPressed: () {
                    setState(() => filtered = List.from(tasks));
                    Navigator.pop(ctx);
                  },
                  child: const Text("Clear"),
                ),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    setState(() {
                      filtered = tasks.where((t) {
                        if (uinCtrl.text.isNotEmpty && t.uin != uinCtrl.text) return false;
                        if (typeCtrl.text.isNotEmpty && t.type != typeCtrl.text) return false;
                        if (fromDate != null && t.scheduledDate.isBefore(fromDate!)) return false;
                        if (toDate != null && t.scheduledDate.isAfter(toDate!)) return false;
                        return true;
                      }).toList();
                    });

                    Navigator.pop(ctx);
                  },
                  child: const Text("Apply"),
                ),


              ],
            );
          },
        );
      },
    );
  }

  Widget _greySearchBtn(VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      hoverColor: Colors.black.withOpacity(0.04),
      child: Container(
        height: 40,
        width: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFEDEDED), // slightly richer grey
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.search,
          size: 20,
          color: Color(0xFF424242), // darker for contrast
        ),
      ),
    );
  }




  Widget _webTopBar() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: surface,
        border: Border(bottom: BorderSide(color: border)),
      ),
      child: Row(
        children: [
          // ☰ MENU + TITLE (ALIGNED WITH SIDEBAR)
          SizedBox(
            width: sidebarCollapsed ? 72 : 240,
            child: Row(
              children: [
                Text(
                  "",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: textMain,
                  ),
                ),

                if (!sidebarCollapsed)
                  Text(
                    "Scheduler",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: textMain,
                    ),
                  ),
              ],
            ),
          ),

          const Spacer(),

          // 🔍 SEARCH FIELD (WEB)
          if (showSearch)
            SizedBox(
              width: 260,
              child: TextField(
                controller: searchCtrl,
                autofocus: true,
                onChanged: _searchTask,
                decoration: _outlinedInput(
                  hint: "Search scheduler...",
                  prefixIcon: Icon(Icons.search, color: textMuted),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        showSearch = false;
                        searchCtrl.clear();
                        filtered = List.from(tasks);
                      });
                    },
                  ),
                ),
              ),
            ),

          const SizedBox(width: 6),
          _greySearchBtn(() {
            setState(() => showSearch = !showSearch);
          }),



// ➕ ADD SCHEDULER (ICON ONLY)
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            color: textMain,
            tooltip: "Add Scheduler",
            onPressed: _addScheduler,
          ),

// 📄 EXPORT PDF (ICON ONLY)
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            color: textMain,
            tooltip: "Export PDF",
            onPressed: _exportPdf,
          ),


          // ☑️ SELECT ALL (TRI-STATE)
          Checkbox(
            tristate: true,
            value: isAllSelected
                ? true
                : isPartiallySelected
                ? null
                : false,
            onChanged: (val) {
              setState(() {
                if (val == true) {
                  selectionMode = true;
                  for (var t in filtered) {
                    t.selected = true;
                  }
                } else {
                  selectionMode = false;
                  for (var t in filtered) {
                    t.selected = false;
                  }
                }
              });
            },
          ),

          // 🗑 DELETE (ONLY WHEN SELECTED)
          if (hasSelection)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              color: Colors.red,
              onPressed: _bulkDelete,
            ),

          // 🔽 FILTER + BULK STATUS
          Builder(
            builder: (btnContext) {
              return IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: () {
                  final box =
                  btnContext.findRenderObject() as RenderBox;
                  (
                  context: context,
                  anchor: box,
                  );
                },
              );
            },
          ),

          const SizedBox(width: 12),

          const CircleAvatar(
            radius: 16,
            backgroundImage: NetworkImage("https://i.pravatar.cc/150"),
          ),
        ],
      ),
    );
  }

  Widget _webDashboard(BuildContext context) {
    return Column(
      children: [
        // 🔒 FIXED STATS (DO NOT SCROLL)
        Padding(
          padding: const EdgeInsets.all(16),
          child: _webStatsRow(),
        ),

        // 🔽 ONLY CARDS SCROLL
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _webGrid(context),
          ),
        ),
      ],
    );
  }

  Widget _webStatsRow() {
    return Row(
      children: [
        Expanded(child: _stat("Total Schedulers", tasks.length.toString())),
        const SizedBox(width: 12),
        Expanded(
          child: _stat(
            "Pending",
            tasks.where((t) => t.status == "Pending").length.toString(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _stat(
            "Approved",
            tasks.where((t) => t.status == "Approved").length.toString(),
          ),
        ),
        const SizedBox(width: 12),
        _csvCard(),
      ],
    );
  }


  Widget _stat(String title, String value) {
    return Container(
      height: 100,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: textMuted)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  void _uploadCsv() {
    Fluttertoast.showToast(msg: "CSV upload coming next");
  }

  Widget _csvCard() {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.black.withOpacity(0.12),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // 🔥 important
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            "Data Quality",
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: textMain,
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: 0,
            color: accent,
            backgroundColor: accent.withOpacity(0.2),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 34, // 🔥 control button height
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: _uploadCsv,
              child: const Text("Upload CSV"),
            ),
          ),
        ],
      ),
    );
  }



  Widget _webGrid(BuildContext context) {
    final double cardWidth =
        (MediaQuery.of(context).size.width - 300) / 2;

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: filtered.map((task) {
        return enableWebHero
            ? Hero(
          tag: task.heroTag,
          flightShuttleBuilder: _heroFlight,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _openHeroDetails(task),
              child: _webCard(task, cardWidth),
            ),
          ),
        )
            : _webCard(task, cardWidth);
      }).toList(),
    );
  }

  TextStyle _cardText({
    double size = 14,
    FontWeight weight = FontWeight.w500,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: 'Inter',
      fontSize: size,
      fontWeight: weight,
      letterSpacing: 0.3,
      color: color ?? textMain,
    );
  }

  TextStyle _cardTitleStyle() {
    return TextStyle(
      fontFamily: 'Inter',
      fontSize: 15,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.3,
      color: textMain,
    );
  }

  TextStyle _cardMetaStyle() {
    return TextStyle(
      fontFamily: 'Inter',
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.25,
      color: textMuted,
    );
  }

  Widget _paperStripIcon({
    required IconData icon,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 36,
        width: 36,
        decoration: BoxDecoration(
          color: active ? accent.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(
          icon,
          size: 20,
          color: active ? accent : Colors.black54,
        ),
      ),
    );
  }


  Widget _webCard(Task task, double width) {
    const double cardHeight = 190;

    final bool showInfo = task.panel == CardPanel.info;
    final bool showActions = task.panel == CardPanel.actions;
    final bool showOverlay = showInfo || showActions;

    final double actionWidth = width * 0.20; // 👈 1/4th tray

    return SizedBox(
      width: width,
      height: cardHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ================= BASE CARD =================
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 35,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      task.imageUrl,
                      fit: BoxFit.cover,
                      height: double.infinity,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 65,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _cardTitleStyle(),
                      ),
                      const SizedBox(height: 6),
                      Text("UIN: ${task.uin}", style: _cardMetaStyle()),
                      const SizedBox(height: 4),
                      Text("Type: ${task.type}", style: _cardMetaStyle()),
                      const SizedBox(height: 10),
                      _status(task.status, isWeb: true),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ================= OVERLAY =================
          AnimatedPositioned(
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeInOutCubic,
            right: showOverlay
                ? 0
                : -(showActions ? actionWidth : width),
            top: 0,
            bottom: 0,
            width: showActions ? actionWidth : width,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: showOverlay ? 1 : 0,
              child: IgnorePointer(
                ignoring: !showOverlay,
                child: showInfo
                    ? _InfoOverlayCard(
                  task: task,
                  onClose: () =>
                      setState(() => task.panel = CardPanel.none),
                )
                    : _ActionsOverlayCard(
                  onClose: () =>
                      setState(() => task.panel = CardPanel.none),
                  actions: _ActionPanelContent(
                    active: showActions, //
                    onView: () => _viewTask(task),
                    onEdit: () => _editTask(task),
                    onChangeStatus: () => _changeStatus(task),
                    onDelete: () => _deleteTask(task),
                  ),
                ),
              ),
            ),
          ),

          // ================= PAPER STRIP =================
          Positioned(
            right: 10,
            top: (cardHeight - 72) / 2,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: showOverlay ? 0 : 1, // hide when panel open
              child: IgnorePointer(
                ignoring: showOverlay,
                child: Container(
                  width: 44,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _paperStripIcon(
                        icon: Icons.info_outline,
                        active: showInfo,
                        onTap: () {
                          setState(() {
                            for (final t in tasks) {
                              t.panel = CardPanel.none;
                            }
                            task.panel =
                            showInfo ? CardPanel.none : CardPanel.info;
                          });
                        },
                      ),
                      const SizedBox(height: 6),
                      _paperStripIcon(
                        icon: Icons.chevron_left,
                        active: showActions,
                        onTap: () {
                          setState(() {
                            for (final t in tasks) {
                              t.panel = CardPanel.none;
                            }
                            task.panel =
                            showActions ? CardPanel.none : CardPanel.actions;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _bulkDelete() async {
    final selected = tasks.where((t) => t.selected).toList();
    if (selected.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete selected"),
        content: Text("Delete ${selected.length} scheduler(s)?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "Delete",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      tasks.removeWhere((t) => t.selected);
      filtered.removeWhere((t) => t.selected);
      selectionMode = false;
    });

    Fluttertoast.showToast(msg: "Selected schedulers deleted");
  }

  void _bulkChangeStatus(String status) {
    final selected = tasks.where((t) => t.selected).toList();
    if (selected.isEmpty) return;

    setState(() {
      for (var t in selected) {
        t.status = status;
      }
      selectionMode = false;
    });

    Fluttertoast.showToast(msg: "Status changed to $status");
  }


  /// ===================== CARD 3-DOT FOLD MENU =====================

  /// ===================== TOP BAR FILTER FOLD MENU =====================

  /// ===================== CLOSE ANY OPEN FOLD MENU ====================

  void _openFilter() {
    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Filter Tasks"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _filterTile("All", dialogContext),
              _filterTile("Pending", dialogContext),
              _filterTile("Approved", dialogContext),
              _filterTile("Rejected", dialogContext),
            ],
          ),
        );
      },
    );
  }

  Widget _filterTile(String status, BuildContext dialogContext) {
    return ListTile(
      title: Text(status),
      onTap: () {
        Navigator.pop(dialogContext);

        setState(() {
          filtered = status == "All"
              ? tasks
              : tasks.where(
                (t) => t.status.toLowerCase() == status.toLowerCase(),
          ).toList();
        });
      },
    );
  }

  Widget _checkTile({
    required String label,
    required bool value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Checkbox(
              value: value,
              visualDensity: VisualDensity.compact,
              onChanged: (_) => onTap(),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: value ? textMain : textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _checkStatus(String value) => _checkTile(
    label: value,
    value: statusFilter.contains(value),
    onTap: () {
      setState(() {
        statusFilter.contains(value)
            ? statusFilter.remove(value)
            : statusFilter.add(value);
        _applyFilters();
      });
    },
  );

  Widget _checkType(String value) => _checkTile(
    label: value,
    value: typeFilter.contains(value),
    onTap: () {
      setState(() {
        typeFilter.contains(value)
            ? typeFilter.remove(value)
            : typeFilter.add(value);
        _applyFilters();
      });
    },
  );

  Widget _checkUser(String value) => _checkTile(
    label: value,
    value: userFilter.contains(value),
    onTap: () {
      setState(() {
        userFilter.contains(value)
            ? userFilter.remove(value)
            : userFilter.add(value);
        _applyFilters();
      });
    },
  );


  void _addScheduler() {
    final TextEditingController nameCtrl = TextEditingController();
    final TextEditingController uinCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              elevation: 14,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: Text(
                "Add Scheduler",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textMain,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 🏷 ASSET NAME
                  TextField(
                    controller: nameCtrl,
                    decoration: _outlinedInput(hint: "Asset Name"),
                  ),
                  const SizedBox(height: 12),

                  // 🔢 UIN
                  TextField(
                    controller: uinCtrl,
                    decoration: _outlinedInput(hint: "UIN"),
                  ),
                  const SizedBox(height: 14),

                  // 📅 DATE PICKER
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(
                      selectedDate.toString().split(' ')[0],
                      style: TextStyle(color: accent),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: accent),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: ColorScheme.light(
                                primary: accent,
                                onPrimary: Colors.white,
                                surface: Colors.white,
                                onSurface: textMain,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setDialogState(() => selectedDate = picked);
                      }
                    },
                  ),
                ],
              ),
              actionsPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    "Cancel",
                    style: TextStyle(color: textMuted),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty ||
                        uinCtrl.text.trim().isEmpty) {
                      Fluttertoast.showToast(
                        msg: "Asset name & UIN are required",
                      );
                      return;
                    }

                    Navigator.of(dialogContext).pop();

                    if (isDemoMode) {
                      final newTask = Task(
                        id: DateTime.now()
                            .millisecondsSinceEpoch
                            .toString(),
                        name: nameCtrl.text.trim(),
                        uin: uinCtrl.text.trim(),
                        type: "Demo",
                        scheduledDate: selectedDate,
                        assignedUser: "Demo User",
                        imageUrl: "https://picsum.photos/200?demo",
                        status: "Pending",
                      );

                      setState(() {
                        tasks.insert(0, newTask);
                        filtered.insert(0, newTask);
                      });

                      Fluttertoast.showToast(
                        msg: "Scheduler added (Demo)",
                      );
                    } else {
                      final res = await _api.makePostRequest(
                        "https://uatapi.arresto.in/api/client/1825/tasks",
                        jsonEncode({
                          "meta_data": {
                            "component_name": nameCtrl.text.trim(),
                          },
                          "field_value": uinCtrl.text.trim(),
                          "schedule_date":
                          selectedDate.toIso8601String(),
                        }),
                      );

                      final decoded = jsonDecode(res.body);
                      final newTask = Task.fromJson(decoded['data']);

                      setState(() {
                        tasks.insert(0, newTask);
                        filtered.insert(0, newTask);
                      });

                      Fluttertoast.showToast(
                        msg: "Scheduler added",
                      );
                    }
                  },
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// ===================== TOP BAR =====================

  Widget _topBar() {
    final selectedCount = tasks.where((t) => t.selected).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: surface,
        border: Border(bottom: BorderSide(color: border)),
      ),
      child: Row(
        children: [
          /// 🏷 TITLE
          Text(
            selectionMode ? "$selectedCount selected" : "Scheduler",
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: textMain,
              fontWeight: FontWeight.w600,
            ),
          ),

          const Spacer(),

          /// 🔍 INLINE SEARCH FIELD
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: showSearch
                ? Container(
              key: const ValueKey("search"),
              width: 260,
              margin: const EdgeInsets.only(right: 8),
              child: TextField(
                controller: searchCtrl,
                autofocus: true,
                onChanged: _searchTask,
                decoration: InputDecoration(
                  hintText: "Search scheduler...",
                  isDense: true,
                  prefixIcon:
                  Icon(Icons.search, color: textMuted),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        showSearch = false;
                        searchCtrl.clear();
                        filtered = List.from(tasks);
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            )
                : const SizedBox.shrink(),
          ),

          /// 🔍 SEARCH ICON
          _iconBtn(
            Icons.search,
                () {
              setState(() => showSearch = true);
            },
            iconColor: textMuted,
            bgColor: Colors.transparent,
          ),
          const SizedBox(width: 8),

          /// ☑ SELECT ALL
          _selectAllBtn(),
          const SizedBox(width: 8),

          /// ➕ ADD
          _iconBtn(
            Icons.add,
            _addScheduler,
            iconColor: Colors.white,
            bgColor: Colors.grey.shade700,
          ),
          const SizedBox(width: 8),

          /// 🔽 FILTER
          _iconBtn(
            Icons.filter_list,
            _openFilter,
            iconColor: Colors.white,
            bgColor: Colors.grey.shade700,
          ),
          const SizedBox(width: 8),

          /// 📄 EXPORT
          _iconBtn(
            Icons.picture_as_pdf,
            _exportPdf,
            iconColor: Colors.white,
            bgColor: Colors.grey.shade700,
          ),

          /// 🗑 DELETE (ONLY WHEN SELECTED)
          if (selectionMode && hasSelection) ...[
            const SizedBox(width: 8),
            _iconBtn(
              Icons.delete,
              _deleteSelected,
              iconColor: Colors.red,
              bgColor: Colors.red.withOpacity(0.12),
            ),
          ],

          /// ❌ EXIT SELECTION
          if (selectionMode)
            IconButton(
              icon: const Icon(Icons.close),
              color: textMain,
              onPressed: _exitSelectionMode,
            ),
        ],
      ),
    );
  }



  void _exitSelectionMode() {
    setState(() {
      selectionMode = false;
      for (var t in tasks) {
        t.selected = false;
      }
    });
  }


  Future<void> _deleteSelected() async {
    final selectedTasks = tasks.where((t) => t.selected).toList();

    if (selectedTasks.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Delete Selected"),
        content: Text(
          "Delete ${selectedTasks.length} selected scheduler(s)?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              "Delete",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    for (var task in selectedTasks) {
      if (!isDemoMode) {
        await _api.makeDeleteRequest(
          "https://uatapi.arresto.in/api/client/1825/tasks/${task.id}",
        );
      }
    }

    setState(() {
      tasks.removeWhere((t) => t.selected);
      filtered.removeWhere((t) => t.selected);
    });

    Fluttertoast.showToast(msg: "Selected schedulers deleted");
  }



  Widget _iconBtn(
      IconData icon,
      VoidCallback onTap, {
        Color? iconColor,
        Color? bgColor,
      }) {
    return InkWell(
      hoverColor: accent.withOpacity(0.04),
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 38,
        width: 38,
        decoration: BoxDecoration(
          color: bgColor ?? Colors.grey.shade700,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: iconColor ?? Colors.white,
          size: 18,
        ),
      ),
    );
  }


  Widget _selectAllBtn() {
    IconData icon;

    if (isAllSelected) {
      icon = Icons.check_box;
    } else if (isPartiallySelected) {
      icon = Icons.indeterminate_check_box;
    } else {
      icon = Icons.check_box_outline_blank;
    }

    return InkWell(
      onTap: () {
        setState(() {
          selectionMode = true;
          final selectAll = !isAllSelected;
          for (var t in filtered) {
            t.selected = selectAll;
          }
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 38,
        width: 38,
        decoration: BoxDecoration(
          color: Colors.grey.shade700,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }




  Widget _inlineDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              "$label:",
              style: _cardMetaStyle().copyWith(
                fontSize: 11,
                color: textMain,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? "-" : value,
              style: _cardText(
                size: 11,
                color: textMain,
              ),
            ),
          ),
        ],
      ),
    );
  }


  /// ===================== WEB ROW =====================


  /// ===================== MOBILE ROW =====================

  Widget _heroFlight(
      BuildContext context,
      Animation<double> animation,
      HeroFlightDirection direction,
      BuildContext from,
      BuildContext to,
      ) {
    return ScaleTransition(
      scale: CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOutCubic,
      ),
      child: to.widget,
    );
  }

  void _openHeroDetails(Task task) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withOpacity(0.45),
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (_, __, ___) {
          return _HeroTaskPopup(task: task);
        },
      ),
    );
  }



  Widget _mobileRow(Task task) {
    const double cardHeight = 190;
    const double actionWidth = 72;

    final bool showActions = task.panel == CardPanel.actions;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: SizedBox(
        height: cardHeight,
        child: Stack(
          children: [
            // ================= SWIPE BASE CARD =================
            Dismissible(
              key: ValueKey(task.id),
              direction: DismissDirection.horizontal,
              background: _swipeBg(
                color: Colors.green,
                icon: Icons.check,
                alignLeft: true,
              ),
              secondaryBackground: _swipeBg(
                color: Colors.red,
                icon: Icons.close,
                alignLeft: false,
              ),
              confirmDismiss: (direction) async {
                if (direction == DismissDirection.startToEnd) {
                  setState(() => task.status = "Approved");
                  Fluttertoast.showToast(msg: "Approved");
                } else {
                  setState(() => task.status = "Rejected");
                  Fluttertoast.showToast(msg: "Rejected");
                }
                return false; // ❌ keep card
              },
              child: Hero(
                tag: task.heroTag,
                flightShuttleBuilder: _heroFlight, // 👈 reuse same animation
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () {
                      // ❌ do NOT open hero if action panel is open
                      if (task.panel != CardPanel.none) return;

                      _openHeroDetails(task); // 👈 SAME as web
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // IMAGE
                          Expanded(
                            flex: 35,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.network(
                                task.imageUrl,
                                fit: BoxFit.cover,
                                height: double.infinity,
                              ),
                            ),
                          ),

                          const SizedBox(width: 14),

                          // CONTENT
                          Expanded(
                            flex: 65,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  task.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: _cardTitleStyle(),
                                ),
                                const SizedBox(height: 6),
                                Text("UIN: ${task.uin}", style: _cardMetaStyle()),
                                const SizedBox(height: 4),
                                Text("Type: ${task.type}", style: _cardMetaStyle()),
                                const Spacer(),
                                _status(task.status, isWeb: false),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ================= ARROW TRIGGER =================
            Positioned(
              right: 8,
              top: (cardHeight - 36) / 2,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    for (final t in tasks) {
                      t.panel = CardPanel.none;
                    }
                    task.panel = CardPanel.actions;
                  });
                },
                child: Container(
                  height: 36,
                  width: 36,
                  decoration: BoxDecoration(
                    color: surface,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.chevron_left,
                    size: 20,
                    color: Colors.black54,
                  ),
                ),
              ),
            ),

            // ================= ACTION OVERLAY =================
            AnimatedPositioned(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeInOutCubic,
              right: showActions ? 0 : -actionWidth,
              top: 0,
              bottom: 0,
              width: actionWidth,
              child: IgnorePointer(
                ignoring: !showActions,
                child: _ActionsOverlayCard(
                  onClose: () {
                    setState(() => task.panel = CardPanel.none);
                  },
                  actions: _MobileActionsColumn(
                    onView: () => _viewTask(task),
                    onEdit: () => _editTask(task),
                    onChangeStatus: () {
                      _changeStatus(task); // 👈 reuse your existing dialog
                    },
                    onDelete: () => _deleteTask(task),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ===================== HELPERS =====================

  Widget _status(String status, {required bool isWeb}) {
    // ❌ hide "Pending" text label on WEB
    if (isWeb && status.toLowerCase() == "pending") {
      return const SizedBox.shrink();
    }

    final color = status == "Approved"
        ? success
        : status == "Rejected"
        ? danger
        : warning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

/// ===================== ACTIONS =====================

}


// ===================== DUMMY DATA (LOCAL) =====================
List<Task> mockTasks() {
  return [
    Task(
      id: "D1",
      name: "Fire Extinguisher",
      uin: "UIN-001",
      type: "Safety",
      scheduledDate: DateTime.now().add(const Duration(days: 2)),
      assignedUser: "Rahul Sharma",
      imageUrl: "https://picsum.photos/200?1",
      status: "Pending",
    ),
    Task(
      id: "D2",
      name: "Lifting Hook",
      uin: "UIN-002",
      type: "Mechanical",
      scheduledDate: DateTime.now().add(const Duration(days: 5)),
      assignedUser: "Ankit Verma",
      imageUrl: "https://picsum.photos/200?2",
      status: "Approved",
    ),
    Task(
      id: "D3",
      name: "Safety Helmet",
      uin: "UIN-003",
      type: "PPE",
      scheduledDate: DateTime.now().add(const Duration(days: 1)),
      assignedUser: "Priya Singh",
      imageUrl: "https://picsum.photos/200?3",
      status: "Rejected",
    ),
  ];
}

class _InlineSideBar extends StatelessWidget {
  final bool collapsed;
  final VoidCallback onAddScheduler;
  final VoidCallback onExportPdf;
  final Widget filterSection;

  const _InlineSideBar({
    required this.collapsed,
    required this.onAddScheduler,
    required this.onExportPdf,
    required this.filterSection,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: collapsed ? 72 : 240,
      decoration: BoxDecoration(
        color: surface, // 🔥 THIS LINE
        border: Border(right: BorderSide(color: border)),
      ),
      child: Column(
        children: [
          /// 🔹 TOP SPACER
          const SizedBox(height: 2),

          /// 🔹 CENTERED MENU
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  filterSection,

                  const SizedBox(height: 20),
                  Divider(color: border),

                  const SizedBox(height: 12),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 🧠 SINGLE MENU ITEM (PILL STYLE)

}
class _ActionsOverlayCard extends StatelessWidget {
  final VoidCallback onClose;
  final Widget actions;

  const _ActionsOverlayCard({
    required this.onClose,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),

          /// ❌ CLOSE BUTTON (TOP)
          Align(
            alignment: Alignment.topLeft,
            child: IconButton(
              icon: const Icon(Icons.close, size: 16),
              padding: const EdgeInsets.only(left: 10),
              constraints: const BoxConstraints(),
              onPressed: onClose,
            ),
          ),

          const SizedBox(height: 6),

          /// ✅ ACTIONS WITH PROPER LEFT/RIGHT MARGIN
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Center(child: actions),
            ),
          ),

          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
class _DelayedFade extends StatefulWidget {
  final Widget child;
  final int delay;

  const _DelayedFade({
    required this.child,
    required this.delay,
  });

  @override
  State<_DelayedFade> createState() => _DelayedFadeState();
}
class _DelayedFadeState extends State<_DelayedFade> {
  bool _show = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) setState(() => _show = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 260),
      opacity: _show ? 1 : 0,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 260),
        scale: _show ? 1 : 0.92,
        child: widget.child,
      ),
    );
  }
}
class _HeroTaskPopup extends StatelessWidget {
  final Task task;

  const _HeroTaskPopup({required this.task});

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;

    // 📏 NARROWER – LIKE CARD WIDTH
    final double popupWidth =
    size.width.clamp(300, 360).toDouble();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.pop(context),
      child: Stack(
        children: [
          /// 🌫 BLUR BACKDROP
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: Colors.black.withOpacity(0.35),
            ),
          ),

          /// 🎯 CENTER CARD
          Center(
            child: Hero(
              tag: task.heroTag,
              child: Material(
                color: Colors.transparent,
                child: AnimatedScale(
                  scale: 1,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  child: Container(
                    width: popupWidth,
                    constraints: BoxConstraints(
                      maxHeight: size.height * 0.8, // 🔥 prevents overflow
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F8FA), // ✅ NEW COLOR
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 30,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        /// 🖼 IMAGE (TOP)
                        SizedBox(
                          height: 200,
                          width: double.infinity,
                          child: Image.network(
                            task.imageUrl,
                            fit: BoxFit.cover,
                          ),
                        ),

                        /// 📄 DETAILS (SCROLLABLE – NO OVERFLOW)
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Task Details",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),

                                const SizedBox(height: 14),

                                _row("Asset Name", task.name),
                                _row("UIN", task.uin),
                                _row("Type", task.type),
                                _row("Status", task.status),

                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Divider(height: 1),
                                ),

                                _row("Assigned To", task.assignedUser),
                                _row(
                                  "Created On",
                                  task.scheduledDate
                                      .toString()
                                      .split(' ')[0],
                                ),
                                _row(
                                  "Due Date",
                                  task.scheduledDate
                                      .toString()
                                      .split(' ')[0],
                                ),
                                _row("Task ID", task.id),

                                const SizedBox(height: 16),

                                /// CLOSE BUTTON
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context),
                                    child: const Text("Close"),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(
              "$label:",
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? "-" : value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
class _InfoOverlayCard extends StatelessWidget {
  final Task task;
  final VoidCallback onClose;

  const _InfoOverlayCard({
    required this.task,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          // ================= HEADER =================
          Row(
            children: [
              const Icon(Icons.info_outline, size: 18),
              const SizedBox(width: 8),
              const Text(
                "Task Details",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                splashRadius: 18,
                onPressed: onClose,
              ),
            ],
          ),

          const Divider(height: 16),

          // ================= BODY =================
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // IMAGE (same size as base card)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    task.imageUrl,
                    width: 140,
                    height: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),

                const SizedBox(width: 14),

                // DETAILS
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        _infoRow("Asset", task.name),
                        _infoRow("UIN", task.uin),
                        _infoRow("Type", task.type),
                        _infoRow("Status", task.status),

                        const SizedBox(height: 10),
                        const Divider(),

                        _infoRow("Assigned To", task.assignedUser),
                        _infoRow(
                          "Created On",
                          task.scheduledDate.toString().split(' ')[0],
                        ),
                        _infoRow(
                          "Due Date",
                          task.scheduledDate.toString().split(' ')[0],
                        ),
                        _infoRow("Task ID", task.id),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? "-" : value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
class _ActionPanelContent extends StatelessWidget {
  final bool active; // 👈 add this
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onChangeStatus;
  final VoidCallback onDelete;

  const _ActionPanelContent({
    required this.active,
    required this.onView,
    required this.onEdit,
    required this.onChangeStatus,
    required this.onDelete,
  });


  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _icon(Icons.visibility, onView),
        const SizedBox(height: 6),
        _icon(Icons.edit, onEdit),
        const SizedBox(height: 6),
        _icon(Icons.sync_alt, onChangeStatus),
        const SizedBox(height: 6),
        _icon(Icons.delete, onDelete, color: Colors.red),
      ],
    );
  }
  Widget _icon(
      IconData icon,
      VoidCallback onTap, {
        Color? color,
      }) {
    final bool isActive = active;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 32,
        width: 32,
        decoration: BoxDecoration(
          color: isActive
              ? (color ?? accent) // ✅ STAYS COLORED
              : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 16,
          color: isActive
              ? Colors.white
              : (color ?? Colors.black54),
        ),
      ),
    );
  }
}
class _MobileActionsColumn extends StatelessWidget {
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onChangeStatus;
  final VoidCallback onDelete;

  const _MobileActionsColumn({
    required this.onView,
    required this.onEdit,
    required this.onChangeStatus,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _icon(Icons.visibility, onView),
        const SizedBox(height: 8),

        _icon(Icons.edit, onEdit),
        const SizedBox(height: 8),

        // 🔁 CHANGE STATUS (APPROVE / REJECT)
        _icon(Icons.swap_horiz, onChangeStatus),
        const SizedBox(height: 8),

        _icon(Icons.delete, onDelete, color: Colors.red),
      ],
    );
  }

  Widget _icon(IconData icon, VoidCallback onTap, {Color? color}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 30,
        width: 30,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 16,
          color: color ?? Colors.black54,
        ),
      ),
    );
  }
}
