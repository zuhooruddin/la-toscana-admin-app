# La Toscana — admin app (staff, Android / iOS)

Mobile companion of the web dashboard for owners, managers and kitchen/front-of-house staff. Same backend, database and
permissions as the dashboard (`la-toscana-backend`, `/api/v1/admin/*`); the full back-office (menu editing, restaurants,
promotions, content, settings…) is in `la-toscana-admin-web`.

## Features

- Sign in (staff roles only; drivers use the driver app), forced change of the temporary password
- **Pedidos**: live kitchen board (Socket.IO: new orders arrive instantly with vibration + sound and a badge), tabs New /
  Preparing / Ready / Out for delivery, one-tap next step, order sheet with options, notes, "if sold out" preference,
  customer call, cancel with reason. Resyncs after every reconnection and every 30 s.
- **Agotados**: mark dishes sold out for today in the selected restaurant
- **Reservas**: bookings per day, seated / no-show, call the guest
- **Hoy**: today's orders, sales and average ticket; pause / resume online ordering per restaurant (15 min … until resumed)
- Restaurant switcher for users with several restaurants. What a role cannot do is hidden; the API enforces everything.

## Run

```bash
flutter pub get
flutter run --dart-define=API_URL=http://10.0.2.2:4000      # Android emulator → local API
```

Checks: `flutter analyze`, `flutter test`. Release builds are HTTPS only and need the client's signing keys.
Push notifications for new orders when the app is closed need the client's Firebase project (not configured; the app alerts
while open).
