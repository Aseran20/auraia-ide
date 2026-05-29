# Arclen — Carte des surfaces & TODO de dé-scaring

> Tracker vivant. Source des décisions : brainstorm 2026-05-29 (voir `chantier-arclen.md` pour la vision).
> **Principe gravé : on cache la SURFACE humaine, le MOTEUR reste 100 % intact pour Claude Code** (git, terminal, extensions, fichiers, tasks).

**Statut** : ✅ fait · 🟡 partiel · ⬜ à faire · ⏸ différé (phase ultérieure)
**Mécanisme** : `setting` = defaults du build (réversible, léger) · `patch` = modif source (profond)
**Phase** : 1 = enlever (cheap, maintenant) · 2 = recadrer · 3 = ajouter/orchestrer (extension custom)

---

## 1. Barre d'activité (rail gauche)

| # | Surface | Décision | Mécanisme | Risque | Phase | Statut |
|---|---|---|---|---|---|---|
| A1 | Explorer | KEEP — tiroir à livrables (relabel léger « Mandat » plus tard) | — | — | — | ✅ garde |
| A2 | Search | KEEP — chercher dans les livrables | — | — | — | ✅ garde |
| A3 | Source Control (git) | REBRAND → « Historique / Versions » (moteur git intact) | patch | moyen | 1–2 | ⬜ |
| A4 | Run & Debug | REMOVE du rail | patch | faible | 1 | ✅ fait (arclen-clean-activity-bar) |
| A5 | Extensions | HIDE icône + verrou marketplace (gallery retirée) | patch + prepare_vscode.sh | faible-moyen | 1 | ✅ fait — vérifié (search « python » = 0 résultat). Reste : retirer le raccourci Ctrl+Shift+X qui ré-révèle l'icône (refinement) |
| A6 | Account (bas) | REMOVE (login GitHub / Settings Sync) | patch | faible-moyen | 1 | ✅ fait (arclen-clean-activity-bar) |
| A7 | Settings ⚙ (bas) | REPLACE → panneau « Préférences Arclen » curé ; supprimer items dev du menu roue (Profiles / Snippets / Tasks / Keyboard Shortcuts) | patch | élevé | 1–2 | ⬜ |

## 2. Barre de menu (trim en place)

| # | Menu | Décision | Statut |
|---|---|---|---|
| M0 | Run / Selection / Go | SUPPRIMÉS | ✅ fait (arclen-hide-run-menu, arclen-hide-menus) |
| M1 | File | KEEP, trimmé : Ouvrir mandat / Ouvrir fichier / Enregistrer / Récents / Quitter. Drop : New Window, workspace code | ⬜ |
| M2 | Edit | KEEP, trimmé : Annuler/Rétablir/Couper/Copier/Coller/Rechercher. Drop : spécifique code | ⬜ |
| M3 | View | VIDÉ (tout est code). Command Palette reste au clavier (Ctrl+Shift+P) en attendant la palette d'actions M&A (Phase 3) | ⬜ |
| M4 | Terminal | RENAME → « Assistant » ; trim : garder Nouveau/Effacer ; drop Run Task / Configure Tasks / Build | ✅ fait (arclen-terminal-assistant) — menu = « Assistant », ne garde que New Terminal + Split ; Run Active File/Selected Text + tous les items Tâches (Run/Build/Show/Restart/Terminate/Configure) + New Window retirés. **Moteur intact** : commandes tasks toujours enregistrées (palette + API). Vérifié live. |
| M5 | Help | Trim/rebrand : garder À propos (Arclen) ; drop Dev Tools, Process Explorer, etc. | ⬜ |

## 3. Éditeur & Welcome

| # | Surface | Décision | Mécanisme | Statut |
|---|---|---|---|---|
| E1 | Welcome — titre | « M&A Intelligence Platform » | setting/patch | ✅ fait |
| E2 | Welcome — Start (New File / Open File / Open Folder) | REBRAND langage M&A (Ouvrir mandat…) | patch | 🟡 à finir |
| E3 | Minimap / breadcrumbs / n° ligne / outline éditeur | OFF par défaut | setting | 🟡 partiel |
| E4 | Outline (Explorer) | HIDE (symboles de code) | patch (`hideByDefault`) | ✅ fait (arclen-hide-explorer-views) — vérifié profil neuf |
| E5 | Timeline (Explorer) | HIDE (repli possible dans « Historique » plus tard) | patch (`hideByDefault`) | ✅ fait (arclen-hide-explorer-views) — vérifié profil neuf |

## 4. Barre de statut (bas)

| # | Décision | Mécanisme | Statut |
|---|---|---|---|
| S1 | Trim : drop langage, encodage, ligne/col, indentation, smiley feedback. Garder : cloche notifications | patch | ⬜ |
| S2 | Afficher nom du mandat / agent actif | patch/extension | ⏸ Phase 3 |

## 5. Panneaux (bas)

