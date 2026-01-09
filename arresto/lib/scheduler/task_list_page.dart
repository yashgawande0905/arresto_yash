import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:arresto/networks/ApisRequests.dart';
import 'package:fluttertoast/fluttertoast.dart' show Fluttertoast;




// ===================== THEME =====================
const Color pageBg   = Color(0xFFFBF3D1); // page + appbar stays same
const Color headerBg = Color(0xFFFBF3D1);
const Color surface  = Color(0xFFFFDAB3); // ✅ CARD COLOR (NEW)
const Color border   = Color(0xFFE2B98F);
const Color textMain = Color(0xFF3B2A1A);
const Color textMuted= Color(0xFF6B4E3A);


class Task {
  final String id;
  final String name;
  final String uin;
  final String type;
  DateTime scheduledDate;
  final String assignedUser;
  final String imageUrl;
  String status;

  bool selected; // ✅ NEW

  Task({
    required this.id,
    required this.name,
    required this.uin,
    required this.type,
    required this.scheduledDate,
    required this.assignedUser,
    required this.imageUrl,
    this.status = "pending",
    this.selected = false, // ✅ default
  });

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
      imageUrl: json['meta_data']?['component_imagepath']
          ?? 'https://picsum.photos/200',
      status: json['status'] ?? 'pending',
      selected: false, // ✅ IMPORTANT
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
  final TextEditingController _search = TextEditingController();

  bool isDemoMode = true;
// 🔥 true = dummy cards
// 🔥 false = real API

  bool showSearch = false;
  final TextEditingController searchCtrl = TextEditingController();


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

