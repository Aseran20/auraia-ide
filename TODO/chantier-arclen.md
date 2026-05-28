# Chantier Arclen — du fork VS Codium au cockpit d'agents pour analystes M&A

> Statut : **brouillon vivant** (créé 2026-05-28). À itérer ensemble.
> Les ❓ marquent les endroits où j'ai besoin de ton input métier ou d'une décision.

---

## A. Vision & principe directeur

**Arclen n'est pas un éditeur de code simplifié. C'est un cockpit d'orchestration d'agents Claude Code pour analystes M&A / finance / conseil.**

- Châssis = l'enveloppe VS Code (arborescence, onglets, terminal, panneaux).
- Moteur = Claude Code (extension terminal) + les skills User-level.
- Produit = les livrables (PPTX, XLSX, DOCX, PDF, mémos, data packs).
- Le métier de l'analyste = **diriger des agents** + **gérer des livrables**. Pas coder.

**Principe gravé : on simplifie la SURFACE, pas le MOTEUR.**
Tout ce que Claude Code utilise (terminal, édition fichiers, diffs, tasks) reste intact même si l'humain n'y touche jamais. On ne coupe que ce que *l'humain* voit.

**Modèle d'agents = par flow, pas par outil.** Un agent enchaîne PPT↔Excel↔recherche dans un même mandat. Les skills sont au niveau User et utilisés au même moment. Le cockpit organise les agents par *workflow/livrable* (ex. « monter ce pitch »), pas par application.

---

## B. Le métier de l'analyste — jobs-to-be-done  ❓ À COMPLÉTER PAR TOI

C'est la fondation : tout le reste découle de ce que l'analyste fait *vraiment* dans sa journée. Ma compréhension (à corriger / compléter) :

