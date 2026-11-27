# Fixtures

Synthetic test data and model fixtures for Flutter work. Everything
here is made up — names, emails (`.invalid` domains), and URLs are
placeholders, safe to commit and share.

| Fixture | What it is | Use it for |
|---|---|---|
| [sample-data/items.json](sample-data/items.json) | Five sample items matching the app skeleton's `SampleItem` shape (camelCase fields: `id`, `title`, `subtitle`, `isFavorite`, `ownerId`, `createdAt`) | Loading into the skeleton's repository in tests, seeding a local database, stubbing an API response |
| [sample-data/users.json](sample-data/users.json) | Three sample users (`id`, `displayName`, `email`, `avatarUrl`, `isPro`, `joinedAt`); item `ownerId` values reference these ids | Owner/author lookups in tests, profile UI with fake data |
| [dart/sample_item.dart](dart/sample_item.dart) | A hand-written plain Dart model with the items' shape, plus — clearly labelled in comments — the `@freezed` source it is modelled on and what the generator would emit | Seeing the model shape without running codegen; the file is explicit about what is hand-written vs generated, and ships no fake generated output |
| [golden/](golden/) | A README explaining golden (screenshot) tests | Learning how goldens work and why this pack deliberately contains no PNG golden files |

## Conventions

- Field names are Dart/JSON camelCase (`isFavorite`, `ownerId`,
  `createdAt`), matching Dart model classes and `fromJson` code —
  unlike snake_case fixtures you may know from other packs.
- Dates are UTC ISO 8601 strings ending in `Z`, the form
  `DateTime.parse` accepts directly.
- Ids are small sequential integers, consistent across files:
  `items.ownerId` points at `users.id`.
