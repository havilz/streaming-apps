import 'dart:async';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class CloudflareBypassService {
  CloudflareBypassService._();
  
  static final instance = CloudflareBypassService._();

  String? _userAgent;
  String? _cookieString;
  DateTime? _lastHarvested;

  bool _isHarvesting = false;
  Completer<void>? _harvestCompleter;

  String? get userAgent => _userAgent;
  String? get cookieString => _cookieString;

  bool get hasValidCookies {
    if (_lastHarvested == null) return false;
    // Clearance cookies usually last from 1 to 24 hours.
    // We renew them every 2 hours to stay fresh.
    return DateTime.now().difference(_lastHarvested!) < const Duration(hours: 2);
  }

  Future<void> ensureBypass(String targetUrl) async {
    if (hasValidCookies) return;
    if (_isHarvesting) {
      return _harvestCompleter?.future;
    }

    _isHarvesting = true;
    _harvestCompleter = Completer<void>();

    try {
      print('[CloudflareBypassService] Starting cookie harvesting for $targetUrl...');
      
      final headlessWebView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(
          url: WebUri(targetUrl),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          },
        ),
        initialSettings: InAppWebViewSettings(
          mediaPlaybackRequiresUserGesture: false,
          javaScriptEnabled: true,
          contentBlockers: [
            ContentBlocker(
              trigger: ContentBlockerTrigger(
                urlFilter: ".*(ads|doubleclick|googleadservices|popads|propellerads|exoclick|a-ads|adsterra|trafficstars|onclick|mgid|taboola|outbrain|adnxs|yandex|criteo|pubmatic).*|.*\\.(gif|png|jpg|jpeg|mp4|webm)\\?.*",
              ),
              action: ContentBlockerAction(
                type: ContentBlockerActionType.BLOCK,
              ),
            ),
          ],
        ),
        onLoadStart: (controller, url) {
          print('[CloudflareBypassService] Load started: $url');
        },
        onLoadStop: (controller, url) async {
          print('[CloudflareBypassService] Page loaded: $url');
          // Wait briefly for Turnstile / JS challenge / cookies to settle
          await Future.delayed(const Duration(seconds: 4));

          final cookieManager = CookieManager.instance();
          final cookies = await cookieManager.getCookies(url: WebUri(targetUrl));
          
          final Map<String, String> cookieMap = {};
          for (var cookie in cookies) {
            cookieMap[cookie.name] = cookie.value.toString();
          }

          print('[CloudflareBypassService] Harvested cookies: $cookieMap');
          _cookieString = cookieMap.entries.map((e) => '${e.key}=${e.value}').join('; ');
          
          final ua = await controller.evaluateJavascript(source: "navigator.userAgent");
          if (ua != null && ua is String) {
            _userAgent = ua.replaceAll('"', '').trim();
          } else {
            _userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
          }

          _lastHarvested = DateTime.now();
          print('[CloudflareBypassService] Harvested cookies and userAgent successfully!');
        },
      );

      await headlessWebView.run();

      // Poll until cookies are harvested or we hit a 15-second timeout
      int maxPolls = 15;
      while (maxPolls > 0 && !hasValidCookies) {
        await Future.delayed(const Duration(seconds: 1));
        maxPolls--;
      }

      await headlessWebView.dispose();
      print('[CloudflareBypassService] Headless WebView disposed.');

      if (hasValidCookies) {
        _harvestCompleter?.complete();
      } else {
        throw Exception('Cloudflare bypass timed out.');
      }
    } catch (e, stack) {
      print('[CloudflareBypassService] Error during bypass: $e\n$stack');
      _harvestCompleter?.completeError(e);
    } finally {
      _isHarvesting = false;
      _harvestCompleter = null;
    }
  }

  /// Run HTTP request inside a headless WebView browser context to bypass Cloudflare TLS fingerprint blocks.
  Future<String?> fetchInWebView(String url, {String method = 'GET', String? body}) async {
    final completer = Completer<String?>();
    final baseUrl = const String.fromEnvironment('IDLIX_BASE_URL', defaultValue: 'https://z2.idlixku.com');
    
    final headless = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(baseUrl)),
      onWebViewCreated: (controller) {
        controller.addJavaScriptHandler(
          handlerName: 'fetchCallback',
          callback: (args) {
            final result = args[0] as String?;
            if (!completer.isCompleted) {
              completer.complete(result);
            }
          },
        );
      },
      onLoadStop: (controller, uri) async {
        try {
          // Escaping dynamic body variables for JavaScript injection
          final escapedBody = body != null ? body.replaceAll("'", "\\'").replaceAll('"', '\\"') : '';
          
          final jsCode = """
            (async function() {
              try {
                const options = {
                  method: '$method',
                  headers: {
                    'Accept': 'application/json, text/plain, */*',
                    'Referer': '$baseUrl/'
                  }
                };
                if ('$method' === 'POST' && '$escapedBody' !== '') {
                  options.headers['Content-Type'] = 'application/json';
                  options.body = JSON.stringify(JSON.parse('$escapedBody'));
                }
                const res = await fetch('$url', options);
                if (!res.ok) {
                  window.flutter_inappwebview.callHandler('fetchCallback', 'ERROR: ' + res.status);
                  return;
                }
                const text = await res.text();
                window.flutter_inappwebview.callHandler('fetchCallback', text);
              } catch (e) {
                window.flutter_inappwebview.callHandler('fetchCallback', 'ERROR: ' + e.message);
              }
            })()
          """;
          await controller.evaluateJavascript(source: jsCode);
        } catch (e) {
          if (!completer.isCompleted) {
            completer.completeError(e);
          }
        }
      },
    );
    
    await headless.run();
    final res = await completer.future.timeout(const Duration(seconds: 15), onTimeout: () => null);
    await headless.dispose();
    return res;
  }
}

