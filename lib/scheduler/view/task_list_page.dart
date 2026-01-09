import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:arresto/networks/ApisRequests.dart';
import 'package:fluttertoast/fluttertoast.dart' show Fluttertoast;

class Task {
  final String id;
  final String name;
  final String uin;
  final String type;
  DateTime scheduledDate;
  final String assignedUser;
  final String imageUrl;
  String status;

  Task({
    required this.id,
    required this.name,
    required this.uin,
    required this.type,
    required this.scheduledDate,
    required this.assignedUser,
    required this.imageUrl,
    this.status = "pending",
  });


  factory Task.fromJson(Map<String, dynamic> json) {
    // 🔹 MongoDB date parsing
    DateTime scheduledDate = DateTime.now();
    if (json['schedule_date'] != null &&
        json['schedule_date']['\$date'] != null &&
        json['schedule_date']['\$date']['\$numberLong'] != null) {
      scheduledDate = DateTime.fromMillisecondsSinceEpoch(
        int.parse(json['schedule_date']['\$date']['\$numberLong']),
      );
    }

    return Task(
      id: json['_id'].toString(),
      name: json['meta_data']?['component_name'] ?? 'Unknown Asset',
      uin: json['field_value'] ?? '',
      type: json['type'] ?? '',
      scheduledDate: scheduledDate,
      assignedUser: json['assigned_user']?['name'] ?? 'Unassigned',
      imageUrl: json['meta_data']?['component_imagepath'] ??
          'https://picsum.photos/id/237/200/300',
      status: json['status'] ?? 'pending',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "status": status,
      "scheduled_date": scheduledDate.toIso8601String(),
    };
  }
}

class TaskListPage extends StatefulWidget {
  const TaskListPage({super.key});

