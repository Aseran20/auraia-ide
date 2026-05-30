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
| A3 | Source Control (git) | REBRAND → **« Versions »** (anglais ; moteur git intact) | patch | moyen | 1–2 | ✅ fait (`arclen-rebrand-scm-versions`) — container `Source Control` → **Versions** (titre + tooltip rail, Ctrl+Shift+G). Toute la mécanique git intacte. Vérifié live (onglet rail = « Versions »). |
| A4 | Run & Debug | REMOVE du rail | patch | faible | 1 | ✅ fait (arclen-clean-activity-bar) |
| A5 | Extensions | HIDE icône + verrou marketplace (gallery retirée) + raccourci off | patch + prepare_vscode.sh | faible-moyen | 1 | ✅ fait — gallery retirée (search « python » = 0), icône cachée, **et raccourci Ctrl+Shift+X retiré** (`arclen-extensions-no-reveal`) → ne ré-révèle plus l'icône. Commande viewlet intacte (palette/API). |
| A6 | Account (bas) | REMOVE (login GitHub / Settings Sync) | patch | faible-moyen | 1 | ✅ fait (arclen-clean-activity-bar) |
| A7 | Settings ⚙ (bas) | Menu roue curé + **écran Settings curé** + (plus tard) panneau « Arclen Preferences » | patch | élevé | 1–2 | 🟡 **menu roue fait** (`arclen-trim-gear-menu`, **6 fichiers**) — la roue ⚙ ne montre plus que **Command Palette · Settings**. Retirés (roue **+** File›Preferences) : **Profiles, Extensions, Keyboard Shortcuts, Snippets, Tasks, et Themes** (2026-05-30 — Themes retiré : Arclen Dark est le défaut, switch thème reste dans la palette « Preferences: Color Theme » ; sous-menu + commandes Color/Icon/Product theme intacts). **Note vérif Themes** : source confirmée (2 `appendMenuItem(GlobalActivity/MenubarPreferences, {Themes})` retirés) + TS-clean + même pattern que les 5 autres items déjà vérifiés live ; screenshot live du flyout non capturé (agent-browser ouvre mal le menu roue au survol). Toutes les commandes restent dans la palette (moteur intact). Vérifié live profil neuf. **Écran Settings (Ctrl+,) curé** (2026-05-30, patch `arclen-curate-settings`, 1 fichier `settingsLayout.ts`) : via le champ natif `ITOCEntry.hide` (mécanisme déjà utilisé par upstream → le rendu fait `.filter(child => child.hide !== true)`). **Cachées** : top-level **Application** (Proxy/Keyboard/Update/Telemetry/Sync/Network/Experimental) + **Security** (Workspace-Trust) ; sous-Workbench dev (Zen/Screencast/Browser) ; **11 sous-catégories Features-dev** (Debug, Testing, Source Control, Extensions, Task, Problems, Output, Comments, Remote, Notebook, Merge Editor). **Gardées** : Text Editor · Workbench › Appearance · Window · **Chat** (= config moteur Claude Code) · Features › Explorer/Search/Accessibility/Terminal/Timeline. « Commonly Used » remplacé par liste analyste (theme/font/wordwrap/autosave + chat.*). **Caveat** : `hide` retire de la **nav TOC** (le browse), pas de la **recherche/JSON** → moteur 100 % intact (principe gravé). Vérifié live : top-level = Commonly Used(8)·Text Editor·Workbench·Window·Chat·Features·Extensions (App/Security partis), TS-clean, apply-check ✓. **Résidu connu** : le node dynamique **Extensions (458)** (settings contribués par les extensions) n'est pas dans `tocData` → non couvert par ce levier (autre patch si on veut le cacher). **Reste** : panneau « Arclen Preferences » → Phase 2. **Approche figée (2026-05-30)** : NE PAS construire une UI webview from-scratch (= over-engineering, re-coder toggles/dropdowns + suivre chaque montée de version). Plutôt **contraindre l'éditeur NATIF à une allowlist** via le `ITOCFilter.include.keyPatterns` que `_resolveSettingsTree(tocData, …, filter)` accepte déjà (point d'injection : `settingsEditor2.ts`, là où le filtre `ADVANCED_SETTING_TAG` est construit) → l'écran Settings natif n'affiche plus que ~15 clés choisies, en réutilisant tout le rendu/lecture/écriture/recherche natif. **Conséquence** : cette allowlist *subsume* tout hide de catégorie → ne PAS investir plus dans le rabotage de l'arbre natif (`arclen-curate-settings`) d'ici là, ce serait jetable. Seule décision produit restante = la liste des ~15 clés (thème, police, word-wrap, auto-save, quelques `chat.*`). **MAJ 2026-05-30 (Strict — choix user)** : exécuté en 2 étapes. (1) Section **« Arclen »** ajoutée en tête du `tocData` (sous-sections **Appearance** / **Files & Deliverables** / **Assistant** → 10 vrais settings, rendus par widgets natifs ; first-match-wins `settingsTree.ts:673` → consommés du pool, pas de doublon sous les catégories). (2) **Strict** : `hide:true` sur top-level **editor/workbench/window/chat/features** → nav core = **Arclen** seul + Commonly Used. **Extensions** géré par **allowlist d'IDs** dans `settingsEditor2.ts:1496` = `['anthropic.claude-code']` (extensible aux futures extensions Arclen ; push seulement si non-vide) → **458 → 14 (Claude Code only)**, clés `claudeCode.*` confirmées live. **Correction d'approche vs note ci-dessus** : `ITOCFilter.include.keyPatterns` *élargit* par nœud (union `settingsTree.ts:579`, `.some`), donc **inutilisable comme allowlist pure** pour le core ; la vraie restriction = `hide` (core, data-only) + filtre d'IDs (extensions). Patch `arclen-curate-settings` (**2 fichiers** : settingsLayout.ts + settingsEditor2.ts) régénéré, apply-check upstream ✓, TS-clean. Vérifié live : TOC = **Commonly Used(8)·Arclen(10)·Extensions(14 Claude)** ; recherche intacte (chemin `searchResultModel` séparé). **Reste = étape 3** : rebrand titre/commande « Settings » → « Arclen Preferences » (+ option : enrichir Arclen/Assistant avec d'autres knobs Claude si voulu). |

## 2. Barre de menu (trim en place)

| # | Menu | Décision | Statut |
|---|---|---|---|
| M0 | Run / Selection / Go | SUPPRIMÉS | ✅ fait (arclen-hide-run-menu, arclen-hide-menus) |
| M1 | File | KEEP, trimmé | ✅ fait (`arclen-trim-file-menu`) — File = New Text File / New File… / Open File… / Open Folder… / Open Recent / Save·As·All / Auto Save / Preferences / Revert / Close Editor / Close Window / Exit. **Retirés** : New Window, New Window with Profile, Share, et tout le « workspace » (Open Workspace from File, Add Folder to Workspace, Save Workspace As, Duplicate Workspace, Close Workspace). Commandes + raccourcis intacts. Vérifié live profil neuf. |
| M2 | Edit | KEEP, trimmé | ✅ fait (`arclen-trim-edit-menu`) — Edit = Undo/Redo/Cut/Copy/Paste/Find/Replace + Find/Replace in Files. **Retirés** : Copy As, Toggle Line/Block Comment, Emmet Expand Abbreviation. Commandes + raccourcis intacts. Vérifié live. |
| M3 | View | VIDÉ | ✅ fait (`arclen-trim-view-menu` — sous-menu View retiré du menubar, comme Selection/Go). Palette reste Ctrl+Shift+P. Vérifié live (menubar = File · Edit · Assistant · Help). |
| M4 | Terminal | RENAME → « Assistant » ; trim : garder Nouveau/Effacer ; drop Run Task / Configure Tasks / Build | ✅ fait (arclen-terminal-assistant) — menu = « Assistant », ne garde que New Terminal + Split ; Run Active File/Selected Text + tous les items Tâches (Run/Build/Show/Restart/Terminate/Configure) + New Window retirés. **Moteur intact** : commandes tasks toujours enregistrées (palette + API). Vérifié live. |
| M5 | Help | Trim : garder seulement À propos | ✅ fait (`arclen-trim-help-menu`, 8 fichiers) — Help = **uniquement « About »**. Retirés : Toggle Developer Tools, Open Process Explorer, Report Issue, Show Release Notes, Show All Commands, Welcome, Open Walkthrough, Editor Playground, Ask @vscode + tous les liens MS (Documentation/Tips/Video/Keyboard Shortcuts/YouTube/Feature Requests/License/Privacy). Toutes les commandes restent dans la palette. Vérifié live. **Note patch** : le bloc Help « Welcome » a une ligne de contexte brandée (`get started in !!APP_NAME!!.`) → le placeholder `!!APP_NAME!!` est requis dans le patch (sinon check-patches non-substitué échoue). |

## 3. Éditeur & Welcome

| # | Surface | Décision | Mécanisme | Statut |
|---|---|---|---|---|
| E1 | Welcome — titre | « M&A Intelligence Platform » | setting/patch | ✅ fait |
| E2 | Welcome — Start (New File / Open File / Open Folder) | REBRAND langage M&A (Ouvrir mandat…) | patch | 🟡 à finir |
| E3 | Minimap / breadcrumbs / n° ligne / outline éditeur | OFF par défaut | setting | ✅ fait — `editor.minimap.enabled:false`, `editor.lineNumbers:"off"`, `breadcrumbs.enabled:false` dans `configurationDefaults` (livré via fondation `arclen-product-config-defaults`). |
| E4 | Outline (Explorer) | HIDE (symboles de code) | patch (`when:false`) | ✅ fait (arclen-hide-explorer-views) — **renforcé 2026-05-30** : `hideByDefault` ne masquait que les profils NEUFS (un profil déjà utilisé gardait l'état stocké → la vue revenait). Passé à **`when: ContextKeyExpr.false()`** → vue **complètement retirée de l'explorateur sur TOUS les profils**. Moteur outline intact. Vérifié live (headers explorateur = Open Editors + arbre seulement). |
| E5 | Timeline (Explorer) | HIDE (repli possible dans « Historique » plus tard) | patch (`when:false`) | ✅ fait (arclen-hide-explorer-views) — **renforcé 2026-05-30** : idem E4, `when = ContextKeyExpr.false()` (au lieu de `hideByDefault`) → vue Timeline **retirée sur tous profils**. Moteur timeline + historique git intacts. Vérifié live. **Résidu mineur** : la commande clic-droit « Open Timeline » subsiste (no-op puisque la vue est cachée) — à retirer si gênant. |

## 4. Barre de statut (bas)

| # | Décision | Mécanisme | Statut |
|---|---|---|---|
| S1 | Trim : drop langage, encodage, ligne/col, indentation, smiley feedback. Garder : cloche notifications | patch | ✅ fait (arclen-trim-status-bar) — `EditorStatus.updateElement` filtre les ids `status.editor.{mode,selection,indentation,encoding,eol}`. État + commandes (change language/encoding/EOL…) intacts. Vérifié live (fichier untitled ouvert : footer droite = seulement la cloche). Pas de smiley feedback dans ce build VSCodium. **Compteur Problems `⊗0 ⚠0` (bas-gauche) aussi masqué** (2026-05-30) — `arclen-trim-status-bar` étendu à `markers.contribution.ts` : `updateEntryVisibility('status.problems', false)` juste après l'enregistrement. Vue Problems + commande `toggleProblems` intactes. **Indicateur Remote `><` (`status.host`, bas-gauche) aussi retiré** (2026-05-30, même patch — `remoteIndicator.ts` : `updateEntryVisibility('status.host', false)`) : dev-y/inutile pour analyste local, moteur remote + commande « Open Remote Window » intacts. **Cloche notifications gardée** (décision user : montre la progression Claude). Footer final = **status bar gauche vide · cloche à droite**. Vérifié déterministiquement via `dev/ui-inventory.sh --expect-absent status.host --expect-present status.notifications` (exit 0), TS-clean, apply-check ✓. |
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
| T2 | Vérifier qu'aucun profil/compte ne réapparaît ici | — | ✅ vérifié — header n'a aucun élément Account/profil (login retiré via A6). Seul le ⚙ « Manage » subsiste (→ A7). |
| T3 | **Barre de recherche centrale (Command Center)** — ouvre la palette de commandes (full code) | setting | ✅ fait (`window.commandCenter:false`) — vérifié profil neuf, header n'affiche plus que le titre |
| T4 | Bouton **Split editor** (haut-droit zone éditeur) — peu utile mono-éditeur analyste | ~~patch~~ → setting | ✅ fait (configurationDefaults) — voir T4+T5 ci-dessous |
| T5 | Menu **« … »** (overflow haut-droit) | ~~patch~~ → setting | ✅ fait — `"workbench.editor.editorActionsLocation": "hidden"`. **Découverte** : avec `showTabs:none`, toute la toolbar d'actions éditeur (split **+** « … ») migre dans le **title bar** (`editorActionsEnabled` = `DEFAULT && showTabs===NONE`) ; `hidden` la désactive entièrement → split ET « … » partent ensemble. **Aucun patch source** (on avait commencé à retirer le bouton split à la source → reverté, redondant), zéro risque TS6133/rebase, réversible. Commandes intactes (Ctrl+W, palette). Vérifié live. ⚠️ cache aussi les futures actions title-bar (boutons cockpit Phase 3) → on rebascule à ce moment-là. Note initiale « ré-expose des toggles de layout » corrigée : ces toggles sont dans le Layout Control (T1, off) + menu View (M3), PAS dans le « … » éditeur. |

## 8. Vocabulaire

| # | Décision | Statut |
|---|---|---|
| V1 | Passe légère (Welcome, états vides, titres) | 🟡 Welcome Start fait (patch `arclen-welcome-vocab`), **en anglais** (décision 2026-05-30) : New File → **New Document**, Open File → **Open File…**, Open Folder → **Open Mandate…** (+ variantes Mac/Web). Vérifié live. Reste : autres états vides / titres au fil de l'eau. |
| V1b | Labels du menu Assistant | ✅ fait (`arclen-terminal-assistant`) — **en anglais** : New Terminal → **New Session**, Split Terminal → **Split**. Vérifié live. |
| V2 | Renommage profond (mandate / deal / livrable) via l10n | ⏸ différé |

> 🌐 **LANGUE PRODUIT = ANGLAIS** (décision user 2026-05-30, « et tout en anglais stp ») : toute l'UI Arclen est en **anglais** (analystes M&A/finance internationaux). Le **rebrand M&A reste** mais en anglais : « folder » → **mandate**, « terminal » → **Assistant / session**. Les labels FR posés avant cette date ont été retraduits (welcome-vocab, terminal-assistant). Tout nouveau label = anglais.

---

## Acquis hors dé-scaring (rappel)
- ✅ Thème Arclen Dark par défaut · ✅ Polices IBM Plex par défaut

> 🧱 **FONDATION (2026-05-29) — patch `arclen-product-config-defaults`** : `product.json` `configurationDefaults` est **web-only** upstream → **ignoré dans le `.exe` desktop**. Ce patch le branche dans `DefaultConfiguration` (`configuration.ts`). **Sans lui, TOUS les `✅ fait (configurationDefaults)` de cette TODO étaient morts en packagé** (minimap, workspace trust, update.mode, secondary sidebar, showTabs, layoutControl, commandCenter, terminal defaultLocation…). Vérifié : `showTabs:none` seul dans product.json cache les onglets sur profil neuf. → re-vérifier en packagé que ce bloc s'applique bien maintenant.
>
> ⚠️ **EFFET DE BORD (2026-05-30) — corrigé** : comme la fondation applique désormais TOUTES les valeurs, une valeur enum **invalide** latente s'est mise à mordre. `workbench.activityBar.location` valait `"side"` (valeur inexistante ; l'enum = `default`/`top`/`bottom`/`hidden`) → le **rail de la barre d'activité a totalement disparu** (Explorer/Recherche/Git inaccessibles, sidebar vide). Avant la fondation, `"side"` était ignoré donc le rail s'affichait par défaut. **Corrigé → `"default"`**, vérifié profil neuf (rail = Explorer · Recherche · Source Control · ⚙ Manage, sans Debug/Extensions/Compte). Reste une clé morte inoffensive `debug.console.showInStatusBar` (non enregistrée, ignorée). **Leçon** (dans skill arclen-dev) : toute valeur enum d'un `configurationDefaults` doit être vérifiée à la source, pas devinée par le mot conceptuel.

## Phase 3 (additif / moat) — **stratégie figée : voir [`phase3-additive-strategy.md`](phase3-additive-strategy.md)** (brainstorm 2026-05-29)
Décisions clés : philo **A+B** (réactif piloté, cap = cockpit) · « marketplace verrouillé » = **nous curons** (bundler des extensions tierces est OK) · Agents Window MS **non héritable** (Copilot-gated) mais valide la forme · **l'extension officielle Claude Code fait ~80 % du cockpit** (sur Open VSX, bundlable) · cockpit en **escalier** (Niv.0 bundle officielle → Niv.1 Claude Manager → Niv.2 patch layout / notre extension) · séquence = **dogfood → spike API → fige**.

- 🟡 **AD1** Niv.0 : extension officielle **bundlée** ✅ (product.json `builtInExtensions` + vsix Open VSX). **Position recadrée (2026-05-30, décision user — l'autre IA l'avait mise à droite, rejeté)** : PAS de chat à droite auto. `"claudeCode.preferredLocation":"panel"` (product.json `configurationDefaults`, **pas de patch**) donne exactement le flux voulu : (1) **aucun auto-open** au démarrage (ni droite, ni centre), (2) **icône ✳ rail GAUCHE** = launcher de sessions (New session / Local·Web / liste), (3) ouvrir une session = **onglet au CENTRE** (zone éditeur). Vérifié live profil neuf (palette « Claude Code: Open in Editor » → centre). Alt dispo : `claudeCode.useTerminal` (Claude comme terminal, hint « Prefer the Terminal experience »). **Reste** : masquer le walkthrough « Get started » de l'ext sur le Welcome (P2/V1).
- ⏸ AD2 Niv.1 : bundler/forker Claude Manager (hub sessions, Apache-2.0)
- ✅ **AD5** Onglets verticaux : Open Editors natif restylé (CSS) + lignes 28px + `hideByDefault:false` → patch `arclen-open-editors-vtabs` (3 fichiers : `explorerViewlet`/`openEditorsView`/`style.css`, **sans** hack source). Onglets horizontaux off via `"workbench.editor.showTabs":"none"` dans product.json (marche grâce à `arclen-product-config-defaults`). **Consolidation faite** (hunk showTabs retiré d'AD5) + vérifié profil neuf 2026-05-29.
- ✅ **AD6** « Open in App » — clic-droit explorateur (ou Open Editors / palette) ouvre un fichier dans son **app OS native** : `.pptx`→PowerPoint, `.xlsx`→Excel, `.pdf`→lecteur défaut, via les associations Windows. Évite le « Reveal in File Explorer puis double-clic ». **Patch natif maison `arclen-open-in-app`** (5 fichiers, sans dépendance/extension tierce) : nouvelle méthode `INativeHostService.openPath` (= electron `shell.openPath`, la bonne API pour fichiers locaux — `openExternal` est pour les URLs), helper `openResourcesInOSApp` (calqué sur `revealResourcesInOS`, gère WSL), commande `arclen.openInDefaultApp` + entrées ExplorerContext/OpenEditorsContext/palette (**ordre 8 — tout en haut du menu navigation, 1ᵉʳ item, au-dessus de « Open to the Side »**, 2026-05-30, deliverables-first). **Moteur fichiers 100 % intact.** TS-clean, apply-check ✓, vérifié live (menu DOM = « Open in App » sous Reveal ; lancement réel non déclenché en QA pour ne pas pop d'app). 2026-05-30.
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
6. ✅ **S1** trim status bar (footer, patch `arclen-trim-status-bar`) + **T4/T5** split & menu « … » du header (`editorActionsLocation:hidden`) — 2026-05-30, vérifié live profil neuf, TS-clean, 13 patchs OK
7. ✅ **V1b** labels menu Assistant (Nouvelle session / Diviser) + **V1** Welcome Start FR M&A (`arclen-welcome-vocab`) — 2026-05-30, vérifié live profil neuf, TS-clean, 14 patchs OK
8. ✅ **M1/M2/M3/M5** trim menus File/Edit/View/Help + **A3** Versions (rebrand git) + **A7** menu roue curé + **A5-refin** (Ctrl+Shift+X off) + **E3/T2** vérifs — 2026-05-30, **passe ANGLAIS** (tout le rebrand FR retraduit). 7 nouveaux patchs, TS-clean, apply-check OK (sauf trim-view = faux-négatif dépendance connu), tout vérifié live profil neuf. Menubar final = **File · Edit · Assistant · Help** ; Help = **About** seul ; roue ⚙ = **Command Palette · Settings · Themes**.
9. ✅ **A7-Settings** écran Settings (Ctrl+,) curé via `ITOCEntry.hide` (patch `arclen-curate-settings`, 1 fichier) — App/Security/Features-dev cachés, Chat + Commonly-Used analyste gardés — 2026-05-30, vérifié live, TS-clean, apply-check ✓.
10. ✅ **A7-Strict** « Arclen Preferences » substrat natif (patch `arclen-curate-settings`, 2 fichiers) — section **Arclen** en tête (widgets natifs, vrais settings), top-level dev cachés (`hide`), **allowlist d'extensions** = Claude Code only (458→14). TOC final = **Commonly Used·Arclen·Extensions(Claude)**. 2026-05-30, vérifié live, TS-clean, apply-check ✓. Décision design = **Strict** (user).
11. ✅ **A7-étape 3** rebrand « Settings » → **« Arclen Preferences »** (patch `arclen-rebrand-preferences`, 2 fichiers : `preferencesEditorInput.ts` titre d'onglet + `preferences.contribution.ts` commande Ctrl+,/palette/menu) **+ masquage des onglets de scope User/Workspace/Remote/Folder** (`settingsEditor2.ts`, `targetWidgetContainer.style.display='none'` — widget gardé/épinglé USER_LOCAL, réglages workspace se chargent toujours, moteur intact). 2026-05-30, vérifié live (header = « ⚙ Arclen Preferences », aucun onglet de scope, TOC intact), TS-clean, apply-check ✓ (2 passed).
12. **Hygiène dev** (2026-05-30) : scripts auto-nettoyants pour ne plus accumuler d'orphelins `tsgo` qui laggent le PC — `check-ts.sh` balaye au démarrage + trap, `relaunch.sh` balaye à chaque run, nouveau **`dev/dev-cleanup.sh`** = bouton panique (tsgo/esbuild/chromium agent-browser + profils temp + consoles, sans toucher au vrai Chrome). Voir mémoire `dev-process-hygiene`.
13. **Reste (medium/lourd)** : (option) enrichir Arclen/Assistant avec d'autres knobs Claude ; résidu « Open Timeline » ; **V1** au fil de l'eau (walkthrough Claude, vocab) ; vérif build packagé.

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
