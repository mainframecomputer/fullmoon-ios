<!-- Created by Sébastien DAGUIN -->

# Interface Noctis — base Fullmoon

Interface SwiftUI avec conversations locales SwiftData et moteur Noctis exécuté sur le Mac.

## Développement

Le projet Xcode résout le package Noctis depuis son dépôt GitHub. Les scripts de préparation
et de packaging SearXNG utilisent encore `../NoctisAi` ; conserver les deux dépôts côte à côte :

```text
NoctisAI/
├── NoctisAi/
└── fullmoon-ios/
```

Ouvrir `fullmoon.xcodeproj`, sélectionner la cible Mac et lancer l’application. Le modèle reste
`mlx-community/Ministral-3-14B-Instruct-2512-4bit` ; aucune version de dépendance n’a été changée.

### Recherche Web sur Mac, sans Docker

Préparer une seule fois le runtime autonome depuis ce dépôt (Python 3.10+, Git et `uv` requis) :

```sh
python3 ../NoctisAi/infrastructure/searxng/setup_runtime.py --standalone --destination build/SearXNG
```

Cette préparation télécharge Python 3.13.13 pour l’architecture du Mac et installe la révision
SearXNG épinglée par Noctis. Les fichiers restent dans `build/`, ignoré par Git.
La phase Xcode `Embed SearXNG` copie le runtime dans les ressources de l’app et signe ses
bibliothèques et son interpréteur avec l’identité de Fullmoon, avant la signature finale.
Le script de build a besoin de l’accès au trousseau ; son sandbox de build est désactivé.
Le sandbox de l’application reste actif, avec les droits réseau client et serveur.

Fullmoon démarre SearXNG à la première recherche, sur un port local attribué automatiquement,
puis l’arrête après 120 secondes d’inactivité ou à la fermeture du canal parent.
L’app ne dépend ni de Docker, ni du Python installé sur le Mac de l’utilisateur.
Si le runtime manque, une erreur est affichée au lieu de se connecter au port Docker 8888.
Un accès Internet reste nécessaire pour interroger les moteurs de recherche.

Le runtime préparé est propre à une architecture : compiler et préparer séparément les
distributions Apple Silicon et Intel. La notarisation et la validation App Store restent
des étapes de distribution distinctes.

### Recherche Web embarquée sur iOS

Après la préparation du runtime Mac ci-dessus, préparer les variantes iPhone et simulateur :

```sh
build/SearXNG/python/bin/python3 ../NoctisAi/infrastructure/searxng/setup_ios_runtime.py \
  --mac-runtime build/SearXNG --destination build/SearXNG-iOS
```

Cette étape nécessite Xcode complet et un accès Internet. Elle conserve les versions de
SearXNG et de ses dépendances, prépare Python iOS 3.13 via BeeWare `3.13-b14`, et compile
`lxml`, `msgspec` et le pont de `curl_cffi` pour **arm64 iPhone et simulateur Apple Silicon**.
Les binaires de `cffi` et `MarkupSafe` viennent de leurs distributions iOS sur PyPI ;
libcurl-impersonate vient de sa distribution iOS officielle `2.3.1`.
La préparation réutilise les fichiers Python du runtime de build Mac, sans le modifier.

Sélectionner ensuite la destination iPhone ou simulateur dans Xcode. La phase existante
`Embed SearXNG` choisit le packaging iOS et signe les modules natifs comme frameworks.
Les ressources et binaires préparés restent dans `build/`, ignoré par Git.

`IOSWebSearchService` conserve un interpréteur pour le processus de l’app et exécute les
recherches sur une file série de fond. Il appelle le pipeline WSGI de SearXNG directement :
aucun sous-processus, port HTTP local, Docker ou serveur distant n’est utilisé.
Les requêtes restent des arguments Python, jamais du code à exécuter. Les résultats sont
limités à 2 Mio puis passent par les contrôles habituels de Noctis.
Une annulation libère immédiatement l’appelant ; une recherche Python déjà commencée
termine en arrière-plan avec les délais réseau SearXNG, avant la prochaine recherche.
L’interpréteur n’est pas déchargé pendant la vie du processus iOS.

Deux adaptations sont appliquées uniquement à la copie iOS de SearXNG : métadonnées de version
figées pour éviter un appel Git à l’exécution, et retrait de `pwd` dans le diagnostic
d’erreur Valkey, iOS n’exposant pas de base d’utilisateurs Unix. Le runtime macOS et son
cycle de processus restent inchangés.

