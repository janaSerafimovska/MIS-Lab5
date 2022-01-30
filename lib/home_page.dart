import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lab3/event.dart';

class HomeScreen extends StatefulWidget {
  static String id = "/home";

  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _auth = FirebaseAuth.instance;
  final _store = FirebaseFirestore.instance;
  List<Event> events = [];


  @override
  void initState() {
    super.initState();

    try {
      final user = _auth.currentUser;
      if (user != null) {
        _store
            .collection('Events')
            .where('userEmail', isEqualTo: user.email)
            .get()
            .then((value) {
          for (var element in value.docs) {
            events.add(Event(
              element.data()['address'] as String,
              element.data()['lat'],
              element.data()['long'],
              element.data()['reminderMessage'] as String,
              element.data()['userEmail'] as String,
            ));
          }
        });
      }
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(25.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Material(
                elevation: 5.0,
                color: const Color(0xffBAABDA),
                borderRadius: BorderRadius.circular(30.0),
                child: MaterialButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/');
                  },
                  minWidth: 200.0,
                  height: 42.0,
                  child: const Text(
                    'Show calendar',
                    style: TextStyle(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 20,
              ),
              Material(
                elevation: 5.0,
                color: const Color(0xffBAABDA),
                borderRadius: BorderRadius.circular(30.0),
                child: MaterialButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/map', arguments: events);
                  },
                  minWidth: 200.0,
                  height: 42.0,
                  child: const Text(
                    'Show map',
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
    );
  }
}
