import 'dart:html' as html;
import 'dart:js_interop' as js;
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;
import 'package:cross_file/cross_file.dart';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

class WebFileSelectorPlatformView {
  WebFileSelectorPlatformView._() : _viewType = _getNewViewType();

  static int _currID = 0;

  void Function(List<XFile> files)? onData;
  final String _viewType;
  String? _accept;
  bool? _multiple;
  int? _viewId;

  static bool _isTouchEnabled() {
    return (web.document.hasProperty('ontouchend'.toJS).toDart);
  }

  static bool isIOSWeb() {
    // Web platform

    // Detect from  user agent string
    final userAgent = web.window.navigator.userAgent;

    if (userAgent.contains(' Chrome/')) {
      //
      // Chrome, Edge, Opera, Chromium, etc.
      //
      // Apple's browser doesn't have this embedded in the user agent string
      // This is true for iOS version of Chrome (CriOS), Edge (EdgiOS) &
      // Opera (OPT).
      //
      return false;
    } else if (userAgent.contains(' Firefox/')) {
      //
      // Firefox
      //
      // Apple's browser doesn't have this embedded in the user agent string
      // This is true for iOS version of Firefox (FxiOS).
      //
      return false;
    }

    if (userAgent.contains('(iPhone;')) {
      // iPhone
      return true;
    } else if (userAgent.contains('(iPad;')) {
      // iPadOS < 13
      return true;
    } else if (userAgent.contains('(Macintosh;')) {
      // iPadOS >= 13, macOS

      // iPad has a touch capability whereas macOS does not (for now)
      if (_isTouchEnabled()) {
        return true; // iPadOS >= 13
      } else {
        return false; // macOS
      }
    }

    return false; // Something else
  }

  static String _getNewViewType() {
    ++_currID;
    return 'web-file-selector-$_currID';
  }

  static WebFileSelectorPlatformView newInstance() {
    final platformView = WebFileSelectorPlatformView._();

    platformView._init();

    return platformView;
  }

  String? get accept {
    return _accept;
  }

  set accept(String? val) {
    final oldValue = _accept ?? '';
    final newValue = val ?? '';

    if (_accept != val || oldValue != newValue) {
      _accept = val;

      if (_inputElementID != null) {
        // The input element is already created.
        // Get the element and update its accept attribute.
        final element = web.document.getElementById(_inputElementID!);
        if (element != null) {
          if (element is web.HTMLInputElement) {
            element.accept = _accept ?? '';
          }
        }
      }
    }
  }

  bool? get multiple {
    return _multiple;
  }

  set multiple(bool? val) {
    final oldValue = _multiple ?? false;
    final newValue = val ?? false;

    if (_multiple != val || oldValue != newValue) {
      _multiple = val;

      if (_inputElementID != null) {
        // The input element is already created.
        // Get the element and update its multiple attribute.
        final element = web.document.getElementById(_inputElementID!);
        if (element != null) {
          if (element is web.HTMLInputElement) {
            element.multiple = _multiple ?? false;
          }
        }
      }
    }
  }

  String? get _inputElementID {
    if (_viewId != null) {
      // We have the unique view ID already
      return 'web-selector-file-upload-input-${_viewId!}';
    } else {
      // We don't have the unique view ID yet
      return null;
    }
  }

  void _init() {
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) {
        _viewId = viewId;

        final inputElementID = _inputElementID!;

        // Add HTML label element
        final labelElement = web.HTMLLabelElement();
        labelElement.htmlFor = inputElementID;

        labelElement.style.display = 'block';
        labelElement.style.position = 'absolute';
        labelElement.style.opacity = '0.001';
        labelElement.style.width = '100%';
        labelElement.style.height = '100%';
        labelElement.style.border = '0';
        labelElement.style.backgroundColor = 'transparent';
        labelElement.style.cursor = 'pointer';

        try {
          // This is to prevent mobile version of Chrome from
          // applying a highlight color when tapped.
          if (web.CSS.supports('-webkit-tap-highlight-color: transparent')) {
            labelElement.attributeStyleMap.set(
              '-webkit-tap-highlight-color',
              'transparent'.toJS,
            );
          }
        } catch (_) {
          // CSS.support() is probably not supported the
          // browser this code is currently running on.
        }

        // Add HTML input element
        {
          final inputElement = web.HTMLInputElement();
          inputElement.id = inputElementID;

          inputElement.style.position = 'absolute';
          inputElement.style.inset = '0';
          inputElement.style.display = 'none';

          inputElement.type = 'file';
          inputElement.title = '';
          inputElement.accept = accept ?? '';
          inputElement.multiple = multiple ?? false;

          inputElement.onChange.listen((event) {
            if (onData != null) {
              final List<XFile> webFiles = [];

              final target = event.target;
              if (target != null) {
                if (target is web.HTMLInputElement) {
                  if (target.files != null) {
                    final files = target.files!;
                    for (var idx = 0; idx < files.length; ++idx) {
                      final file = files.item(idx);
                      if (file != null) {
                        webFiles.add(
                          XFile(
                            web.URL.createObjectURL(file),
                            name: file.name,
                            length: file.size,
                            lastModified: DateTime.fromMillisecondsSinceEpoch(
                              file.lastModified,
                            ),
                            mimeType: file.type,
                          ),
                        );
                      }
                    }
                  }

                  target.value = '';
                }
              }

              onData!(webFiles);
            }
          });

          labelElement.append(inputElement);

          if (onData != null) {
            // The onChange or onInput event does not detect if "cancel" was click on file input
            // This is a workaround in which to detect if it is canceled
            // This required adding the following to the index.html

            // <--- Add the js below to the index.html --->
            // document.body.onfocus = function() {
            //   var x = document.getElementById('flutter_web_file_selector_dialog_is_opened');
            //   if (x && x.getAttribute('data-value') === 'true') {
            //     x.setAttribute('data-value', 'false');
            //   }
            // };
            // <--- Add the js above to the index.html --->

            // Create a div that will
            final divElement = web.HTMLDivElement();
            divElement.id = 'flutter_web_file_selector_dialog_is_opened';
            divElement.setAttribute('data-value', 'false');
            web.document.body?.append(divElement);

            inputElement.onClick.listen((event) {
              divElement.setAttribute('data-value', 'true');
            });

            // Define the callback function for the MutationObserver
            void mutationCallback(
              List<dynamic> mutations,
              html.MutationObserver observer,
            ) {
              for (var mutation in mutations) {
                if (mutation.attributeName == 'data-value') {
                  final value = (mutation.target as web.HTMLElement)
                      .getAttribute('data-value');

                  if (value == 'false' && inputElement.files?.length == 0) {
                    // i.e. - The file selection dialog is closed and cancel button is clicked
                    onData!([]);
                  }
                }
              }
            }

            final observer = html.MutationObserver(mutationCallback);
            observer.observe(
              divElement as html.Node,
              childList: true,
              subtree: true,
              attributes: true,
            );
          }
        }

        return labelElement;
      },
    );
  }

  Widget build(
    BuildContext context, {
    required void Function(List<XFile> files)? onData,
    required Widget child,
    String? accept,
    bool? multiple,
  }) {
    this.onData = onData;
    this.accept = accept;
    this.multiple = multiple;

    if (onData != null) {
      return IntrinsicWidth(
        child: IntrinsicHeight(
          child: Stack(
            children: [
              HtmlElementView(
                viewType: _viewType,
              ),
              child,
            ],
          ),
        ),
      );
    } else {
      return child;
    }
  }
}
