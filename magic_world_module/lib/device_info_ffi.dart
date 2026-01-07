import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart';

/// ==================== 调用 Swift DeviceInfoManager 的 FFI 封装 ====================
///
/// 完整流程示例:
///
/// 1. Swift 端 (DeviceInfoBridge.swift):
///    ```swift
///    @_cdecl("device_get_name_swift")
///    public func device_get_name_swift() -> UnsafeMutablePointer<CChar>? {
///        let manager = DeviveInfoManager()
///        return strdup(manager.getDeviceName())
///    }
///    ```
///
/// 2. Dart 端 (本文件):
///    - lookup 查找 "device_get_name_swift" 符号
///    - asFunction 创建 Dart 包装器
///    - 调用函数,接收 C 字符串指针
///    - 转换为 Dart String
///    - 释放 C 内存
///
/// 内存流程:
/// [Swift堆] "iPhone" → strdup → [C堆] "iPhone\0" (malloc)
///                                    ↓ 返回指针
/// [Dart] Pointer<Char> → toDartString() → [Dart堆] "iPhone"
///                                    ↓ device_free_string
/// [C堆] 释放内存

// ==================== 函数签名定义 ====================

/// 返回字符串指针的函数 (无参数)
typedef NativeGetStringFunc = ffi.Pointer<ffi.Char> Function();
typedef DartGetStringFunc = ffi.Pointer<ffi.Char> Function();

/// 释放字符串的函数
typedef NativeFreeStringFunc = ffi.Void Function(ffi.Pointer<ffi.Char> ptr);
typedef DartFreeStringFunc = void Function(ffi.Pointer<ffi.Char> ptr);

/// 带参数的格式化函数
typedef NativeFormatInfoFunc = ffi.Pointer<ffi.Char> Function(
    ffi.Pointer<ffi.Char> format);
typedef DartFormatInfoFunc = ffi.Pointer<ffi.Char> Function(
    ffi.Pointer<ffi.Char> format);

// ==================== FFI 绑定类 ====================

class DeviceInfoFFI {
  late final ffi.DynamicLibrary _dylib;

  // Swift 桥接函数绑定
  late final DartGetStringFunc _deviceGetNameSwift;
  late final DartGetStringFunc _deviceGetRealName;
  late final DartGetStringFunc _deviceGetModel;
  late final DartGetStringFunc _deviceGetSystemVersion;
  late final DartGetStringFunc _deviceGetFullInfo;
  late final DartFreeStringFunc _deviceFreeString;
  late final DartFormatInfoFunc _deviceFormatInfo;

  DeviceInfoFFI() {
    // 加载动态库
    _dylib = _loadLibrary();

    // 绑定函数
    _deviceGetNameSwift = _dylib
        .lookup<ffi.NativeFunction<NativeGetStringFunc>>(
            'device_get_name_swift')
        .asFunction();

    _deviceGetRealName = _dylib
        .lookup<ffi.NativeFunction<NativeGetStringFunc>>('device_get_real_name')
        .asFunction();

    _deviceGetModel = _dylib
        .lookup<ffi.NativeFunction<NativeGetStringFunc>>('device_get_model')
        .asFunction();

    _deviceGetSystemVersion = _dylib
        .lookup<ffi.NativeFunction<NativeGetStringFunc>>(
            'device_get_system_version')
        .asFunction();

    _deviceGetFullInfo = _dylib
        .lookup<ffi.NativeFunction<NativeGetStringFunc>>(
            'device_get_full_info')
        .asFunction();

    _deviceFreeString = _dylib
        .lookup<ffi.NativeFunction<NativeFreeStringFunc>>(
            'device_free_string')
        .asFunction();

    _deviceFormatInfo = _dylib
        .lookup<ffi.NativeFunction<NativeFormatInfoFunc>>(
            'device_format_info')
        .asFunction();
  }

