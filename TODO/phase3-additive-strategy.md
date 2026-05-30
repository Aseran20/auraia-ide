# Phase 3 — Stratégie additive (le cockpit & au-delà)

> **Décision « une fois pour toute »** — brainstorm 2026-05-29.
> Répond à : *une fois l'app dé-scarée (propre mais nue), qu'est-ce qu'on AJOUTE ?*
> Compagnons : `chantier-arclen.md` (vision, section E), `TODO.md` (carte des surfaces, bloc Phase 3 différé).
> **Principe gravé inchangé : on simplifie la SURFACE humaine, le MOTEUR reste 100 % intact pour Claude Code.**

---

## 0. TL;DR (si tu ne lis qu'une chose)

1. **Philosophie = A+B.** Réactif comme *moteur de décision* (on n'ajoute pas dans le vide), cockpit multi-agents comme *cap* (le seul vrai différenciateur).
2. **« Marketplace verrouillé » = NOUS curons.** L'utilisateur ne peut pas ajouter d'extension ; *nous* pré-installons ce qu'on veut. → bundler une extension tierce est **first-class**, plus une entorse.
3. **L'Agents Window de Microsoft n'est PAS héritable** (verrouillée à Copilot + login GitHub). Mais elle **valide publiquement la forme** qu'on vise.
4. **L'extension officielle Claude Code fait déjà ~80 % du cockpit** (chat déplaçable à droite, liste de sessions, sessions parallèles, historique) et est **sur Open VSX → bundlable**.
5. **Cockpit = escalier de coût croissant**, on ne monte une marche que si la précédente ne suffit pas :
   - **Niv. 0** (gratuit) : bundler l'extension officielle, chat à droite par défaut, Explorer à gauche.
   - **Niv. 1** : bundler/forker **Claude Manager** (Apache-2.0) pour le hub sessions/skills/agents.
   - **Niv. 2** (seulement si le dogfood le réclame) : petit patch de layout (triptyque sans clic) et/ou notre extension fine pour le *delta* non couvert.
6. **Séquence = dogfood d'abord** (1-2 vrais mandats sur l'app propre-mais-nue) → **spike time-boxé** sur l'API proposée → puis on fige.

---

## 1. Décisions verrouillées

### D1 — Philosophie d'ajout : **A+B**
- **A (réactif)** est le moteur : chaque ajout doit répondre à une friction réelle vécue, pas à une intuition. Le moat se construit par accumulation de douleurs résolues.
- **B (proactif)** est le cap : le **cockpit multi-agents** (sessions Claude Code nommées par flow/livrable) est la seule chose qui justifie qu'Arclen existe plutôt qu'un VSCodium nu. On l'assume comme premier ajout proactif.
- Concrètement : on ne construit pas dans le vide, mais on va *chercher activement* les frictions sur le terrain (dogfood) plutôt que d'« attendre qu'elles arrivent ».

### D2 — « Extensions verrouillées » = **curation, pas interdiction**
- Le verrou marketplace (déjà posé, cf. `TODO.md` A5) empêche **l'utilisateur** d'ajouter du tiers.
- **Nous (Arclen)** pouvons pré-installer (bundler) n'importe quelle extension de notre choix.
- Conséquence : le chemin « extension tierce pré-installée » n'a plus d'astérisque — il est légitime et souvent le plus rapide.

### D3 — Mécanismes d'ajout (le template, validé sur l'exemple « onglets verticaux »)
Trois mécanismes, du moins cher au plus lourd. **Toujours préférer le plus haut de cette liste qui fait le job :**
1. **Défaut de build** (réglages dans `product.json` / settings) — réversible, zéro maintenance.
2. **Extension pré-installée** (tierce OSS bundlée, éventuellement re-brandée) — faible coût, on hérite la maintenance amont.
3. **Patch source** ou **notre extension** — pour le *delta* que rien d'autre ne couvre. Le patch profond se rebat à chaque update upstream → réservé au strict nécessaire ; notre extension est préférable au patch quand c'est de la fonctionnalité.

