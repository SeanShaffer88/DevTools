// A tiny in-memory repository so the skeleton runs with real-shaped
// data and no backend. In a real project this is the seam where a
// dio/http client or a drift database goes (see the guides on data
// and networking in this resource pack), and where fixtures from
// fixtures/sample-data/ can be loaded in tests.

/// One row of sample data, shaped like fixtures/sample-data/items.json.
class SampleItem {
  const SampleItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.isFavorite,
  });

  factory SampleItem.fromJson(Map<String, dynamic> json) {
    return SampleItem(
      id: json['id'] as int,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String,
      isFavorite: json['isFavorite'] as bool? ?? false,
    );
  }

  final int id;
  final String title;
  final String subtitle;
  final bool isFavorite;
}

/// Synchronous sample source. Swap [loadItems] for an async method
/// returning a Future when a real backend or database is wired in,
/// and drive the page with a FutureBuilder / state-management layer.
class SampleRepository {
  const SampleRepository();

  List<SampleItem> loadItems() {
    return const [
      SampleItem(
        id: 1,
        title: 'Welcome',
        subtitle: 'This list comes from SampleRepository',
        isFavorite: true,
      ),
      SampleItem(
        id: 2,
        title: 'Feature-first layout',
        subtitle: 'Pages live under lib/features/<feature>/',
        isFavorite: false,
      ),
      SampleItem(
        id: 3,
        title: 'Replace the data source',
        subtitle: 'Point this repository at an API or local database',
        isFavorite: false,
      ),
    ];
  }
}
