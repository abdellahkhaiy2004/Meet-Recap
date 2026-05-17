import 'package:flutter/material.dart';

// Full implementation: [IP-0058]
class ProcessingPage extends StatelessWidget {
  const ProcessingPage({super.key, required this.draftId});
  final String draftId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Traitement…')),
      body: Center(child: Text('ProcessingPage $draftId — [IP-0058]')),
    );
  }
}