### D4 — Cockpit (E1) : **escalier de coût** (voir TL;DR pt. 5 et §4)
On ne s'engage sur du code custom (Niv. 2) qu'après avoir épuisé Niv. 0 et Niv. 1 et seulement pour le delta prouvé utile par le dogfood.

### D5 — Séquence
**Dogfood d'abord (court, cadré)** → **spike time-boxé** sur l'API proposée → fige la v1. Le dogfood et la recherche « ce qui existe » tournent en parallèle (ce doc EST la passe de recherche).

---

## 2. Findings — l'Agents Window de Microsoft (avr–mai 2026)

- VS Code 1.115→1.122 a livré une **Agent Sessions sidebar** + une **Agents window** dédiée : liste de sessions nommées + horodatage + compteur de fichiers modifiés non-revus, sessions indépendantes en parallèle, fenêtre « optimisée pour orchestrer des tâches haut-niveau ». **C'est notre E1 mot pour mot.**
- **MAIS : verrouillée à GitHub Copilot + sign-in GitHub.** Supporte seulement `Copilot CLI`, `Copilot Cloud`, `Claude agent` (via GitHub). Sur un VSCodium sans Copilot → **inaccessible**. *On ne peut pas cocher une case et hériter le cockpit.*
- **Valeur pour nous** : Microsoft a **validé la forme** du marché. On la copie au lieu de la deviner.
- **API proposée `chatSessionsProvider` / `ChatSessionItemController`** (issue microsoft/vscode#288459 « adopt … for Claude sessions ») : permet à une extension d'alimenter la vue de sessions.
  - **Faisabilité dans le fork** : on contrôle `product.json` → on peut « bénir » notre extension dans `extensionEnabledApiProposals` (avantage de fork qu'une extension marketplace n'a pas). Donc **techniquement faisable**.
  - **Risque réel = maintenance, pas faisabilité** : les API proposées changent à chaque version VS Code ; à chaque bump du commit upstream épinglé, re-synchro. Probablement intriqué avec le framework chat de Copilot (que le fork retire).
  - **Statut : SPIKE time-boxé** (cf. §6), pas une fondation.

**Pourquoi c'est vraiment compliqué (motif d'élimination raisonné, pas un préjugé) :** l'Agents Window n'est pas une feature autonome du cœur — c'est une **scène vide rendue par l'extension Copilot Chat** (propriétaire MS, non bundlée par VSCodium). Tout le code des sessions, y compris l'intégration « Claude agent », vit dans `extensions/copilot/.../chatSessions/claude/` et le repo `vscode-copilot-chat`, pas dans le cœur (cf. issue microsoft/vscode#295682 « Agent Sessions list always empty »). Donc trois chemins, tous mauvais :
1. **Hériter telle quelle** → vide dans le fork (aucun fournisseur enregistré). Inutilisable.
2. **Installer le VSIX Copilot Chat** → exige login GitHub + abonnement Copilot, propriétaire. Contraire au projet.
3. **Écrire notre fournisseur** via l'API proposée → faisable mais dette de maintenance récurrente (cf. risque ci-dessus).

→ **Décision : on PARKE l'Agents Window** — pas par dédain, mais parce que ce serait *racheter très cher* (maintenance permanente) ce que **l'extension officielle Claude Code donne déjà gratuitement** (liste de sessions + parallèle + historique). Révisable seulement si l'officielle finit par ne plus suffire.

## 3. Findings — panorama des extensions existantes

**Tête de gondole : l'extension officielle Claude Code fait déjà ~80 % du cockpit.**

