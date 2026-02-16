# Quel io ?

Application iOS native de suivi des horaires de travail intégrée avec Kelio.

## 🚀 Technologies

- **SwiftUI** pour l'interface native iOS
- **Swift 6** pour le développement applicatif
- **WidgetKit** pour le widget iOS
- **Xcode / xcodebuild** pour le build et l'exécution
- **API Kelio** (URL configurable dans l'app)

## 🛠️ Installation

```bash
# Ouvrir le projet iOS
open QuelIO.xcodeproj
```

## 🔧 Développement

Pour lancer un environnement de développement complet (API + app iOS) :

```bash
# Terminal 1 (projet web/API)
pnpm dev

# Terminal 2 (ce repo iOS)
open QuelIO.xcodeproj
```

Cela va :
1. Démarrer l'API PHP via Docker sur le port 8080 (depuis le projet web)
2. Permettre de lancer l'app iOS sur simulateur depuis Xcode
3. Utiliser `http://localhost:8080/` comme API par défaut (modifiable dans l'app)

### Commandes disponibles

```bash
# Ouvrir le projet dans Xcode
open QuelIO.xcodeproj

# Lister les cibles/schémas
xcodebuild -project QuelIO.xcodeproj -list

# Build simulateur
xcodebuild -project QuelIO.xcodeproj -scheme QuelIO -destination 'generic/platform=iOS Simulator' build
```

## ⚙️ Configuration API

Par défaut, l'app cible `http://localhost:8080/`.

Tu peux modifier l'URL dans `Réglages > API Kelio`.
