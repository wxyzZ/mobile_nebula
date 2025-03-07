import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mobile_nebula/components/DangerButton.dart';
import 'package:mobile_nebula/components/SimplePage.dart';
import 'package:mobile_nebula/components/config/ConfigCheckboxItem.dart';
import 'package:mobile_nebula/components/config/ConfigItem.dart';
import 'package:mobile_nebula/components/config/ConfigPageItem.dart';
import 'package:mobile_nebula/components/config/ConfigSection.dart';
import 'package:mobile_nebula/models/Certificate.dart';
import 'package:mobile_nebula/models/HostInfo.dart';
import 'package:mobile_nebula/models/Site.dart';
import 'package:mobile_nebula/screens/siteConfig/CertificateDetailsScreen.dart';
import 'package:mobile_nebula/services/utils.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

class HostInfoScreen extends StatefulWidget {
  const HostInfoScreen({
    super.key,
    required this.hostInfo,
    required this.isLighthouse,
    required this.pending,
    this.onChanged,
    required this.site,
    required this.supportsQRScanning,
  });

  final bool isLighthouse;
  final bool pending;
  final HostInfo hostInfo;
  final Function? onChanged;
  final Site site;

  final bool supportsQRScanning;

  @override
  _HostInfoScreenState createState() => _HostInfoScreenState();
}

//TODO: have a config option to refresh hostmaps on a cadence (applies to 3 screens so far)

class _HostInfoScreenState extends State<HostInfoScreen> {
  late HostInfo hostInfo;
  RefreshController refreshController = RefreshController(initialRefresh: false);

  @override
  void initState() {
    _setHostInfo(widget.hostInfo);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.pending ? 'Pending' : 'Active';

    return SimplePage(
      title: Text('$title Host Info'),
      refreshController: refreshController,
      onRefresh: () async {
        await _getHostInfo();
        refreshController.refreshCompleted();
      },
      child: Column(
        children: [_buildMain(), _buildDetails(), _buildRemotes(), !widget.pending ? _buildClose() : Container()],
      ),
    );
  }

  Widget _buildMain() {
    return ConfigSection(
      children: [
        ConfigItem(label: Text('VPN IP'), labelWidth: 150, content: SelectableText(hostInfo.vpnIp)),
        hostInfo.cert != null
            ? ConfigPageItem(
              label: Text('Certificate'),
              labelWidth: 150,
              content: Text(hostInfo.cert!.details.name),
              onPressed:
                  () => Utils.openPage(
                    context,
                    (context) => CertificateDetailsScreen(
                      certInfo: CertificateInfo(cert: hostInfo.cert!),
                      supportsQRScanning: widget.supportsQRScanning,
                    ),
                  ),
            )
            : Container(),
      ],
    );
  }

  Widget _buildDetails() {
    return ConfigSection(
      children: <Widget>[
        ConfigItem(
          label: Text('Lighthouse'),
          labelWidth: 150,
          content: SelectableText(widget.isLighthouse ? 'Yes' : 'No'),
        ),
        ConfigItem(label: Text('Local Index'), labelWidth: 150, content: SelectableText('${hostInfo.localIndex}')),
        ConfigItem(label: Text('Remote Index'), labelWidth: 150, content: SelectableText('${hostInfo.remoteIndex}')),
        ConfigItem(
          label: Text('Message Counter'),
          labelWidth: 150,
          content: SelectableText('${hostInfo.messageCounter}'),
        ),
      ],
    );
  }

  Widget _buildRemotes() {
    if (hostInfo.remoteAddresses.isEmpty) {
      return ConfigSection(
        label: 'REMOTES',
        children: [ConfigItem(content: Text('No remote addresses yet'), labelWidth: 0)],
      );
    }

    return widget.pending ? _buildStaticRemotes() : _buildEditRemotes();
  }

  Widget _buildEditRemotes() {
    List<Widget> items = [];
    final currentRemote = hostInfo.currentRemote.toString();
    final double ipWidth =
        Utils.textSize("000.000.000.000:000000", CupertinoTheme.of(context).textTheme.textStyle).width;

    for (var remoteObj in hostInfo.remoteAddresses) {
      String remote = remoteObj.toString();
      items.add(
        ConfigCheckboxItem(
          key: Key(remote),
          label: Text(remote), //TODO: need to do something to adjust the font size in the event we have an ipv6 address
          labelWidth: ipWidth,
          checked: currentRemote == remote,
          onChanged: () async {
            if (remote == currentRemote) {
              return;
            }

            try {
              final h = await widget.site.setRemoteForTunnel(hostInfo.vpnIp, remote);
              if (h != null) {
                _setHostInfo(h);
              }
            } catch (err) {
              Utils.popError(context, 'Error while changing the remote', err.toString());
            }
          },
        ),
      );
    }

    return ConfigSection(label: items.isNotEmpty ? 'Tap to change the active address' : null, children: items);
  }

  Widget _buildStaticRemotes() {
    List<Widget> items = [];
    final currentRemote = hostInfo.currentRemote.toString();
    final double ipWidth =
        Utils.textSize("000.000.000.000:000000", CupertinoTheme.of(context).textTheme.textStyle).width;

    for (var remoteObj in hostInfo.remoteAddresses) {
      String remote = remoteObj.toString();
      items.add(
        ConfigCheckboxItem(
          key: Key(remote),
          label: Text(remote), //TODO: need to do something to adjust the font size in the event we have an ipv6 address
          labelWidth: ipWidth,
          checked: currentRemote == remote,
        ),
      );
    }

    return ConfigSection(label: items.isNotEmpty ? 'REMOTES' : null, children: items);
  }

  Widget _buildClose() {
    return Padding(
      padding: EdgeInsets.only(top: 50, bottom: 10, left: 10, right: 10),
      child: SizedBox(
        width: double.infinity,
        child: DangerButton(
          child: Text('Close Tunnel'),
          onPressed:
              () => Utils.confirmDelete(context, 'Close Tunnel?', () async {
                try {
                  await widget.site.closeTunnel(hostInfo.vpnIp);
                  if (widget.onChanged != null) {
                    widget.onChanged!();
                  }
                  Navigator.pop(context);
                } catch (err) {
                  Utils.popError(context, 'Error while trying to close the tunnel', err.toString());
                }
              }, deleteLabel: 'Close'),
        ),
      ),
    );
  }

  _getHostInfo() async {
    try {
      final h = await widget.site.getHostInfo(hostInfo.vpnIp, widget.pending);
      if (h == null) {
        return Utils.popError(context, '', 'The tunnel for this host no longer exists');
      }

      _setHostInfo(h);
    } catch (err) {
      Utils.popError(context, 'Failed to refresh host info', err.toString());
    }
  }

  _setHostInfo(HostInfo h) {
    h.remoteAddresses.sort((a, b) {
      final diff = a.ip.compareTo(b.ip);
      return diff == 0 ? a.port - b.port : diff;
    });

    setState(() {
      hostInfo = h;
    });
  }
}
