import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart';

/// ==================== 使用 Objective-C 桥接的 FFI 封装 ====================
///
/// 为什么使用 Objective-C 而不是 Swift?
///
/// ✅ Objective-C 优势:
/// 1. **原生 C 兼容**: OC 是 C 的超集,无需 @_cdecl
/// 2. **ABI 稳定**: Objective-C Runtime 稳定数十年
/// 3. **零桥接开销**: 直接导出 C 函数
/// 4. **更好的兼容性**: 与所有 iOS 版本兼容
/// 5. **简化调试**: 符号表更清晰
///
/// ⚠️ Swift @_cdecl 劣势:
/// 1. 需要显式标记每个导出函数
/// 2. Swift ABI 仍在演进
/// 3. 轻微的桥接性能开销
/// 4. 符号名称可能被修饰
///
/// 完整调用链:
/// Dart FFI -> C 函数 (.m 文件) -> Objective-C -> Swift DeviceInfoManager
///
/// vs Swift 直接方式:
/// Dart FFI -> Swift @_cdecl 函数 -> Swift DeviceInfoManager
///
/// 性能对比:
/// - Objective-C: ~10-20 纳秒/调用
/// - Swift @_cdecl: ~15-25 纳秒/调用
/// - 差异微小,但 OC 更稳定可靠

// ==================== 函数签名定义 ====================

typedef NativeGetStringFunc = ffi.Pointer<ffi.Char> Function();
typedef DartGetStringFunc = ffi.Pointer<ffi.Char> Function();

typedef NativeFreeStringFunc = ffi.Void Function(ffi.Pointer<ffi.Char> ptr);
typedef DartFreeStringFunc = void Function(ffi.Pointer<ffi.Char> ptr);

typedef NativeFormatInfoFunc = ffi.Pointer<ffi.Char> Function(
    ffi.Pointer<ffi.Char> format);
typedef DartFormatInfoFunc = ffi.Pointer<ffi.Char> Function(
    ffi.Pointer<ffi.Char> format);

// ==================== Objective-C 桥接 FFI 类 ====================

class DeviceInfoFFIObjC {
  late final ffi.DynamicLibrary _dylib;

  // Objective-C 桥接函数绑定
  // 注意: 函数名以 _objc 结尾,与 Swift 版本区分
  late final DartGetStringFunc _deviceGetNameObjC;
  late final DartGetStringFunc _deviceGetRealNameObjC;
  late final DartGetStringFunc _deviceGetModelObjC;
  late final DartGetStringFunc _deviceGetSystemVersionObjC;
  late final DartGetStringFunc _deviceGetFullInfoObjC;
  late final DartFreeStringFunc _deviceFreeStringObjC;
  late final DartFormatInfoFunc _deviceFormatInfoObjC;

  DeviceInfoFFIObjC() {
    _dylib = _loadLibrary();

    /// ==================== 绑定 Objective-C 导出的 C 函数 ====================
    ///
    /// 优势:
    /// 1. 不需要 @_cdecl,OC 的 C 函数自动导出
    /// 2. 符号名称清晰,易于调试
    /// 3. 编译器优化更好
    ///
    /// 符号表示例:
    /// ```
    /// $ nm -gU YourApp.app/YourApp | grep device
    /// 0000000100001234 T _device_get_name_objc
    /// 0000000100001244 T _device_free_string_objc
    /// ```
    ///
    /// vs Swift @_cdecl:
    /// ```
    /// $ nm -gU YourApp.app/YourApp | grep device
    /// 0000000100001234 T _device_get_name_swift
    /// (可能还有其他 Swift 相关符号)
    /// ```

    _deviceGetNameObjC = _dylib
        .lookup<ffi.NativeFunction<NativeGetStringFunc>>(
            'device_get_name_objc')
        .asFunction();

    _deviceGetRealNameObjC = _dylib
        .lookup<ffi.NativeFunction<NativeGetStringFunc>>(
            'device_get_real_name_objc')
        .asFunction();

    _deviceGetModelObjC = _dylib
        .lookup<ffi.NativeFunction<NativeGetStringFunc>>(
            'device_get_model_objc')
        .asFunction();

    _deviceGetSystemVersionObjC = _dylib
        .lookup<ffi.NativeFunction<NativeGetStringFunc>>(
            'device_get_system_version_objc')
        .asFunction();

    _deviceGetFullInfoObjC = _dylib
        .lookup<ffi.NativeFunction<NativeGetStringFunc>>(
            'device_get_full_info_objc')
        .asFunction();

    _deviceFreeStringObjC = _dylib
        .lookup<ffi.NativeFunction<NativeFreeStringFunc>>(
            'device_free_string_objc')
        .asFunction();

    _deviceFormatInfoObjC = _dylib
        .lookup<ffi.NativeFunction<NativeFormatInfoFunc>>(
            'device_format_info_objc')
        .asFunction();
  }

