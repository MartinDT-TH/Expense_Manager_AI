import 'dart:async';
import 'package:flutter/material.dart';

class TopAlert {
  static void show(
    BuildContext context, {
    required String message,
    Color backgroundColor = const Color(0xFF323232),
    Color textColor = Colors.white,
    IconData? icon,
    Duration duration = const Duration(seconds: 3),
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.clearMaterialBanners();

    final controller = messenger.showMaterialBanner(
      MaterialBanner(
        backgroundColor: backgroundColor,
        content: Text(
          message,
          style: TextStyle(color: textColor),
        ),
        leading: icon == null ? null : Icon(icon, color: textColor),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: const [SizedBox.shrink()],
      ),
    );

    Timer(duration, () {
      controller.close();
    });
  }
}