| Extension | Placement UI | Multi-sessions | Local/privé | OSS / licence | Vivant | Fit |
|---|---|---|---|---|---|---|
| **Claude Code officielle** (Anthropic) | **Déplaçable** : secondary sidebar (droite), primary (gauche), onglet éditeur ; + liste sessions Activity Bar | ✅ tabs/fenêtres, pastilles statut | ✅ login Anthropic, code privé, MCP local `127.0.0.1` | closed, mais **sur Open VSX** → bundlable | ✅✅ | **Base** |
| **Claude Manager** (vishalguptax) | Activity Bar (Ctrl+Alt+C) + status bar, webview | ✅ resume/rename/fork/pin/export/search, filtre branche | ✅ 100 % local, 0 télémétrie | ✅ **Apache-2.0** | ✅ 1048 inst., VSCodium/Win OK | **Très fort, forkable** |
| **Agent Terminal Manager** (jakub-musik) | **niché sous l'Explorer** + icône | ✅ concurrent, rename, statut ●/○ | ✅ local | ⚠️ licence/repo flous | ⚠️ 51 inst. | placement intéressant, projet petit |
| **Claude Code Pulse** | Activity Bar tree | ✅ multi-fenêtres | ✅ local | ✅ MIT | ⚠️ **macOS only** | ❌ (on est Windows) |
| **Claude Code Sidebar** (diruuu) | Activity Bar (terminal xterm) | ❌ mono | ✅ local | ✅ MIT | ⚠️ dormant 2025 | ❌ |
| **Parallel Code** (johannesjo) | **app Electron séparée** | ✅✅ // + worktree/tâche, diff viewer | ✅ local | ✅ MIT, 687★ | ✅ | ❌ hors IDE, mais **réf. design pour le //** |

Liens : extension officielle `open-vsx.org/extension/Anthropic/claude-code` · Claude Manager `github.com/vishalguptax/claude-code-manager` · Parallel Code `github.com/johannesjo/parallel-code`.

## 4. Le cockpit — stratégie en escalier

**Cap visé (forme validée par MS + l'officielle)** : une liste de sessions Claude Code **nommées par flow/livrable** (« Pitch deal X », « Data pack Y »), statut visible, lancement/reprise en un clic, sessions parallèles.

| Niveau | Quoi | Mécanisme | Quand |
|---|---|---|---|
| **0** | Bundler l'extension officielle ; chat Claude par défaut **à droite** (secondary sidebar) ; Explorer à gauche | défaut + bundle | **Tout de suite** (cheap, gros effet) |
| **1** | Bundler/forker **Claude Manager** (re-brandé/trimmé) pour le hub sessions/skills/agents | extension OSS bundlée | Si le dogfood montre un besoin de « hub » |
| **2** | Petit **patch de layout** pour figer le triptyque *fichiers \| sessions \| chat* sans icône-à-cliquer ; et/ou **notre extension fine** pour le delta | patch / notre extension | **Seulement si** le dogfood le prouve nécessaire |

> Le « from scratch » descend tout en bas : on ne code que le delta que ni l'officielle ni Claude Manager ne couvrent.

## 5. Cible de layout — « fichiers | sessions | chat »

Préférence utilisateur : la colonne sessions **à droite de l'arborescence**, le chat **encore à droite** — **sans devoir cliquer une icône d'activity-bar**.

- **2 colonnes natives, zéro dev** : Explorer (sidebar gauche) + panneau Claude **glissé dans la secondary sidebar (droite)** = `fichiers | éditeur | chat`. ≈ 90 % du confort visé, atteignable en réglages par défaut.
- **La colonne « sessions » au milieu sans clic = le seul vrai manque.** C'est le périmètre exact d'un **petit patch de layout** (Niv. 2). Léger, pas un bourbier.
- ⚠️ À matérialiser en **mockup** avant de coder (étape proposée mais non encore faite).

## 5bis. Onglets : deux axes à ne PAS confondre

On mélangeait deux choses sous « tabs/sessions ». Elles sont distinctes :

| Axe | C'est quoi | Douleur | Solution |
|---|---|---|---|
| **A — Onglets d'éditeur** | les **fichiers ouverts** (barre horizontale en haut) | **« ça sature super vite »** ← douleur réelle | **onglets verticaux** (AD5) |
| **B — Sessions agent** | les conversations Claude Code (le cockpit) | — | déjà couvert par l'extension officielle |

**Synergie clé** : dans l'extension officielle, *chaque session Claude s'ouvre aussi comme un onglet d'éditeur*. Donc fichiers + sessions saturent la même barre horizontale. → **rendre les onglets d'éditeur verticaux résout les DEUX d'un coup.** C'est pourquoi AD5 remonte en candidat *early* (pas un simple spike différé).

**✅ Implémenté puis SIMPLIFIÉ (patch `arclen-show-open-editors`, 2026-05-30)** — décision : *pas* d'extension (les extensions VS Code ne peuvent PAS rendre de vrais onglets — pas d'accès DOM ; toutes sont soit une liste = le natif, soit un hack CSS fragile). On utilise le **natif Open Editors**, qu'on possède :
1. **Onglets horizontaux cachés par défaut** — `"workbench.editor.showTabs":"none"` dans `product.json` `configurationDefaults` (marche grâce au patch fondation `arclen-product-config-defaults`, cf. §9 ; pas de hack source).
2. **Open Editors visible + NON-MASQUABLE** — `explorerViewlet.ts` : `hideByDefault: false` + `canToggleVisibility: false`. Non-masquable car, avec `showTabs:"none"`, Open Editors est le **seul** moyen de voir/switcher les éléments de la zone éditeur (terminaux `defaultLocation:"editor"`, fichiers) — la cacher = « perdre » ses terminaux ouverts (incident relevé 2026-05-30).

