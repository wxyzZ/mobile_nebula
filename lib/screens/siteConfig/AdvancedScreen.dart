import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:mobile_nebula/components/FormPage.dart';
import 'package:mobile_nebula/components/PlatformTextFormField.dart';
import 'package:mobile_nebula/components/config/ConfigPageItem.dart';
import 'package:mobile_nebula/components/config/ConfigItem.dart';
import 'package:mobile_nebula/components/config/ConfigSection.dart';
import 'package:mobile_nebula/models/Site.dart';
import 'package:mobile_nebula/models/UnsafeRoute.dart';
import 'package:mobile_nebula/screens/siteConfig/CipherScreen.dart';
import 'package:mobile_nebula/screens/siteConfig/LogVerbosityScreen.dart';
import 'package:mobile_nebula/screens/siteConfig/RenderedConfigScreen.dart';
import 'package:mobile_nebula/services/utils.dart';

import 'UnsafeRoutesScreen.dart';

//TODO: form validation (seconds and port)
//TODO: wire up the focus nodes, add a done/next/prev to the keyboard
//TODO: fingerprint blacklist
//TODO: show site id here

class Advanced {
  int lhDuration;
  int port;
  String cipher;
  String verbosity;
  List<UnsafeRoute> unsafeRoutes;
  int mtu;

  Advanced({
    required this.lhDuration,
    required this.port,
    required this.cipher,
    required this.verbosity,
    required this.unsafeRoutes,
    required this.mtu,
  });
}

class AdvancedScreen extends StatefulWidget {
  const AdvancedScreen({super.key, required this.site, required this.onSave});

  final Site site;
  final ValueChanged<Advanced> onSave;

  @override
  _AdvancedScreenState createState() => _AdvancedScreenState();
}

class _AdvancedScreenState extends State<AdvancedScreen> {
  late Advanced settings;
  var changed = false;

  @override
  void initState() {
    settings = Advanced(
      lhDuration: widget.site.lhDuration,
      port: widget.site.port,
      cipher: widget.site.cipher,
      verbosity: widget.site.logVerbosity,
      unsafeRoutes: widget.site.unsafeRoutes,
      mtu: widget.site.mtu,
    );
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return FormPage(
      title: 'Advanced Settings',
      changed: changed,
      onSave: () {
        Navigator.pop(context);
        widget.onSave(settings);
      },
      child: Column(
        children: [
          ConfigSection(
            children: [
              ConfigItem(
                label: Text("Lighthouse interval"),
                labelWidth: 200,
                //TODO: Auto select on focus?
                content:
                    widget.site.managed
                        ? Text("${settings.lhDuration} seconds", textAlign: TextAlign.right)
                        : PlatformTextFormField(
                          initialValue: settings.lhDuration.toString(),
                          keyboardType: TextInputType.number,
                          suffix: Text("seconds"),
                          textAlign: TextAlign.right,
                          maxLength: 5,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          onSaved: (val) {
                            setState(() {
                              if (val != null) {
                                settings.lhDuration = int.parse(val);
                              }
                            });
                          },
                        ),
              ),
              ConfigItem(
                label: Text("Listen port"),
                labelWidth: 150,
                //TODO: Auto select on focus?
                content:
                    widget.site.managed
                        ? Text(settings.port.toString(), textAlign: TextAlign.right)
                        : PlatformTextFormField(
                          initialValue: settings.port.toString(),
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.right,
                          maxLength: 5,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          onSaved: (val) {
                            setState(() {
                              if (val != null) {
                                settings.port = int.parse(val);
                              }
                            });
                          },
                        ),
              ),
              ConfigItem(
                label: Text("MTU"),
                labelWidth: 150,
                content:
                    widget.site.managed
                        ? Text(settings.mtu.toString(), textAlign: TextAlign.right)
                        : PlatformTextFormField(
                          initialValue: settings.mtu.toString(),
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.right,
                          maxLength: 5,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          onSaved: (val) {
                            setState(() {
                              if (val != null) {
                                settings.mtu = int.parse(val);
                              }
                            });
                          },
                        ),
              ),
              ConfigPageItem(
                disabled: widget.site.managed,
                label: Text('Cipher'),
                labelWidth: 150,
                content: Text(settings.cipher, textAlign: TextAlign.end),
                onPressed: () {
                  Utils.openPage(context, (context) {
                    return CipherScreen(
                      cipher: settings.cipher,
                      onSave: (cipher) {
                        setState(() {
                          settings.cipher = cipher;
                          changed = true;
                        });
                      },
                    );
                  });
                },
              ),
              ConfigPageItem(
                disabled: widget.site.managed,
                label: Text('Log verbosity'),
                labelWidth: 150,
                content: Text(settings.verbosity, textAlign: TextAlign.end),
                onPressed: () {
                  Utils.openPage(context, (context) {
                    return LogVerbosityScreen(
                      verbosity: settings.verbosity,
                      onSave: (verbosity) {
                        setState(() {
                          settings.verbosity = verbosity;
                          changed = true;
                        });
                      },
                    );
                  });
                },
              ),
              ConfigPageItem(
                label: Text('Unsafe routes'),
                labelWidth: 150,
                content: Text(Utils.itemCountFormat(settings.unsafeRoutes.length), textAlign: TextAlign.end),
                onPressed: () {
                  Utils.openPage(context, (context) {
                    return UnsafeRoutesScreen(
                      unsafeRoutes: settings.unsafeRoutes,
                      onSave:
                          widget.site.managed
                              ? null
                              : (routes) {
                                setState(() {
                                  settings.unsafeRoutes = routes;
                                  changed = true;
                                });
                              },
                    );
                  });
                },
              ),
            ],
          ),
          ConfigSection(
            children: <Widget>[
              ConfigPageItem(
                content: const Text('View rendered config'),
                onTap: () async {
                  try {
                    final config = await widget.site.getConfig();
                    if (!mounted) return;

                    await showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return _ConfigDialog(
                          initialConfig: config,
                          onSave: (String newConfig) async {
                            try {
                              await widget.site.saveConfig(newConfig);
                              if (!mounted) return;
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Config saved successfully')),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to save config: $e')),
                              );
                            }
                          },
                        );
                      },
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to load config: $e')),
                    );
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConfigDialog extends StatefulWidget {
  final String initialConfig;
  final Function(String) onSave;

  const _ConfigDialog({
    required this.initialConfig,
    required this.onSave,
  });

  @override
  State<_ConfigDialog> createState() => _ConfigDialogState();
}

class _ConfigDialogState extends State<_ConfigDialog> {
  late TextEditingController _controller;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialConfig);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Rendered Config',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: Icon(_isEditing ? Icons.save : Icons.edit),
                  onPressed: () {
                    if (_isEditing) {
                      widget.onSave(_controller.text);
                      Navigator.of(context).pop();
                    } else {
                      setState(() {
                        _isEditing = true;
                      });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: _isEditing
                    ? TextField(
                        controller: _controller,
                        maxLines: null,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.all(8.0),
                        ),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                        ),
                      )
                    : Text(
                        widget.initialConfig,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            if (!_isEditing)
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
          ],
        ),
      ),
    );
  }
}