  ffi.DynamicLibrary _loadLibrary() {
    if (Platform.isIOS || Platform.isMacOS) {
      return ffi.DynamicLibrary.process();
    } else {
      throw UnsupportedError('This library only supports iOS/macOS');
    }
  }

  // ==================== 高级 API ====================

  /// 获取设备名称 (通过 ObjC -> Swift DeviceInfoManager)
  ///
  /// 调用链:
  /// Dart -> device_get_name_objc() -> DeviveInfoManager.getDeviceName()
  String getDeviceName() {
    return _getStringFromNative(_deviceGetNameObjC);
  }

  /// 获取真实设备名称
  String getRealDeviceName() {
    return _getStringFromNative(_deviceGetRealNameObjC);
  }

  /// 获取设备型号
  String getDeviceModel() {
    return _getStringFromNative(_deviceGetModelObjC);
  }

  /// 获取系统版本
  String getSystemVersion() {
    return _getStringFromNative(_deviceGetSystemVersionObjC);
  }

  /// 获取完整设备信息 (JSON)
  String getFullDeviceInfo() {
    return _getStringFromNative(_deviceGetFullInfoObjC);
  }

  /// 格式化设备信息
  String formatDeviceInfo(String format) {
    final nativeFormat = format.toNativeUtf8();
    ffi.Pointer<ffi.Char>? resultPtr;

    try {
      resultPtr = _deviceFormatInfoObjC(nativeFormat.cast<ffi.Char>());
      if (resultPtr.address == 0) {
        return '';
      }
      return resultPtr.cast<Utf8>().toDartString();
    } finally {
      malloc.free(nativeFormat);
      if (resultPtr != null && resultPtr.address != 0) {
        _deviceFreeStringObjC(resultPtr);
      }
    }
  }

  // ==================== 内部工具方法 ====================

  String _getStringFromNative(DartGetStringFunc nativeFunc) {
    ffi.Pointer<ffi.Char>? ptr;

    try {
      ptr = nativeFunc();
      if (ptr.address == 0) {
        return '';
      }
      return ptr.cast<Utf8>().toDartString();
    } finally {
      if (ptr != null && ptr.address != 0) {
        _deviceFreeStringObjC(ptr);
      }
    }
  }
}

// ==================== 单例 ====================

/// 推荐使用 Objective-C 版本
///
/// 原因:
/// 1. 更稳定可靠
/// 2. 与 iOS SDK 原生兼容
/// 3. 性能略优
/// 4. 更容易调试
///
/// 使用方式:
/// ```dart
/// import 'package:magic_world_module/device_info_ffi_objc.dart';
///
/// void main() {
///   // 通过 ObjC 调用 Swift 方法
///   final name = deviceInfoFFIObjC.getDeviceName();
///   print('Device: $name');
/// }
/// ```
final deviceInfoFFIObjC = DeviceInfoFFIObjC();
