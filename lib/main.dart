import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_apns/flutter_apns.dart';
import 'package:sendbird_flutter/screens/channel/channel_screen.dart';
import 'package:sendbird_flutter/screens/channel_info/channel_info_screen.dart';
import 'package:sendbird_flutter/screens/channel_list/channel_list_screen.dart';
import 'package:sendbird_flutter/screens/create_channel/create_channel_screen.dart';
import 'package:sendbird_flutter/screens/login/login_screen.dart';
import 'package:sendbird_flutter/styles/color.dart';
import 'package:sendbird_flutter/utils/notification_service.dart';
import 'package:sendbird_sdk/sendbird_sdk.dart';
import 'package:fluttertoast/fluttertoast.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)..maxConnectionsPerHost = 10;
  }
}

final GlobalKey<NavigatorState> navigatorKey = new GlobalKey<NavigatorState>();
final sendbird = SendbirdSdk(appId: '77B002CB-6071-43CE-83A9-6D30E21EB5C6');
final connector = createPushConnector();
final appState = AppState();

class AppState with ChangeNotifier {
  bool didRegisterToken = false;
  String? token;
  String? destChannelUrl;

  void setDestination(String? channelUrl) {
    destChannelUrl = channelUrl;
    notifyListeners();
  }
}

void main() {
  HttpOverrides.global = MyHttpOverrides();
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  final PushConnector connector = createPushConnector();

  Future<void> _register() async {
    final connector = this.connector;
    connector.configure(
      onLaunch: (data) async {
        //launch
        print('onLaunch: $data');
        final rawData = data.data;
        Fluttertoast.showToast(msg: rawData['sendbird']['channel']['channel_url'], toastLength: Toast.LENGTH_LONG);
        appState.setDestination(rawData['sendbird']['channel']['channel_url']);
      },
      onMessage: (data) async {
        //terminated? background
        print('onMessage: $data');
      },
      onResume: (data) async {
        //called when user tap on push notification
        print('onResume');
        final rawData = data.data;
        appState.setDestination(rawData['sendbird']['channel']['channel_url']);
      },
      onBackgroundMessage: handleBackgroundMessage,
    );
    connector.token.addListener(() {
      print('Token ${connector.token.value}');
      appState.token = connector.token.value;
    });
    connector.requestNotificationPermissions();
  }

  @override
  void initState() {
    _register();
    super.initState();
  }

  String initialRoute() {
    // TODO: Switch initial view between login or channel list, depending on prior
    // login state.
    return "/";
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      initialRoute: initialRoute(),
      navigatorKey: navigatorKey,
      onGenerateRoute: (settings) {
        var routes = <String, WidgetBuilder>{
          '/': (context) => LoginScreen(),
          '/channel_list': (context) => ChannelListScreen(),
          '/create_channel': (context) => CreateChannelScreen(),
          '/channel_info': (context) =>
              ChannelInfoScreen(channel: settings.arguments as GroupChannel),
          '/channel': (context) =>
              ChannelScreen(channelUrl: settings.arguments as String),
        };
        WidgetBuilder builder = routes[settings.name]!;
        return MaterialPageRoute(
          settings: settings,
          builder: (ctx) => builder(ctx),
        );
      },
      theme: ThemeData(
        fontFamily: "Gellix",
        primaryColor: Color(0xff742DDD),
        buttonColor: Color(0xff742DDD),
        accentColor: SBColors.primary_300,
        textTheme: TextTheme(
            headline1: TextStyle(fontSize: 72.0, fontWeight: FontWeight.bold),
            headline6: TextStyle(fontSize: 32.0, fontWeight: FontWeight.bold)),
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: Color(0xff732cdd),
          selectionHandleColor: Color(0xff732cdd),
          selectionColor: Color(0xffD1BAF4),
        ),
      ),
    );
  }
}

Future<dynamic> handleBackgroundMessage(RemoteMessage data) async {
  print('onBackground $data'); // android only for firebase_messaging v7
  NotificationService.showNotification(
    json.decode(data.data['sendbird'])['sender']['name'],
    json.decode(data.data['sendbird'])['message'],
    payload: data.data['sendbird'],
  );
}
