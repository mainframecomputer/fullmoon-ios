<!-- Created by Sébastien DAGUIN -->

# Contribuer à Fullmoon

Les contributions doivent préserver l'expérience native SwiftUI et le fonctionnement
local du moteur Noctis.

## Préparer l'environnement

Utiliser un Mac Apple Silicon, Xcode avec Swift 6.4 ou ultérieur et le composant Metal.
Les minima de plateforme sont ceux du projet Xcode et du package Noctis.

Noctis est une dépendance Swift distante, résolue par Xcode depuis son dépôt GitHub.
Les scripts SearXNG utilisent encore les outils de préparation du dépôt voisin :

```text
NoctisAI/
├── NoctisAi/
└── fullmoon-ios/
```

Depuis `fullmoon-ios`, préparer une fois le runtime macOS avec Python 3.10+, Git et `uv` :

```sh
python3 ../NoctisAi/infrastructure/searxng/setup_runtime.py \
  --standalone --destination build/SearXNG
```

Pour compiler l'application iOS, préparer aussi les variantes iPhone et simulateur :

```sh
build/SearXNG/python/bin/python3 ../NoctisAi/infrastructure/searxng/setup_ios_runtime.py \
  --mac-runtime build/SearXNG --destination build/SearXNG-iOS
```

Ne pas relancer la préparation macOS sur une destination déjà présente : le script
refuse de l'écraser. Les runtimes sont locaux et ne doivent pas être commités.
Voir [README.md](README.md) pour les détails de préparation et de packaging.

## Branche et pull request

Créer une branche dédiée depuis `main` à jour, avec un nom décrivant le changement,
par exemple `feat/nom-court`, `fix/nom-court` ou `docs/nom-court`.

Toute modification passe par une pull request vers `main`. Les pushes directs,
force-pushes et suppressions de `main` sont interdits. La fusion est réservée à
**Sébastien DAGUIN (`Sebastien972-collab`)**.

## Conventions

Respecter le style et l'architecture existants. Garder les changements localisés,
préserver les modifications sans rapport avec la contribution et vérifier les usages
avant de supprimer du code. Expliquer toute évolution d'architecture, de dépendances,
de SDK ou de configuration de build dans le périmètre de la pull request.

Pour le chat, préserver l'annulation, le contenu sauvegardé et le rendu Markdown.
Ne pas forcer un défilement à chaque fragment de texte ni rejouer une animation sur
l'ensemble de la réponse. Respecter Dynamic Type et les préférences de réduction
du mouvement et de la transparence.

Préserver les attributions du projet d'origine et des dépendances. Ne pas remplacer
les headers des auteurs tiers et ne pas signer des fichiers avec le nom d'un outil IA.

## SwiftLint

```sh
./scripts/lint.sh
```

SwiftLint 0.65.1 s'exécute également avant la compilation dans Xcode. Le script
télécharge la version portable dans un cache temporaire et vérifie son SHA-256.
Une installation locale de la même version peut être fournie avec `SWIFTLINT_BIN`.

La baseline conserve les écarts existants ; les nouvelles violations sont bloquantes.
Ne pas régénérer `.swiftlint-baseline.json` pour masquer une régression.

## Vérifier les builds et l'interface

Une fois les runtimes préparés, depuis la racine du dépôt :

```sh
xcodebuild -project fullmoon.xcodeproj -scheme fullmoon -configuration Debug \
  -destination 'generic/platform=macOS' -skipPackageUpdates -skipMacroValidation \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO build

xcodebuild -project fullmoon.xcodeproj -scheme fullmoon -configuration Debug \
  -destination 'generic/platform=iOS Simulator' -skipPackageUpdates -skipMacroValidation \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO build
```

Ces commandes vérifient la compilation, pas la signature de distribution ni le
comportement sur un iPhone physique. Pour un changement d'interface, contrôler les
thèmes clair/sombre, le texte long, la génération, l'arrêt et le défilement manuel.
Ajouter des captures pertinentes à la pull request et distinguer ce qui a été
compilé de ce qui a été réellement testé dans l'application.

## Contenu de la pull request

Décrire le problème, le résultat et les vérifications effectuées. Mentionner les
plateformes non vérifiées et les limites restantes. Éviter les refontes et le
formatage sans rapport avec le sujet.

Ne pas commiter de secrets, `.env`, profils de signature, trousseaux, poids de modèles,
runtimes ou artefacts de build. Respecter la [licence MIT du projet d'origine](LICENSE)
et conserver les licences et notices des dépendances distribuées.
