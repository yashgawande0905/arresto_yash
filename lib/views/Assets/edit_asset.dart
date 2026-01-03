import 'dart:convert';

import 'package:arresto/app_utility/methods.dart';
import 'package:arresto/models/DropDownValue_model.dart';
import 'package:arresto/views/Sub_Asset/sub_asset_list.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:responsive_framework/responsive_row_column.dart';
import 'package:responsive_framework/responsive_wrapper.dart';
import 'package:toggle_switch/toggle_switch.dart';

import '../../app_utility/app_colors.dart';
import '../../app_utility/theme_helper.dart';
import '../../custom_views_layout/custom_view/expandable_text_field.dart';
import '../../custom_views_layout/widgets/common.dart';
import '../../custom_views_layout/widgets/reorderlist_dialog.dart';
import '../../models/Asset_model.dart';
import '../../models/expectedModel.dart';
import '../../models/multiselect_model.dart';
import '../../models/sub_asset_model.dart';
import '../../networks/ApisRequests.dart';
import '../../services/Apis_File.dart';
import '../../third_party_libs/multiselect_lib/multi_select_dialog_field.dart';
import '../../third_party_libs/multiselect_lib/multi_select_item.dart';

class EditAssetsController extends GetxController {
  RxList<TypeData> inspections = <TypeData>[].obs,
      uoms = <TypeData>[].obs,
      assetTemplateArr = <TypeData>[].obs,
      standardArr = <TypeData>[].obs,
      bodyTestReportArr = <TypeData>[].obs,
      articleArr = <TypeData>[].obs,
      assetTypeArr = <TypeData>[].obs,
      assetCategoryArr = <TypeData>[].obs,
      assetStatusArr = <TypeData>[].obs;

  Rx<Assets?> assetData = Rx<Assets?>(null);

  Rx<TypeData?> selectUom = Rx<TypeData?>(null),
      selectInspectionType = Rx<TypeData?>(null),
      selectAssetTemplate = Rx<TypeData?>(null),
      selectStandard = Rx<TypeData?>(null),
      selectBodyTestrprt = Rx<TypeData?>(null),
      select11bArticle = Rx<TypeData?>(null),
      selectAssetType = Rx<TypeData?>(null),
      selectAssetCategory = Rx<TypeData?>(null);

  TextEditingController description_controller = TextEditingController(),
      assetcode_controller = TextEditingController(),
      assetimage_controller = TextEditingController(),
      assetalias_controller = TextEditingController(),
      assetean_controller = TextEditingController(),
      frequencyinspemonth_controller = TextEditingController(),
      frequencyinspedays_controller = TextEditingController(),
      dueperioddays_controller = TextEditingController(),
      duedate_controller = TextEditingController(),
      frequencyinspection_controller = TextEditingController(),
      lifespanmonth_controller = TextEditingController(),
      lifespanhour_controller = TextEditingController(),
      freqprevmaint_controller = TextEditingController(),
      ectypecertificate_controller = TextEditingController(),
      assetname_controller = TextEditingController();

  RxString status = "active".obs;
  RxBool repairValue = false.obs,
      inspectionValue = false.obs,
      geofencingValue = false.obs,
      workPermitValue = false.obs,
      refreshSubAsset = false.obs,
      refreshExpectResult = false.obs;

  List<String> statusArr = ['Active', 'Inactive'];
  Rx<String?> selectKnowledgetree = Rx<String?>(null);

  //-------file--------
  var file;
  RxString file_name = "No file chosen".obs;
  RxString fileData = "".obs;

  RxList<TypeData> selectSubAsset = <TypeData>[].obs;
  RxList<ExpectedModel> selectExpectedResults = <ExpectedModel>[].obs;

  RxList<MultiSelectItem<TypeData>> subAssetData =
      <MultiSelectItem<TypeData>>[].obs;

  RxList<MultiSelectItem<ExpectedModel>> expectedData =
      <MultiSelectItem<ExpectedModel>>[].obs;


  @override
  void onInit() {
    super.onInit();
    getDropdown();
    getSubAsset();
    getExpectedResults();
  }

  Future getDropdown() async {
    final response = await ApisRequests().makeGetRequest(ApisFile().client_sa);
    // .makeGetRequest(get_post_categories_api);
    if (response.statusCode == 200) {
      List<dynamic> dropDownValueData =
          (json.decode(response.body)['data'] as List)
              .map((data) => Dropdownmodel.fromJson(data))
              .toList();
      dropDownValueSet(dropDownValueData);
    }
  }

  dropDownValueSet(List<dynamic> dropDownValueData) {
    for (var i = 0; i < dropDownValueData.length; i++) {
      final item = dropDownValueData[i];
      Type temobj = item.type;
      if (temobj.typeName == "Inspection Type") {
        inspections.assignAll(item.type_data);
      }
      if (temobj.typeName == "UOM") {
        uoms.assignAll(item.type_data);
      }
      if (temobj.typeName == "Standard") {
        standardArr.assignAll(item.type_data);
      }
      if (temobj.typeName == "Notified Body (Certification)") {
        bodyTestReportArr.assignAll(item.type_data);
      }
      if (temobj.typeName == "Notified Body (Article 11B)") {
        articleArr.assignAll(item.type_data);
      }
      if (temobj.typeName == "Asset Type (Sensor)") {
        assetTypeArr.assignAll(item.type_data);
      }
      if (temobj.typeName == "Asset Category") {
        assetCategoryArr.assignAll(item.type_data);
      }
      if (temobj.typeName == "Asset Template Type") {
        assetTemplateArr.assignAll(item.type_data);
      }
      if (temobj.typeName == "Status") {
        assetStatusArr.assignAll(item.type_data);
      }
    }
    setData();
  }