class WebViewSession {
  HeadlessInAppWebView? _headless;
  InAppWebViewController? _controller;
  final Completer<void> _readyCompleter = Completer<void>();
  final Map<String, Completer<String?>> _pendingRequests = {};
  int _requestIdCounter = 0;

  Future<void> init() async {
    final baseUrl = const String.fromEnvironment('IDLIX_BASE_URL', defaultValue: 'https://z2.idlixku.com');
    _headless = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(baseUrl)),
      onWebViewCreated: (controller) {
        _controller = controller;
        controller.addJavaScriptHandler(
          handlerName: 'sessionCallback',
          callback: (args) {
            final requestId = args[0] as String;
            final result = args[1] as String?;
            final completer = _pendingRequests[requestId];
            if (completer != null && !completer.isCompleted) {
              completer.complete(result);
            }
          },
        );
      },
      onLoadStop: (controller, uri) async {
        if (!_readyCompleter.isCompleted) {
          _readyCompleter.complete();
        }
      },
    );
    await _headless!.run();
    await _readyCompleter.future.timeout(const Duration(seconds: 15));
  }

  Future<String?> fetch(String url, {String method = 'GET', String? body}) async {
    if (_controller == null) return null;
    await _readyCompleter.future;
    
    final requestId = 'req_${_requestIdCounter++}';
    final completer = Completer<String?>();
    _pendingRequests[requestId] = completer;

    final escapedBody = body != null ? body.replaceAll("'", "\\'").replaceAll('"', '\\"') : '';
    final baseUrl = const String.fromEnvironment('IDLIX_BASE_URL', defaultValue: 'https://z2.idlixku.com');

    final jsCode = """
      (async function() {
        try {
          const options = {
            method: '$method',
            headers: {
              'Accept': 'application/json, text/plain, */*',
              'Referer': '$baseUrl/'
            }
          };
          if ('$method' === 'POST' && '$escapedBody' !== '') {
            options.headers['Content-Type'] = 'application/json';
            options.body = JSON.stringify(JSON.parse('$escapedBody'));
          }
          const res = await fetch('$url', options);
          if (!res.ok) {
            window.flutter_inappwebview.callHandler('sessionCallback', '$requestId', 'ERROR: ' + res.status);
            return;
          }
          const text = await res.text();
          window.flutter_inappwebview.callHandler('sessionCallback', '$requestId', text);
        } catch (e) {
          window.flutter_inappwebview.callHandler('sessionCallback', '$requestId', 'ERROR: ' + e.message);
        }
      })()
    """;

    try {
      await _controller!.evaluateJavascript(source: jsCode);
      final res = await completer.future.timeout(const Duration(seconds: 15));
      _pendingRequests.remove(requestId);
      return res;
    } catch (e) {
      _pendingRequests.remove(requestId);
      return 'ERROR: ' + e.toString();
    }
  }

  Future<void> dispose() async {
    await _headless?.dispose();
    _headless = null;
    _controller = null;
  }
}
