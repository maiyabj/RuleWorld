import 'package:flutter/material.dart';
import 'device_info_ffi.dart';
import 'dart:convert';

/// ==================== FFI 调用 Swift 示例页面 ====================
///
/// 这个页面演示如何通过 FFI 调用 Swift 的 DeviceInfoManager

class DeviceInfoExamplePage extends StatefulWidget {
  const DeviceInfoExamplePage({super.key});

  @override
  State<DeviceInfoExamplePage> createState() => _DeviceInfoExamplePageState();
}

class _DeviceInfoExamplePageState extends State<DeviceInfoExamplePage> {
  String _deviceName = '';
  String _realName = '';
  String _model = '';
  String _version = '';
  Map<String, dynamic> _fullInfo = {};
  String _formattedInfo = '';
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadDeviceInfo();
  }

  /// 加载设备信息
  void _loadDeviceInfo() {
    try {
      setState(() {
        _errorMessage = '';

        // 示例1: 调用 Swift 的 DeviceInfoManager.getDeviceName()
        _deviceName = deviceInfoFFI.getDeviceName();

        // 示例2: 获取真实设备名称
        _realName = deviceInfoFFI.getRealDeviceName();

        // 示例3: 获取设备型号
        _model = deviceInfoFFI.getDeviceModel();

        // 示例4: 获取系统版本
        _version = deviceInfoFFI.getSystemVersion();

        // 示例5: 获取完整信息 (JSON)
        final jsonStr = deviceInfoFFI.getFullDeviceInfo();
        _fullInfo = jsonDecode(jsonStr) as Map<String, dynamic>;

        // 示例6: 格式化信息
        _formattedInfo =
            deviceInfoFFI.formatDeviceInfo('设备: {device}, 系统版本: $_version');
      });
    } catch (e) {
      setState(() {
        _errorMessage = '加载失败: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FFI 调用 Swift 示例'),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 错误信息
            if (_errorMessage.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  border: Border.all(color: Colors.red),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.red),
                ),
              ),

            // 标题
            const Text(
              '📱 设备信息',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // 信息卡片
            _buildInfoCard(
              title: '设备名称 (Swift)',
              subtitle: '调用 DeviceInfoManager.getDeviceName()',
              value: _deviceName,
              icon: Icons.phone_iphone,
              color: Colors.blue,
            ),

            _buildInfoCard(
              title: '真实设备名称',
              subtitle: 'UIDevice.current.name',
              value: _realName,
              icon: Icons.person,
              color: Colors.green,
            ),

            _buildInfoCard(
              title: '设备型号',
              subtitle: 'UIDevice.current.model',
              value: _model,
              icon: Icons.devices,
              color: Colors.orange,
            ),

            _buildInfoCard(
              title: '系统版本',
              subtitle: 'UIDevice.current.systemVersion',
              value: _version,
              icon: Icons.info,
              color: Colors.purple,
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // 完整信息 JSON
            const Text(
              '📋 完整信息 (JSON)',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Text(
                const JsonEncoder.withIndent('  ').convert(_fullInfo),
                style: const TextStyle(
                  fontFamily: 'Courier',
                  fontSize: 12,
                ),
              ),
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // 格式化信息
            const Text(
              '🎨 格式化信息',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Text(
                _formattedInfo,
                style: const TextStyle(fontSize: 14),
              ),
            ),

            const SizedBox(height: 24),

            // 刷新按钮
            Center(
              child: ElevatedButton.icon(
                onPressed: _loadDeviceInfo,
                icon: const Icon(Icons.refresh),
                label: const Text('刷新信息'),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 说明文字
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    '💡 实现原理',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '1. Swift 端使用 @_cdecl 导出 C 函数\n'
                    '2. Dart FFI 通过 lookup 查找函数地址\n'
                    '3. 调用 Swift 函数并传递数据\n'
                    '4. 自动管理内存 (strdup + free)',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建信息卡片
  Widget _buildInfoCard({
    required String title,
    required String subtitle,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 11)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value.isEmpty ? '加载中...' : value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

/// ==================== 使用示例 ====================
///
/// 在你的 Flutter 应用中使用:
///
/// ```dart
/// import 'package:magic_world_module/device_info_example.dart';
///
/// // 方式1: 直接使用页面
/// Navigator.push(
///   context,
///   MaterialPageRoute(
///     builder: (context) => const DeviceInfoExamplePage(),
///   ),
/// );
///
/// // 方式2: 直接调用 FFI
/// import 'package:magic_world_module/device_info_ffi.dart';
///
/// void printDeviceInfo() {
///   print('Device: ${deviceInfoFFI.getDeviceName()}');
///   print('Model: ${deviceInfoFFI.getDeviceModel()}');
///   print('Version: ${deviceInfoFFI.getSystemVersion()}');
/// }
/// ```