  Future getSubAsset() async {
    String url =getSubAssetUrl();
        //ApisFile().client_get_SubAsset_api;
    // if (UserType != "SA" || UserType != "CLIENT_SA") {
    //   url += "?company_id=${currentUser.company ?? "0"}";
    // }
    final response = await ApisRequests().makeGetRequest(url);
    if (response.statusCode == 200) {
      List<SubAsset> subAssedata = (json.decode(response.body)['data'] as List)
          .map((data) => SubAsset.fromJson(data))
          .toList();

      subAssetData.assignAll(
        subAssedata.map((e) {
          return MultiSelectItem<TypeData>(
            TypeData(
              typeId: e.sub_assets_id,
              typeName: e.sub_assets_code,
            ),
            e.sub_assets_code,
          );
        }).toList(),
      );


      if (((assetData.value?.component_sub_assets ?? []) as List).isNotEmpty) {
        for (var subdata in assetData.value?.component_sub_assets) {
          if ((subAssetData
              .any((element) => element.value.typeId == subdata))) {
            var index = subAssetData
                .indexWhere((element) => element.value.typeId == subdata);

            selectSubAsset.add(subAssetData[index].value);
          }
        }
      }
      refreshSubAsset.value = true;
      refreshSubAsset.refresh();
      selectSubAsset.refresh();
      subAssetData.refresh();
      refresh();
    }
  }

  Future getExpectedResults() async {
    final response = await ApisRequests()
        .makeGetRequest(ApisFile().client_get_expected_results);
    if (response.statusCode == 200) {
      List<ExpectedModel> all_expectedResults =
          (json.decode(response.body)['data'] as List)
              .map((data) => ExpectedModel.fromJson(data))
              .toList();

      expectedData.assignAll(all_expectedResults
          .map((e) => MultiSelectItem<ExpectedModel>(e, e.type_name!))
          .toList());

      if ((assetData.value?.result_data ?? []).isNotEmpty) {
        selectExpectedResults.clear();

        for (var exdata in assetData.value!.result_data) {
          final match = expectedData.firstWhereOrNull(
                (e) => e.value.type_id == exdata.type_id,
          );

          if (match != null) {
            selectExpectedResults.add(match.value);
          }
        }
      }

      refreshExpectResult.value = true;
      selectExpectedResults.refresh();
      expectedData.refresh();
      refreshExpectResult.refresh();
      refresh();
    }
  }

  Future<bool> refreshOrderExpected(List<dynamic> newOrderList) async {
    selectExpectedResults.clear();
    Common.printLog('refreshOrderExpected');

    for (ExpectedModel exdata in newOrderList.cast<ExpectedModel>()) {
      final match = expectedData.firstWhereOrNull(
            (e) => e.value.type_id == exdata.type_id,
      );

      if (match != null) {
        selectExpectedResults.add(match.value);
      }
    }

    selectExpectedResults.refresh();
    return true;
  }

  Future<bool> refreshOrderSubAsset(List<dynamic> newOrderList) async {
    selectSubAsset.clear();
    Common.printLog('refreshOrderSubAsset Start -> $newOrderList');

    for (TypeData subAsset in newOrderList.cast<TypeData>()) {
      final match = subAssetData.firstWhereOrNull(
            (e) => e.value.typeId == subAsset.typeId,
      );

      if (match != null) {
        selectSubAsset.add(match.value);
      }
    }

    selectSubAsset.refresh();
    Common.printLog('refreshOrderSubAsset End ${selectSubAsset.value}');
    return true;
  }

  getAsset(assetId) async {
    String url = '${ApisFile().asset_details_api}$assetId';
    final response = await ApisRequests().makeGetRequest(url);
    if (response.statusCode == 200) {
      assetData.value = Assets.fromJson(json.decode(response.body)['data']);

      description_controller.text = assetData.value?.component_description;
      assetcode_controller.text = assetData.value?.component_code;
      assetname_controller.text = assetData.value?.component_name ?? "";
      assetalias_controller.text = assetData.value?.component_alias ?? "";
      assetean_controller.text = assetData.value?.component_ean ?? "";
      assetimage_controller.text = assetData.value?.component_imagepath ?? "";
      frequencyinspemonth_controller.text =
          assetData.value?.component_frequency_asset.toString() ?? "";
      frequencyinspedays_controller.text =
          assetData.value?.component_frequency_hours.toString() ?? "";
      dueperioddays_controller.text =
          assetData.value?.component_due_period.toString() ?? "";
      frequencyinspection_controller.text =
          assetData.value?.freq_hours.toString() ?? "";
      lifespanmonth_controller.text =
          assetData.value?.component_lifespan_month.toString() ?? "";
      lifespanhour_controller.text =
          assetData.value?.component_lifespan_hours.toString() ?? "";
      freqprevmaint_controller.text =
          assetData.value?.component_pdm_frequency.toString() ?? "";
      ectypecertificate_controller.text =
          assetData.value?.ec_type_certificate_text;
      repairValue.value =
          assetData.value?.component_repair.toString().toLowerCase() ==
              Common.yes.toLowerCase();
      workPermitValue.value =
          assetData.value?.component_work_permit.toString().toLowerCase() ==
              Common.yes.toLowerCase();
      inspectionValue.value =
          assetData.value?.component_inspection.toString().toLowerCase() ==
              Common.yes.toLowerCase();
      geofencingValue.value =
          assetData.value?.component_geo_fancing.toString().toLowerCase() ==
              Common.yes.toLowerCase();
      status.value = assetData.value?.status;
      selectKnowledgetree.value = assetData.value?.kt_status != null &&
              assetData.value?.kt_status != "" &&
              statusArr.contains(assetData.value?.kt_status.toString())
          ? assetData.value?.kt_status.toString()
          : null;
      assetData.refresh();
      setData();
    }
  }

  @override
  void onClose() {
    super.onClose();
  }