> **Simplification 2026-05-30** : l'ancien patch `arclen-open-editors-vtabs` ajoutait aussi (a) des lignes plus hautes (28px) et (b) du CSS custom (`.open-editors` : barre d'accent sur l'actif, hover, séparateurs, gras). Jugé **over-engineered et à faible valeur** — la sélection native suffit à montrer le fichier actif. Les deux ont été **retirés** ; Open Editors retombe sur le **style de liste natif, identique à l'arborescence** juste en dessous. Patch renommé `arclen-open-editors-vtabs` → `arclen-show-open-editors` (le nom « vtabs » sur-promettait).

> ⚠️ **Cause racine (résolue)** : `product.json` `configurationDefaults` est **web-only** upstream → **ignoré dans le `.exe` desktop**, donc minimap/trust/showTabs/etc. étaient TOUS morts en packagé (pas seulement showTabs). Résolu globalement par le patch **fondation `arclen-product-config-defaults`** (cf. §9). Depuis : un réglage dans `product.json` suffit, plus de hack source.
>
> Limite assumée : c'est la liste Open Editors *dans la même colonne que l'arbo* (pas un triptyque). Les vrais onglets dans la zone éditeur restent un gros patch core, écarté.

## 6. Spikes & questions ouvertes (à traiter avant tout code lourd)

