import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart';

/// ==================== FFI 原理概述 ====================
///
/// FFI (Foreign Function Interface) 是 Dart 调用 C/C++ 代码的桥梁
///
/// 工作流程:
/// 1. 加载动态库 (.so/.dylib/.dll) 到内存
/// 2. 通过符号名称查找 C 函数地址 (lookup)
/// 3. 创建 Dart 函数包装器 (asFunction)
/// 4. 调用时进行数据类型转换和内存管理
///
/// 内存模型:
/// - Dart 堆: Dart 对象的自动垃圾回收区域
/// - Native 堆: C/C++ 的手动内存管理区域 (malloc/free)
/// - FFI 负责在两者之间传递数据,需要手动管理 Native 内存
///
/// ======================================================

// ==================== 结构体映射 ====================
/// SystemInfo 是 C 结构体在 Dart 中的镜像
///
/// 原理:
/// 1. 使用 ffi.Struct 告诉 Dart 这是一个 C 结构体
/// 2. external 关键字表示字段在 Native 内存中,不在 Dart 堆
/// 3. Dart 会按 C 的内存布局(对齐规则)访问这些字段
///
/// 内存布局示例 (64位系统):
/// +0:  platform (8字节指针)
/// +8:  version  (8字节指针)
/// +16: timestamp (8字节 int64)
/// 总大小: 24字节
final class SystemInfo extends ffi.Struct {
  external ffi.Pointer<ffi.Char> platform;
  external ffi.Pointer<ffi.Char> version;
  @ffi.Int64()
  external int timestamp;
}

// ==================== 函数签名类型定义 ====================
/// 为什么需要两个 typedef?
///
/// 1. Native 签名 (NativeXxxFunc):
///    - 描述 C 函数的实际签名
///    - 使用 FFI 类型: ffi.Int32, ffi.Void, ffi.Pointer
///    - 用于 `lookup<NativeFunction<T>>()` 时的类型参数
///
/// 2. Dart 签名 (DartXxxFunc):
///    - 描述在 Dart 中调用时的签名
///    - 使用 Dart 类型: int, void, Pointer (已转换)
///    - 用于 `asFunction<T>()` 的返回类型
///
/// 类型转换规则:
/// - `ffi.Int32 <-> int` (自动转换)
/// - `ffi.Void <-> void`
/// - `ffi.Pointer<T> <-> ffi.Pointer<T>` (不变,但需显式声明)

// 示例: 简单加法函数
typedef NativeAddFunc = ffi.Int32 Function(ffi.Int32 a, ffi.Int32 b);
typedef DartAddFunc = int Function(int a, int b);

// 示例: 接收 C 字符串指针
typedef NativeStringLengthFunc = ffi.Int32 Function(ffi.Pointer<ffi.Char> str);
typedef DartStringLengthFunc = int Function(ffi.Pointer<ffi.Char> str);

// 示例: 返回 C 字符串指针 (需手动释放)
typedef NativeGetGreetingFunc = ffi.Pointer<ffi.Char> Function(
    ffi.Pointer<ffi.Char> name);
typedef DartGetGreetingFunc = ffi.Pointer<ffi.Char> Function(
    ffi.Pointer<ffi.Char> name);

// 示例: 接收数组指针和长度
typedef NativeSumArrayFunc = ffi.Int32 Function(
    ffi.Pointer<ffi.Int32> array, ffi.Int32 length);
typedef DartSumArrayFunc = int Function(ffi.Pointer<ffi.Int32> array, int length);

// 示例: 释放 Native 内存的函数
typedef NativeFreeStringFunc = ffi.Void Function(ffi.Pointer<ffi.Char> str);
typedef DartFreeStringFunc = void Function(ffi.Pointer<ffi.Char> str);

// 示例: 返回结构体指针
typedef NativeGetSystemInfoFunc = ffi.Pointer<SystemInfo> Function();
typedef DartGetSystemInfoFunc = ffi.Pointer<SystemInfo> Function();

// 示例: 释放结构体内存
typedef NativeFreeSystemInfoFunc = ffi.Void Function(
    ffi.Pointer<SystemInfo> info);
typedef DartFreeSystemInfoFunc = void Function(ffi.Pointer<SystemInfo> info);

/// ==================== FFI 绑定类 ====================
///
/// 核心职责:
/// 1. 加载动态库到进程地址空间
/// 2. 查找 C 函数地址并创建 Dart 包装器
/// 3. 提供类型安全的高级 API
class NativeFFI {
  /// 动态库句柄 - 代表加载到内存的 .so/.dylib 文件
  late final ffi.DynamicLibrary _dylib;

