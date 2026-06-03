## Tastie Firestore Import (one-time)

This script imports `assets/mock/tag_list.json` into Cloud Firestore collection **`tags`** (docId = `id`).

Explore feed and recipe details use the **`recipes`** collection only; legacy **`index_cards`** / **`card_details`** are no longer imported here.

### 1) Create a Firebase service account key

In Firebase Console:

- Project Settings → Service accounts → **Generate new private key**
- Save the file as:
  - `scripts/firestore_import/serviceAccountKey.json`

Do **not** commit this file.

### 2) Install script dependencies

From `tastie/scripts/firestore_import/`:

```bash
npm install
```

### 3) Dry run (validate only)

```bash
npm run dry-run
```

### 4) Import (write to Firestore)

```bash
npm run import
```

### Spoonacular preview recipes (12 dishes, 2 per mood tag)

For realistic demo content (ingredients, nutrition, steps, images) without hand-entering in the app.

Preview import skips alcohol/pork-related recipes and ingredients (halal-friendly), rounds amounts to whole numbers, and converts cups/tbsp to ml where possible to reduce `as needed` units. Re-running `spoonacular:seed` deletes prior `source: spoonacular_preview` documents first.

### Remove legacy mock data (seedRecipes.js)

```bash
npm run mock:cleanup          # dry-run
npm run mock:cleanup:apply    # delete picsum / tbsp-pcs mock docs
```

1. Copy `.env.example` → `.env` and set `SPOONACULAR_API_KEY` ([free console](https://spoonacular.com/food-api/console)).
2. Edit `recipes_preview_manifest.json` if you want different Spoonacular IDs or **manual mood tags** (`Comfort`, `Cooling`, …).
3. Fetch + transform:

```bash
npm run spoonacular:fetch
```

4. Seed Firestore (uses `serviceAccountKey.json` + demo author in `seedSpoonacularPreview.js`):

```bash
npm run spoonacular:seed
```

Or both: `npm run spoonacular:preview`

Dry-run: `npm run spoonacular:fetch:dry-run` / `npm run spoonacular:seed:dry-run`

### Optional env vars

- `GOOGLE_APPLICATION_CREDENTIALS`: absolute path to your service account JSON (if you don't want to place it in the script folder)
- `FIREBASE_PROJECT_ID`: defaults to value in the service account JSON
- `SPOONACULAR_API_KEY`: required for `spoonacular:fetch` (see `.env.example`)
