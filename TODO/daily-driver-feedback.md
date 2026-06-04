# Arclen daily-driver — journal de feedback

> Ce qu'on note en utilisant Arclen comme éditeur principal. **On batche les fixes** puis on re-cut UN build CI (pas un run par item — cf. `CLAUDE.md` « Local-only philosophy »).
> Format : `- [ ]` zone — observation — (réf TRACKER) — fix envisagé. Coche `- [x]` + commit/build quand corrigé.

## 2026-06-04 — premier install (build CI `f51109b`, `ArclenUserSetup-x64-1.121.03735.exe`)

- [ ] **Installeur — logo wizard VSCodium** : le coral **bleu** de VSCodium s'affiche en haut à droite (petite image) ET dans le panneau gauche. Les 14 `src/stable/resources/win32/inno-{big,small}-*.bmp` sont le logo VSCodium inchangé (vérifié visuellement 2026-06-04). (TRACKER **IN3** — réouvert : mon « non-issue » précédent était une mauvaise lecture du coral bleu.) → Fix : remplacer les BMP par des images wizard Arclen (régénérer via `icons/build_icons.sh` depuis le logo Arclen, ou déposer les BMP directement). `SetupIconFile`=code.ico reste Arclen ✅.
- [ ] **Installeur — licence brute VSCodium** : le wizard affiche la licence MIT « VSCodium contributors / Peter Squicciarini / Microsoft Corporation », sans présentation Arclen. (TRACKER **IN2** — décidé : on GARDE ces attributions (fork MIT), on re-skin juste `LICENSE.rtf` au nom/couleurs Arclen.) → Fix : re-skin `LICENSE.rtf`.
- [ ] **`.exe` — CompanyName/copyright = « Aseran20 »** : le CI force `ORG_NAME=github.repository_owner` au lieu de « Arclen ». Cosmétique (propriétés de fichier / UAC). (TRACKER **IN1**.) → Fix : pin `ORG_NAME: Arclen` dans `ci-build-windows.yml`.
