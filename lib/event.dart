import 'dart:ffi';

class Event {
  final String address;
  final double lat;
  final double long;
  final String reminderMessage;
  final String userEmail;

  Event(
      this.address, this.lat, this.long, this.reminderMessage, this.userEmail);
}