La validation sur un iPhone physique et la distribution App Store restent à effectuer.

## Chargement et conversations

- Les fichiers du modèle sont conservés dans le cache Hugging Face utilisé par l’application.
- Une installation complète est recherchée localement avant tout accès réseau. Une installation
  absente ou incomplète passe par le téléchargement Hugging Face, qui réutilise les fichiers présents.
- L’interface distingue « Téléchargement… », « Chargement du modèle… » et « Prêt ».
- Chaque fenêtre conserve son moteur pendant sa durée de vie. Changer de chat ou interrompre
  une réponse réinitialise uniquement la conversation, après le nettoyage de la génération.
- L’historique complet est transmis avec ses rôles ; il n’est pas injecté comme JSON dans un prompt.
- Après fermeture complète, les poids doivent être rechargés du disque en mémoire. Un cache
  supprimé par l’utilisateur ou le système nécessite une nouvelle installation.

## Interaction

Sur Mac, **Retour** envoie le message, **Maj+Retour** conserve la saisie multiligne et
**Commande+Retour** reste disponible. L’envoi est bloqué pendant une réponse ; le bouton Arrêt
attend le nettoyage du moteur avant d’autoriser le message suivant.

Le premier fragment s’affiche immédiatement. Les fragments suivants sont regroupés par fenêtres
de 50 ms pour limiter les recalculs du Markdown. Le texte en attente est affiché à la fin, lors
d’un arrêt ou d’une erreur. Les anciens messages utilisent une liste paresseuse ; remonter dans
la conversation suspend le défilement automatique, qui reprend près du bas ou au nouvel envoi.

## Mesures

Les journaux macOS, catégorie `Inference`, enregistrent les durées de téléchargement et de
chargement séparément, le délai avant le premier texte et le débit en **caractères par seconde**.
Ils ne contiennent pas le contenu des messages. Ces mesures ne sont pas des tokens par seconde.

Pour comparer deux versions, utiliser le même Mac, le même modèle, les mêmes prompts et une
compilation identique ; séparer démarrage du processus, messages successifs et changement de
conversation. Mesurer la mémoire GPU MLX en plus de la mémoire du processus : la seule mémoire
résidente du processus ne représente pas les poids alloués par Metal.

Mesure ponctuelle du moteur le 4 novembre 2026, avant/après sur le même Mac, en Debug,
avec le modèle déjà installé et le réseau bloqué. Le même prompt demande les nombres de
1 à 20 ; chaque réponse comporte 69 caractères. Le second échange simule un changement
de conversation. Les autres compilations en cours rendent les durées et débits indicatifs.

| Second échange | Avant | Après |
| --- | ---: | ---: |
| Préparation de la conversation, chargement inclus | 6,467 s | 0,004 s |
| Premier texte après préparation | 20,873 s | 13,951 s |
| Débit du texte généré | 11,76 caractères/s | 10,10 caractères/s |
| Mémoire MLX active | 8,11 Gio | 8,11 Gio |
| Pic mémoire MLX du processus | 8,57 Gio | 8,84 Gio |

Ce test confirme la suppression du rechargement des poids et le fonctionnement hors ligne.
Il ne démontre pas de gain de débit d’inférence ; le pic mémoire augmente légèrement avec
la réutilisation du cache de session. La taille du modèle et le contexte restent inchangés.

## Origine et licence

Projet d’origine : [Fullmoon](https://github.com/mainframecomputer/fullmoon-ios),
par Mainframe Computer, Inc. Licence MIT : voir `LICENSE`.
Le moteur utilise [MLX Swift](https://github.com/ml-explore/mlx-swift).

## SwiftLint et contributions

Le build Xcode exécute SwiftLint avant la compilation. Le contrôle peut aussi être lancé seul :

```sh
./scripts/lint.sh
```

Le script télécharge SwiftLint **0.65.1** dans un cache temporaire et vérifie son SHA-256.
`SWIFTLINT_BIN=/chemin/vers/swiftlint ./scripts/lint.sh` permet d'utiliser une installation
locale de la même version. La baseline conserve les écarts existants ; les nouvelles
violations sont bloquantes. Ne pas la régénérer pour masquer une régression.

Les règles de contribution et les commandes de validation sont décrites dans
[CONTRIBUTING.md](CONTRIBUTING.md).
