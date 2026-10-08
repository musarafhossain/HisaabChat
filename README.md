# HisaabChat

*Hisaab* (हिसाब) means "keeping accounts". HisaabChat is a WhatsApp-style personal expense tracker: every money account is a chat, and logging an expense feels like sending a message.

| Part | Stack | Folder |
|---|---|---|
| API | AdonisJS 7 · Node.js 24 · Lucid ORM | [`backend/`](backend/) |
| Database | MariaDB 10.4+ (production: 11.4) · MySQL 8.0.16+ compatible | — |
| App | Flutter 3.41 · Riverpod · go_router · Material 3 (Android, Windows, Web) | [`app/`](app/) |
| Docs | PRD, TRD, App Flow, UI/UX brief, schema, implementation plan | [`docs/`](docs/) |

## Prerequisites

- **Node.js 24** (`nvm install 24 && nvm use 24`)
- **Flutter 3.41+** with the Android SDK, Visual Studio (Desktop C++) and Chrome (`flutter doctor`)
- **MariaDB or MySQL**: either XAMPP's MariaDB (what local dev uses today) or `docker compose up -d` with the included [`docker-compose.yml`](docker-compose.yml)

## First-time setup

### 1. Database

Start MariaDB (XAMPP Control Panel → MySQL → Start), then create the databases and user:

```sql
CREATE DATABASE hisaabchat CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE hisaabchat_test CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'hisaabchat'@'localhost' IDENTIFIED BY '<password>';
CREATE USER 'hisaabchat'@'127.0.0.1' IDENTIFIED BY '<password>';
GRANT ALL PRIVILEGES ON hisaabchat.* TO 'hisaabchat'@'localhost', 'hisaabchat'@'127.0.0.1';
GRANT ALL PRIVILEGES ON hisaabchat_test.* TO 'hisaabchat'@'localhost', 'hisaabchat'@'127.0.0.1';
```

(With Docker Compose this is done for you.)

### 2. API

```bash
cd backend
npm install
cp .env.example .env          # set DB_PASSWORD
node ace generate:key
node ace migration:run
npm run dev                   # http://localhost:3333/api/v1/health
```

### 3. App

```bash
cd app
flutter pub get
flutter run -d chrome --web-port 5000      # Web
flutter run -d windows                     # Windows
flutter run -d emulator-5554               # Android emulator (uses http://10.0.2.2:3333)
```

For a physical phone on the same Wi-Fi, pass your PC's LAN address:
`flutter run --dart-define=API_BASE_URL=http://192.168.x.x:3333/api/v1`

## Tests

```bash
cd backend && npm test        # Japa unit + functional tests (uses the hisaabchat_test DB)
cd app && flutter analyze && flutter test
```

## Notes

- **`@swc/core` is pinned to 1.16.2** in `backend/package.json` (`overrides`). From 1.16.12 on, SWC refuses to load its native binary from a cache folder that another Windows account can modify, and on this machine `C:\Users\<you>` grants full control to an extra sandbox account. Remove the override once that permission is cleaned up or SWC relaxes the check.
- **Icons** come from a bundled subset of Material Symbols Rounded (`app/assets/fonts`). To add one, list it in `app/tool/icons/icons.txt` and run `python tool/icons/generate_icons.py <font.ttf> <codepoints>` (needs `pip install fonttools`; see the script header for the source files).
- Riverpod providers are written by hand (no `riverpod_generator`): the generator currently requires a newer `meta` than Flutter 3.41 ships.
