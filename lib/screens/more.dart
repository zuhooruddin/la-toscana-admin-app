import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config.dart';
import '../core/i18n.dart';
import '../core/media.dart';
import '../core/theme.dart';
import '../session.dart';
import 'auth.dart';
import 'branches.dart';
import 'customers.dart';
import 'drivers.dart';
import 'reports.dart';

/// Account hub: profile card, active restaurant, management shortcuts, language, help and sign-out.
class MorePage extends StatelessWidget {
  const MorePage({super.key});

  void _push(BuildContext context, Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    final t = S.of(context);
    final me = s.me!;
    final manage = <Widget>[
      if (me.can('drivers:read'))
        _Item(icon: Icons.delivery_dining_outlined, color: Brand.tomato, title: t.t('drivers'), subtitle: t.t('driversSub'), onTap: () => _push(context, const DriversPage())),
      if (me.can('customers:read'))
        _Item(icon: Icons.people_outline, color: Brand.blue, title: t.t('customers'), subtitle: t.t('customersSub'), onTap: () => _push(context, const CustomersPage())),
      if (me.can('analytics:read'))
        _Item(icon: Icons.insights_outlined, color: const Color(0xFF6A55B5), title: t.t('reports'), subtitle: t.t('reportsSub'), onTap: () => _push(context, const ReportsPage())),
    ];
    return Scaffold(
      backgroundColor: const Color(0xFFFCF9F5),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
          // Brand header: back, logo, "ADMINISTRADOR".
          Row(children: [
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back), tooltip: MaterialLocalizations.of(context).backButtonTooltip),
            const SizedBox(width: 4),
            Image.asset('assets/images/logo.png', height: 46, filterQuality: FilterQuality.medium, semanticLabel: 'La Toscana Pizzería'),
            const SizedBox(width: 12),
            Expanded(child: Text(t.t('adminTagline'), style: const TextStyle(letterSpacing: 4, fontSize: 12, fontWeight: FontWeight.w600, color: Brand.charcoal))),
          ]),
          const SizedBox(height: 12),
          _ProfileCard(),
          const SizedBox(height: 14),
          if (s.branches.length > 1 || s.branch != null) _ActiveRestaurant(onChange: () => _push(context, const BranchPickerPage())),
          if (manage.isNotEmpty) ...[
            _Section(t.t('secManage')),
            _Group(children: manage),
          ],
          _Section(t.t('secAccount')),
          _Group(children: [
            _Item(icon: Icons.person_outline, color: Brand.tomato, title: t.t('profile'), subtitle: t.t('profileSub'), onTap: () => _profile(context)),
            _Item(
              icon: Icons.language,
              color: Brand.orange,
              title: t.t('languageItem'),
              subtitle: t.t('languageSub'),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: Brand.border)),
                child: Text(s.lang.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              onTap: () => _language(context),
            ),
            _Item(
              icon: Icons.help_outline,
              color: Brand.basil,
              title: t.t('help'),
              subtitle: t.t('helpSub'),
              onTap: () => launchUrl(Uri.parse(AppConfig.websiteUrl), mode: LaunchMode.externalApplication),
            ),
          ]),
          const SizedBox(height: 16),
          Material(
            color: const Color(0xFFFDECEA),
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _signOut(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                child: Row(children: [
                  const Icon(Icons.logout, color: Brand.tomato),
                  const SizedBox(width: 14),
                  Expanded(child: Text(t.t('signOut'), style: const TextStyle(color: Brand.tomato, fontWeight: FontWeight.w800, fontSize: 16))),
                  const Icon(Icons.chevron_right, color: Brand.tomato),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(t.t('versionLine', {'v': AppConfig.appVersion}), textAlign: TextAlign.center, style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
        ]),
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    final t = S.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(t.t('signOutConfirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.t('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t.t('signOut'))),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      final session = context.read<Session>();
      Navigator.of(context).popUntil((r) => r.isFirst);
      await session.logout();
    }
  }

  void _language(BuildContext context) {
    final s = context.read<Session>();
    final t = S.of(context);
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(t.t('language'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
          RadioGroup<String>(
            groupValue: s.lang,
            onChanged: (v) {
              if (v != null) s.setLang(v);
              Navigator.pop(ctx);
            },
            child: const Column(children: [
              RadioListTile(value: 'es', title: Text('Español')),
              RadioListTile(value: 'en', title: Text('English')),
            ]),
          ),
        ]),
      ),
    );
  }

  void _profile(BuildContext context) {
    final s = context.read<Session>();
    final t = S.of(context);
    final me = s.me!;
    final branches = s.branches.map((b) => b.name).join(', ');
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(me.name ?? me.email, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.mail_outline), title: Text(me.email)),
            ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.badge_outlined), title: Text(t.t('roleLong.${me.role}'))),
            if (branches.isNotEmpty) ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.storefront_outlined), title: Text(branches)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChangePasswordScreen(forced: false)));
              },
              icon: const Icon(Icons.lock_outline),
              label: Text(t.t('changePassword')),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Red gradient card: initials avatar with live dot, name, role, online pill; food photo fading in on the right.
