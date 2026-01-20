import 'package:flutter/material.dart';
import '../scheduler/task_list_page.dart';

Future<List<Map<String, dynamic>>> showParameterSelector(
    BuildContext context, {
      required String apiUrl,
      required String listKey,
      required String idKey,
      required String labelKey,
      required String lastPageKey,
      List<Map<String, dynamic>> initialSelected = const [],
    }) async {

  List<Map<String, dynamic>> selected =
  List<Map<String, dynamic>>.from(initialSelected);

  final result = await showGeneralDialog<List<Map<String, dynamic>>>(
    context: context,
    barrierDismissible: true,
    barrierLabel: "close",
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (_, __, ___) {
      return Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;

            return ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isMobile
                    ? constraints.maxWidth * 0.95   // mobile
                    : 520,                           // web
                maxHeight: isMobile
                    ? constraints.maxHeight * 0.75
                    : constraints.maxHeight * 0.85,
              ),
              child: ApiMultiSelectPanel(
                apiUrl: apiUrl,
                listKey: listKey,
                idKey: idKey,
                labelKey: labelKey,
                lastPageKey: lastPageKey,
                selectedItems: selected,
                onChanged: (items) {
                  selected = items;
                },
              ),
            );
          },
        ),
      );
    },
  );

  return result ?? selected;
}

