import 'package:flutter/material.dart';

import 'weather_code.dart';
import 'weather_service.dart';

void main() => runApp(const WeatherApp());

class WeatherApp extends StatefulWidget {
  const WeatherApp({super.key});

  @override
  State<WeatherApp> createState() => _WeatherAppState();
}

class _WeatherAppState extends State<WeatherApp> {
  // Follows the phone's setting until the person taps the toggle.
  ThemeMode _mode = ThemeMode.system;

  void _toggle(Brightness current) {
    setState(() {
      _mode =
          current == Brightness.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor:
          dark ? const Color(0xFF0E0F12) : const Color(0xFFF7F7F5),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF4F8CFF),
        brightness: brightness,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weather',
      debugShowCheckedModeBanner: false,
      themeMode: _mode,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: HomePage(onToggleTheme: _toggle),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.onToggleTheme});

  final void Function(Brightness current) onToggleTheme;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _controller = TextEditingController();
  final _service = WeatherService();

  Weather? _weather;
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _service.fetch(query);
      if (!mounted) return;
      setState(() => _weather = result);
    } on WeatherException catch (e) {
      if (!mounted) return;
      setState(() {
        _weather = null;
        _error = e.message;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: isDark ? 'Light mode' : 'Dark mode',
                  onPressed: () => widget.onToggleTheme(theme.brightness),
                  icon: Icon(isDark
                      ? Icons.light_mode_rounded
                      : Icons.dark_mode_rounded),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _controller,
                textInputAction: TextInputAction.search,
                onSubmitted: _search,
                decoration: InputDecoration(
                  hintText: 'Search a city',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: isDark ? 0.4 : 0.6),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _body(theme),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(ThemeData theme) {
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);

    if (_loading) {
      return const CircularProgressIndicator(key: ValueKey('loading'));
    }
    if (_error != null) {
      return Text(_error!,
          key: const ValueKey('error'),
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(color: muted));
    }
    final weather = _weather;
    if (weather == null) {
      return Column(
        key: const ValueKey('empty'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wb_cloudy_rounded, size: 56, color: muted),
          const SizedBox(height: 12),
          Text('Search for a place', style: TextStyle(color: muted)),
        ],
      );
    }

    final visual = visualFor(weather.code, isDay: weather.isDay);
    return Column(
      key: ValueKey(weather.place),
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(visual.icon, size: 96, color: visual.color),
        const SizedBox(height: 16),
        Text(
          '${weather.temperatureC.round()}°',
          style: const TextStyle(fontSize: 88, fontWeight: FontWeight.w200),
        ),
        const SizedBox(height: 4),
        Text(weather.place,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(visual.label, style: TextStyle(color: muted)),
      ],
    );
  }
}
