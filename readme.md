# GleeLight 🏠💡✨

Eine minimalistische Flutter-App zur lokalen Steuerung von Yeelight-Lampen **ohne Cloud-Verbindung**. Basiert auf der offiziellen Yeelight WiFi Light Inter-Operation Specification.

![Flutter](https://img.shields.io/badge/Flutter-3.0+-blue.svg)
![Dart](https://img.shields.io/badge/Dart-3.0+-blue.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

> **GleeLight** - Bringe Freude in deine Beleuchtung! 😊

## ✨ Features

### 🔍 **Automatische Lampenerkennung**
- Erkennt Yeelight-Lampen automatisch im lokalen Netzwerk
- Kein manueller Setup-Prozess erforderlich
- Pull-to-refresh für manuelle Aktualisierung

### 👥 **Intelligente Gruppenverwaltung**
- **"All"** - Steuert alle Lampen gleichzeitig
- **Einzellampen** - Jede Lampe als eigene Gruppe
- **Custom Groups** - Benutzerdefinierte Gruppenbildung
- Automatische Sortierung und Verwaltung

### 🎨 **Szenen-System**
- Vordefinierte Szenen: Warm, Hell, Gedimmt
- Benutzerdefinierte Szenen mit individuellen Einstellungen
- Einfache Anwendung per Fingertipp

### ⚙️ **Direkte Steuerung**
- **An/Aus** mit letzten Einstellungen
- **Helligkeit** (1-100%)
- **Farbtemperatur** (1700K-6500K) für unterstützte Lampen
- Smooth-Transitions für sanfte Übergänge

### 📱 **Native Experience**
- Material Design 3 mit automatischem Dark/Light Mode
- Responsive UI für alle Bildschirmgrößen
- Optimiert für Android (iOS-Support möglich)
- Offline-Anzeige für nicht erreichbare Lampen

## 🚀 Installation & Setup

### Voraussetzungen
- Flutter SDK (>=3.1.0)
- Android Studio / VS Code
- Android Device/Emulator (API Level 21+)
- Yeelight-Lampen im selben WLAN-Netzwerk

### 1. Repository klonen
```bash
git clone <repository-url>
cd gleelight
```

### 2. Dependencies installieren
```bash
flutter pub get
```

### 3. App starten
```bash
flutter run
```

### 4. Yeelight-Lampen vorbereiten
1. Stelle sicher, dass deine Yeelight-Lampen eingeschaltet sind
2. Aktiviere "LAN Control" in der offiziellen Yeelight-App:
   - Öffne die Yeelight-App
   - Wähle deine Lampe aus
   - Tippe auf das Zahnrad-Symbol (Einstellungen)
   - Aktiviere "LAN Control"
3. Starte die App - die Lampen werden automatisch erkannt

## 📁 Projektstruktur

```
lib/
├── main.dart                    # App Entry Point + Theme
├── models/                      # Datenmodelle
│   ├── lamp.dart               # Lampen-Datenmodell
│   ├── group.dart              # Gruppen-Datenmodell  
│   └── scene.dart              # Szenen-Datenmodell
├── services/                    # Business Logic
│   ├── yeelight_service.dart   # UDP Discovery + TCP Commands
│   └── storage_service.dart    # Lokale Datenpersistierung
├── screens/                     # UI-Screens
│   ├── home_screen.dart        # Hauptansicht mit Gruppen
│   ├── settings_screen.dart    # Helligkit/Farbtemperatur
│   └── scenes_screen.dart      # Szenen verwalten
└── widgets/                     # Wiederverwendbare UI-Komponenten
    ├── group_card.dart         # Gruppen-Kachel
    └── lamp_icon.dart          # Lampen-Symbol mit Status
```

## 🔧 Verwendung

### Erste Schritte
1. **Lampenerkennung**: Die App sucht automatisch nach Lampen beim Start
2. **Pull-to-refresh**: Ziehe die Liste nach unten für manuelle Suche
3. **Gruppen**: Lampen werden automatisch in "All" und Einzelgruppen organisiert

### Hauptfunktionen
- **Tippen auf Gruppe**: Schaltet alle Lampen der Gruppe an/aus
- **Szenen-Button** (🎨): Öffnet Szenen-Verwaltung
- **Einstellungen-Button** (⚙️): Öffnet Helligkeits- und Farbtemperatur-Regler
- **Plus-Button**: Erstellt neue benutzerdefinierte Gruppe

### Erweiterte Features
- **Offline-Erkennung**: Graue, kursive Anzeige für nicht erreichbare Lampen
- **Status-Anzeige**: Farbige Icons zeigen Online/Offline und An/Aus Status
- **Letzte Einstellungen**: Beim Einschalten werden die letzten Werte wiederhergestellt

## 🛠️ Technische Details

### Netzwerk-Protokoll
- **Discovery**: SSDP-ähnlich über UDP Multicast (239.255.255.250:1982)
- **Steuerung**: JSON-Kommandos über TCP (Port 55443)
- **Basiert auf**: Offizielle Yeelight Inter-Operation Specification

### Unterstützte Lampenmodelle
- **Color**: RGB + Farbtemperatur + Helligkeit
- **White**: Farbtemperatur + Helligkeit  
- **Mono**: Nur Helligkeit
- **Ceiling**: Deckenlampen mit Hintergrundlicht
- **Stripe**: LED-Streifen

### Datenpersistierung
- **SharedPreferences** für lokale Speicherung
- **Automatische Bereinigung** verwaister Daten
- **Keine Cloud-Verbindung** erforderlich

## 🐛 Troubleshooting

### Lampen werden nicht gefunden
1. Prüfe ob "LAN Control" in der Yeelight-App aktiviert ist
2. Stelle sicher, dass Gerät und Lampen im selben WLAN sind
3. Versuche Pull-to-refresh oder App-Neustart
4. Firewall/Router-Einstellungen prüfen (Multicast erlauben)

### Kommandos funktionieren nicht
1. Prüfe Netzwerkverbindung zur Lampe
2. Lampe könnte überlastet sein (max. 4 gleichzeitige Verbindungen)
3. Rate-Limiting: Max. 60 Kommandos/Minute pro Lampe

### Performance-Probleme
1. Zu viele gleichzeitige Kommandos vermeiden
2. App schließen und neu starten
3. Nicht benötigte Gruppen/Szenen löschen

## 🔮 Geplante Features (Future)

- [ ] **Android Widgets** für Home Screen
- [ ] **Quick Settings Tiles** für Android-Systemmenü  
- [ ] **Zeitgesteuerte Szenen** (Sonnenauf-/untergang)
- [ ] **Farbverläufe** (Color Flows) mit eigenem Editor
- [ ] **Backup/Restore** von Einstellungen
- [ ] **Themes** und weitere Anpassungen

## 🤝 Beitragen

Contributions sind willkommen! 

1. Fork das Repository
2. Erstelle einen Feature-Branch (`git checkout -b feature/amazing-feature`)
3. Committe deine Änderungen (`git commit -m 'Add amazing feature'`)
4. Push zum Branch (`git push origin feature/amazing-feature`)
5. Öffne eine Pull Request

## 📄 Lizenz

Dieses Projekt steht unter der MIT-Lizenz - siehe [LICENSE](LICENSE) für Details.

## 🙏 Danksagungen

- **Yeelight** für die offene Inter-Operation Specification
- **Flutter Team** für das großartige Framework
- **Material Design** für die Design-Guidelines

## 📞 Support

Bei Problemen oder Fragen:
- Öffne ein [Issue](../../issues)
- Beschreibe dein Problem mit Lampenmodell und Android-Version
- Füge Logs hinzu wenn möglich

---

**GleeLight - Entwickelt mit ❤️ und Flutter** ✨