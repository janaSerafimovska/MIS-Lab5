import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_google_places/flutter_google_places.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_webservice/places.dart';
import 'package:lab3/constants.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart'
as bg;
import 'package:geolocator/geolocator.dart';
import 'package:lab3/event.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'main.dart';

late User loggedInUser;

class MapScreen extends StatefulWidget {
  final AndroidNotificationChannel channel;

  const MapScreen({Key? key, required this.channel}) : super(key: key);

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  var _homeLocation;
  var _homeLatitude;
  var _homeLongitude;
  var _destinationLocation;
  var _destinationLatitude;
  var _destinationLongitude;
  late Position _currentPosition;

  final _places = GoogleMapsPlaces(apiKey: apiKey);
  final reminderController = TextEditingController();

  final LatLng _center = const LatLng(41.9981, 21.4254);
  late GoogleMapController mapController;
  late PolylinePoints polylinePoints;
  List<LatLng> polylineCoordinates = [];
  Map<PolylineId, Polyline> polylines = {};

  final _auth = FirebaseAuth.instance;
  final _store = FirebaseFirestore.instance;
  List<Event> events = [];

  Set<Marker> getMarkers() {
    getEventsForUser();
    Set<Marker> markers = {};
    for (final event in events) {
      final marker = Marker(
          markerId: MarkerId(event.reminderMessage),
          position: LatLng(event.lat, event.long),
          infoWindow: InfoWindow(
            title: event.reminderMessage,
            snippet: event.address,
          ),
          onTap: () {
            setState(() {
              _destinationLocation = event.address;
              _destinationLatitude = event.lat;
              _destinationLongitude = event.long;

              polylines.clear();
              polylineCoordinates.clear();
              _createPolylines(
                  _currentPosition.latitude, _currentPosition.longitude, _destinationLatitude,
                  _destinationLongitude);
            });
          }
      );

      markers.add(marker);
    }
    return markers;
  }

  _createPolylines(double startLatitude,
      double startLongitude,
      double destinationLatitude,
      double destinationLongitude,) async
  {
    polylinePoints = PolylinePoints();

    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      apiKey,
      PointLatLng(startLatitude, startLongitude),
      PointLatLng(destinationLatitude, destinationLongitude),
    );

    print(result.errorMessage);
    print(result.status);
    print(result.points);

    if (result.points.isNotEmpty) {
      result.points.forEach((PointLatLng point) {
        polylineCoordinates.add(LatLng(point.latitude, point.longitude));
      });
    }

    PolylineId id = PolylineId('poly');

    Polyline polyline = Polyline(
      polylineId: id,
      color: Colors.purple.shade400,
      points: polylineCoordinates,
      width: 3,
    );

    setState(() {
      polylines[id] = polyline;
    });
  }

  getEventsForUser() async {
    try {
      final user = await _auth.currentUser;
      if (user != null) {
        loggedInUser = user;
        _store
            .collection('Events')
            .where('userEmail', isEqualTo: user.email)
            .get()
            .then((value) {
          for (var element in value.docs) {
            events.add(
                Event(
                  element.data()['address'] as String,
                  element.data()['lat'],
                  element.data()['long'],
                  element.data()['reminderMessage'] as String,
                  element.data()['userEmail'] as String,
                ));
          }
        });
      }
    }
    catch (e) {}
  }

  addEventToDatabase() async {
    Map<String, dynamic> newEvent = {
      "address": _homeLocation,
      "lat": _homeLatitude,
      "long": _homeLongitude,
      "reminderMessage": reminderController.text,
      "userEmail": loggedInUser.email.toString()
    };
    await _store.collection('Events').doc().set(newEvent);

    setState(() {
      events.add(Event(_homeLocation, _homeLatitude, _homeLongitude,
          reminderController.text, loggedInUser.email.toString()));
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  Future<Null> displayPrediction(Prediction p) async {
    if (p != null) {
      PlacesDetailsResponse detail =
      await _places.getDetailsByPlaceId(p.placeId!);

      setState(() {
        _homeLocation = p.description;
        _homeLatitude = detail.result.geometry!.location.lat;
        _homeLongitude = detail.result.geometry!.location.lng;
      });

      _addGeofence();
      await addEventToDatabase();
    }
  }

  void _addGeofence() {
    bg.BackgroundGeolocation.addGeofence(bg.Geofence(
      identifier: 'REMINDER',
      radius: 150,
      latitude: _homeLatitude,
      longitude: _homeLongitude,
      notifyOnEntry: true,
      notifyOnExit: false,
      notifyOnDwell: false,
      loiteringDelay: 30000, // 30 seconds
    ));
  }

  void _onGeofence(bg.GeofenceEvent event) {
    var platformChannelSpecifics = NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        color: const Color(0xff676FA3),
        playSound: true,
        icon: '@mipmap/ic_launcher',
      ),
    );
    flutterLocalNotificationsPlugin
        .show(0, 'Hey!', reminderController.text, platformChannelSpecifics)
        .then((result) {});
  }

  void onError(PlacesAutocompleteResponse response) {
    print("Error: ${response.errorMessage}");
  }

  _getCurrentLocation() async {
    await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high)
        .then((Position position) async {
      setState(() {
        _currentPosition = position;
      });
    }).catchError((e) {
      print(e);
    });
  }

  @override
  void initState() {
    super.initState();

    _getCurrentLocation();

    bg.BackgroundGeolocation.onGeofence(_onGeofence);

    bg.BackgroundGeolocation.ready(bg.Config(
        desiredAccuracy: bg.Config.DESIRED_ACCURACY_HIGH,
        distanceFilter: 10.0,
        stopOnTerminate: false,
        startOnBoot: true,
        debug: false,
        logLevel: bg.Config.LOG_LEVEL_OFF))
        .then((bg.State state) {
      if (!state.enabled) {
        bg.BackgroundGeolocation.startGeofences();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    events = ModalRoute
        .of(context)!
        .settings
        .arguments as List<Event>;

    return Scaffold(

      body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(
                        border: Border.all(color: Colors.blueGrey),
                        color: Colors.grey.shade100
                    ),
                    child: Column(
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(10.0),
                            child: Text('ENTER LOCATION REMINDER',
                              style: TextStyle(
                                fontSize: 20.0, fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: TextField(
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: 'Reminder message',
                              ),
                              controller: reminderController,
                            ),
                          ),
                          FloatingActionButton(
                            onPressed: () async {
                              Prediction? p = await PlacesAutocomplete.show(
                                  offset: 2,
                                  radius: 1000,
                                  strictbounds: false,
                                  sessionToken: "017C58-0486B0-3E6C6B",
                                  context: context,
                                  apiKey: apiKey,
                                  onError: onError,
                                  language: 'en'
                                  components: [Component(Component.country,
                                  'mk')]
                              types: ["address"],
                              mode: Mode.overlay,
                              );
                              await displayPrediction(p!
                              ); // call to update user selection values
                            },
                            backgroundColor: const Color(0xff676FA3),
                            tooltip: 'Set Home Location',
                            child: const Icon(Icons.location_on_outlined),
                          ),
                        ]
                    ),
                  ),
                ),
                Expanded(
                  flex: 6,
                  child: GoogleMap(
                    onMapCreated: _onMapCreated,
                    initialCameraPosition: CameraPosition(
                      target: _center,
                      zoom: 11.0,
                    ),
                    markers: getMarkers(),
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    mapType: MapType.normal,
                    polylines: Set<Polyline>.of(polylines.values),
                  ),
                ),
              ],
            ),
          )
      ),

    );
  }
}
