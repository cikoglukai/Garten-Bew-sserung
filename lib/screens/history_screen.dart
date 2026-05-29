import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/watering_event.dart';
import '../state/app_state.dart';
import '../utils/date_format.dart';

/// A month calendar that marks the days a pump was watered, with a list of
/// that day's waterings below.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  // Local UI state: which month the calendar is showing, and which day is
  // tapped. The watering data itself lives in AppState, not here.
  late DateTime _focusedDay;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    // Start on today.
    _focusedDay = DateTime.now();
    _selectedDay = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);

    // Bound the calendar to the range we actually have data for: from just
    // before the oldest record's month, up to today. History is newest-first,
    // so .last is the earliest event.
    final now = DateTime.now();
    final earliest = state.history.isEmpty
        ? now
        : state.history.last.timestamp;
    final firstDay = DateTime(earliest.year, earliest.month, 1)
        .subtract(const Duration(days: 1));
    final lastDay = DateTime(now.year, now.month, now.day);

    // The waterings to list under the calendar for the currently-tapped day.
    final dayEvents = state.eventsForDay(_selectedDay);

    return Scaffold(
      appBar: AppBar(title: const Text('Watering history')),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(12),
            child: TableCalendar<WateringEvent>(
              firstDay: firstDay,
              lastDay: lastDay,
              // Clamp focus to lastDay so we never focus a day past the range.
              focusedDay: _focusedDay.isAfter(lastDay) ? lastDay : _focusedDay,
              selectedDayPredicate: (d) => isSameDay(_selectedDay, d),
              // Dots under a day come from how many events that day has.
              eventLoader: state.eventsForDay,
              availableCalendarFormats: const {CalendarFormat.month: 'Month'},
              calendarStyle: CalendarStyle(
                markerDecoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              // Tapping a day updates both pieces of local state (which also
              // refreshes the list below via setState).
              onDaySelected: (selected, focused) {
                setState(() {
                  _selectedDay = selected;
                  _focusedDay = focused;
                });
              },
            ),
          ),
          // Heading for the selected day, e.g. "Thu, May 28".
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                DateFormatting.dayHeading(_selectedDay),
                style: theme.textTheme.titleMedium,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // The selected day's waterings, or an empty-state message.
          Expanded(
            child: dayEvents.isEmpty
                ? Center(
                    child: Text(
                      'No watering on this day.',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.outline),
                    ),
                  )
                : ListView.builder(
                    itemCount: dayEvents.length,
                    itemBuilder: (_, i) {
                      final e = dayEvents[i];
                      return ListTile(
                        leading: Icon(Icons.water_drop,
                            color: theme.colorScheme.primary),
                        title: Text(e.pumpName),
                        subtitle: Text('Watered for ${e.durationSeconds}s'),
                        trailing: Text(DateFormatting.time(e.timestamp)),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
