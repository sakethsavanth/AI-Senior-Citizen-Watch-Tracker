import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'theme/app_theme.dart';

void main() => runApp(const ProviderScope(child: SeniorCareApp()));

class SeniorCareApp extends ConsumerWidget {
  const SeniorCareApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'SeniorCare AI',
      theme: buildAppTheme(),
      debugShowCheckedModeBanner: false,
      routerConfig: router,
    );
  }
}
