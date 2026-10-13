import 'package:flutter/material.dart';

/// The Material icon of a subject's `icon_key` (the starter set of the migration).
/// Unknown or missing keys get the generic school icon, so a subject never shows
/// without one (specs/15: colour and icon, never colour alone).
IconData schoolIcon(String? key) => switch (key) {
  'book' => Icons.menu_book_outlined,
  'numbers' => Icons.calculate_outlined,
  'globe' => Icons.public,
  'chat' => Icons.chat_bubble_outline,
  'music' => Icons.music_note_outlined,
  'palette' => Icons.palette_outlined,
  'hands' => Icons.volunteer_activism_outlined,
  'run' => Icons.directions_run,
  'swim' => Icons.pool,
  _ => Icons.school_outlined,
};
