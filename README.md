<!-- Created by Sébastien DAGUIN -->

# Interface Noctis — base Fullmoon

Cette copie de Fullmoon est allégée pour préparer l’intégration du moteur Noctis.

## Fonctions conservées

- Interface SwiftUI pour Mac, iPhone, iPad et visionOS.
- Conversations et historique local avec SwiftData.
- Consultation des messages avec rendu Markdown.
- Recherche et suppression des conversations.
- Réglages d’apparence, prompt système et retours haptiques.

Le moteur Noctis n’est pas encore intégré. L’ancien moteur Fullmoon et ses
dépendances directes MLX et Transformers ont été retirés. L’application ne
charge ni ne télécharge de modèle. La saisie est désactivée avec le message
« Noctis n’est pas encore connecté. » jusqu’au branchement du package Noctis.
L’historique existant reste consultable et les réglages sont conservés.

La sélection de modèles, le parcours d’installation initial, l’affichage du
raisonnement, les raccourcis Siri, les demandes de note App Store et le suivi
GPU inutilisé ont été retirés. Les champs des modèles SwiftData existants sont
conservés pour ne pas modifier le schéma de stockage à cette étape.

## Origine et licence

Projet d’origine : [Fullmoon](https://github.com/mainframecomputer/fullmoon-ios),
par Mainframe Computer, Inc. Licence MIT : voir `LICENSE`.
Le moteur d’origine utilise [MLX Swift](https://github.com/ml-explore/mlx-swift).
