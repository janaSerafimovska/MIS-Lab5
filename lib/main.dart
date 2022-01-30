import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:lab3/login_screen.dart';
import 'package:lab3/map_screen.dart';
import 'package:lab3/register_screen.dart';
import 'package:lab3/slots_view.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as timeZone;

import 'home_page.dart';

late User loggedInUser;
late FirebaseMessaging _firebaseMessaging;
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance channel',
  'Exams Reminder',
  description: 'You have a exam comming soon! Tap and see your schedule',
  importance: Importance.high,
  playSound: true,
);
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  _firebaseMessaging = FirebaseMessaging.instance;
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true, badge: true, sound: true);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Slot organizer',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
      ),
      initialRoute: LoginScreen.id,
      routes: {
        '/': (context) => const MyAppClass(),
        LoginScreen.id: (context) => const LoginScreen(),
        RegistrationScreen.id: (context) => const RegistrationScreen(),
        HomeScreen.id: (context) => const HomeScreen(),
        '/map': (context) => const MapScreen(channel: channel),
      },
    );
  }
}

class MyAppClass extends StatefulWidget {
  const MyAppClass({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyAppClass> {
  final _auth = FirebaseAuth.instance;
  final _store = FirebaseFirestore.instance;

  final predmetController = TextEditingController();
  final datumController = TextEditingController();

  List<Map<String, String>> elements = [];
  List<Map<String, String>> _selectedElements = [];


  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  void getCurrentUserAndData() async {
    try {
      final user = await _auth.currentUser;
      if (user != null) {
        loggedInUser = user;
        _store
            .collection('Exams')
            .where('UserEmail', isEqualTo: user.email)
            .get()
            .then((value) {
          for (var element in value.docs) {
            Map<String, String> slot = {
              "predmet": element.data()['Predmet'] as String,
              "termin": element.data()['Termin'] as String
            };
            setState(() {
              elements.add(slot);
            });
          }
        });
      }
    } catch (e) {}
  }

  void addSubject() async {
    String name = predmetController.text;
    String termin = datumController.text;

    Map<String, String> newSlot = {
      "Predmet": name,
      "Termin": termin,
      "UserEmail": loggedInUser.email.toString()
    };
    await _store.collection('Exams').doc().set(newSlot);
    setState(() {
      elements.add({"predmet": name, "termin": termin});
    });

    var parser = DateFormat('dd.MM.yyyy hh:mm');
    var terminParsed = parser.parse("${termin}T07:00");

    flutterLocalNotificationsPlugin.schedule(
      1,
      'Slot organizer',
      'You have an exam today. Tap to see your full schedule',
      timeZone.TZDateTime.from(terminParsed, timeZone.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          color: const Color(0xff676FA3),
          playSound: true,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      androidAllowWhileIdle: true,
    );
  }

  List<Map<String, String>> _getEventsForDay(DateTime day) {
    List<Map<String, String>> filteredElements = [];
    elements.forEach((element) {
      var parser = DateFormat('dd.MM.yyyy');
      var termin = parser.parse(element['termin'] as String);

      if (termin.toString() == day.toString().replaceAll("Z", "")) {
        filteredElements.add(element);
      }
    });
    return filteredElements;
  }

  _MyAppState();

  @override
  void initState() {
    super.initState();
    Firebase.initializeApp().whenComplete(() {
      setState(() {});
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? androidNotification = message.notification?.android;

      if (notification != null && androidNotification != null) {
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
              android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            color: const Color(0xff676FA3),
            playSound: true,
            icon: '@mipmap/ic_launcher',
          )),
        );
      }
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? androidNotification = message.notification?.android;

      if (notification != null && androidNotification != null) {
        showDialog(
          context: context,
          builder: (_) {
            return AlertDialog(
              title: Text(notification.title != null
                  ? notification.title!
                  : 'Exam Organizer'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(notification.body != null
                        ? notification.body!
                        : 'You have an exam coming soon! Tap nd see your schedule')
                  ],
                ),
              ),
            );
          },
        );
      }
    });
    getCurrentUserAndData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Flex(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          direction: Axis.vertical,
          clipBehavior: Clip.hardEdge,
          children: [
            TableCalendar(
              firstDay: DateTime.utc(2021, 1, 1),
              lastDay: DateTime.utc(2030, 3, 14),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (DateTime selectedDay, DateTime focusedDay) {
                if (!isSameDay(_selectedDay, selectedDay)) {
                  setState(() {
                    _focusedDay = focusedDay;
                    _selectedDay = selectedDay;
                    _selectedElements = _getEventsForDay(selectedDay);
                  });
                }
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (context) => SingleChildScrollView(
                    child: Container(
                      height: 400,
                      padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).viewInsets.bottom),
                      child: SlotsView(
                        elements: _selectedElements,
                      ),
                    ),
                  ),
                );
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
              },
              eventLoader: _getEventsForDay,
            ),
            Expanded(
              child: Card(
                elevation: 5,
                margin: const EdgeInsets.all(15),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(5),
                      child: Text(
                        'Vnesi predmet',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(5),
                      child: TextField(
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Ime na predmet',
                        ),
                        controller: predmetController,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(5),
                      child: TextField(
                        decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Datum na polaganje',
                            hintText: 'Ex: 25.02.2022'),
                        controller: datumController,
                      ),
                    ),
                    Material(
                      borderRadius: BorderRadius.circular(15.0),
                      color: const Color(0xff676FA3),
                      child: MaterialButton(
                        onPressed: () => addSubject(),
                        child: const Text(
                          'Add new exam',
                          style: TextStyle(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ), // child:
    );
  }
}
