## Tastie Firestore Import (one-time)

This script imports the existing mock JSON files into **Cloud Firestore**:

- `assets/mock/index_list.json` → collection `index_cards` (docId = `id`)
- `assets/mock/tag_list.json` → collection `tags` (docId = `id`)
- `assets/mock/card_detail_list.json` → collection `card_details` (docId = `id`)

Before writing, it **validates every item** against the expected structure used by the Flutter models.

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
- `FIREBASE_PROJECT_ID`: defaults to `tastie-1701f`