  void setData() {
    if (assetData.value != null) {
      selectInspectionType.value = findIndex(inspections.value,
          assetData.value?.component_inspectiontype!.type_id);
      selectUom.value =
          findIndex(uoms.value, assetData.value?.component_uom!.type_id);
      selectStandard.value = findIndex(
          standardArr.value, assetData.value?.standard_certificate_id!.type_id);
      selectBodyTestrprt.value = findIndex(bodyTestReportArr.value,
          assetData.value?.notified_body_certificate_id!.type_id);
      select11bArticle.value = findIndex(articleArr.value,
          assetData.value?.article_11b_certificate_id!.type_id);
      selectAssetType.value = findIndex(
          assetTypeArr.value, assetData.value?.component_type!.type_id);
      selectAssetCategory.value = findIndex(
          assetCategoryArr.value, assetData.value?.component_category!.type_id);
      selectAssetTemplate.value = findIndex(assetTemplateArr.value,
          assetData.value?.component_template_type!.type_id);
      refresh();
    }
  }

  void clearController() {
    selectExpectedResults.clear();
    selectSubAsset.clear();
    description_controller.text = '';
    assetcode_controller.text = '';
    assetname_controller.text = '';
    assetalias_controller.text = '';
    assetean_controller.text = '';
    assetimage_controller.text = '';
    frequencyinspemonth_controller.text = '';
    frequencyinspedays_controller.text = '';
    dueperioddays_controller.text = '';
    frequencyinspection_controller.text = '';
    lifespanmonth_controller.text = '';
    lifespanhour_controller.text = '';
    freqprevmaint_controller.text = '';
    ectypecertificate_controller.text = '';
    repairValue.value = inspectionValue.value = geofencingValue.value =
        workPermitValue.value =
            refreshSubAsset.value = refreshExpectResult.value = false;

    status.value = 'active';
    selectKnowledgetree.value = null;

    selectInspectionType.value = null;
    selectUom.value = null;
    selectStandard.value = null;
    selectBodyTestrprt.value = null;
    select11bArticle.value = null;
    selectAssetType.value = null;
    selectAssetCategory.value = null;
    selectAssetTemplate.value = null;
    refresh();
  }
}

class EditAssets extends StatefulWidget {
  final String title;
  final String assetId;

  const EditAssets({
    super.key,
    required this.title,
    required this.assetId,
  });

  @override
  State<EditAssets> createState() => _EditAssetsState();
}

class _EditAssetsState extends State<EditAssets> {
  late final EditAssetsController controller;

  BuildContext? contxt;
  List byte_data = [];
  final size20 = const SizedBox(height: 20.0);

  late ScaffoldMessengerState scaffoldMessenger;
  bool isdesktop = false;