- **SP1 — API proposée `chatSessionsProvider`** : monter un POC dans le fork (bénir une extension de test dans `product.json`). Mesurer : (a) la vue de sessions rend-elle correctement *sans* le chat Copilot ? (b) combien ça churne entre deux versions VS Code ? → **oui = cadeau ; non = on reste sur l'officielle + Claude Manager.** Time-box : 1-2 j.
- **SP2 — Onglets verticaux** : choisir le mécanisme (défaut « Open Editors » + `workbench.editor.showTabs:"none"` vs extension SideTabs bundlée vs patch). À décider quand on s'y attaque (Phase de recadrage, pas bloquant).
- **SP3 — Patch de layout triptyque** : faisabilité/coût de figer Explorer | sessions | chat en 3 colonnes sans activity-bar.
- **Q1** — Re-branding de Claude Manager si bundlé (nom, retrait des surfaces dev type hooks/MCP pour l'analyste ?).
- **Q2** — Le dogfood : sur quels vrais mandats ? (dépend de la section B du chantier, encore à remplir.)

## 7. Protocole dogfood (comment « réactif » devient concret)

Pour que A ne soit pas « on verra » :
1. L'utilisateur fait 1-2 **vrais mandats** sur l'app au **Niveau 0** (officielle bundlée, chat à droite).
2. Chaque friction → une ligne dans un **journal de frictions** (section ci-dessous ou un fichier `TODO/dogfood-frictions.md`) : *quoi / contexte / mécanisme candidat (défaut/extension/patch) / fréquence*.
3. On ne promeut une friction en feature que si elle revient ou bloque. La fréquence dicte la priorité.

## 8. Backlog des candidats additifs (vivant)

> Statut : ⬜ à faire · 🟡 en cours · ✅ fait · ⏸ différé · 🔬 spike
> Bucket : A=réactif/défaut · B=cockpit/proactif · C=extension tierce curée

| # | Candidat | Bucket | Mécanisme pressenti | Statut |
|---|---|---|---|---|
| AD1 | Bundler extension officielle Claude Code + chat à droite par défaut | B/C | défaut + bundle (Niv. 0) | ✅ **fait 2026-05-30** (built-in via `builtInExtensions` vsix local ; `claudeCode.preferredLocation:"sidebar"`) — **reste : vérifier sur build `-s`** |
| AD2 | Bundler/forker Claude Manager (hub sessions) | C | extension OSS (Niv. 1) | ⬜ après dogfood |
| AD3 | Patch layout triptyque fichiers\|sessions\|chat | B | patch (Niv. 2) | 🔬 SP3 |
| AD4 | Spike API `chatSessionsProvider` dans le fork | B | POC | 🔬 SP1 |
| AD5 | **Onglets verticaux** (fichiers + sessions) | A→B léger | natif Open Editors `hideByDefault:false` (CSS + hauteur retirés 2026-05-30, over-engineered) | ✅ **fait** (patch `arclen-show-open-editors`) — style natif, identique à l'arbo |
| AD6 | Aperçu livrables PPTX/XLSX (ou « ouvrir dans Office ») | A | extension / tasks | ⏸ cf. chantier E2 |
| AD7 | Boutons-actions (tasks → « Générer data pack ») | B | tasks + extension | ⏸ cf. chantier E3 |
| AD8 | Pont repo COM (PPT/Excel) | B | à définir | ⏸ cf. chantier E4 |
| AD9 | Templates de mandat / onboarding agent | A | overlay + extension | ⏸ cf. chantier E5/E6 |

---

## 9. Fondation — defaults produit dans le desktop (patch `arclen-product-config-defaults`)

Découvert pendant AD5 (2026-05-29). **`product.json` `configurationDefaults` est un mécanisme WEB-only upstream** : `DefaultConfiguration` (`src/vs/workbench/services/configuration/browser/configuration.ts`) ne les enregistre que depuis `environmentService.options?.configurationDefaults` (options de construction du workbench *web*), `undefined` en desktop. `IProductService` ne type même pas le champ. → **tout le bloc `configurationDefaults` d'Arclen était mort dans le `.exe`.**

**Fix (~5 lignes)** : dans le constructeur de `DefaultConfiguration`, enregistrer aussi `product.configurationDefaults` (le `product` brut = `globalThis._VSCODE_PRODUCT_JSON`, casté car non typé) via `registerDefaultConfigurations`, au même timing précoce que le web. Vérifié profil neuf : `showTabs:none` seul dans product.json cache les onglets.

**Conséquence** : les réglages-defaults (minimap, trust, update.mode, secondary sidebar, showTabs, layoutControl, commandCenter, terminal.defaultLocation…) passent par `product.json` et **fonctionnent enfin en packagé**. Les non-réglages (view `hideByDefault`, hauteurs de ligne, CSS) restent des patches dédiés. → **à re-vérifier sur un build packagé** que tout le bloc s'applique.

## Références
- MS Agents window (prérequis Copilot) : `code.visualstudio.com/docs/copilot/agents/agents-window`
- API proposée : microsoft/vscode#288459 ; `vscode.proposed.chatSessionsProvider.d.ts`
- Proposed API dans un fork : `code.visualstudio.com/api/advanced-topics/using-proposed-api` (+ `extensionEnabledApiProposals` dans product.json)
- Extension officielle : `code.claude.com/docs/en/vs-code` ; Open VSX `Anthropic/claude-code`
- Onglets verticaux (workaround natif) : `weberdominik.com/blog/vscode-vertical-tabs` ; issue microsoft/vscode#108264