                const Divider(),

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
    final isWeb = MediaQuery
        .of(context)
        .size
        .width > 900;

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: headerBg,
        elevation: 0,
      ),
      body: Column(
        children: [
          _topBar(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
              padding: const EdgeInsets.only(top: 8),
              itemCount: filtered.length,
              itemBuilder: (_, i) =>
              isWeb ? _webRow(filtered[i]) : _mobileRow(filtered[i]),
            ),
          ),
        ],
      ),

    );
  }

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

  void _addScheduler() {
    final TextEditingController nameCtrl = TextEditingController();
    final TextEditingController uinCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Add Scheduler"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: "Asset Name",
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: uinCtrl,
                    decoration: const InputDecoration(
                      labelText: "UIN",
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 📅 Date picker
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      selectedDate.toString().split(' ')[0],
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          selectedDate = picked;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  child: const Text("Save"),
            onPressed: () async {
            if (nameCtrl.text.isEmpty || uinCtrl.text.isEmpty) {
            Fluttertoast.showToast(msg: "Asset name & UIN are required");
            return;
            }

            Navigator.of(dialogContext).pop();

            if (isDemoMode) {
            // 🧪 DEMO ADD
            final newTask = Task(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: nameCtrl.text,
            uin: uinCtrl.text,
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

            Fluttertoast.showToast(msg: "Scheduler added (Demo)");
            } else {
            // 🌐 REAL API ADD
            final res = await _api.makePostRequest(
            "https://uatapi.arresto.in/api/client/1825/tasks",
            jsonEncode({
            "meta_data": {
            "component_name": nameCtrl.text,
            },
            "field_value": uinCtrl.text,
            "schedule_date": selectedDate.toIso8601String(),
            }),
            );

            final decoded = jsonDecode(res.body);
            final newTask = Task.fromJson(decoded['data']);

            setState(() {
            tasks.insert(0, newTask);
            filtered.insert(0, newTask);
            });

            Fluttertoast.showToast(msg: "Scheduler added");
            }
            },
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
        color: headerBg,
        border: Border(bottom: BorderSide(color: border)),
      ),
      child: Row(
        children: [

          /// 🔍 TITLE OR SEARCH FIELD (INLINE)
          Text(
            selectionMode ? "$selectedCount selected" : "Scheduler",
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: textMain,
              fontWeight: FontWeight.w600,
            ),
          ),

          const Spacer(),

// 🔍 INLINE SEARCH FIELD (RIGHT SIDE)
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
                  prefixIcon: const Icon(Icons.search),
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
          _iconBtn(Icons.search, () {
            setState(() => showSearch = true);
          }),
          const SizedBox(width: 8),

          _selectAllBtn(),
          const SizedBox(width: 8),

          _iconBtn(Icons.add, _addScheduler),
          const SizedBox(width: 8),

          _iconBtn(Icons.filter_list, _openFilter),
          const SizedBox(width: 8),

          _iconBtn(Icons.picture_as_pdf, _exportPdf),

          if (selectionMode && hasSelection) ...[
            const SizedBox(width: 8),
            _iconBtn(Icons.delete, _deleteSelected),
          ],

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



  Widget _iconBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
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




  /// ===================== TABLE HEADER =====================

  /// ===================== WEB ROW =====================
  Widget _webRow(Task task) {
    return InkWell(
      onLongPress: kIsWeb ? null : () {
        setState(() {
          selectionMode = true;
          task.selected = true;
        });
      },

      onTap: () {
        if (selectionMode) {
          setState(() {
            task.selected = !task.selected;
            if (!hasSelection) selectionMode = false;
          });
        } else {
          _viewTask(task);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            // 🖼 IMAGE + CHECKBOX OVERLAY
            Stack(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: border),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      task.imageUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

                // ✅ Checkbox (web-style overlay)
                Positioned(
                  top: 4,
                  left: 4,
                  child: AnimatedOpacity(
                    opacity: selectionMode ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                      ),
                      child: Checkbox(
                        value: task.selected,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onChanged: (val) {
                          setState(() {
                            selectionMode = true;   // ⭐ ENTER SELECTION MODE
                            task.selected = val ?? false;
                          });
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),


            const SizedBox(width: 16),

// ✅ NEW CLEAN CARD CONTENT
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🏷 Asset Name
                  Text(
                    task.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textMain,
                    ),
                  ),

                  const SizedBox(height: 4),

                  // 🔢 UIN
                  Text(
                    "UIN: ${task.uin}",
                    style: TextStyle(
                      fontSize: 12.5,
                      color: textMuted,
                    ),
                  ),

                  const SizedBox(height: 4),

                  // 🧩 TYPE
                  Text(
                    "Type: ${task.type}",
                    style: TextStyle(
                      fontSize: 12,
                      color: textMuted,
                    ),
                  ),
                ],
              ),
            ),

            _status(task.status, isWeb: true),
            const SizedBox(width: 12),
            _actions(task),
          ],
        ),
      ),
    );
  }




  /// ===================== MOBILE ROW =====================
  Widget _mobileRow(Task task) {
    return Dismissible(
      key: ValueKey(task.id),

      // 👉 LEFT = APPROVE, RIGHT = DELETE
      direction: DismissDirection.horizontal,

      // 🟢 Swipe RIGHT → APPROVE
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        decoration: BoxDecoration(
          color: Colors.green.shade600,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.check, color: Colors.white, size: 28),
      ),

      // 🔴 Swipe LEFT → DELETE
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade600,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: Colors.white, size: 28),
      ),

      // ❗ Decide what happens
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // ✅ APPROVE
          if (task.status != "Approved") {
            setState(() {
              task.status = "Approved";
            });

            if (!isDemoMode) {
              await _api.makePutRequest(
                "https://uatapi.arresto.in/api/client/1825/tasks/${task.id}/status",
                jsonEncode({"status": "Approved"}),
              );
            }

            Fluttertoast.showToast(msg: "Task approved");
          }
          return false; // ❌ Don't remove card
        }

        if (direction == DismissDirection.endToStart) {
          // ❌ DELETE CONFIRMATION
          return await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("Delete Task"),
              content: const Text("Are you sure you want to delete this task?"),
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
        }

        return false;
      },

      // 🗑 FINAL DELETE
      onDismissed: (_) {
        setState(() {
          tasks.remove(task);
          filtered.remove(task);
        });

        Fluttertoast.showToast(msg: "Task deleted");
      },

      child: InkWell(
        onLongPress: () {
          setState(() {
            selectionMode = true;
            task.selected = true;
          });
        },
        onTap: () {
          if (selectionMode) {
            setState(() {
              task.selected = !task.selected;
              if (!hasSelection) selectionMode = false;
            });
          } else {
            _viewTask(task);
          }
        },

        // 👇 YOUR EXISTING CARD UI (UNCHANGED)
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: border),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(task.imageUrl, fit: BoxFit.cover),
                        ),
                      ),

                      if (selectionMode)
                        Positioned(
                          top: 4,
                          left: 4,
                          child: Checkbox(
                            value: task.selected,
                            visualDensity: VisualDensity.compact,
                            onChanged: (val) {
                              setState(() {
                                selectionMode = true;
                                task.selected = val ?? false;
                              });
                            },
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: textMain,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "UIN: ${task.uin}",
                          style: TextStyle(fontSize: 12, color: textMuted),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Type: ${task.type}",
                          style: TextStyle(fontSize: 12, color: textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _status(task.status, isWeb: false),
                  _actions(task),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }



  /// ===================== HELPERS =====================
  Widget _image(String url, {double size = 48}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(url, fit: BoxFit.cover),
      ),
    );
  }

  Widget _cell(String text, int flex) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 14, color: textMain),
      ),
    );
  }

  Widget _status(String status, {required bool isWeb}) {
    // ❌ hide "Pending" text label on WEB
    if (isWeb && status.toLowerCase() == "pending") {
      return const SizedBox.shrink();
    }

    final color = status == "Approved"
        ? Colors.green
        : status == "Rejected"
        ? Colors.red
        : Colors.orange;

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
  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case "approved":
        return Icons.check_circle;
      case "rejected":
        return Icons.cancel;
      case "pending":
      default:
        return Icons.hourglass_bottom;
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case "approved":
        return Colors.green;
      case "rejected":
        return Colors.red;
      case "pending":
      default:
        return Colors.orange;
    }
  }

  Widget _actions(Task task) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 🔁 STATUS ICON (dynamic)
        Tooltip(
          message: "Change status",
          child: IconButton(
            icon: Icon(_statusIcon(task.status)),
            color: _statusColor(task.status),
            onPressed: task.status == "Approved"
                ? null // ❌ disable when approved
                : () => _changeStatus(task),
          ),
        ),

        // 👁 View
        IconButton(
          icon: const Icon(Icons.visibility_outlined),
          color: Colors.blue,
          onPressed: () => _viewTask(task),
        ),

        // ✏️ Edit
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          color: Colors.green,
          onPressed: () => _editTask(task),
        ),

        // 🗑 Delete
        IconButton(
          icon: const Icon(Icons.delete_outline),
          color: Colors.red,
          onPressed: () => _deleteTask(task),
        ),
      ],
    );
  }

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
