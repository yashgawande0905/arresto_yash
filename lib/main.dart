import 'package:flutter/material.dart';
import 'app_utility/methods.dart';
import 'models/flavour_config.dart';
import 'myApp.dart';

const baseColor = Color.fromRGBO(84, 83, 85, 1);
const baseColorDark = Color.fromRGBO(130, 130, 131, 1);

main() async {
  FlavorConfig(
    name: 'Arresto',
    values: FlavorValues(
      // id: '11823133',
      logo: 'assets/images/logo.png',
      appType: AppType.dev,
        clientGroup: [],
      lightTheme: simpleLightTheme(baseColor),
      darkTheme: simpleDarkTheme(baseColor),
      customUrlScheme: 'Arresto',
      deepLinkUrl: ""
    ),
  );
  await runArrestoApp();
}