- [ ] Monter des **pitch decks / teasers / CIM / IM** (PowerPoint)
- [ ] Construire des **data packs / modèles** (Excel : comps, DCF, LBO, trading/transaction multiples)
- [ ] Rédiger des **mémos / notes** (Word/PDF)
- [ ] **Recherche** : marché, cibles, comparables, précédents de transaction
- [ ] **Gestion de mandat** : organisation des fichiers d'un deal, versions, handoff
- [ ] ❓ Autres ? (suivi de process, Q&A de due diligence, dataroom, listes d'acquéreurs...)

> ❓ **Question pour toi :** liste-moi tes 5-6 tâches les plus fréquentes, dans tes mots. C'est ça qui dicte quels « agents par flow » et quels boutons on crée.

---

## C. ENLEVER — dé-scarer (Phase 1, surtout patches + réglages)

| # | À couper / cacher | Mécanisme | Effort | Risque | Statut |
|---|---|---|---|---|---|
| C1 | Menu Run | patch | faible | faible | ✅ fait (arclen-hide-run-menu) |
| C2 | Menus Selection/View/Go/Help | patch | faible | faible | ✅ fait (arclen-hide-menus) |
| C3 | Walkthroughs / Welcome announcements | patch + setting | faible | faible | ✅ fait |
| C4 | Run & Debug (activity bar + vues) | patch/setting | moyen | faible | ⬜ |
| C5 | Test Explorer | setting | faible | faible | ⬜ |
| C6 | Debug Console / Output / Problems (panneaux) | patch | moyen | moyen | ⬜ |
| C7 | Marketplace extensions (verrouiller) | product.json / setting | faible | moyen | ⬜ |
| C8 | Command Palette : commandes dev | patch (filtrage) | élevé | moyen | ⬜ ❓ |
| C9 | Status bar : langage, encodage, ligne/col, indent, feedback | patch | moyen | faible | ⬜ |
| C10 | Éditeur : minimap, breadcrumbs, n° ligne, outline | setting | faible | faible | 🟡 partiel (defaults) |
| C11 | Workspace Trust (dialogues « do you trust ») | setting | faible | moyen | ⬜ |
| C12 | Notifs updates / extensions | setting | faible | faible | 🟡 partiel |
| C13 | Settings UI complète → sous-ensemble curé | patch | élevé | élevé | ⬜ ❓ |
| C14 | Layout controls / secondary sidebar par défaut | patch/setting | faible | faible | ✅ fait |

> ❓ **Décision C7 :** marketplace totalement coupé (tu pré-installes tout) ou liste blanche d'extensions autorisées ?

---

## D. RECADRER les surfaces (Phase 2)

| # | Surface | Recadrage analyste | Mécanisme | Statut |
|---|---|---|---|---|
| D1 | Welcome page | « Ouvrir un mandat », « Démarrer un assistant », « Générer un data pack » au lieu de Clone/Open Repo | patch | ⬜ |
| D2 | Explorateur | icônes PPTX/XLSX/DOCX/PDF soignées, état vide « Ouvrir un mandat » | patch + icon theme | ⬜ |
| D3 | Activity bar | ne garder que Explorer + Search + (Agents) ; virer SCM/Run/Test/Extensions | patch | ⬜ |
| D4 | Command Palette | mini-palette d'actions haut-niveau en langage M&A | extension | ⬜ |
| D5 | Status bar | réduite à l'essentiel (nom mandat ? agent actif ?) | patch | ⬜ |
| D6 | Vocabulaire global | « workspace »→« mandat/deal », « repository »→? | l10n / nls | ⬜ ❓ |

---

## E. AJOUTER / ORCHESTRER — le moat (Phase 3, probablement une extension custom)

| # | Capacité | Idée | Statut |
|---|---|---|---|
| E1 | **Cockpit multi-agents** | Sessions Claude Code nommées **par flow/livrable** (« Pitch deal X », « Data pack Y »), pilotées depuis une vue dédiée | ⬜ ❓ |
| E2 | Aperçu livrables | Preview PPTX/XLSX dans le workspace OU one-click « Ouvrir dans PowerPoint/Excel » | ⬜ |
| E3 | Boutons-actions | VS Code *tasks* détournés en boutons « Générer data pack » qui lancent les scripts COM | ⬜ |
| E4 | Pont repo COM | Comment cockpit (ici) ↔ moteur (repo PPT/Excel COM) communiquent | ⬜ ❓ |
| E5 | Templates mandat | Structure de dossier deal pré-faite, templates de slides | ⬜ |
| E6 | Onboarding agent | Première session guidée « dis à l'agent de faire X » | ⬜ |

> ❓ **Décision E1/E4 :** on a dit « réfléchir avant de construire ». À trancher plus tard : extension custom vs terminaux nommés ; et la forme du lien avec le repo COM (multi-root vs coordination haut-niveau).

---

## F. Questions ouvertes / décisions en attente

1. ❓ **Git / SCM** : supprimer, ou **rebrander en « Historique / Versions »** (piste d'audit du deal) ? Penche vers rebrand.
2. ❓ **Marketplace** : coupé total vs liste blanche (cf. C7).
3. ❓ **Settings** : verrouillage total vs sous-ensemble curé (cf. C13).
4. ❓ **Pont repo COM** : architecture (cf. E4).
5. ❓ **Vocabulaire** : jusqu'où renommer (mandat, deal, livrable...) sans casser des trucs internes ?

---

## G. Séquencement proposé

- **Phase 1 — Soustractive** (now, cheap, patches+settings) : section C. Fort impact visuel, faible risque.
- **Phase 2 — Recadrage surfaces** (patches + icon theme + un peu d'extension) : section D.
- **Phase 3 — Additive / orchestration** (extension custom pré-installée) : section E. Le vrai moat.

Phase 1 & 2 vivent dans le fork (patches). Phase 3 vit dans une extension (plus maintenable qu'un patch profond).

---

## H. Prochaine action

Une fois le build fini : on remplit la **section B** ensemble (tes vrais workflows), puis on priorise la section C pour un premier lot de patches « dé-scaring » visible immédiatement.
