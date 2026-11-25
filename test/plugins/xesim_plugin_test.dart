import 'package:ble/ble.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nlpa2/adapter/ble/ble_adapter.dart';
import 'package:nlpa2/adapter/ble/ble_manager.dart';
import 'package:nlpa2/adapter/ble/nble_sim_adapter.dart';
import 'package:nlpa2/plugins/plugin_manager.dart';
import 'package:nlpa2/plugins/xesim_plugin.dart';
import 'package:nlpa2/utils/hex_utils.dart';
import 'package:nlpa2/widgets/profiles_screen/reader_helper.dart';

void main() {
  setUpAll(() {
    expect(PluginManager().hasPlugin('xesim'), isTrue);
  });

  final xesim = XesimPlugin.kind.type;

  test('detects Xesim names and nothing near them', () {
    for (final name in ['Xesim123456', ' xesim000184 ']) {
      expect(
        BleAdapterType.fromDeviceNames(displayName: name, advertisedName: ''),
        xesim,
        reason: name,
      );
      expect(
        BleAdapterType.fromDeviceNames(
          displayName: 'Bluetooth Device',
          advertisedName: name,
        ),
        xesim,
        reason: name,
      );
    }
    for (final name in ['Xesim12345', 'Xesim1234567', 'Xesim12345A']) {
      expect(
        BleAdapterType.fromDeviceNames(displayName: name, advertisedName: ''),
        isNot(xesim),
        reason: name,
      );
    }
  });

  test('the native scan keeps Xesim names', () {
    expect(XesimPlugin.kind.scanKeywords.any('Xesim123456'.contains), isTrue);
  });

  test('keeps the advertised name, which the PIN key is derived from', () {
    final info = BleReaderInfo.fromScanResult(
      ScanResult(
        device: _NamedBluetoothDevice('Bluetooth Device'),
        advertisementData: AdvertisementData(
          advName: 'Xesim123456',
          txPowerLevel: null,
          appearance: null,
          connectable: true,
          manufacturerData: const {},
          serviceData: const {},
          serviceUuids: const [],
        ),
        rssi: -50,
        timeStamp: DateTime(2026, 11, 23),
      ),
    );
    expect(info.type, xesim);
    expect(info.readerName, 'xesim: Xesim123456|device');
  });

  test('round-trips the Xesim reader ID and has its own icon', () {
    expect(BleAdapterType.tryFromId('xesim'), xesim);
    expect(BleAdapterType.fromReaderId('xesim: Xesim123456|device'), xesim);
    expect(ReaderHelper.getBleAdapterIconData(xesim), XesimPlugin.kind.icon);
  });

  test('uses the NBLE adapter without the 9eSIM device actions', () {
    final adapter = XesimPlugin.kind.createAdapter();
    expect(adapter, isA<NBLESimAdapter>());
    expect((adapter as NBLESimAdapter).variant, NBLESimVariant.xesim);
    expect(adapter.extraActions, isEmpty);
    expect(adapter.requiresRefresh, isTrue);
    expect(NBLESimAdapter().extraActions, isNotEmpty);
  });

  test('NBLE frames match the Xesim app byte for byte', () {
    // The Xesim app numbers its first APDU 2; these are the frames it writes.
    String frame(int counter, String apdu) => HexUtils.bytesToHex(
      NBLESimAdapter.encodeFramesForTransport(
        counter,
        HexUtils.hexToBytes(apdu),
        maxWriteSize: 101,
      ).single,
    ).toUpperCase();

    expect(frame(2, '0070000001'), '200200700000010073');
    expect(
      frame(3, '01A4040010A0000005591010FFFFFFFF8900000100'),
      '200301A4040010A0000005591010FFFFFFFF89000001000660',
    );
    expect(
      frame(4, '81E2910006BF3E035C015A'),
      '200481E2910006BF3E035C015A03B5',
    );
  });
}

class _NamedBluetoothDevice extends Fake implements BluetoothDevice {
  _NamedBluetoothDevice(this.platformName);

  @override
  final DeviceIdentifier remoteId = DeviceIdentifier('device');

  @override
  final String platformName;
}
