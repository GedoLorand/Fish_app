import 'package:flutter/material.dart';
import 'package:login_fish_app/homepage/Initial/initialType.dart';
import 'package:webview_flutter/webview_flutter.dart';

class LegalWebViewScreen extends StatefulWidget {
  const LegalWebViewScreen({super.key, required this.title, required this.url});

  final String title;
  final String url;

  @override
  State<LegalWebViewScreen> createState() => _LegalWebViewScreenState();
}

class _LegalWebViewScreenState extends State<LegalWebViewScreen> {
  WebViewController? _controller;
  var _isLoading = true;
  var _hasError = false;

  bool get _hasValidUrl {
    final uri = Uri.tryParse(widget.url.trim());
    return uri != null && (uri.scheme == 'https' || uri.scheme == 'http');
  }

  @override
  void initState() {
    super.initState();
    if (!_hasValidUrl) {
      _isLoading = false;
      return;
    }

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _isLoading = true;
              _hasError = false;
            });
          },
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() => _isLoading = false);
          },
          onWebResourceError: (_) {
            if (!mounted) return;
            setState(() {
              _isLoading = false;
              _hasError = true;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: AppTheme.textColor,
        actions: [
          if (_controller != null)
            IconButton(
              tooltip: 'Frissítés',
              icon: const Icon(Icons.refresh),
              onPressed: () => _controller?.reload(),
            ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            if (!_hasValidUrl)
              _LegalMessage(
                icon: Icons.link_off,
                title: 'A link még nincs beállítva',
                message:
                    'Add meg az oldal nyilvános URL-jét a legal_links.dart fájlban.',
              )
            else if (_hasError)
              _LegalMessage(
                icon: Icons.error_outline,
                title: 'Nem sikerült betölteni az oldalt',
                message:
                    'Ellenőrizd az internetkapcsolatot vagy a megadott URL-t.',
                action: _controller == null
                    ? null
                    : ElevatedButton.icon(
                        onPressed: () => _controller?.reload(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Újrapróbálás'),
                      ),
              )
            else if (_controller != null)
              WebViewWidget(controller: _controller!),
            if (_isLoading)
              LinearProgressIndicator(
                backgroundColor: AppTheme.surfaceColor,
                color: AppTheme.primaryColor,
              ),
          ],
        ),
      ),
    );
  }
}

class _LegalMessage extends StatelessWidget {
  const _LegalMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppTheme.primaryColor),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textColor,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textColor.withValues(alpha: 0.75),
              ),
            ),
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}
