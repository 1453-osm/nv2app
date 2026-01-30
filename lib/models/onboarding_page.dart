import 'package:flutter/material.dart';

class OnboardingPage {
  final String title;
  final String description;
  final IconData icon;
  final Color? iconColor;

  const OnboardingPage({
    required this.title,
    required this.description,
    required this.icon,
    this.iconColor,
  });
} 