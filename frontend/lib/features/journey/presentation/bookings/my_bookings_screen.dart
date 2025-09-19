// lib/features/journey/presentation/bookings/my_bookings_screen.dart

import 'package:flutter/material.dart';

import 'widgets/upcoming_bookings.dart';
import 'widgets/past_bookings.dart';
import 'widgets/refunds_tab.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({
    super.key,
    this.initialTabIndex = 0,
    this.upcoming = const <Map<String, dynamic>>[],
    this.past = const <Map<String, dynamic>>[],
    this.refunds = const <Map<String, dynamic>>[],
    this.onRefreshUpcoming,
    this.onRefreshPast,
    this.onRefreshRefunds,
    this.onTapBooking,
    this.onCancelBooking,
    this.onMoreForBooking,
    this.onViewRefund,
    this.title = 'My bookings',
  });

  final int initialTabIndex;

  /// Normalized lists (see child widgets for expected keys)
  final List<Map<String, dynamic>> upcoming;
  final List<Map<String, dynamic>> past;
  final List<Map<String, dynamic>> refunds;

  // Refresh hooks
  final Future<void> Function()? onRefreshUpcoming;
  final Future<void> Function()? onRefreshPast;
  final Future<void> Function()? onRefreshRefunds;

  // Booking callbacks
  final void Function(Map<String, dynamic> booking)? onTapBooking;
  final void Function(Map<String, dynamic> booking)? onCancelBooking;
  final void Function(Map<String, dynamic> booking)? onMoreForBooking;

  // Refund callbacks
  final void Function(Map<String, dynamic> refund)? onViewRefund;

  final String title;

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3, // Upcoming, Past, Refunds
      initialIndex: widget.initialTabIndex.clamp(0, 2),
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          bottom: const TabBar(
            isScrollable: false,
            tabs: [
              Tab(icon: Icon(Icons.event_available), text: 'Upcoming'),
              Tab(icon: Icon(Icons.history), text: 'Past'),
              Tab(icon: Icon(Icons.receipt_long_outlined), text: 'Refunds'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            UpcomingBookings(
              bookings: widget.upcoming,
              onRefresh: widget.onRefreshUpcoming,
              onTapBooking: widget.onTapBooking,
              onCancelBooking: widget.onCancelBooking,
              onMoreForBooking: widget.onMoreForBooking,
            ),
            PastBookings(
              bookings: widget.past,
              onRefresh: widget.onRefreshPast,
              onTapBooking: widget.onTapBooking,
              onCancelBooking: widget.onCancelBooking,
              onMoreForBooking: widget.onMoreForBooking,
            ),
            RefundsTab(
              items: widget.refunds,
              onRefresh: widget.onRefreshRefunds,
              onView: widget.onViewRefund,
            ),
          ],
        ),
      ),
    );
  }
}
