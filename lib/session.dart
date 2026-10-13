import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'core/api.dart';
import 'core/config.dart';
import 'models.dart';

const _staffRoles = ['owner', 'manager', 'staff'];

/// Signed-in staff member, their restaurants and the live connection. Drivers and customers are refused here.
class Session extends ChangeNotifier {
  Session(this.api, this.tokens) {
    api.onSessionExpired = () => _signedOut();
  }

  final Api api;
  final TokenStore tokens;
  Me? me;
  List<StaffBranch> branches = [];
  String? branchId; // null = all my restaurants
  String lang = 'es';
  bool ready = false;

  // realtime
  io.Socket? _socket;
  bool live = false;
  int newOrders = 0;
  final _events = StreamController<String>.broadcast();

  /// Emits event names (order.created, order.updated, branch.ordering_changed, menu.availability_changed).
  Stream<String> get events => _events.stream;

  Future<void> init() async {
    await tokens.load();
    final p = await SharedPreferences.getInstance();
    branchId = p.getString('lt_staff_branch');
    lang = p.getString('lt_staff_lang') ?? (PlatformDispatcher.instance.locale.languageCode == 'en' ? 'en' : 'es');
    if (tokens.hasSession) await _loadMe();
    ready = true;
    notifyListeners();
  }

  Future<void> _loadMe() async {
    try {
      final r = await api.get<Map<String, dynamic>>('/api/v1/auth/me');
      final u = (r['user'] as Map).cast<String, dynamic>();
      if (!_staffRoles.contains(u['role'])) {
        await logout();
        return;
      }
      me = Me('${u['id']}', '${u['email']}', u['name'] as String?, '${u['role']}', (u['branchIds'] as List? ?? const []).map((e) => '$e').toList(),
          u['mustChangePassword'] == true, (r['permissions'] as List? ?? const []).map((e) => '$e').toList());
      if (!me!.mustChangePassword) {
        await loadBranches();
        _connect();
      }
    } catch (_) {
      me = null;
    }
    notifyListeners();
  }

  Future<void> loadBranches() async {
    final r = await api.get<Map<String, dynamic>>('/api/v1/admin/branches');
    branches = (r['items'] as List).map((b) => StaffBranch.fromJson((b as Map).cast<String, dynamic>())).toList();
    if (branchId != null && !branches.any((b) => b.id == branchId)) branchId = null;
    if (branches.length == 1) branchId = branches.first.id;
    notifyListeners();
  }

  Future<void> selectBranch(String? id) async {
    branchId = id;
    final p = await SharedPreferences.getInstance();
    if (id == null) {
      await p.remove('lt_staff_branch');
    } else {
      await p.setString('lt_staff_branch', id);
    }
    notifyListeners();
  }

  Future<void> setLang(String l) async {
    lang = l;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString('lt_staff_lang', l);
  }

  StaffBranch? get branch => branches.where((b) => b.id == branchId).firstOrNull;

  Future<void> login(String email, String password) async {
    final r = await api.post<Map<String, dynamic>>('/api/v1/auth/login', body: {'email': email, 'password': password, 'client': 'mobile'});
    final role = '${(r['user'] as Map)['role']}';
    if (!_staffRoles.contains(role)) {
      await api.post('/api/v1/auth/logout', body: {'refreshToken': r['refreshToken']}).catchError((_) => null);
      throw ApiException(403, 'NOT_STAFF', 'Not a staff account');
    }
    await tokens.save(r['accessToken'] as String, r['refreshToken'] as String);
    await _loadMe();
  }

  Future<void> changePassword(String current, String next) async {
    final r = await api.post<Map<String, dynamic>>('/api/v1/auth/change-password', body: {'currentPassword': current, 'newPassword': next, 'client': 'mobile'});
    await tokens.save(r['accessToken'] as String, r['refreshToken'] as String);
    await _loadMe();
  }

  Future<void> logout() async {
    final rt = tokens.refresh;
    if (rt != null) {
      try {
        await api.post('/api/v1/auth/logout', body: {'refreshToken': rt});
      } catch (_) {}
    }
    await tokens.clear();
    _signedOut();
  }

  void _signedOut() {
    _socket?.dispose();
    _socket = null;
    live = false;
    me = null;
    branches = [];
    notifyListeners();
  }

  void _connect() {
    _socket?.dispose();
    // forceNew: a fresh manager per session (socket.io caches managers per URL; a disposed one never reconnects).
    final s = io.io(
      AppConfig.apiUrl,
      io.OptionBuilder().setTransports(['websocket']).disableAutoConnect().enableForceNew().enableReconnection().setAuth({'token': tokens.access}).build(),
    );
    s.onConnect((_) {
      live = true;
      // Rooms are per connection: (re)join after every reconnect.
      for (final b in branches) {
        s.emit('join_branch', b.id);
      }
      notifyListeners();
      _events.add('resync');
    });
    s.onDisconnect((_) {
      live = false;
      notifyListeners();
    });
    // Access tokens rotate: always hand the current one to the next attempt…
    s.onReconnectAttempt((_) => s.auth = {'token': tokens.access});
    // …and if the server rejected an expired one, a cheap authenticated call refreshes it before the next retry.
    s.onConnectError((_) {
      if (me != null) api.get<dynamic>('/api/v1/auth/me').catchError((_) => null);
    });
    s.onAny((event, _) {
      if (event == 'order.created') {
        newOrders++;
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.alert);
        notifyListeners();
      }
      _events.add(event);
    });
    s.connect();
    _socket = s;
  }

  void clearNewOrders() {
    newOrders = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _socket?.dispose();
    _events.close();
    super.dispose();
  }
}
