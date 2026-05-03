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

### Optional env vars

- `GOOGLE_APPLICATION_CREDENTIALS`: absolute path to your service account JSON (if you don't want to place it in the script folder)
- `FIREBASE_PROJECT_ID`: defaults to value in the service account JSON
