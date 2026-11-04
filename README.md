<!-- Created by Sébastien DAGUIN -->

# Interface Noctis — base Fullmoon

Interface SwiftUI avec conversations locales SwiftData et moteur Noctis exécuté sur le Mac.

## Développement

Le projet Xcode utilise le package local `../NoctisAi`. Conserver les deux dépôts côte à côte :

```text
NoctisAI/
├── NoctisAi/
└── fullmoon-ios/
```

Ouvrir `fullmoon.xcodeproj`, sélectionner la cible Mac et lancer l’application. Le modèle reste
`mlx-community/Ministral-3-14B-Instruct-2512-4bit` ; aucune version de dépendance n’a été changée.

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