class _ProfileCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    final t = S.of(context);
    final me = s.me!;
    final name = me.name ?? me.email;
    final initials = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join();
    return Container(
      height: 150,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(colors: [Color(0xFFE0322B), Color(0xFF9E1C17)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: [BoxShadow(color: Brand.tomato.withValues(alpha: 0.3), blurRadius: 22, offset: const Offset(0, 10))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: 170,
          child: ShaderMask(
            shaderCallback: (r) => const LinearGradient(colors: [Colors.transparent, Colors.white], stops: [0, 0.55]).createShader(r),
            blendMode: BlendMode.dstIn,
            child: Image.asset('assets/images/banner.jpg', fit: BoxFit.cover, alignment: const Alignment(0.6, 0)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            Stack(clipBehavior: Clip.none, children: [
              CircleAvatar(
                radius: 42,
                backgroundColor: const Color(0xFFFDE8E6),
                child: Text(initials, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Brand.tomatoDark)),
              ),
              Positioned(
                right: 2,
                bottom: 2,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: s.live ? const Color(0xFF2DBE5C) : Brand.muted, border: Border.all(color: Colors.white, width: 3)),
                ),
              ),
            ]),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                Text(t.t('roleLong.${me.role}'), style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 15)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white24)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.circle, size: 9, color: s.live ? const Color(0xFF5BE38A) : Colors.white54),
                    const SizedBox(width: 6),
                    Text(t.t(s.live ? 'online' : 'offline'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _ActiveRestaurant extends StatelessWidget {
  const _ActiveRestaurant({required this.onChange});
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    final t = S.of(context);
    final b = s.branch;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: Brand.softShadow),
      child: Row(children: [
        b?.imageUrl != null
            ? Photo(b!.imageUrl, size: 52, radius: 26, icon: Icons.storefront)
            : CircleAvatar(radius: 26, backgroundColor: Brand.tomato.withValues(alpha: 0.1), child: const Icon(Icons.storefront, color: Brand.tomato)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.t('activeRestaurant'), style: const TextStyle(color: Brand.muted, fontSize: 13)),
            Text(b?.name ?? t.t('allRestaurants'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ]),
        ),
        if (s.branches.length > 1)
          TextButton.icon(
            onPressed: onChange,
            style: TextButton.styleFrom(
              foregroundColor: Brand.tomato,
              backgroundColor: Brand.tomato.withValues(alpha: 0.08),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.swap_horiz, size: 20),
            label: Text(t.t('change'), style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
      ]),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(6, 20, 6, 8),
        child: Text(text.toUpperCase(), style: const TextStyle(color: Brand.muted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
      );
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: Brand.softShadow),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 74, endIndent: 16, color: Color(0x14000000)),
            children[i],
          ],
        ]),
      );
}

/// Row with a tinted icon tile, title, subtitle and chevron.
class _Item extends StatelessWidget {
  const _Item({required this.icon, required this.color, required this.title, required this.subtitle, required this.onTap, this.trailing});
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                Text(subtitle, style: const TextStyle(color: Brand.muted, fontSize: 13)),
              ]),
            ),
            if (trailing != null) ...[trailing!, const SizedBox(width: 8)],
            const Icon(Icons.chevron_right, color: Brand.muted),
          ]),
        ),
      );
}
