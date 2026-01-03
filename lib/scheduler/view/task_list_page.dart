import 'package:flutter/material.dart';
import 'dart:ui';

class Task {
  final String id;
  final String name;
  final String uin;
  final String type;
  late final DateTime scheduledDate;
  final String assignedUser;
  final String imageUrl;
  String status; // NEW FIELD

  Task({
    required this.id,
    required this.name,
    required this.uin,
    required this.type,
    required this.scheduledDate,
    required this.assignedUser,
    required this.imageUrl,
    this.status = "Pending", // default value
  });
}

final List<Task> tasks = [
  Task(
    id: '1',
    name: 'MacBook Pro',
    uin: 'UIN-10234',
    type: 'Laptop',
    scheduledDate: DateTime(2025, 1, 15),
    assignedUser: 'Yash G',
    imageUrl:
    'https://images.unsplash.com/photo-1517336714731-489689fd1ca8',
  ),
  Task(
    id: '2',
    name: 'iMac',
    uin: 'UIN-56789',
    type: 'Desktop',
    scheduledDate: DateTime(2025, 1, 20),
    assignedUser: 'Admin',
    imageUrl:
    'https://images.unsplash.com/photo-1527443154391-507e9dc6c5cc',
  ),
];

class TaskListPage extends StatefulWidget {
  const TaskListPage({super.key});

  @override
  State<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends State<TaskListPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  String _selectedFilter = "UIN";
  final TextEditingController _filterController = TextEditingController();
  DateTime? _fromDate;
  DateTime? _toDate;
  final TextEditingController _searchController = TextEditingController();
  List<Task> _filteredTasks = [];
  bool _isExactDate = true;

  @override
  void initState() {
    super.initState();
    _filteredTasks = tasks;
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
                controller: _searchController,   // <<--- USE SEARCH CONTROLLER
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
                            Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
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

                if (width >= 700) {
                  return _responsiveGrid(width);
                }

                return _mobilePagination();
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
      itemBuilder: (_, i) => AssetCard(task: _filteredTasks[i]),
    );
  }

  // -------- MOBILE PAGINATION --------
  Widget _mobilePagination() {
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _filteredTasks.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.all(20),
              child: AssetCard(task: _filteredTasks[i]),
            ),
          ),
        ),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _filteredTasks.length,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
              height: 8,
              width: _currentPage == i ? 22 : 8,
              decoration: BoxDecoration(
                color: _currentPage == i
                    ? Colors.blue
                    : Colors.grey.shade400,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class AssetCard extends StatefulWidget {
  final Task task;
  const AssetCard({super.key, required this.task});


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
                    final isMobile = constraints.maxWidth < 500;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        _actionBtn("Change Status", Icons.sync, () {
                          setState(() {
                            _showStatusOptions = !_showStatusOptions;
                          });
                        }, width: isMobile ? (constraints.maxWidth / 2 - 12) : 120),
                        _actionBtn("Reschedule", Icons.calendar_month, () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: task.scheduledDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setState(() {
                              task.scheduledDate = picked;
                            });
                          }
                        }, width: isMobile ? (constraints.maxWidth / 2 - 12) : 120),
                        _actionBtn("View", Icons.visibility, () {
                          setState(() {
                            _showAssignedInfo = !_showAssignedInfo;
                          });
                        }, width: isMobile ? (constraints.maxWidth / 2 - 12) : 120),
                        _actionBtn("Delete", Icons.delete, () {}, width: isMobile ? (constraints.maxWidth / 2 - 12) : 120),
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
                      children: ["Pending", "Approved", "Rejected"]
                          .map((s) => GestureDetector(
                        onTap: () {
                          setState(() {
                            _statusSelection = s;
                            widget.task.status = s;
                            _showStatusOptions = false;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 6, horizontal: 14),
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
                      ))
                          .toList(),
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
            gradient: const LinearGradient(colors: [Colors.blue, Colors.blueAccent]),
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
void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: TaskListPage(),
  ));
}

  // ------------------ METHODS INSIDE CLASS ------------------

  void _openCalendar(BuildContext context) {
    showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
  }

  Widget _glassButton(String text, List<Color> gradientColors, VoidCallback onTap,
      {bool expand = true}) {
    Widget button = GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            height: 40,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradientColors),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.35)),
            ),
            child: Text(
              text,
              style: const TextStyle(
                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );

    return expand ? Expanded(child: button) : button;
  }

  Widget _meta(String label, String value) {
    return Text("$label: $value", style: _small());
  }

  TextStyle _small() {
    return TextStyle(fontSize: 13, color: Colors.grey[700]);
  }

  Widget _viewButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.blue,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Center(
        child: Text("View", style: TextStyle(color: Colors.white, fontSize: 14)),
      ),
    );
  }

  List<Color> _getStatusGradient(String status) {
    switch (status) {
      case "Approved":
        return [Colors.green.withOpacity(0.7), Colors.greenAccent];
      case "Rejected":
        return [Colors.red.withOpacity(0.7), Colors.redAccent];
      case "Pending":
      default:
        return [Colors.orange.withOpacity(0.7), Colors.deepOrange];
    }
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
class StatusButton extends StatelessWidget {
  final String statusText;       // Pending / Approved / Rejected
  final List<Color> gradientColors; // Gradient colors
  final VoidCallback? onTap;     // Optional tap callback

  const StatusButton({
    super.key,
    required this.statusText,
    required this.gradientColors,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradientColors),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(0.35)),
                boxShadow: [
                  BoxShadow(
                    color: gradientColors.last.withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  statusText,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


