import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart';

// 定义SystemInfo结构体对应的Dart类
final class SystemInfo extends ffi.Struct {
  external ffi.Pointer<ffi.Char> platform;
  external ffi.Pointer<ffi.Char> version;
  @ffi.Int64()
  external int timestamp;
}

// FFI函数签名定义
typedef NativeAddFunc = ffi.Int32 Function(ffi.Int32 a, ffi.Int32 b);
typedef DartAddFunc = int Function(int a, int b);

typedef NativeStringLengthFunc = ffi.Int32 Function(ffi.Pointer<ffi.Char> str);
typedef DartStringLengthFunc = int Function(ffi.Pointer<ffi.Char> str);

typedef NativeGetGreetingFunc = ffi.Pointer<ffi.Char> Function(
    ffi.Pointer<ffi.Char> name);
typedef DartGetGreetingFunc = ffi.Pointer<ffi.Char> Function(
    ffi.Pointer<ffi.Char> name);

typedef NativeSumArrayFunc = ffi.Int32 Function(
    ffi.Pointer<ffi.Int32> array, ffi.Int32 length);
typedef DartSumArrayFunc = int Function(ffi.Pointer<ffi.Int32> array, int length);

typedef NativeFreeStringFunc = ffi.Void Function(ffi.Pointer<ffi.Char> str);
typedef DartFreeStringFunc = void Function(ffi.Pointer<ffi.Char> str);

typedef NativeGetSystemInfoFunc = ffi.Pointer<SystemInfo> Function();
typedef DartGetSystemInfoFunc = ffi.Pointer<SystemInfo> Function();

typedef NativeFreeSystemInfoFunc = ffi.Void Function(
    ffi.Pointer<SystemInfo> info);
typedef DartFreeSystemInfoFunc = void Function(ffi.Pointer<SystemInfo> info);

class NativeFFI {
  late final ffi.DynamicLibrary _dylib;
  late final DartAddFunc nativeAdd;
  late final DartStringLengthFunc nativeStringLength;
  late final DartGetGreetingFunc nativeGetGreeting;
  late final DartSumArrayFunc nativeSumArray;
  late final DartFreeStringFunc nativeFreeString;
  late final DartGetSystemInfoFunc nativeGetSystemInfo;
  late final DartFreeSystemInfoFunc nativeFreeSystemInfo;

  NativeFFI() {
    // 加载动态库
    _dylib = _loadLibrary();

    // 查找并绑定函数
    nativeAdd = _dylib
        .lookup<ffi.NativeFunction<NativeAddFunc>>('native_add')
        .asFunction();

    nativeStringLength = _dylib
        .lookup<ffi.NativeFunction<NativeStringLengthFunc>>(
            'native_string_length')
        .asFunction();

    nativeGetGreeting = _dylib
        .lookup<ffi.NativeFunction<NativeGetGreetingFunc>>(
            'native_get_greeting')
        .asFunction();

    nativeSumArray = _dylib
        .lookup<ffi.NativeFunction<NativeSumArrayFunc>>('native_sum_array')
        .asFunction();

    nativeFreeString = _dylib
        .lookup<ffi.NativeFunction<NativeFreeStringFunc>>('native_free_string')
        .asFunction();

    nativeGetSystemInfo = _dylib
        .lookup<ffi.NativeFunction<NativeGetSystemInfoFunc>>(
            'native_get_system_info')
        .asFunction();

    nativeFreeSystemInfo = _dylib
        .lookup<ffi.NativeFunction<NativeFreeSystemInfoFunc>>(
            'native_free_system_info')
        .asFunction();
  }

  ffi.DynamicLibrary _loadLibrary() {
    if (Platform.isAndroid) {
      return ffi.DynamicLibrary.open('libnative_ffi.so');
    } else if (Platform.isIOS) {
      // iOS上，静态链接的库使用process方法
      return ffi.DynamicLibrary.process();
    } else if (Platform.isMacOS) {
      return ffi.DynamicLibrary.process();
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  // 高级封装方法

  /// 加法运算
  int add(int a, int b) {
    return nativeAdd(a, b);
  }

  /// 获取字符串长度
  int getStringLength(String str) {
    final nativeStr = str.toNativeUtf8();
    try {
      return nativeStringLength(nativeStr.cast<ffi.Char>());
    } finally {
      malloc.free(nativeStr);
    }
  }

  /// 获取问候语
  String getGreeting(String name) {
    final nativeName = name.toNativeUtf8();
    ffi.Pointer<ffi.Char>? resultPtr;

    try {
      resultPtr = nativeGetGreeting(nativeName.cast<ffi.Char>());
      if (resultPtr.address == 0) {
        return '';
      }
      final result = resultPtr.cast<Utf8>().toDartString();
      return result;
    } finally {
      malloc.free(nativeName);
      if (resultPtr != null && resultPtr.address != 0) {
        nativeFreeString(resultPtr);
      }
    }
  }

  /// 数组求和
  int sumArray(List<int> array) {
    if (array.isEmpty) {
      return 0;
    }

    final nativeArray = malloc.allocate<ffi.Int32>(array.length * 4);
    try {
      for (var i = 0; i < array.length; i++) {
        nativeArray[i] = array[i];
      }
      return nativeSumArray(nativeArray, array.length);
    } finally {
      malloc.free(nativeArray);
    }
  }

  /// 获取系统信息
  Map<String, dynamic> getSystemInfo() {
    ffi.Pointer<SystemInfo>? infoPtr;

    try {
      infoPtr = nativeGetSystemInfo();
      if (infoPtr.address == 0) {
        return {};
      }

      final info = infoPtr.ref;
      final result = {
        'platform': info.platform.cast<Utf8>().toDartString(),
        'version': info.version.cast<Utf8>().toDartString(),
        'timestamp': info.timestamp,
      };

      return result;
    } finally {
      if (infoPtr != null && infoPtr.address != 0) {
        nativeFreeSystemInfo(infoPtr);
      }
    }
  }
}

// 单例实例
final nativeFFI = NativeFFI();