| # | Décision | Mécanisme | Statut |
|---|---|---|---|
| P1 | Garder l'onglet Terminal → « Assistant » | patch | ✅ fait (arclen-terminal-assistant) — onglet panneau = ASSISTANT (titre container + nom de vue). Vérifié live. |
| P2 | HIDE : Problems, Output, Debug Console (+ Ports) | patch | ✅ fait (arclen-clean-activity-bar étendu) — les containers de panneau `workbench.panel.markers/.output/.repl` + `~remote.forwardedPortsContainer` filtrés de la composite-bar (mêmes 2 hunks que la barre d'activité). Containers restent enregistrés (logs/engine intacts). Vérifié live : onglets disparus. |
| P3 | **Terminal au CENTRE (zone éditeur), panneau bas supprimé** — c'est là qu'on utilise Claude Code | setting | ✅ fait (`terminal.integrated.defaultLocation: "editor"`) — nouveau terminal s'ouvre plein centre comme onglet éditeur ; combiné à P2 → panneau bas vide donc masqué (hideIfEmpty). Livré dev+packagé via `arclen-product-config-defaults`. Vérifié live (termInEditor=true). |

## 6. Dialogues & notifications globales

| # | Décision | Mécanisme | Statut |
|---|---|---|---|
| G1 | Walkthroughs / Welcome announcements | setting + patch | ✅ fait |
| G2 | Workspace Trust (« do you trust ») | setting (configurationDefaults) | ✅ fait (enabled/banner/startupPrompt = off/never) |
| G3 | Notifs update / extensions | setting (configurationDefaults) | ✅ fait (update.mode none, autoUpdate/autoCheckUpdates off, ignoreRecommendations on) |

## 7. Header (barre de titre)

| # | Décision | Mécanisme | Statut |
|---|---|---|---|
| T1 | Contrôles de layout minimaux | setting | ✅ fait — `workbench.layoutControl.enabled:false` ; vérifié profil neuf (0 icône) via `arclen-product-config-defaults` |
| T2 | Vérifier qu'aucun profil/compte ne réapparaît ici | — | ⬜ |
| T3 | **Barre de recherche centrale (Command Center)** — ouvre la palette de commandes (full code) | setting | ✅ fait (`window.commandCenter:false`) — vérifié profil neuf, header n'affiche plus que le titre |
| T4 | Bouton **Split editor** (haut-droit zone éditeur) — peu utile mono-éditeur analyste | patch | ⬜ (cheap, à voir) |
| T5 | Menu **« … »** (overflow haut-droit) — ⚠️ ré-expose des toggles de layout (panneau, etc.) qui peuvent re-révéler ce qu'on cache | patch | ⬜ (medium — important pour ne pas annuler les autres masquages) |

## 8. Vocabulaire

| # | Décision | Statut |
|---|---|---|
| V1 | Passe légère maintenant (Welcome, états vides, titres) | ⬜ |
| V1b | Labels du menu Assistant : « New Terminal » → « Nouvelle session », « Split Terminal » → « Diviser » | ⬜ (cheap, dans arclen-terminal-assistant) |
| V2 | Renommage profond (mandat / deal / livrable) via l10n | ⏸ différé |

---

## Acquis hors dé-scaring (rappel)
- ✅ Thème Arclen Dark par défaut · ✅ Polices IBM Plex par défaut

> 🧱 **FONDATION (2026-05-29) — patch `arclen-product-config-defaults`** : `product.json` `configurationDefaults` est **web-only** upstream → **ignoré dans le `.exe` desktop**. Ce patch le branche dans `DefaultConfiguration` (`configuration.ts`). **Sans lui, TOUS les `✅ fait (configurationDefaults)` de cette TODO étaient morts en packagé** (minimap, workspace trust, update.mode, secondary sidebar, showTabs, layoutControl, commandCenter, terminal defaultLocation…). Vérifié : `showTabs:none` seul dans product.json cache les onglets sur profil neuf. → re-vérifier en packagé que ce bloc s'applique bien maintenant.

## Phase 3 (additif / moat) — **stratégie figée : voir [`phase3-additive-strategy.md`](phase3-additive-strategy.md)** (brainstorm 2026-05-29)
Décisions clés : philo **A+B** (réactif piloté, cap = cockpit) · « marketplace verrouillé » = **nous curons** (bundler des extensions tierces est OK) · Agents Window MS **non héritable** (Copilot-gated) mais valide la forme · **l'extension officielle Claude Code fait ~80 % du cockpit** (sur Open VSX, bundlable) · cockpit en **escalier** (Niv.0 bundle officielle → Niv.1 Claude Manager → Niv.2 patch layout / notre extension) · séquence = **dogfood → spike API → fige**.

- ⬜ **AD1** Niv.0 : bundler extension officielle + chat à droite par défaut (prêt à faire)
- ⏸ AD2 Niv.1 : bundler/forker Claude Manager (hub sessions, Apache-2.0)
- ✅ **AD5** Onglets verticaux : Open Editors natif restylé (CSS) + lignes 28px + `hideByDefault:false` → patch `arclen-open-editors-vtabs` (3 fichiers : `explorerViewlet`/`openEditorsView`/`style.css`, **sans** hack source). Onglets horizontaux off via `"workbench.editor.showTabs":"none"` dans product.json (marche grâce à `arclen-product-config-defaults`). **Consolidation faite** (hunk showTabs retiré d'AD5) + vérifié profil neuf 2026-05-29.
- 🔬 AD3/AD4 spikes : patch layout triptyque · API `chatSessionsProvider` dans le fork
- ⏸ Cockpit multi-agents (sessions nommées par flow/livrable) · palette d'actions M&A
- ⏸ Aperçu livrables (PPTX/XLSX) + boutons-actions (tasks → « Générer data pack »)
- ⏸ Pont repo COM (PPT/Excel) · templates mandat / onboarding agent
- ⏸ Section B du chantier : workflows métier réels (à remplir ensemble — dicte le contenu Phase 3)

---

## Prochain lot suggéré (Phase 1, cheap, fort impact visuel)
1. ✅ **A4** Run & Debug off · **A6** Account remove · **A5** Extensions icône cachée → patch `arclen-clean-activity-bar` (2026-05-29) — vérifié live, TS-clean
2. ✅ **A5-suite** verrou marketplace (`extensionsGallery` retirée dans `prepare_vscode.sh`) — vérifié live
3. ✅ **E4/E5** Outline + Timeline off (patch `arclen-hide-explorer-views`) · **G2** Workspace Trust off · **G3** notifs — vérifié profil neuf (2026-05-29)
4. ✅ **M4/P1** Terminal → « Assistant » (menu renommé + trimmé, onglet panneau ASSISTANT) — patch `arclen-terminal-assistant` (2026-05-29), vérifié live, TS-clean
5. ✅ **P2/P3 + T3** Panneau bas vidé (Problems/Output/Debug/Ports off) + **terminal au centre** (`defaultLocation:editor`) + **Command Center off** (`window.commandCenter:false`) — patch `arclen-clean-activity-bar` étendu + 2 settings (2026-05-29)
6. **S1** trim status bar (footer) + **T4/T5** split & menu « … » du header ← PROCHAIN (cheap–medium)
7. **V1/V1b** passe vocabulaire (labels menu Assistant) — cheap
8. Puis les plus lourds : **A3** Historique, **A7** Préférences Arclen, **M1/M2/M3** trim menus File/Edit/View

> ⚠️ **Caveat « profil existant »** : `hideByDefault` (Outline/Timeline) ne s'applique qu'aux **profils neufs** ; un profil déjà utilisé garde l'état stocké des vues. Idem l'icône Extensions revient via Ctrl+Shift+X dans la session. Pour la barre d'activité on a aussi filtré le cache → propre même sur profil existant. Vérif définitive = build packagé / profil neuf.

> ✅ **RÉSOLU (2026-05-29) — `product.json.configurationDefaults` était MORT dans le build desktop, maintenant patché.** Cause racine (confirmée dans le source) : upstream ne lit les configurationDefaults que depuis `environmentService.options` (= options du workbench **WEB**), `undefined` en Electron → tout le bloc `configurationDefaults` de product.json était silencieusement ignoré (dev ET packagé). C'est pour ça que `showTabs` avait dû être patché à la source (AD5). **Fix** : patch `arclen-product-config-defaults` enregistre `product.configurationDefaults` au même timing que le web (constructeur `DefaultConfiguration`, `configuration.ts`). Vérifié profil neuf vierge : commandCenter:false, layoutControl 0 icône, showTabs none — tout le bloc s'applique. Désormais : **un setting dans le `configurationDefaults` racine s'applique en dev (après transpile+relaunch) ET en packagé.** → AD5 (source-patch showTabs) est devenu redondant.

## Note — bruit dev-only (pas un bug produit) + built-ins retirables [INVESTIGUÉ 2026-05-29]
Les erreurs rouges en bas à droite à chaque relance (« Activating extension 'vscode.X' failed:
Cannot find module …/out/extension.js ») sont un **artefact de l'arbre de DEV** : les extensions
intégrées n'y sont pas compilées (`out/` absent). Ce **n'est PAS 3 extensions fixes** — c'est
**tout** built-in non compilé (git, github, merge-conflict, debug-auto-launch, emmet…) ; la pile de
notifs n'en montre que ~3 à la fois. Elles **n'apparaissent PAS** dans l'`.exe` packagé (gulp compile
tous les built-ins au packaging).

**Tentative de les compiler en dev (`npm run gulp compile-extensions`) → échoue** (TS2688 @types
mocha/node manquants dans l'arbre dev). Donc : **pas de fix dev propre dispo** → on vit avec, c'est
cosmétique et ça ne ship pas. (`compile-extension:<name>` marche au cas par cas si besoin ponctuel.)

**Retirer des built-ins du PRODUIT = DÉFÉRÉ ⏸** — testé : `rm -rf extensions/<x>` **casse le build**
car les extensions utilisent des **TS project references** entre elles (supprimer une cible
référencée → TS5058 chez le dépendant). Vérifié : `emmet` ET `github-authentication` sont tous deux
référencés. Suppression propre = démêler le graphe (retirer les dépendants / les `references`), pas
juste `rm`. Backout effectué, build sûr. À refaire proprement plus tard si on veut alléger le produit.