  ffi.DynamicLibrary _loadLibrary() {
    if (Platform.isIOS || Platform.isMacOS) {
      // iOS/macOS: Swift 代码编译进主程序
      return ffi.DynamicLibrary.process();
    } else {
      throw UnsupportedError('This library only supports iOS/macOS');
    }
  }

  // ==================== 高级 API ====================

  /// 获取设备名称 (通过 Swift DeviceInfoManager)
  ///
  /// 调用链:
  /// Dart -> C 桥接函数 -> Swift DeviceInfoManager.getDeviceName()
  String getDeviceName() {
    return _getStringFromNative(_deviceGetNameSwift);
  }

  /// 获取真实设备名称 (用户设置的名称,如 "张三的 iPhone")
  String getRealDeviceName() {
    return _getStringFromNative(_deviceGetRealName);
  }

  /// 获取设备型号 (如 "iPhone", "iPad")
  String getDeviceModel() {
    return _getStringFromNative(_deviceGetModel);
  }

  /// 获取系统版本 (如 "17.0")
  String getSystemVersion() {
    return _getStringFromNative(_deviceGetSystemVersion);
  }

  /// 获取完整设备信息 (JSON 字符串)
  String getFullDeviceInfo() {
    return _getStringFromNative(_deviceGetFullInfo);
  }

  /// 格式化设备信息
  ///
  /// 示例:
  /// ```dart
  /// final info = deviceInfoFFI.formatDeviceInfo("Current device: {device}");
  /// print(info); // "Current device: iPhone"
  /// ```
  String formatDeviceInfo(String format) {
    final nativeFormat = format.toNativeUtf8();
    ffi.Pointer<ffi.Char>? resultPtr;

    try {
      resultPtr = _deviceFormatInfo(nativeFormat.cast<ffi.Char>());
      if (resultPtr.address == 0) {
        return '';
      }
      return resultPtr.cast<Utf8>().toDartString();
    } finally {
      malloc.free(nativeFormat);
      if (resultPtr != null && resultPtr.address != 0) {
        _deviceFreeString(resultPtr);
      }
    }
  }

  // ==================== 工具方法 ====================

  /// 从 Native 函数获取字符串的通用方法
  ///
  /// 原理:
  /// 1. 调用 Native 函数,获取 C 字符串指针
  /// 2. 检查指针是否有效 (address != 0)
  /// 3. 转换为 Dart String (复制到 Dart 堆)
  /// 4. 调用 Swift 的释放函数,清理 C 堆内存
  ///
  /// 内存安全:
  /// - try-finally 确保无论是否异常都会释放内存
  /// - 空指针检查防止访问无效内存
  String _getStringFromNative(DartGetStringFunc nativeFunc) {
    ffi.Pointer<ffi.Char>? ptr;

    try {
      // 调用 Native 函数
      ptr = nativeFunc();

      // 检查指针有效性
      if (ptr.address == 0) {
        return '';
      }

      // 转换为 Dart String (会复制数据到 Dart 堆)
      return ptr.cast<Utf8>().toDartString();
    } finally {
      // 释放 Swift 端分配的内存
      if (ptr != null && ptr.address != 0) {
        _deviceFreeString(ptr);
      }
    }
  }
}

// ==================== 单例 ====================

/// 全局单例,方便调用
///
/// 使用方式:
/// ```dart
/// import 'package:magic_world_module/device_info_ffi.dart';
///
/// void main() {
///   // 调用 Swift 的 DeviceInfoManager.getDeviceName()
///   final name = deviceInfoFFI.getDeviceName();
///   print('Device: $name');
///
///   // 获取真实设备名称
///   final realName = deviceInfoFFI.getRealDeviceName();
///   print('Real name: $realName');
///
///   // 获取完整信息
///   final info = deviceInfoFFI.getFullDeviceInfo();
///   print('Full info: $info');
/// }
/// ```
final deviceInfoFFI = DeviceInfoFFI();
