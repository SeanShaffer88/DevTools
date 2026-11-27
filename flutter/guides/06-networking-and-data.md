# 06 — Networking and Data

Most apps talk to a JSON API. The Dart pattern is stable: an HTTP
client fetches text, generated model classes turn JSON into typed
objects, a repository hides both from the UI, and errors are
values the UI can render — not exceptions that escape.

HTTP docs: https://docs.flutter.dev/data-and-backend/networking

## Choosing an HTTP client

### http — the simple default

`http` (**1.6.0**) is the lightweight client the Flutter docs use.
For straightforward GET/POST JSON work it is all most apps need:

```dart
import 'package:http/http.dart' as http;

Future<List<dynamic>> fetchItems() async {
  final response = await http.get(
    Uri.parse('https://api.example.com/items'),
    headers: {'Accept': 'application/json'},
  );
  if (response.statusCode != 200) {
    throw HttpException('Failed: ${response.statusCode}');
  }
  return jsonDecode(response.body) as List<dynamic>;
}
```

Always build URIs with `Uri.parse` / `Uri.https` — never string-
concatenate query parameters (escaping bugs and injection bugs).

### dio — the power tool

`dio` (**5.11.1**) earns its place when you need what `http` does
not bundle: interceptors (auth token attach + refresh in one
place), request cancellation, timeouts per request, upload/download
progress, and form data without hand-rolling:

```dart
final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
dio.interceptors.add(InterceptorsWrapper(
  onRequest: (options, handler) {
    options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  },
));
```

Rule of thumb: start with `http`; move to `dio` when a second
feature needs an interceptor or cancellation — not on day one
"out of habit".

## Models: never hand-write fromJson at scale

Manual `fromJson` factories work for one model and rot by the
tenth. The standard is code generation with `build_runner`
(**2.17.1**) driving a generator. Remember from guide 02: Dart
macros were abandoned — `build_runner` *is* the codegen route.

### json_serializable — the plain option

`json_serializable` (**6.15.2**) generates `fromJson`/`toJson` for
an annotated class:

```dart
import 'package:json_annotation/json_annotation.dart';
part 'item.g.dart';

@JsonSerializable()
class Item {
  const Item({required this.id, required this.name, this.priceCents});
  factory Item.fromJson(Map<String, dynamic> json) => _$ItemFromJson(json);

  final int id;
  final String name;
  final int? priceCents;

  Map<String, dynamic> toJson() => _$ItemToJson(this);
}
```

### freezed — the full-featured option

`freezed` (**4.0.3**) generates the model *plus* equality,
`copyWith`, and union (sealed) types — the same sealed-state style
as guides 02 and 04:

```dart
@freezed
sealed class Item with _$Item {
  const factory Item({required int id, required String name}) = _Item;
  factory Item.fromJson(Map<String, dynamic> json) => _$ItemFromJson(json);
}
```

**Version quirk, read carefully:** with freezed 4.x you pin the
*annotation* package at **3.1.0** (`freezed_annotation: 3.1.0`)
while the generator package is 4.0.3. The mismatched majors are
intentional in this release line — "fixing" them to match breaks
the build. Check the freezed readme for the current pairing
before changing either number.

### The build_runner workflow

Generated files (`*.g.dart`, `*.freezed.dart`) live next to your
sources and are checked in like normal code:

```powershell
# one-off generation after editing a model:
dart run build_runner build --delete-conflicting-outputs

# regenerate continuously while you work:
dart run build_runner watch --delete-conflicting-outputs
```

Typical `pubspec.yaml` shape (verify versions on pub.dev):

```yaml
dependencies:
  http: ^1.6.0            # or dio: ^5.11.1
  json_annotation: ^4.9.0
  freezed_annotation: 3.1.0   # pinned — see the quirk above

dev_dependencies:
  build_runner: ^2.17.1
  json_serializable: ^6.15.2
  freezed: ^4.0.3
```

If generation fails, read the *first* error — build_runner output
is long, and later errors are usually echoes of the first.

## Structure: a repository between API and UI

Widgets should never import `http` or `dio` directly:

```dart
class ItemRepository {
  ItemRepository(this._client);
  final http.Client _client;
  List<Item>? _cache;

  Future<List<Item>> getItems() async {
    if (_cache != null) return _cache!;
    final response = await _client.get(
      Uri.https('api.example.com', '/items'),
    );
    if (response.statusCode != 200) {
      throw ItemLoadException(response.statusCode);
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return _cache = [
      for (final j in list) Item.fromJson(j as Map<String, dynamic>),
    ];
  }
}
```

Benefits you feel immediately: one place for the base URL, one
place for caching, and tests can pass a fake client (guide 08).

## Error handling

- **Model errors as states, not snackbars from the data layer.**
  The repository throws typed exceptions or returns a sealed
  result; the state layer converts that into a `Failed` state
  (guide 04); the UI renders it with a retry button.
- **Distinguish failure kinds:** no connectivity, timeout,
  401 (re-auth), 404 (gone), 5xx (retry later), and malformed
  JSON (your bug or the API's breaking change) need different
  messages and different retry behaviour.
- **Set timeouts.** Both clients support them; an unbounded wait
  is a hung app.
- **Never log tokens or full auth headers**, even in debug builds
  that might get shared.

## Caching, honestly

Three levels, in order of sanity:

1. **In-memory** (the repository field above) — free, gone on
   restart, right for most screens.
2. **HTTP caching semantics** — honour `ETag`/`Cache-Control` if
   your API sends them; dio interceptors make this practical.
3. **On-disk** — persist responses in local storage (guide 07)
   only when offline use is a real requirement; now you own
   invalidation, and invalidation is the hard part.

For big JSON responses, parse off the main isolate
(`Isolate.run`, guide 02) so scrolling never stutters.

## Next

Local storage: [07-local-storage.md](07-local-storage.md).
Testing all of this: [08-testing.md](08-testing.md).
