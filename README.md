# EACN – Communications sans fil : simulation et mise en œuvre sur USRP

Projet de l'UE **UM4EE201 – EACN (Wireless Communications)**, M1 Systèmes Communicants, Sorbonne Université. Travail réalisé en binôme.

L'objectif : construire une chaîne de communication numérique complète, d'abord en simulation (Livescripts 1 à 5), puis la mettre en œuvre sur du matériel réel (radio logicielle USRP B210).

## Contenu

### Simulation – `Impl/Livescript 1` à `Impl/Livescript 5`

| Livescript | Thème | Notions |
|------------|-------|---------|
| 1 | Simulation dans l'espace des symboles | Mapping / démapping 16-QAM, estimation de symboles, taux d'erreur binaire (BER) |
| 2 | Mise en forme d'impulsion | Filtre en cosinus surélevé (*raised cosine*), facteur de roll-off |
| 3 | Simulation dans l'espace du signal | Filtrage d'émission / de réception en racine de cosinus surélevé, suréchantillonnage, comparaison au BER théorique |
| 4 | Modèles de canal | Génération de canaux de propagation |
| 5 | Chaîne complète avec canal | Émission, canal, réception et BER |

Chaque dossier contient le Livescript principal (`main_*.mlx`) et les fonctions qu'il appelle (`mapping_QAM`, `demapping_QAM`, `symbol_estimation_QAM`, `raised_cosine`, `convolution_TX`, `convolution_RX`, `generate_channel`, `biterr`).

### Mise en œuvre sur USRP – `Impl/*.m`

- `projet.m` : génération de la trame (symboles pilotes + symboles de données 16-QAM, mise en forme RRC) et émission via l'USRP B210, avec enregistrement du spectre.
- `session2_TX.m` : émetteur ; sauvegarde les paramètres et les bits émis dans `tx_params.mat`.
- `session2_RX.m` : récepteur ; synchronisation de trame, estimation du canal sur les pilotes, égalisation, constellation en temps réel et mesure du BER.
- `Mesures/syncfun.m` : fonction de synchronisation utilisée par le récepteur.
- `Impl/Resultats/` et `Impl/RX constellation.png` : exemples de résultats (spectre émis, constellation reçue).

## Utilisation

- MATLAB avec la *Communications Toolbox* pour les Livescripts.
- Pour la partie matérielle : le package de support *USRP Radio* et un USRP B210.
- Ouvrir MATLAB **dans le dossier `Impl/`** : les scripts ajoutent automatiquement `Livescript 1`, `Livescript 3` et `../Mesures` au chemin.
- Ordre pour la partie USRP : lancer `session2_TX.m` (crée `tx_params.mat`), puis `session2_RX.m`.
