# tool/

One-off scripts. **Never imported from `lib/`.** Nothing here ships in the app.

## Prerequisites

Neither of these is checked into the repo.

### 1. A service account key

Firebase console → Project settings → Service accounts → **Generate new private key**.

Save it **outside this repository** (it grants full admin access to the project — treat it like
a password) and point the environment at it:

```bash
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccountKey.json
```

PowerShell:

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS = "C:\path\to\serviceAccountKey.json"
```

### 2. `firebase-admin`

```bash
npm install firebase-admin
```

---

## `migrate_foods.js` — single_male → foods

Copies the existing component catalog into the new `foods` collection, renaming the macro keys
onto the new vocabulary and generating search tokens.

| old key | new location |
|---|---|
| `name` | `name` |
| `category` | `category` |
| `protein` | `per100.protein` |
| `fat` | `per100.fat` |
| `carp` | `per100.carbs` |
| `note` | `note` |
| document id | preserved, so nothing has to be re-linked |

It also computes `kcalPer100` (denormalized, for sorting only) and builds `searchTokens` — word
prefixes in both the raw and Arabic-normalized forms, so searching "دجاج" matches "دَجاج".

**Dry run first. Always.**

```bash
node tool/migrate_foods.js            # prints what it would write, writes nothing
node tool/migrate_foods.js --commit   # actually writes
```

The dry run flags any entry whose macros are all zero — worth eyeballing before it becomes a
catalog entry the user builds meals from.

`single_male` is never modified. It is the rollback: if a run goes wrong, fix the script and run
it again.

The Admin SDK bypasses security rules, which is why this can write to `foods` even though the
deployed rules make that collection read-only to clients.

---

## Deploying rules and indexes

The Firebase CLI is not installed globally on this machine, so use `npx`:

```bash
npx firebase-tools login
npx firebase-tools use diet-app-a908a
npx firebase-tools deploy --only firestore:rules,firestore:indexes
```

`login` is interactive and opens a browser — run it yourself rather than through an agent.

Indexes take a few minutes to build. Marketplace browse queries in step 3 will fail with a
console link until they finish.