  @override
  void initState() {
    super.initState();
    controller = Get.put(EditAssetsController());
    controller.getAsset(widget.assetId); // ✅ MUST BE HERE
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveRowColumnType rowColumnType;
    contxt = context;
    if (ResponsiveWrapper.of(context).isSmallerThan(TABLET)) {
      rowColumnType = ResponsiveRowColumnType.COLUMN;
      isdesktop = false;
    } else {
      isdesktop = true;
      rowColumnType = ResponsiveRowColumnType.ROW;
    }
    scaffoldMessenger = ScaffoldMessenger.of(context);

    return Obx(() =>
        Scaffold(
          body: SingleChildScrollView(
            child: Container(
              padding: EdgeInsets.all(10),
              margin: EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Common.successHeaderCustomBack(
                      title: getStringTranslate("edit_asset"),
                      icon: Icons.language,
                      context: context,
                      mCallback: () {
                        Common.disposeController<EditAssetsController>();
                        // controller.clearController();
                        Navigator.pop(context, "");
                      }),
                  size20,
                  Container(
                    alignment: Alignment.topLeft,
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.app_main_dark_color,
                      border: Border.all(color: Colors.black12, width: 0.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            getStringTranslate("assets_details"),
                            style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                ToggleSwitch(
                                  minWidth: 15.0,
                                  minHeight: 15,
                                  cornerRadius: 7.5,
                                  activeBgColors: [
                                    [Colors.white!],
                                    [AppColors.app_button_blue_color!]
                                  ],
                                  activeFgColor: Colors.white,
                                  inactiveBgColor: Colors.grey,
                                  inactiveFgColor: Colors.white,
                                  initialLabelIndex:
                                  controller.status.value.toLowerCase() ==
                                      "active"
                                      ? 1
                                      : 0,
                                  totalSwitches: 2,
                                  labels: const ['', ''],
                                  radiusStyle: true,
                                  onToggle: (index) {
                                    controller.status.value =
                                    index == 0 ? "inactive" : "active";
                                    Common.printLog('switched to: $index');
                                  },
                                ),
                                const SizedBox(width: 25),
                                Text(
                                  getStringTranslate("status"),
                                  style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                      fontWeight: FontWeight.normal),
                                ),
                              ]),
                        ),
                      ],
                    ),
                  ),
                  size20,
                  ResponsiveRowColumn(
                    layout: rowColumnType,
                    children: [
                      ResponsiveRowColumnItem(
                        rowFlex: 1,
                        rowFit: FlexFit.tight,
                        child: Container(
                          width: double.infinity,
                          margin: isdesktop
                              ? EdgeInsets.only(right: 20)
                              : EdgeInsets.only(bottom: 20),
                          decoration: ThemeHelper().inputBoxDecorationShaddow(),
                          child: TextField(
                            // readOnly: true,
                            controller: controller.assetcode_controller,
                            style: const TextStyle(fontSize: 14),
                            decoration: ThemeHelper().textInputDecoration(
                                getStringTranslate('asset_code') + " *",
                                getStringTranslate('enter_asset_code') + " *"),
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                      ),
                      ResponsiveRowColumnItem(
                        rowFlex: 1,
                        rowFit: FlexFit.tight,
                        child: Container(
                          decoration: ThemeHelper().inputBoxDecorationShaddow(),
                          child: TextField(
                            controller: controller.assetalias_controller,
                            textAlign: TextAlign.start,
                            style: const TextStyle(fontSize: 14),
                            decoration: ThemeHelper().textInputDecoration(
                                getStringTranslate('asset_alias'),
                                getStringTranslate('enter_asset_alias')),
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.jobTitle],
                          ),
                        ),
                      ),
                    ],
                  ),
                  size20,
                  ResponsiveRowColumn(
                    layout: rowColumnType,
                    children: [
                      ResponsiveRowColumnItem(
                        rowFlex: 1,
                        rowFit: FlexFit.tight,
                        child: Container(
                          width: double.infinity,
                          margin: isdesktop
                              ? EdgeInsets.only(right: 20)
                              : EdgeInsets.only(bottom: 20),
                          decoration: ThemeHelper().inputBoxDecorationShaddow(),
                          child: TextField(
                            controller: controller.assetean_controller,
                            style: const TextStyle(fontSize: 14),
                            decoration: ThemeHelper().textInputDecoration(
                                getStringTranslate('asset_ean'),
                                getStringTranslate('enter_asset_ean')),
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                      ),
                      ResponsiveRowColumnItem(
                        rowFlex: 1,
                        rowFit: FlexFit.tight,
                        child: Container(
                          decoration: ThemeHelper().inputBoxDecorationShaddow(),
                          child: ExpandableTextField(
                            child: TextField(
                              controller: controller.description_controller,
                              maxLines: 100,
                              textAlign: TextAlign.start,
                              style: const TextStyle(fontSize: 14),
                              decoration: ThemeHelper().textInputDecoration(
                                  "${getStringTranslate('description')} *",
                                  "${getStringTranslate(
                                      'enter_description')} *"),
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.jobTitle],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  size20,
                  ResponsiveRowColumn(
                    layout: rowColumnType,
                    children: [
                      ResponsiveRowColumnItem(
                        rowFlex: 1,
                        rowFit: FlexFit.tight,
                        child: Container(
                          margin: isdesktop
                              ? EdgeInsets.only(right: 20, top: 15)
                              : EdgeInsets.only(bottom: 20, top: 15),
                          decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0),
                                  blurRadius: 0,
                                  offset: const Offset(0, 0),
                                )
                              ],
                              border: const Border(
                                  bottom: BorderSide(
                                    color: AppColors.input_underline_color,
                                    width: 1.0,
                                  ))),
                          child: InkWell(
                            focusColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            splashColor: Colors.transparent,
                            onTap: () async {
                              final result = await FilePicker.platform
                                  .pickFiles(
                                  type: FileType.custom,
                                  allowedExtensions: ['jpeg', 'png', 'jpg'],
                                  allowMultiple: false);

                              if (result!.files.first != null) {
                                var fileBytes = result.files.first.bytes;
                                controller.file_name.value =
                                    result.files.first.name;
                                controller.fileData.value =
                                    base64.encode(fileBytes!); //
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.only(left: 0),
                              //height: 47,
                              child: Row(children: [
                                Expanded(
                                    flex: 2,
                                    child: Container(
                                        alignment: Alignment.bottomLeft,
                                        child: Padding(
                                          padding:
                                          EdgeInsets.only(bottom: 15.0),
                                          child: Text(
                                            getStringTranslate("choose_file"),
                                            style:
                                            TextStyle(color: Colors.grey),
                                          ),
                                        ))),
                                Expanded(
                                    flex: 5,
                                    child: Container(
                                        margin: const EdgeInsets.only(right: 1),
                                        //height: 47,
                                        color: Colors.transparent,
                                        alignment: Alignment.bottomRight,
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                              bottom: 15.0),
                                          child: Text(
                                              controller.file_name.value,
                                              style: const TextStyle(
                                                  color: Colors.grey)),
                                        )))
                              ]),
                            ),
                          ),
                        ),
                      ),
                      ResponsiveRowColumnItem(
                        rowFlex: 1,
                        rowFit: FlexFit.tight,
                        child: Container(
                          decoration: ThemeHelper().inputBoxDecorationShaddow(),
                          child: ExpandableTextField(
                            child: TextField(
                              controller: controller.assetimage_controller,
                              maxLines: 1,
                              textAlign: TextAlign.start,
                              style: TextStyle(fontSize: 14),
                              decoration: ThemeHelper().textInputDecoration(
                                  getStringTranslate('asset_image'),
                                  getStringTranslate('enter_url')),
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.jobTitle],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  size20,
                  ResponsiveRowColumn(
                    layout: rowColumnType,
                    children: [
                      if (controller.uoms.value.isNotEmpty)
                        ResponsiveRowColumnItem(
                          rowFlex: 1,
                          rowFit: FlexFit.tight,
                          child: Container(
                            width: double.infinity,
                            margin: isdesktop
                                ? EdgeInsets.only(right: 20)
                                : EdgeInsets.only(bottom: 20),
                            child: Common.myDropDownWidget(
                                labelText: getStringTranslate('uom') + " *",
                                items: controller.uoms.value,
                                selectedValue: controller.selectUom.value,
                                onChange: (value) {
                                  controller.selectUom.value = value;
                                }),
                          ),
                        ),
                      if (controller.inspections.value.isNotEmpty)
                        ResponsiveRowColumnItem(
                          rowFlex: 1,
                          rowFit: FlexFit.tight,
                          child: Container(
                            child: Common.myDropDownWidget(
                                labelText:
                                getStringTranslate('inspection_type') +
                                    " *",
                                items: controller.inspections.value,
                                selectedValue:
                                controller.selectInspectionType.value,
                                onChange: (value) {
                                  controller.selectInspectionType.value = value;
                                }),
                          ),
                        ),
                    ],
                  ),
                  size20,
                  ResponsiveRowColumn(
                    layout: rowColumnType,
                    children: [
                      ResponsiveRowColumnItem(
                        rowFlex: 1,
                        rowFit: FlexFit.tight,
                        child: Container(
                          width: double.infinity,
                          margin: isdesktop
                              ? EdgeInsets.only(right: 20)
                              : EdgeInsets.only(bottom: 20),
                          decoration: ThemeHelper().inputBoxDecorationShaddow(),
                          child: TextField(
                            controller:
                            controller.frequencyinspemonth_controller,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 14),
                            decoration: ThemeHelper().textInputDecoration(
                                getStringTranslate(
                                    'frequency_of_inspection_months') +
                                    " *",
                                getStringTranslate(
                                    'enter_frequency_of_inspection') +
                                    " *"),
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                      ),
                      ResponsiveRowColumnItem(
                        rowFlex: 1,
                        rowFit: FlexFit.tight,
                        child: Container(
                          decoration: ThemeHelper().inputBoxDecorationShaddow(),
                          child: TextField(
                            controller:
                            controller.frequencyinspedays_controller,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.start,
                            style: TextStyle(fontSize: 14),
                            decoration: ThemeHelper().textInputDecoration(
                                getStringTranslate(
                                    'frequency_of_inspection_hours'),
                                getStringTranslate(
                                    'enter_freq_inspection_hour')),
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.jobTitle],
                          ),
                        ),
                      ),
                    ],
                  ),
                  size20,
                  ResponsiveRowColumn(
                    layout: rowColumnType,
                    children: [
                      ResponsiveRowColumnItem(
                        rowFlex: 1,
                        rowFit: FlexFit.tight,
                        child: Container(
                          width: double.infinity,
                          margin: isdesktop
                              ? EdgeInsets.only(right: 20)
                              : EdgeInsets.only(bottom: 20),
                          decoration: ThemeHelper().inputBoxDecorationShaddow(),
                          child: TextField(
                            controller: controller.dueperioddays_controller,
                            keyboardType: TextInputType.number,
                            style: TextStyle(fontSize: 14),
                            decoration: ThemeHelper().textInputDecoration(
                                getStringTranslate('due_period_(in_days)'),
                                getStringTranslate(
                                    'enter_due_period_(in_days)')),
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                      ),
                      ResponsiveRowColumnItem(
                        rowFlex: 1,
                        rowFit: FlexFit.tight,
                        child: Container(
                          decoration: ThemeHelper().inputBoxDecorationShaddow(),
                          child: ExpandableTextField(
                            child: TextField(
                              controller:
                              controller.ectypecertificate_controller,
                              textAlign: TextAlign.start,
                              style: TextStyle(fontSize: 14),
                              decoration: ThemeHelper().textInputDecoration(
                                  getStringTranslate('ec_type_certificate'),
                                  getStringTranslate(
                                      'enter_ec_type_certificate')),
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.jobTitle],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  size20,
                  ResponsiveRowColumn(
                    layout: rowColumnType,
                    children: [
                      ResponsiveRowColumnItem(
                        rowFlex: 1,
                        rowFit: FlexFit.tight,
                        child: Container(
                          width: double.infinity,
                          margin: isdesktop
                              ? EdgeInsets.only(right: 20)
                              : EdgeInsets.only(bottom: 20),
                          decoration: ThemeHelper().inputBoxDecorationShaddow(),
                          child: TextField(
                            controller: controller.lifespanmonth_controller,
                            keyboardType: TextInputType.number,
                            style: TextStyle(fontSize: 14),
                            decoration: ThemeHelper().textInputDecoration(
                                getStringTranslate('life_span_product_months'),
                                getStringTranslate('enter') +
                                    " " +
                                    getStringTranslate(
                                        'life_span_product_months')),
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                      ),
                      ResponsiveRowColumnItem(
                        rowFlex: 1,
                        rowFit: FlexFit.tight,
                        child: Container(
                          decoration: ThemeHelper().inputBoxDecorationShaddow(),
                          child: TextField(
                            controller: controller.lifespanhour_controller,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.start,
                            style: TextStyle(fontSize: 14),
                            decoration: ThemeHelper().textInputDecoration(
                                getStringTranslate(
                                    'life_span_of_product_hours'),
                                getStringTranslate('enter') +
                                    " " +
                                    getStringTranslate(
                                        'life_span_of_product_hours')),
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.jobTitle],
                          ),
                        ),
                      ),
                    ],
                  ),
                  size20,
                  ResponsiveRowColumn(
                    layout: rowColumnType,
                    children: [
                      ResponsiveRowColumnItem(
                        rowFlex: 1,
                        rowFit: FlexFit.tight,
                        child: Container(
                          width: double.infinity,
                          margin: isdesktop
                              ? EdgeInsets.only(right: 20)
                              : EdgeInsets.only(bottom: 20),
                          decoration: ThemeHelper().inputBoxDecorationShaddow(),
                          child: TextField(
                            controller:
                            controller.frequencyinspection_controller,
                            keyboardType: TextInputType.number,
                            style: TextStyle(fontSize: 14),
                            decoration: ThemeHelper().textInputDecoration(
                                getStringTranslate(
                                    'preventive_maintenance_hour'),
                                getStringTranslate('enter') +
                                    " " +
                                    getStringTranslate(
                                        'preventive_maintenance_hour')),
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                      ),
                      ResponsiveRowColumnItem(
                        rowFlex: 1,
                        rowFit: FlexFit.tight,
                        child: Container(
                          decoration: ThemeHelper().inputBoxDecorationShaddow(),
                          child: TextField(
                            controller: controller.freqprevmaint_controller,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.start,
                            style: TextStyle(fontSize: 14),
                            decoration: ThemeHelper().textInputDecoration(
                                getStringTranslate(
                                    'preventive_maintenance_days'),
                                getStringTranslate('enter') +
                                    " " +
                                    getStringTranslate(
                                        'preventive_maintenance_days')),
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.jobTitle],
                          ),
                        ),
                      ),
                    ],
                  ),
                  size20,
                  ResponsiveRowColumn(
                    layout: rowColumnType,
                    children: [
                      ResponsiveRowColumnItem(
                        rowFlex: 1,
                        rowFit: FlexFit.tight,
                        child: Container(
                          width: double.infinity,
                          margin: isdesktop
                              ? EdgeInsets.only(right: 20)
                              : EdgeInsets.only(bottom: 20),
                          child: Common.myDropDownWidget(
                              labelText:
                              getStringTranslate('knowledge_tree_status') +
                                  " *",
                              items: controller.statusArr!,
                              selectedValue:
                              controller.selectKnowledgetree.value,
                              onChange: (value) {
                                controller.selectKnowledgetree.value = value;
                              }),
                        ),
                      ),
                      if (controller.standardArr.value.isNotEmpty)
                        ResponsiveRowColumnItem(
                          rowFlex: 1,
                          rowFit: FlexFit.tight,
                          child: Container(
                            child: Common.myDropDownWidget(
                                labelText: getStringTranslate('standards'),
                                items: controller.standardArr.value,
                                selectedValue: controller.selectStandard.value,
                                onChange: (value) {
                                  controller.selectStandard.value = value;
                                }),
                          ),
                        ),
                    ],
                  ),
                  size20,
                  ResponsiveRowColumn(
                    layout: rowColumnType,
                    children: [
                      if (controller.bodyTestReportArr.value.isNotEmpty)
                        ResponsiveRowColumnItem(
                          rowFlex: 1,
                          rowFit: FlexFit.tight,
                          child: Container(
                            margin: isdesktop
                                ? EdgeInsets.only(right: 20)
                                : EdgeInsets.only(bottom: 20),
                            child: Common.myDropDownWidget(
                                labelText: getStringTranslate(
                                    'notified_body_test_report'),
                                items: controller.bodyTestReportArr.value,
                                selectedValue:
                                controller.selectBodyTestrprt.value,
                                onChange: (value) {
                                  controller.selectBodyTestrprt.value = value;
                                }),
                          ),
                        ),
                      if (controller.articleArr.value.isNotEmpty)
                        ResponsiveRowColumnItem(
                          rowFlex: 1,
                          rowFit: FlexFit.tight,
                          child: Container(
                            child: Common.myDropDownWidget(
                                labelText: getStringTranslate(
                                    'notified_body_article_11b'),
                                items: controller.articleArr.value,
                                selectedValue:
                                controller.select11bArticle.value,
                                onChange: (value) {
                                  controller.select11bArticle.value = value;
                                }),
                          ),
                        ),
                    ],
                  ),
                  size20,
                  ResponsiveRowColumn(
                    layout: rowColumnType,
                    children: [
                      if (controller.assetTypeArr.value.isNotEmpty)
                        ResponsiveRowColumnItem(
                          rowFlex: 1,
                          rowFit: FlexFit.tight,
                          child: Container(
                            width: double.infinity,
                            margin: isdesktop
                                ? EdgeInsets.only(right: 20)
                                : EdgeInsets.only(bottom: 20),
                            child: Common.myDropDownWidget(
                                labelText: getStringTranslate(
                                    'asset_type_(sensor_only)'),
                                items: controller.assetTypeArr.value,
                                selectedValue: controller.selectAssetType.value,
                                onChange: (value) {
                                  controller.selectAssetType.value = value;
                                }),
                          ),
                        ),
                      if (controller.assetCategoryArr.value.isNotEmpty)
                        ResponsiveRowColumnItem(
                          rowFlex: 1,
                          rowFit: FlexFit.tight,
                          child: Container(
                            child: Common.myDropDownWidget(
                                labelText: getStringTranslate('asset_category'),
                                items: controller.assetCategoryArr.value,
                                selectedValue:
                                controller.selectAssetCategory.value,
                                onChange: (value) {
                                  controller.selectAssetCategory.value = value;
                                }),
                          ),
                        ),
                    ],
                  ),
                  size20,

                  ResponsiveRowColumn(
                    rowMainAxisAlignment: MainAxisAlignment.start,
                    rowCrossAxisAlignment: CrossAxisAlignment.start,
                    layout: rowColumnType,
                    children: [

                      // ================= EXPECTED RESULTS =================
                      ResponsiveRowColumnItem(
                        rowFlex: 1,
                        rowFit: FlexFit.tight,
                        child: Container(
                          width: double.infinity,
                          margin: isdesktop
                              ? const EdgeInsets.only(right: 20)
                              : const EdgeInsets.only(bottom: 20),
                          child: controller.refreshExpectResult.value
                              ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [

                              // -------- Expected Results Dropdown --------
                              Expanded(
                                child: MultiSelectDialogField(
                                  searchable: true,

                                  items: controller.expectedData.value,
                                  // ✅ already MultiSelectItem
                                  initialValue: controller.selectExpectedResults
                                      .value,
                                  title: Text(
                                    getStringTranslate("expected_results") +
                                        " *",
                                  ),
                                  selectedColor: AppColors.app_main_dark_color,
                                  separateSelectedItems: true,
                                  selectedItemsTextStyle: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.black,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: Colors.transparent,
                                    border: Border(
                                      bottom: BorderSide(
                                        width: 1,
                                        color: AppColors.input_underline_color,
                                      ),
                                    ),
                                  ),
                                  buttonIcon: const Icon(Icons.arrow_drop_down),
                                  buttonText: Text(
                                    getStringTranslate("expected_results") +
                                        " *",
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  onConfirm: (results) {
                                    controller.selectExpectedResults.value =
                                        List.from(results);
                                  },
                                ),
                              ),

                              // -------- Reorder Button --------
                              Container(
                                margin: const EdgeInsets.only(top: 15),
                                child: Common.myInkWell(
                                  ontap: () async {
                                    final reorderedList =
                                    await showDialog<List<dynamic>>(
                                      context: context,
                                      builder: (context) {
                                        return ReorderableListDialog(
                                          items: controller
                                              .selectExpectedResults.value,
                                        );
                                      },
                                    );

                                    if (reorderedList != null) {
                                      await controller
                                          .refreshOrderExpected(reorderedList);
                                    }
                                  },
                                  child: const Icon(Icons.reorder_outlined),
                                ),
                              ),
                            ],
                          )
                              : const Padding(
                            padding: EdgeInsets.only(top: 10),
                            child: Center(
                              child: Text("Expected Results Loading..."),
                            ),
                          ),
                        ),
                      ),

                      // ================= SUB ASSETS =================
                      ResponsiveRowColumnItem(
                        rowFlex: 1,
                        rowFit: FlexFit.tight,
                        child: controller.refreshSubAsset.value
                            ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [

                            // -------- Sub Asset Dropdown --------
                            Expanded(
                              child: MultiSelectDialogField(
                                searchable: true,

                                items: controller.subAssetData.value,
                                // ✅ already MultiSelectItem
                                initialValue: controller.selectSubAsset.value,
                                title: Text(
                                  getStringTranslate("sub_asset") + " *",
                                ),
                                selectedColor: AppColors.app_main_dark_color,
                                separateSelectedItems: true,
                                selectedItemsTextStyle: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black,
                                ),
                                decoration: const BoxDecoration(
                                  color: Colors.transparent,
                                  border: Border(
                                    bottom: BorderSide(
                                      width: 1,
                                      color: AppColors.input_underline_color,
                                    ),
                                  ),
                                ),
                                buttonIcon: const Icon(Icons.arrow_drop_down),
                                buttonText: Text(
                                  getStringTranslate("sub_asset") + " *",
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                                onConfirm: (results) {
                                  controller.selectSubAsset.value =
                                      List.from(results);
                                },
                              ),
                            ),

                            // -------- Reorder Button --------
                            Container(
                              margin: const EdgeInsets.only(top: 15),
                              child: Common.myInkWell(
                                ontap: () async {
                                  final reorderedList =
                                  await showDialog<List<dynamic>>(
                                    context: context,
                                    builder: (context) {
                                      return ReorderableListDialog(
                                        items: controller.selectSubAsset.value,
                                      );
                                    },
                                  );

                                  if (reorderedList != null) {
                                    await controller
                                        .refreshOrderSubAsset(reorderedList);
                                  }
                                },
                                child: const Icon(Icons.reorder_outlined),
                              ),
                            ),
                          ],
                        )
                            : const Padding(
                          padding: EdgeInsets.only(top: 10),
                          child: Center(
                            child: Text("Sub Assets Loading..."),
                          ),
                        ),
                      ),
                    ],
                  ),

                  size20,
                  ResponsiveRowColumn(
                    layout: rowColumnType,
                    children: [
                      if (controller.assetTemplateArr.value.isNotEmpty)
                        ResponsiveRowColumnItem(
                          rowFlex: 1,
                          rowFit: FlexFit.tight,
                          child: Container(
                            width: double.infinity,
                            margin: isdesktop
                                ? EdgeInsets.only(right: 20)
                                : EdgeInsets.only(bottom: 20),
                            child: Common.myDropDownWidget(
                                labelText:
                                getStringTranslate('asset_template_type'),
                                items: controller.assetTemplateArr.value,
                                selectedValue:
                                controller.selectAssetTemplate.value,
                                onChange: (value) {
                                  controller.selectAssetTemplate.value = value;
                                }),
                          ),
                        ),
                      ResponsiveRowColumnItem(
                        rowFlex: 1,
                        rowFit: FlexFit.tight,
                        child: Container(
                          decoration: ThemeHelper().inputBoxDecorationShaddow(),
                          child: TextField(
                            controller: controller.assetname_controller,
                            textAlign: TextAlign.start,
                            style: const TextStyle(fontSize: 14),
                            decoration: ThemeHelper().textInputDecoration(
                                "Asset Name", "Enter Asset Name"),
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.jobTitle],
                          ),
                        ),
                      ),
                    ],
                  ),
                  size20,
                  ResponsiveRowColumn(
                    layout: rowColumnType,
                    children: [
                      ResponsiveRowColumnItem(
                        rowFlex: 1,
                        rowFit: FlexFit.tight,
                        child: Container(
                          width: double.infinity,
                          margin: isdesktop
                              ? EdgeInsets.only(right: 20)
                              : EdgeInsets.only(bottom: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  getStringTranslate("inspection"),
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.black),
                                ),
                              ),
                              Common.returnSwitch(
                                  controller.inspectionValue.value ? 1 : 0,
                                  getStringTranslate("no"),
                                  getStringTranslate("yes"), (index) {
                                controller.inspectionValue.value = index == 1;
                              }),
                            ],
                          ),
                        ),
                      ),
                      ResponsiveRowColumnItem(
                        rowFlex: 1,
                        rowFit: FlexFit.tight,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                getStringTranslate("repair"),
                                style: TextStyle(
                                    fontSize: 16, color: Colors.black),
                              ),
                            ),
                            Common.returnSwitch(
                                controller.repairValue.value ? 1 : 0,
                                getStringTranslate("no"),
                                getStringTranslate("yes"), (index) {
                              controller.repairValue.value = index == 1;
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                  size20,
                  ResponsiveRowColumn(
                    layout: rowColumnType,
                    children: [
                      ResponsiveRowColumnItem(
                        rowFlex: 1,
                        rowFit: FlexFit.tight,
                        child: Container(
                          width: double.infinity,
                          margin: isdesktop
                              ? EdgeInsets.only(right: 20)
                              : EdgeInsets.only(bottom: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  getStringTranslate("geo_fencing"),
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.black),
                                ),
                              ),
                              Common.returnSwitch(
                                  controller.geofencingValue.value ? 1 : 0,
                                  getStringTranslate("no"),
                                  getStringTranslate("yes"), (index) {
                                controller.geofencingValue.value = index == 1;
                              }),
                            ],
                          ),
                        ),
                      ),
                      ResponsiveRowColumnItem(
                        rowFlex: 1,
                        rowFit: FlexFit.tight,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                getStringTranslate("work_permit"),
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            Common.returnSwitch(
                                controller.workPermitValue.value ? 1 : 0,
                                getStringTranslate("no"),
                                getStringTranslate("yes"), (index) {
                              controller.workPermitValue.value = index == 1;
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                  size20,
                  SizedBox(
                    height: isdesktop ? 35 : 45,
                    width: isdesktop ? 200 : double.infinity,
                    child: Common.myButton(
                        textLabel: getStringTranslate('save'),
                        radius: 0,
                        mCallback: () {
                          if (controller.assetcode_controller.text.isEmpty ||
                              controller.description_controller.text.isEmpty ||
                              controller.selectUom.value == null ||
                              controller.selectInspectionType.value == null ||
                              controller.selectExpectedResults.value.isEmpty) {
                            scaffoldMessenger.showSnackBar(const SnackBar(
                                content: Text(
                                    "Please enter or select mandatory field")));
                            return;
                          }
                          editAsset();
                        }),
                  ),
                ],
              ),
            ),
          ),
        ));
  }

  getStringTranslate(key) {
    if (contxt != null) {
      return getResStr(key, contxt!);
    } else {
      return key;
    }
  }

  editAsset() async {

    // --- Safe extraction of ExpectedModel IDs ---
    List<int> expectresultstr = [];
    for (final element in controller.selectExpectedResults) {
      if (element is ExpectedModel && element.type_id != null) {
        expectresultstr.add(element.type_id!);
      }
    }

// --- Safe extraction of Typedata IDs ---
    List<int> subassetstr = [];
    for (final element in controller.selectSubAsset) {
      if (element is Typedata && element.typeId != null) {
        subassetstr.add(element.typeId!);
      }
    }

    // --- Step 3: Prepare image ---
    var fileData = controller.fileData.isNotEmpty
        ? "data:image/png;base64,${controller.fileData.value}"
        : controller.assetimage_controller.text;

    // --- Step 4: Build API payload ---
    Map datapost = {
      "component_code": controller.assetcode_controller.text,
      "component_name": controller.assetname_controller.text ?? "",
      "component_alias": controller.assetalias_controller.text,
      "component_ean": controller.assetean_controller.text,
      "component_description": controller.description_controller.text,
      "component_frequency_asset": controller.frequencyinspemonth_controller
          .text,
      "component_due_period": controller.dueperioddays_controller.text,
      "freq_hours": controller.frequencyinspection_controller.text,
      "component_frequency_hours": controller.frequencyinspedays_controller
          .text,
      "component_lifespan_month": controller.lifespanmonth_controller.text,
      "component_lifespan_hours": controller.lifespanhour_controller.text,
      "component_pdm_frequency": controller.freqprevmaint_controller.text,
      "ec_type_certificate_text": controller.ectypecertificate_controller.text,
      if (controller.refreshSubAsset.value) "component_sub_assets": subassetstr,
      if (controller.refreshExpectResult.value)
        "component_expectedresult": expectresultstr,
      "component_type": controller.selectAssetType.value != null
          ? controller.selectAssetType.value!.typeId
          : "",
      if (controller.selectUom.value != null)
        "component_uom": controller.selectUom.value?.typeId,
      if (controller.selectInspectionType.value != null)
        "component_inspectiontype": controller.selectInspectionType.value
            ?.typeId,
      "component_repair": controller.repairValue.value ? Common.yes : Common.no,
      "component_inspection":
      controller.inspectionValue.value ? Common.yes : Common.no,
      "component_geo_fancing":
      controller.geofencingValue.value ? Common.yes : Common.no,
      "component_work_permit":
      controller.workPermitValue.value ? Common.yes : Common.no,
      if (controller.selectAssetCategory.value != null)
        "component_category": controller.selectAssetCategory.value?.typeId,
      "status": controller.status.value,
      "kt_status": controller.selectKnowledgetree.value,
      if (controller.selectStandard.value != null)
        "standard_certificate_id": controller.selectStandard.value?.typeId,
      "component_template_type": controller.selectAssetTemplate.value != null
          ? controller.selectAssetTemplate.value?.typeName
          : "",
      if (controller.selectBodyTestrprt.value != null)
        "notified_body_certificate_id":
        controller.selectBodyTestrprt.value?.typeId,
      if (controller.select11bArticle.value != null)
        "article_11b_certificate_id": controller.select11bArticle.value?.typeId,
      "component_image": fileData ?? ""
    };

    var body = json.encode(datapost);
    Common.printLog("=== API Payload ===");
    Common.printLog(body.toString());

    // --- Step 5: Make API request ---
    String url = ApisFile().client_Update_Asset_api +
        controller.assetData.value!.component_id.toString();
    Common.printLog("API URL: $url");

    final response = await ApisRequests().makePutRequest(url, body);
    Map<String, dynamic> mapData = jsonDecode(response.body);

    Common.printLog("API Response: $mapData");

    // --- Step 6: Handle response ---
    if (response.statusCode == 200) {
      if (mapData['ststus'] == 'success') {
        Common.disposeController<EditAssetsController>();
        Navigator.pop(contxt!, mapData['ststus']);
      }
      scaffoldMessenger
          .showSnackBar(SnackBar(content: Text("${mapData['message']}")));
    } else {
      Common.printLog("API Error: ${response.body}");
      scaffoldMessenger
          .showSnackBar(SnackBar(content: Text(mapData['message'] ?? "Error")));
    }
  }
}


//-----------------------------------***********
