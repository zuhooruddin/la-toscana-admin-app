import 'package:flutter/material.dart';

import 'core/theme.dart';

/// Small rounded label with an optional icon on a tinted background ("Recogida", "Efectivo", "Fraga").
class TintChip extends StatelessWidget {
  const TintChip(this.label, {super.key, this.icon, this.color = Brand.muted});
  final String label;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 15, color: color), const SizedBox(width: 4)],
          Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color.lerp(color, Brand.charcoal, 0.25))),
        ]),
      );
}

/// Status pill ("hace 32 min", "Confirmada", "No pagado").
class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.color = Brand.tomato});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      );
}

/// White rounded panel with a soft shadow, the base of every card in the redesign.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.onTap, this.color = Colors.white, this.border});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color color;
  final Color? border;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
          boxShadow: Brand.softShadow,
          border: border == null ? null : Border.all(color: border!, width: 1.4),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(borderRadius: BorderRadius.circular(18), onTap: onTap, child: Padding(padding: padding, child: child)),
        ),
      );
}

/// Centered illustration, title and explanation for an empty list.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.body, this.action});
  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(32, 56, 32, 32),
        child: Column(children: [
          Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(color: Brand.tomato.withValues(alpha: 0.07), shape: BoxShape.circle),
            child: Icon(icon, size: 64, color: Brand.tomato.withValues(alpha: 0.55)),
          ),
          const SizedBox(height: 20),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          if (body != null) ...[const SizedBox(height: 6), Text(body!, textAlign: TextAlign.center, style: const TextStyle(color: Brand.muted))],
          if (action != null) ...[const SizedBox(height: 20), action!],
        ]),
      );
}

/// Section heading used on the dashboard and detail pages.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 10),
        child: Row(children: [
          Expanded(child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          ?trailing,
        ]),
      );
}
