# Points de corrosion remorques R1→R8 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Peupler les points de corrosion des 16 plans de remorques (R1→R8 × Droit-Pair / Gauche-Impair) dans `assets/seed/zones.json`, avec une nomenclature unique et les photos de référence des points structurels.

**Architecture:** Édition du seed JSON `assets/seed/zones.json` (aucune modif de code Dart). Un gabarit R2 (les 2 côtés) est saisi à la main depuis `R2.png`, vérifié par une image de contrôle générée (points dessinés sur les plans réels de l'app), validé par l'utilisateur, puis répliqué sur les 7 autres remorques par script.

**Tech Stack:** JSON (seed), Python (openpyxl/Pillow) pour les scripts de validation et d'image de contrôle, Flutter (build APK via GitHub Actions / hot-reload local).

## Global Constraints

- Donnée réelle de l'app = `E:\Tab visite\tab_visite\assets\seed\zones.json`. Les `R*.xlsx` ne sont PAS lus par l'app (supports visuels).
- Coordonnées de zone **normalisées 0→1** (`x`, `y`, `largeur`, `hauteur`) relatives à l'image du plan.
- **Nomenclature nom de zone : `R{rame} {D|G}{id}`** — `D`=Droit-Pair, `G`=Gauche-Impair, `id`=chiffre (point 1→8) ou lettre (panneau). Noms **uniques** par (rame, côté, point).
- Lettres par côté : Droit-Pair = `L,M,N,O,P,Q,R,S,T,U,V,W,Y` ; Gauche-Impair = `A,B,C,D,E,F,G,H,I,J,K,X`.
- Points structurels : **1→8, identiques des deux côtés** ; `imageReference` point N → `Image N`.
- Taille par défaut des nouvelles zones : `largeur=0.03`, `hauteur=0.07` (comme les points R1 existants).
- Périmètre : **R1→R8, R4 incluse**. R1 Droit-Pair conserve ses 8 points existants (positions + photos), renommés `R1 D1`…`R1 D8`.
- Le seed n'est rechargé qu'au premier lancement (`SeedService.seedIfEmpty`) : pour tester sur un appareil déjà seedé, il faut réinstaller / vider la base.

---

### Task 1 : Gabarit R2 — saisie des zones + image de contrôle

**Files:**
- Modify: `tab_visite/assets/seed/zones.json` (plans `Remorque (Droit-Pair) R2` → image3.png, `Remorque (Gauche-Impair) R2` → image16.png)
- Create: `scratchpad/validate_zones.py` (validation seed)
- Create: `scratchpad/draw_control.py` (image de contrôle)

**Interfaces:**
- Produces: le bloc de zones R2 (2 côtés) servant de gabarit répliqué en Task 3. Chaque zone : `{nom, x, y, largeur, hauteur, imageReference?}`.

- [ ] **Step 1 : Vérifier l'alignement des images de fond**
  Générer un aperçu de `assets/plans/image3.png` (R2 Droit) et `image16.png` (R2 Gauche) et les comparer visuellement au cadrage de `R2.png`. Si le cadrage diffère nettement, noter le décalage à appliquer.

- [ ] **Step 2 : Saisir les zones R2 Droit-Pair dans zones.json**
  Dans le plan `Remorque (Droit-Pair) R2`, remplir `zones` :
  - 8 points structurels `R2 D1`…`R2 D8` (positions lues sur R2.png, croix de bas de caisse/bogie), `imageReference` = `assets/reference/Image 1.png`…`Image 8.png`.
  - Zones-lettres `R2 DL, R2 DM, R2 DN, R2 DO, R2 DP, R2 DQ, R2 DR, R2 DS, R2 DT, R2 DU, R2 DV, R2 DW, R2 DY` (position = croix sous chaque case-lettre), sans `imageReference`.
  - `largeur=0.03`, `hauteur=0.07`.

- [ ] **Step 3 : Saisir les zones R2 Gauche-Impair dans zones.json**
  Dans le plan `Remorque (Gauche-Impair) R2`, remplir `zones` :
  - 8 points `R2 G1`…`R2 G8` + `imageReference` Image 1→8.
  - Zones-lettres `R2 GA, R2 GB, R2 GC, R2 GD, R2 GE, R2 GF, R2 GG, R2 GH, R2 GI, R2 GJ, R2 GK, R2 GX`.

- [ ] **Step 4 : Écrire le script de validation**

```python
# scratchpad/validate_zones.py
import json, sys, collections
d = json.load(open(r'E:/Tab visite/tab_visite/assets/seed/zones.json', encoding='utf-8'))
names = collections.Counter()
errs = []
for p in d['plans']:
    for z in p['zones']:
        names[z['nom']] += 1
        for k in ('x','y','largeur','hauteur'):
            v = z.get(k)
            if not isinstance(v,(int,float)) or not (0 <= v <= 1):
                errs.append(f"{p['nom']} / {z['nom']}: {k}={v} hors [0,1]")
dups = [n for n,c in names.items() if c>1]
if dups: errs.append(f"Noms dupliqués: {dups}")
print("OK" if not errs else "ERREURS:\n"+"\n".join(errs))
sys.exit(1 if errs else 0)
```

- [ ] **Step 5 : Lancer la validation**
  Run: `python scratchpad/validate_zones.py`
  Expected: `OK` (JSON valide, coords dans [0,1], aucun nom dupliqué).

- [ ] **Step 6 : Générer l'image de contrôle**

```python
# scratchpad/draw_control.py  — dessine les zones sur les plans réels de l'app
import json
from PIL import Image, ImageDraw, ImageFont
d = json.load(open(r'E:/Tab visite/tab_visite/assets/seed/zones.json', encoding='utf-8'))
base = r'E:/Tab visite/tab_visite/assets/plans/'
targets = {'Remorque (Droit-Pair) R2':'image3.png', 'Remorque (Gauche-Impair) R2':'image16.png'}
for p in d['plans']:
    if p['nom'] not in targets: continue
    im = Image.open(base+targets[p['nom']]).convert('RGB'); W,H = im.size
    dr = ImageDraw.Draw(im)
    for z in p['zones']:
        x,y = z['x']*W, z['y']*H
        r = 10
        dr.ellipse([x-r,y-r,x+r,y+r], outline=(255,0,0), width=3)
        dr.text((x+r+2,y-r), z['nom'], fill=(255,0,0))
    im.save(rf'C:/Users/Franck/AppData/Local/Temp/claude/E--Tab-visite/aac0d8f6-c9f2-443f-b79c-937296399465/scratchpad/controle_{targets[p["nom"]]}')
print("images de contrôle générées")
```

  Run: `python scratchpad/draw_control.py`

- [ ] **Step 7 : Soumettre l'image de contrôle à l'utilisateur (checkpoint humain)**
  Envoyer `controle_image3.png` et `controle_image16.png` via SendUserFile. **Attendre validation/corrections avant de continuer.** Boucler sur Steps 2-6 tant que les positions ne sont pas validées.

- [ ] **Step 8 : Commit**

```bash
git add tab_visite/assets/seed/zones.json
git commit -m "data: gabarit R2 points de corrosion (2 côtés, nomenclature R2 D/G)"
```

---

### Task 2 : Intégrer les photos de référence Image 1→8

**Files:**
- Create: `tab_visite/assets/reference/Image 1.png` … `Image 8.png` (copie depuis la racine)
- Modify: `tab_visite/pubspec.yaml` (si `assets/reference/` n'est pas déjà déclaré en glob)

**Interfaces:**
- Consumes: les `imageReference` posés en Task 1 (`assets/reference/Image N.png`).

- [ ] **Step 1 : Copier les images**

```bash
cd "E:/Tab visite"
for n in 1 2 3 4 5 6 7 8; do cp "Image $n.png" "tab_visite/assets/reference/Image $n.png"; done
ls "tab_visite/assets/reference/"
```
  Note : `Image 2 et 3.png` contient les points 2 ET 3 — le découper en `Image 2.png` / `Image 3.png` (ou décider avec l'utilisateur d'une image commune). Vérifier aussi que `Image 4` et `Image 8` (légendes de zones A/B/C/D) conviennent comme réf. des points 4 et 8.

- [ ] **Step 2 : Vérifier la déclaration des assets**
  Ouvrir `tab_visite/pubspec.yaml`, confirmer que `assets/reference/` (ou `assets/`) est listé sous `flutter: assets:`. Sinon l'ajouter.

- [ ] **Step 3 : Vérifier que chaque imageReference pointe vers un fichier existant**

```python
# réutilise validate: ajouter un check d'existence des imageReference
import json, os
d = json.load(open(r'E:/Tab visite/tab_visite/assets/seed/zones.json', encoding='utf-8'))
root = r'E:/Tab visite/tab_visite/'
missing = {z['imageReference'] for p in d['plans'] for z in p['zones']
           if z.get('imageReference') and not os.path.exists(root+z['imageReference'])}
print("MANQUANTES:", missing or "aucune")
```
  Expected: `aucune`.

- [ ] **Step 4 : Commit**

```bash
git add tab_visite/assets/reference/ tab_visite/pubspec.yaml
git commit -m "assets: photos de référence Image 1-8 des points structurels"
```

---

### Task 3 : Réplication sur R1 + R3→R8

**Files:**
- Modify: `tab_visite/assets/seed/zones.json` (14 plans restants)
- Create: `scratchpad/replicate.py`

**Interfaces:**
- Consumes: le gabarit R2 validé (Task 1) : les zones de `Remorque (Droit-Pair) R2` et `Remorque (Gauche-Impair) R2`.

- [ ] **Step 1 : Écrire le script de réplication**

```python
# scratchpad/replicate.py
import json
path = r'E:/Tab visite/tab_visite/assets/seed/zones.json'
d = json.load(open(path, encoding='utf-8'))
plans = {p['nom']: p for p in d['plans']}
tmpl_D = plans['Remorque (Droit-Pair) R2']['zones']
tmpl_G = plans['Remorque (Gauche-Impair) R2']['zones']

def clone(zones, old_prefix, new_prefix):
    out = []
    for z in zones:
        z2 = dict(z)
        z2['nom'] = z['nom'].replace(old_prefix, new_prefix, 1)  # "R2 D1" -> "R1 D1"
        out.append(z2)
    return out

for n in [1,3,4,5,6,7,8]:
    dp = plans[f'Remorque (Droit-Pair) R{n}']
    gp = plans[f'Remorque (Gauche-Impair) R{n}']
    if n == 1:
        # R1 Droit-Pair : garder les 8 points existants (déjà nommés R1 D1..R1 D8 en Task 1 bis)
        existing = [z for z in dp['zones'] if z['nom'].startswith('R1 D') and z['nom'][4:].isdigit()]
        letters = [z for z in clone(tmpl_D,'R2 ','R1 ') if not z['nom'][4:].isdigit()]
        dp['zones'] = existing + letters
    else:
        dp['zones'] = clone(tmpl_D, 'R2 ', f'R{n} ')
    gp['zones'] = clone(tmpl_G, 'R2 ', f'R{n} ')

json.dump(d, open(path,'w',encoding='utf-8'), ensure_ascii=False, indent=2)
print("réplication faite")
```
  Note : avant la réplication, s'assurer que les 8 points R1 Droit-Pair existants ont bien été renommés `R1 D1`…`R1 D8` et leur `imageReference` mis à `Image N` (petite étape préalable d'édition de zones.json, ou intégrée au script).

- [ ] **Step 2 : Lancer la réplication**
  Run: `python scratchpad/replicate.py`
  Expected: `réplication faite`.

- [ ] **Step 3 : Re-valider tout le seed**
  Run: `python scratchpad/validate_zones.py`
  Expected: `OK` — chaque plan de remorque a ses points + lettres, tous noms uniques (préfixe de rame garantit l'unicité globale).

- [ ] **Step 4 : Vérifier les comptes**

```python
import json
d = json.load(open(r'E:/Tab visite/tab_visite/assets/seed/zones.json', encoding='utf-8'))
for p in d['plans']:
    if p['nom'].startswith('Remorque'):
        print(p['nom'], '->', len(p['zones']), 'zones')
```
  Expected : chaque côté = 8 points + 12 (Gauche) ou 13 (Droit) lettres, ~20-21 zones par plan.

- [ ] **Step 5 : Commit**

```bash
git add tab_visite/assets/seed/zones.json
git commit -m "data: réplication points de corrosion R1 + R3-R8 (2 côtés)"
```

---

### Task 4 : Build & vérification dans l'app

**Files:** aucun (vérification).

- [ ] **Step 1 : Analyse Flutter**
  Run (env local `C:\dev`, cf. reference_env_dev_flutter) : `flutter analyze`
  Expected : pas d'erreur (le seed n'impacte pas la compilation, mais vérifie l'intégrité du projet).

- [ ] **Step 2 : Lancer sur la tablette avec base vierge**
  Réinstaller l'APK (ou vider les données de l'app) pour forcer le re-seed, puis ouvrir une remorque (R2 puis R1) et vérifier : marqueurs aux bons endroits, noms `R{n} D…`/`R{n} G…`, photo de référence affichée au clic sur un point 1→8.

- [ ] **Step 3 : Commit éventuel** de correctifs de positions issus de la vérification finale.

---

## Self-Review

- **Couverture spec :** catégories A (points 1-8 + Image N) & B (lettres) → Tasks 1/3 ; nomenclature `R{n} D/G` → Global Constraints + Tasks 1/3 ; photos réf → Task 2 ; gabarit R2 puis réplication → Tasks 1→3 ; build → Task 4. R1 Droit-Pair conservé → Task 3 Step 1. ✓
- **Placeholders :** coordonnées concrètes produites pendant la saisie (Task 1) et validées par image de contrôle — la méthode et le format sont explicites. Scripts fournis en entier.
- **Cohérence des noms :** `validate_zones.py`, `draw_control.py`, `replicate.py` réutilisés de façon cohérente ; nomenclature `R{n} {D|G}{id}` identique partout.
- **Point d'attention reporté :** `Image 2 et 3.png` (à découper) et `Image 4/8` (légendes) — traité en Task 2 Step 1 avec décision utilisateur.
