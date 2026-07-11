import 'dart:async';
import 'package:flutter/material.dart';
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
    // cf_clearance is the real Cloudflare bypass cookie.
    // Without it, even if we have other cookies, the API will return 403.
    if (_cookieString == null || !_cookieString!.contains('cf_clearance')) return false;
    // Clearance cookies usually last from 1 to 24 hours.
    // We renew them every 2 hours to stay fresh.
    return DateTime.now().difference(_lastHarvested!) < const Duration(hours: 2);
  }

  Future<void> ensureBypass(String targetUrl, {BuildContext? context}) async {
    if (hasValidCookies) return;
    if (_isHarvesting) {
      return _harvestCompleter?.future;
    }

    _isHarvesting = true;
    _harvestCompleter = Completer<void>();

    try {
      print('[CloudflareBypassService] Starting cookie harvesting for $targetUrl...');
      
      // Try headless first
      bool success = await _tryHeadlessBypass(targetUrl);
      
      // If headless fails/times out, and we have context, show visible dialog
      if (!success && context != null && context.mounted) {
        print('[CloudflareBypassService] Headless bypass failed. Showing visible verification dialog...');
        success = await _showVisibleBypassDialog(context, targetUrl);
      }

      if (success && hasValidCookies) {
        _harvestCompleter?.complete();
      } else {
        throw Exception('Cloudflare bypass timed out or was cancelled.');
      }
    } catch (e, stack) {
      print('[CloudflareBypassService] Error during bypass: $e\n$stack');
      _harvestCompleter?.completeError(e);
    } finally {
      _isHarvesting = false;
      _harvestCompleter = null;
    }
  }

  Future<bool> _tryHeadlessBypass(String targetUrl) async {
    try {
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
          print('[CloudflareBypassService] Headless load started: $url');
        },
        onLoadStop: (controller, url) async {
          print('[CloudflareBypassService] Headless page loaded: $url');
          // Brief wait for JS cookies to settle (2s is enough to detect if cf_clearance appears)
          await Future.delayed(const Duration(seconds: 2));
          await _saveCookiesAndUA(controller, url!.toString(), targetUrl);
        },
      );

      await headlessWebView.run();

      // Poll up to 6 seconds. If cf_clearance does not appear, Turnstile is blocking us headlessly.
      int maxPolls = 6;
      while (maxPolls > 0 && !hasValidCookies) {
        await Future.delayed(const Duration(seconds: 1));
        maxPolls--;
      }

      await headlessWebView.dispose();
      return hasValidCookies;
    } catch (e) {
      print('[CloudflareBypassService] Headless bypass exception: $e');
      return false;
    }
  }

  Future<bool> _showVisibleBypassDialog(BuildContext context, String targetUrl) async {
    final completer = Completer<bool>();
    InAppWebViewController? dialogController;
    // Key to safely close the dialog without holding a BuildContext across async gaps
    final dialogKey = GlobalKey();

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: const Color(0xFF121212),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (dialogContext) {
        return KeyedSubtree(
          key: dialogKey,
          child: PopScope(
            canPop: false,
            child: Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(dialogContext).viewInsets.bottom),
              child: SizedBox(
                height: MediaQuery.of(dialogContext).size.height * 0.75,
                child: Column(
                  children: [
                    AppBar(
                      backgroundColor: const Color(0xFF1E1E1E),
                      title: const Text(
                        'Verifikasi Keamanan Cloudflare',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      automaticallyImplyLeading: false,
                      actions: [
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                            if (!completer.isCompleted) completer.complete(false);
                          },
                        )
                      ],
                    ),
                    Container(
                      width: double.infinity,
                      color: Colors.amber[900]!.withValues(alpha: 0.2),
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                      child: const Row(
                        children: [
                          Icon(Icons.security, color: Colors.amber, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Ketuk kotak "Verify you are human" jika muncul untuk membuka kunci pemutaran video.',
                              style: TextStyle(color: Colors.amber, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: InAppWebView(
                        initialUrlRequest: URLRequest(
                          url: WebUri(targetUrl),
                          headers: {
                            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                          },
                        ),
                        initialSettings: InAppWebViewSettings(
                          javaScriptEnabled: true,
                        ),
                        onWebViewCreated: (controller) {
                          dialogController = controller;
                        },
                        onLoadStop: (controller, url) async {
                          if (completer.isCompleted) return;
                          print('[CloudflareBypassService] Visible page loaded: $url');
                          await Future.delayed(const Duration(seconds: 3));
                          if (completer.isCompleted) return;
                          await _saveCookiesAndUA(controller, url!.toString(), targetUrl);
                          if (hasValidCookies && !completer.isCompleted) {
                            print('[CloudflareBypassService] cf_clearance detected on loadStop!');
                            // Use dialogContext directly — we're still inside the builder's scope
                            if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                            completer.complete(true);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ).then((_) {
      if (!completer.isCompleted) completer.complete(false);
    });

    // Periodic polling: check every 2 seconds for cf_clearance appearing after Turnstile interaction
    // Turnstile may not trigger onLoadStop after verification — this catches that case.
    Future.doWhile(() async {
      if (completer.isCompleted) return false;
      await Future.delayed(const Duration(seconds: 2));
      if (completer.isCompleted) return false;
      if (dialogController != null) {
        await _saveCookiesAndUA(dialogController!, targetUrl, targetUrl);
      }
      if (hasValidCookies && !completer.isCompleted) {
        print('[CloudflareBypassService] Polling: cf_clearance found! Dismissing dialog.');
        // Capture navigator before async gap to satisfy use_build_context_synchronously
        final nav = context.mounted ? Navigator.maybeOf(context) : null;
        nav?.pop();
        completer.complete(true);
        return false;
      }
      return !completer.isCompleted;
    });

    return completer.future;
  }

  Future<void> _saveCookiesAndUA(InAppWebViewController controller, String url, String targetUrl) async {
    try {
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

      // Only mark as successfully harvested if cf_clearance is present.
      // Without cf_clearance, the cookies are not sufficient to bypass Cloudflare.
      if (cookieMap.containsKey('cf_clearance')) {
        _lastHarvested = DateTime.now();
        print('[CloudflareBypassService] Harvested cookies and userAgent successfully! cf_clearance found.');
      } else {
        print('[CloudflareBypassService] WARNING: cf_clearance not found in cookies. Bypass not complete. Cookies: $cookieMap');
      }
    } catch (e) {
      print('[CloudflareBypassService] Error extracting cookies/UA: $e');
    }
  }

  /// Run HTTP request inside a headless WebView browser context to bypass Cloudflare TLS fingerprint blocks.
  Future<String?> fetchInWebView(String url, {String method = 'GET', String? body}) async {
    final completer = Completer<String?>();
    final baseUrl = const String.fromEnvironment('IDLIX_BASE_URL', defaultValue: 'https://z2.idlixku.com');

    // Use harvested credentials if available
    final cookieStr = _cookieString ?? '';
    final uaStr = _userAgent ?? 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
    
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
        // If we're on a Cloudflare challenge page, navigate directly to the API URL
        // The cf_clearance cookies from ensureBypass are already set in the cookie store
        final currentUrl = uri?.toString() ?? '';
        if (currentUrl.contains('challenges.cloudflare.com') ||
            currentUrl.contains('/cdn-cgi/challenge') ||
            currentUrl.contains('/cdn-cgi/l/chk')) {
          print('[CloudflareBypassService] fetchInWebView: Challenge page detected, navigating directly to API URL...');
          await Future.delayed(const Duration(seconds: 2));
          await controller.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
          return;
        }

        try {
          // Escaping dynamic body variables for JavaScript injection
          final escapedBody = body != null ? body.replaceAll("'", "\\'").replaceAll('"', '\\"') : '';
          // Escape cookie string for JS
          final escapedCookie = cookieStr.replaceAll("'", "\\'");
          final escapedUA = uaStr.replaceAll("'", "\\'");
          
          final jsCode = """
            (async function() {
              try {
                const options = {
                  method: '$method',
                  headers: {
                    'Accept': 'application/json, text/plain, */*',
                    'Referer': '$baseUrl/',
                    'Cookie': '$escapedCookie',
                    'User-Agent': '$escapedUA'
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
    final res = await completer.future.timeout(const Duration(seconds: 20), onTimeout: () => null);
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

    // Pre-inject bypass cookies BEFORE the WebView starts so the first request already has cf_clearance.
    // This prevents Cloudflare from showing a challenge page at all.
    final svc = CloudflareBypassService.instance;
    if (svc.hasValidCookies && svc.cookieString != null) {
      final cookieManager = CookieManager.instance();
      for (final part in svc.cookieString!.split('; ')) {
        final idx = part.indexOf('=');
        if (idx > 0) {
          final name = part.substring(0, idx).trim();
          final value = part.substring(idx + 1).trim();
          try {
            await cookieManager.setCookie(url: WebUri(baseUrl), name: name, value: value);
          } catch (_) {}
        }
      }
    }

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
        final currentUrl = uri?.toString() ?? '';
        // If Cloudflare challenge page is detected even after pre-injection, re-inject and reload
        if (currentUrl.contains('challenges.cloudflare.com') ||
            currentUrl.contains('/cdn-cgi/challenge') ||
            currentUrl.contains('/cdn-cgi/l/chk')) {
          final service = CloudflareBypassService.instance;
          if (service.hasValidCookies && service.cookieString != null) {
            final cookieManager = CookieManager.instance();
            for (final part in service.cookieString!.split('; ')) {
              final idx = part.indexOf('=');
              if (idx > 0) {
                final name = part.substring(0, idx).trim();
                final value = part.substring(idx + 1).trim();
                try {
                  await cookieManager.setCookie(url: WebUri(baseUrl), name: name, value: value);
                } catch (_) {}
              }
            }
            await controller.loadUrl(urlRequest: URLRequest(url: WebUri(baseUrl)));
          } else {
            if (!_readyCompleter.isCompleted) _readyCompleter.complete();
          }
          return;
        }
        if (!_readyCompleter.isCompleted) {
          _readyCompleter.complete();
        }
      },
    );
    await _headless!.run();
    await _readyCompleter.future.timeout(const Duration(seconds: 20));
  }

  Future<String?> fetch(String url, {String method = 'GET', String? body}) async {
    if (_controller == null) return null;
    await _readyCompleter.future;
    
    final requestId = 'req_${_requestIdCounter++}';
    final completer = Completer<String?>();
    _pendingRequests[requestId] = completer;

    final escapedBody = body != null ? body.replaceAll("'", "\\'").replaceAll('"', '\\"') : '';
    final baseUrl = const String.fromEnvironment('IDLIX_BASE_URL', defaultValue: 'https://z2.idlixku.com');

    // Inject harvested cookies and UA into the JS fetch headers for extra reliability
    final svc = CloudflareBypassService.instance;
    final cookieStr = (svc.cookieString ?? '').replaceAll("'", "\\'");
    final uaStr = (svc.userAgent ?? 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36').replaceAll("'", "\\'");

    final jsCode = """
      (async function() {
        try {
          const options = {
            method: '$method',
            headers: {
              'Accept': 'application/json, text/plain, */*',
              'Referer': '$baseUrl/',
              'Cookie': '$cookieStr',
              'User-Agent': '$uaStr'
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
      return 'ERROR: $e';
    }
  }

  Future<void> dispose() async {
    await _headless?.dispose();
    _headless = null;
    _controller = null;
  }
}