  @override
  State<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends State<TaskListPage> {

  final ApisRequests _api = ApisRequests();
  List<Task> tasks = [];
  List<Task> _filteredTasks = [];
  bool _loading = true;
  final PageController _pageController = PageController();
  int _currentPage = 0;

  String _selectedFilter = "UIN";
  final TextEditingController _filterController = TextEditingController();
  DateTime? _fromDate;
  DateTime? _toDate;
  final TextEditingController _searchController = TextEditingController();
  bool _isExactDate = true;

  @override
  void initState() {
    super.initState();
    _loadTasksFromApi();
  }

  Future<void> _loadTasksFromApi() async {
    try {
      final response = await _api.makeGetRequest(
        "https://uatapi.arresto.in/api/client/1825/tasks",
      );

      debugPrint("STATUS => ${response.statusCode}");
      debugPrint("BODY => ${response.body}");

      if (response.statusCode != 200) {
        throw Exception("HTTP ${response.statusCode}");
      }

      final decoded = jsonDecode(response.body);

      // 🔒 SAFE PARSING
      if (decoded is Map && decoded.containsKey('data')) {
        final List list = decoded['data'];

        setState(() {
          tasks = list.map((e) => Task.fromJson(e)).toList();
          _filteredTasks = tasks;
          _loading = false;
        });
      } else {
        throw Exception("Invalid response format");
      }
    } catch (e) {
      _loading = false;
      Fluttertoast.showToast(msg: "Failed to load tasks");
      debugPrint("TASK LOAD ERROR => $e");
    }
  }



  void _onSearch(String query) {
    setState(() {
      _currentPage = 0;
      _filteredTasks = tasks.where((task) {
        return task.name.toLowerCase().contains(query.toLowerCase()) ||
            task.uin.toLowerCase().contains(query.toLowerCase()) ||
            task.type.toLowerCase().contains(query.toLowerCase()) ||
            task.assignedUser.toLowerCase().contains(query.toLowerCase());
      }).toList();
    });
    _pageController.jumpToPage(0);
  }


  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // SEARCH
          Expanded(
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController, // <<--- USE SEARCH CONTROLLER
                onChanged: (_) => _applyFilter(),
                decoration: const InputDecoration(
                  icon: Icon(Icons.search),
                  hintText: "Search assets...",
                  border: InputBorder.none,
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // FILTER BUTTON
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: Colors.blueAccent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: IconButton(
              icon: const Icon(Icons.filter_list, color: Colors.white),
              onPressed: _openFilter,
            ),
          ),

          const SizedBox(width: 12),

          // COUNT
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              "${_filteredTasks.length}",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }


  /// Info row for "View" bottom sheet
  Widget _infoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(
            "$title: ",
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Expanded(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Status option tile for "Change Status" bottom sheet
  Widget _statusTile(String status, Color color, Task task) {
    return ListTile(
      leading: CircleAvatar(backgroundColor: color),
      title: Text(status),
      onTap: () async {
        await _api.makePutRequest(
          "https://uatapi.arresto.in/api/client/1825/tasks/${task.id}/status",
          jsonEncode({"status": status}),
        );

        if (!mounted) return;
        setState(() {
          task.status = status;
        });

        Navigator.of(context, rootNavigator: true).pop();
// close bottom sheet
      },
    );
  }

  Widget _dateBox({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              date == null
                  ? label
                  : date.toString().split(' ')[0],
              style: const TextStyle(fontSize: 14),
            ),
            const Icon(Icons.calendar_today, size: 18),
          ],
        ),
      ),
    );
  }


  void _openFilter() {
    showDialog(
      context: context,
      builder: (context) {
        return Center(
          child: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setSheetState) {
                return Container(
                  width: 360, // width of the filter popup
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Filter Assets",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 16),

                      // ChoiceChip for filter type
                      Wrap(
                        spacing: 10,
                        children: ["UIN", "Asset", "User", "Date"]
                            .map((filter) {
                          final bool selected = _selectedFilter == filter;
                          return ChoiceChip(
                            label: Text(filter),
                            selected: selected,
                            onSelected: (_) {
                              setSheetState(() {
                                _selectedFilter = filter;
                                _filterController.clear();
                                _fromDate = null;
                                _toDate = null;
                                _isExactDate = true;
                              });
                            },
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 16),

                      // Filter input
                      if (_selectedFilter != "Date")
                        TextField(
                          controller: _filterController,
                          decoration: InputDecoration(
                            hintText: "Enter $_selectedFilter",
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        )
                      else
                        Column(
                          children: [
                            Row(
                              children: [
                                ChoiceChip(
                                  label: const Text("Exact Date"),
                                  selected: _isExactDate,
                                  onSelected: (_) {
                                    setSheetState(() {
                                      _isExactDate = true;
                                      _fromDate = null;
                                      _toDate = null;
                                    });
                                  },
                                ),
                                const SizedBox(width: 10),
                                ChoiceChip(
                                  label: const Text("From - To"),
                                  selected: !_isExactDate,
                                  onSelected: (_) {
                                    setSheetState(() {
                                      _isExactDate = false;
                                      _fromDate = null;
                                      _toDate = null;
                                    });
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (_isExactDate)
                              TextField(
                                controller: _filterController,
                                decoration: const InputDecoration(
                                  hintText: "Enter date (YYYY-MM-DD)",
                                  border: OutlineInputBorder(),
                                ),
                              )
                            else
                              Row(
                                children: [
                                  Expanded(
                                    child: _dateBox(
                                      label: "From",
                                      date: _fromDate,
                                      onTap: () async {
                                        final picked =
                                        await showDatePicker(
                                          context: context,
                                          initialDate: DateTime.now(),
                                          firstDate: DateTime(2020),
                                          lastDate: DateTime(2030),
                                        );
                                        if (picked != null) {
                                          setSheetState(
                                                  () => _fromDate = picked);
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _dateBox(
                                      label: "To",
                                      date: _toDate,
                                      onTap: () async {
                                        final picked =
                                        await showDatePicker(
                                          context: context,
                                          initialDate: DateTime.now(),
                                          firstDate: DateTime(2020),
                                          lastDate: DateTime(2030),
                                        );
                                        if (picked != null) {
                                          setSheetState(
                                                  () => _toDate = picked);
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),

                      const SizedBox(height: 20),

                      // Apply filter button
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check),
                          label: const Text("Apply Filter"),
                          onPressed: () {
                            _applyFilter(); // apply only when tick clicked
                            Navigator.of(context, rootNavigator: true).pop();
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _applyFilter() {
    final filterValue = _filterController.text.toLowerCase();

    setState(() {
      _currentPage = 0;

      _filteredTasks = tasks.where((task) {
        switch (_selectedFilter) {
          case "UIN":
            return task.uin.toLowerCase().contains(filterValue);
          case "Asset":
            return task.name.toLowerCase().contains(filterValue);
          case "User":
            return task.assignedUser.toLowerCase().contains(filterValue);
          case "Date":
            final date = task.scheduledDate;

            if (_isExactDate && _filterController.text.isNotEmpty) {
              try {
                final inputDate = DateTime.parse(_filterController.text);
                return date.year == inputDate.year &&
                    date.month == inputDate.month &&
                    date.day == inputDate.day;
              } catch (_) {
                return false; // invalid manual date
              }
            }

            if (!_isExactDate) {
              if (_fromDate != null && date.isBefore(_fromDate!)) return false;
              if (_toDate != null && date.isAfter(_toDate!)) return false;
              return true;
            }

            return true;

          default:
            return true;
        }
      }).toList();
    });

    // reset page on mobile
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
  }

  Widget _mobileHorizontalList() {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      itemCount: _filteredTasks.length,
      itemBuilder: (context, index) {
        final task = _filteredTasks[index];

        return AssetHorizontalCard(
          task: task,

          // -------- DELETE --------
          onDelete: () async {
            await _api.makeDeleteRequest(
              "https://uatapi.arresto.in/api/client/1825/tasks/${task.id}",
            );

            if (!mounted) return;

            setState(() {
              _filteredTasks.removeWhere((t) => t.id == task.id);
            });
          },

          // -------- STATUS CHANGE CALLBACK (OPTIONAL API HIT) --------
          onChangeStatus: () async {
            // If later you want API hit, do it here
            // For now UI already updates inside card
          },

          // -------- RESCHEDULE --------
          onReschedule: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: task.scheduledDate,
              firstDate: DateTime(2000),
              lastDate: DateTime(2030),
            );

            if (picked != null) {
              setState(() => task.scheduledDate = picked);

              await _api.makePutRequest(
                "https://uatapi.arresto.in/api/client/1825/tasks/${task.id}/reschedule",
                jsonEncode({"scheduled_date": picked.toIso8601String()}),
              );
            }
          },
        );
      },
    );
  }



  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Scheduler",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          // TOP SEARCH + FILTER BAR (NO UI BREAK)
          _topBar(),

          // EXISTING UI (UNCHANGED)
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;

                /// WEB → SAME GRID
                if (width >= 900) {
                  return _responsiveGrid(width);
                }

                /// MOBILE + TABLET → STYLE
                return _mobileHorizontalList();
              },
            ),
          ),

        ],
      ),
    );
  }

  // -------- WEB / TABLET GRID --------
  Widget _responsiveGrid(double width) {
    int crossAxisCount = 5;

    if (width < 1200) crossAxisCount = 3;
    if (width < 900) crossAxisCount = 2;

    return GridView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _filteredTasks.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 24,
        crossAxisSpacing: 24,
        childAspectRatio: 0.72,
      ),
      itemBuilder: (_, i) =>
          AssetCard(
            task: _filteredTasks[i],

            onDelete: () async {
              await _api.makeDeleteRequest(
                "https://uatapi.arresto.in/api/client/1825/tasks/${_filteredTasks[i].id}",
              );

              setState(() {
                _filteredTasks.removeWhere((t) => t.id == _filteredTasks[i].id);
              });
            },

            onReschedule: (pickedDate) async {
              await _api.makePutRequest(
                "https://uatapi.arresto.in/api/client/1825/tasks/${_filteredTasks[i].id}/reschedule",
                jsonEncode({
                  "scheduled_date": pickedDate.toIso8601String(),
                }),
              );
            },

            onStatusChange: (status) async {
              await _api.makePutRequest(
                "https://uatapi.arresto.in/api/client/1825/tasks/${_filteredTasks[i].id}/status",
                jsonEncode({"status": status}),
              );
            },
          ),

    );
  }

}


class AssetCard extends StatefulWidget {
  final Task task;

  final VoidCallback onDelete;
  final Function(DateTime) onReschedule;
  final Function(String) onStatusChange;

  const AssetCard({
    super.key,
    required this.task,
    required this.onDelete,
    required this.onReschedule,
    required this.onStatusChange,
  });

  @override
  State<AssetCard> createState() => _AssetCardState();
}


class _AssetCardState extends State<AssetCard> {
  bool _showAssignedInfo = false;
  bool _showStatusOptions = false;
  String? _statusSelection;

  Color _getStatusColor(String status) {
    if (status == "Approved") return Colors.green;
    if (status == "Rejected") return Colors.red;
    return Colors.orange;
  }

  List<Color> _getStatusGradient(String status) {
    if (status == "Approved") return [Colors.green.withOpacity(0.7), Colors.greenAccent];
    if (status == "Rejected") return [Colors.red.withOpacity(0.7), Colors.redAccent];
    return [Colors.orange.withOpacity(0.7), Colors.deepOrange];
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final status = _statusSelection ?? task.status;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          /// IMAGE
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              child: Image.network(
                task.imageUrl,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),

          /// CONTENT
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// UIN + STATUS PILL
                Row(
                  children: [
                    Expanded(child: _meta("UIN", task.uin)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          status,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                _meta("Type", task.type),
                _meta("Scheduled", task.scheduledDate.toString().split(' ')[0]),

                const SizedBox(height: 14),

                /// ACTION BUTTONS RESPONSIVE
                LayoutBuilder(
                  builder: (context, constraints) {
                    final bool isMobile = constraints.maxWidth < 500;
                    final bool isRealMobile = !kIsWeb && isMobile;

                    final double btnWidth =
                    isMobile ? (constraints.maxWidth / 2 - 12) : 120.0;

                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        // CHANGE STATUS
                        SizedBox(
                          width: btnWidth,
                          child: StatusButton(
                            statusText: "Change Status",
                            icon: Icons.sync,
                            iconOnly: isRealMobile, // ✅ ONLY MOBILE
                            gradientColors: const [Colors.blue, Colors.blueAccent],
                            onTap: () {
                              setState(() {
                                _showStatusOptions = !_showStatusOptions;
                              });
                            },
                          ),
                        ),

                        // RESCHEDULE
                        SizedBox(
                          width: btnWidth,
                          child: StatusButton(
                            statusText: "Reschedule",
                            icon: Icons.calendar_month,
                            iconOnly: isRealMobile,
                            gradientColors: const [Colors.indigo, Colors.indigoAccent],
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: task.scheduledDate,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                setState(() => task.scheduledDate = picked);
                                widget.onReschedule(picked);
                              }
                            },
                          ),
                        ),

                        // VIEW
                        SizedBox(
                          width: btnWidth,
                          child: StatusButton(
                            statusText: "View",
                            icon: Icons.visibility,
                            iconOnly: isRealMobile,
                            gradientColors: const [Colors.teal, Colors.tealAccent],
                            onTap: () {
                              setState(() {
                                _showAssignedInfo = !_showAssignedInfo;
                              });
                            },
                          ),
                        ),

                        // DELETE
                        SizedBox(
                          width: btnWidth,
                          child: StatusButton(
                            statusText: "Delete",
                            icon: Icons.delete,
                            iconOnly: isRealMobile,
                            gradientColors: const [Colors.red, Colors.redAccent],
                            onTap: widget.onDelete,
                          ),
                        ),
                      ],
                    );
                  },
                ),


                /// STATUS DROPDOWN
                Visibility(
                  visible: _showStatusOptions,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: ["Pending", "Approved", "Rejected"].map((s) {
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _statusSelection = s;
                              widget.task.status = s;
                              _showStatusOptions = false;
                            });

                            widget.onStatusChange(s);
                            // ✅ parent API
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
                            decoration: BoxDecoration(
                              color: _getStatusColor(s),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              s,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),


                /// ASSIGNED INFO
                Visibility(
                  visible: _showAssignedInfo,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Assigned to: ${task.assignedUser}", style: _small()),
                        Text("Assigned for: ${task.type}", style: _small()),
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

  // ---------------- HELPER METHODS ----------------

  Widget _meta(String label, String value) {
    return Text("$label: $value", style: _small());
  }

  TextStyle _small() {
    return TextStyle(fontSize: 13, color: Colors.grey[700]);
  }

  Widget _actionBtn(String text, IconData icon, VoidCallback onTap, {double width = 120}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: width,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: text == "Delete"
                    ? [Colors.red, Colors.redAccent]
                    : [Colors.blue, Colors.blueAccent],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  text,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// ---------------- MAIN ----------------
// ------------------ METHODS INSIDE CLASS ------------------




class StatusButton extends StatelessWidget {
  final String statusText;
  final List<Color> gradientColors;
  final VoidCallback? onTap;
  final IconData icon;
  final bool iconOnly; // 👈 NEW

  const StatusButton({
    super.key,
    required this.statusText,
    required this.gradientColors,
    required this.icon,
    this.onTap,
    this.iconOnly = false, // 👈 default = text + icon
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradientColors),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: gradientColors.last.withOpacity(0.35),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: iconOnly
              ? Icon(icon, color: Colors.white, size: 20) // 📱 MOBILE
              : Row( // 💻 TAB / WEB
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                statusText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AssetHorizontalCard extends StatefulWidget {
  final Task task;
  final VoidCallback onDelete;
  final VoidCallback onChangeStatus;
  final VoidCallback onReschedule;

  const AssetHorizontalCard({
    super.key,
    required this.task,
    required this.onDelete,
    required this.onChangeStatus,
    required this.onReschedule,
  });

  @override
  State<AssetHorizontalCard> createState() => _AssetHorizontalCardState();
}

class _AssetHorizontalCardState extends State<AssetHorizontalCard> {
  Color _getStatusColor(String status) {
    switch (status) {
      case "Approved":
        return Colors.green;
      case "Rejected":
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  // ================= VIEW ASSET (BOTTOM SHEET) =================
  // ================= VIEW (CENTER DIALOG) =================
  void _showViewDialog() {
    showDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Asset Details",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),

                _infoRow("Name", widget.task.name),
                _infoRow("UIN", widget.task.uin),
                _infoRow("Type", widget.task.type),
                _infoRow("Status", widget.task.status),

                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                    },
                    child: const Text("Close"),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

// ================= CHANGE STATUS (CENTER DIALOG) =================
  void _showChangeStatusDialog() {
    showDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Change Status",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),

                _statusDialogTile("Approved", Colors.green, dialogContext),
                _statusDialogTile("Pending", Colors.orange, dialogContext),
                _statusDialogTile("Rejected", Colors.red, dialogContext),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _statusDialogTile(
      String status,
      Color color,
      BuildContext dialogContext,
      ) {
    return ListTile(
      title: Text(status),
      trailing: Icon(Icons.circle, color: color),
      onTap: () {
        setState(() {
          widget.task.status = status;
        });

        widget.onChangeStatus();
        Navigator.of(dialogContext).pop(); // ✅ close dialog safely
      },
    );
  }



  Widget _statusTile(String status, Color color) {
    return ListTile(
      title: Text(status),
      trailing: Icon(Icons.circle, color: color),
      onTap: () {
        setState(() {
          widget.task.status = status;
        });
        widget.onChangeStatus();
        Navigator.of(context, rootNavigator: true).pop();
      },
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              "$label:",
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _dragHandle() {
    return Center(
      child: Container(
        width: 42,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey[400],
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  // ================= MAIN UI =================
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      height: 150,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // IMAGE
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(18)),
            child: Image.network(
              widget.task.imageUrl,
              width: screenWidth * 0.35,
              height: double.infinity,
              fit: BoxFit.cover,
            ),
          ),

          // NAME + UIN
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 10, top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.task.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "UIN: ${widget.task.uin}",
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
          ),

          // STATUS + ACTIONS
          Padding(
            padding: const EdgeInsets.only(top: 12, right: 10),
            child: Column(
              children: [
                // STATUS PILL
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(widget.task.status),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    widget.task.status,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // ICON GRID
                SizedBox(
                  width: 80,
                  height: 80,
                  child: GridView.count(
                    crossAxisCount: 2,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    children: [
                      _icon(Icons.sync, Colors.blue, _showChangeStatusDialog),
                      _icon(Icons.visibility, Colors.teal, _showViewDialog),
                      _icon(Icons.calendar_month, Colors.indigo, widget.onReschedule),
                      _icon(Icons.delete, Colors.red, widget.onDelete),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _icon(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.85), color],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.35),
              blurRadius: 6,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 26),
      ),
    );
  }
}