  /// ==================== 函数绑定 ====================
  /// late final 的作用:
  /// - late: 延迟初始化,在构造函数中赋值
  /// - final: 一旦初始化后不可变,确保线程安全
  ///
  /// 每个字段都是一个 Dart 函数,指向对应的 C 函数
  late final DartAddFunc nativeAdd;
  late final DartStringLengthFunc nativeStringLength;
  late final DartGetGreetingFunc nativeGetGreeting;
  late final DartSumArrayFunc nativeSumArray;
  late final DartFreeStringFunc nativeFreeString;
  late final DartGetSystemInfoFunc nativeGetSystemInfo;
  late final DartFreeSystemInfoFunc nativeFreeSystemInfo;

  NativeFFI() {
    /// ==================== 步骤1: 加载动态库 ====================
    /// 原理:
    /// - 操作系统将 .so/.dylib 文件映射到进程地址空间
    /// - 解析符号表,准备好所有导出函数的地址
    /// - 返回一个句柄,用于后续的符号查找
    _dylib = _loadLibrary();

    /// ==================== 步骤2: 查找并绑定函数 ====================
    ///
    /// lookup 的工作原理:
    /// 1. 在动态库的符号表中查找 'native_add' 这个名字
    /// 2. 找到对应的函数地址 (例如: 0x7fff12345678)
    /// 3. 返回一个 Pointer<NativeFunction<T>>,包含这个地址
    ///
    /// asFunction 的工作原理:
    /// 1. 创建一个 Dart 闭包,封装调用逻辑
    /// 2. 调用时自动处理:
    ///    - 参数的 Dart -> C 类型转换
    ///    - 调用约定 (calling convention) 的适配
    ///    - 返回值的 C -> Dart 类型转换
    /// 3. 返回类型安全的 Dart 函数
    ///
    /// 内存消耗: 每个 asFunction 约创建 100-200 字节的包装器对象

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

  // ==================== 高级封装方法 ====================
  /// 这些方法隐藏了底层的指针和内存管理细节,提供类型安全的 Dart API

  /// ==================== 示例1: 简单值传递 ====================
  ///
  /// 原理:
  /// 1. Dart int 自动转换为 C int32
  /// 2. 通过寄存器传递参数 (快速,无内存分配)
  /// 3. C 返回值自动转换回 Dart int
  ///
  /// 性能: 纳秒级,几乎无开销
  int add(int a, int b) {
    return nativeAdd(a, b);
  }

  /// ==================== 示例2: 字符串传递 ====================
  ///
  /// 原理:
  /// 1. `toNativeUtf8()`: 在 Native 堆分配内存,复制字符串数据
  ///    - Dart String (UTF-16) -> UTF-8 编码
  ///    - malloc 分配内存
  ///    - 返回 `Pointer<Utf8>`
  ///
  /// 2. `cast<ffi.Char>()`: 类型转换,指向同一内存地址
  ///    - `Pointer<Utf8> -> Pointer<Char>`
  ///    - 无性能开销,只是类型标记
  ///
  /// 3. finally: 确保无论是否异常都释放内存
  ///    - malloc.free() 释放 Native 堆内存
  ///    - 避免内存泄漏
  ///
  /// 内存流程:
  /// [Dart堆] "Hello" (UTF-16)
  ///     ↓ toNativeUtf8()
  /// [Native堆] "Hello\0" (UTF-8, 6字节)
  ///     ↓ 传递给 C
  /// [C函数] 读取字符串
  ///     ↓ 返回后
  /// [Native堆] 释放 6字节
  int getStringLength(String str) {
    final nativeStr = str.toNativeUtf8();
    try {
      return nativeStringLength(nativeStr.cast<ffi.Char>());
    } finally {
      malloc.free(nativeStr);
    }
  }

  /// ==================== 示例3: C 返回字符串 ====================
  ///
  /// 原理:
  /// 1. 传递字符串给 C (同示例2)
  ///
  /// 2. C 函数返回 `Pointer<Char>`:
  ///    - C 端通过 malloc 分配内存
  ///    - 返回指针地址给 Dart
  ///    - 所有权转移给 Dart 端
  ///
  /// 3. toDartString():
  ///    - 读取 Native 内存中的 UTF-8 数据
  ///    - 转换为 Dart String (UTF-16)
  ///    - 复制到 Dart 堆
  ///    - 原 Native 内存仍需手动释放
  ///
  /// 4. 双重释放:
  ///    - malloc.free(nativeName): 释放输入字符串
  ///    - nativeFreeString(resultPtr): 释放返回的字符串
  ///
  /// 内存流程:
  /// [Dart堆] "Alice" → [Native堆] "Alice\0" (输入)
  ///                         ↓ C函数处理
  ///                    [Native堆] "Hello, Alice!\0" (C 分配)
  ///                         ↓ toDartString()
  /// [Dart堆] "Hello, Alice!" ← 复制数据
  ///                         ↓ nativeFreeString()
  ///                    [Native堆] 释放 "Hello, Alice!\0"
  ///
  /// 关键: C 分配的内存必须用 C 的 free 函数释放 (这里是 nativeFreeString)
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

  /// ==================== 示例4: 数组传递 ====================
  ///
  /// 原理:
  /// 1. `malloc.allocate<ffi.Int32>(bytes)`:
  ///    - 在 Native 堆分配连续内存
  ///    - 大小 = array.length * 4 字节 (每个 int32 占 4 字节)
  ///    - 返回 `Pointer<Int32>`,指向内存起始地址
  ///
  /// 2. `nativeArray[i] = array[i]`:
  ///    - Pointer 支持数组索引语法
  ///    - 底层: `*(ptr + i * sizeof(int32)) = value`
  ///    - 逐个复制 Dart List 数据到 Native 内存
  ///
  /// 3. 传递给 C:
  ///    - C 函数接收指针和长度
  ///    - C 端遍历连续内存,无需额外分配
  ///
  /// 4. finally 释放内存
  ///
  /// 内存流程:
  /// [Dart堆] List<int> [1,2,3,4,5]
  ///             ↓ allocate + 复制
  /// [Native堆] [1][2][3][4][5] (连续的 20 字节)
  ///             ↓ 传递指针
  /// [C函数] 读取 20 字节数据
  ///             ↓ 计算完成
  /// [Native堆] 释放 20 字节
  ///
  /// 性能考虑:
  /// - 复制开销: O(n),每次调用都复制整个数组
  /// - 如果频繁调用,考虑复用 Native 内存
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

  /// ==================== 示例5: 结构体传递 ====================
  ///
  /// 原理:
  /// 1. C 函数返回 `Pointer<SystemInfo>`:
  ///    - C 端分配 SystemInfo 结构体 (24字节)
  ///    - 结构体内的字符串字段也在 Native 堆
  ///
  /// 2. `infoPtr.ref`:
  ///    - 解引用指针,访问结构体内容
  ///    - Dart 按照 SystemInfo 的定义读取内存
  ///    - 不复制数据,直接读 Native 内存
  ///
  /// 3. 访问嵌套指针:
  ///    - `info.platform` 是 `Pointer<Char>`
  ///    - `cast<Utf8>()` 转换为 `Pointer<Utf8>`
  ///    - `toDartString()` 复制字符串到 Dart 堆
  ///
  /// 4. 释放复杂结构体:
  ///    - nativeFreeSystemInfo(infoPtr) 必须由 C 端实现
  ///    - C 端需要依次释放:
  ///      a) info->platform 字符串
  ///      b) info->version 字符串
  ///      c) info 结构体本身
  ///
  /// 内存布局:
  /// [Native堆] SystemInfo 结构体 (24字节)
  ///   ├─ platform: 0x1000 → [Native堆] "macOS\0"
  ///   ├─ version:  0x2000 → [Native堆] "13.0\0"
  ///   └─ timestamp: 1234567890
  ///        ↓ toDartString() 复制
  /// [Dart堆] Map {
  ///   'platform': "macOS",
  ///   'version': "13.0",
  ///   'timestamp': 1234567890
  /// }
  ///        ↓ nativeFreeSystemInfo()
  /// [Native堆] 全部释放 (字符串 + 结构体)
  ///
  /// 关键: 多级指针结构必须由同一端(C)统一释放
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

/// ==================== 单例模式 ====================
///
/// final nativeFFI = NativeFFI():
/// - 全局变量,应用启动时不会立即执行
/// - 首次访问 nativeFFI 时才触发构造函数
/// - 构造函数执行时:
///   1. 加载动态库 (几百KB-几MB 内存)
///   2. 创建 7 个函数包装器 (< 1KB)
/// - 之后所有调用共享这些函数包装器
///
/// 性能特点:
/// - 延迟初始化 (Lazy Loading)
/// - 一次性开销
/// - 线程安全 (Dart 单线程保证)
final nativeFFI = NativeFFI();
