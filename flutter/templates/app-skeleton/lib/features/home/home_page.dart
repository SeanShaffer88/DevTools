// Home feature page: shows the sample items as a Material 3 list.
// Kept deliberately small — no counter, no state management package —
// so the data seam (SampleRepository) is the thing being demonstrated.
import 'package:flutter/material.dart';

import '../../data/sample_repository.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, this.repository = const SampleRepository()});

  final SampleRepository repository;

  @override
  Widget build(BuildContext context) {
    final items = repository.loadItems();
    return Scaffold(
      appBar: AppBar(title: const Text('App Skeleton')),
      body: items.isEmpty
          ? const Center(child: Text('No items yet'))
          : ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  leading: Icon(
                    item.isFavorite ? Icons.star : Icons.star_border,
                  ),
                  title: Text(item.title),
                  subtitle: Text(item.subtitle),
                );
              },
            ),
    );
  }
}
