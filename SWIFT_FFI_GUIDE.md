# Dart FFI 调用 Swift 方法完整指南

## 📋 目录
1. [核心原理](#核心原理)
2. [实现步骤](#实现步骤)
3. [完整示例](#完整示例)
4. [常见问题](#常见问题)

---

## 🎯 核心原理

### 为什么不能直接调用 Swift?

```
❌ 不可行:
Dart FFI ----X----> Swift 方法

✅ 正确方式:
Dart FFI --> C 桥接函数 --> Swift 方法
```

**原因:**
- Dart FFI 只支持 C ABI (Application Binary Interface)
- Swift 使用自己的调用约定和名称修饰 (name mangling)
- 需要 C 作为"翻译层"

### 完整调用链

```
┌─────────────────────────────────────────────────────────┐
│  Dart 层                                                 │
│  deviceInfoFFI.getDeviceName()                          │
└──────────────────┬──────────────────────────────────────┘
                   │ FFI 调用
                   ↓
┌─────────────────────────────────────────────────────────┐
│  C 桥接层 (Swift 文件中的 @_cdecl 函数)                  │
│  device_get_name_swift()                                │
└──────────────────┬──────────────────────────────────────┘
                   │ 直接调用
                   ↓
┌─────────────────────────────────────────────────────────┐
│  Swift 层                                                │
│  DeviveInfoManager.getDeviceName()                      │
└─────────────────────────────────────────────────────────┘
```

---

## 🛠️ 实现步骤

### 步骤 1: 创建 Swift 桥接文件

**文件:** `MagicWorld/MagicWorld/DeviceInfoBridge.swift`

```swift
import Foundation
import UIKit

/// 使用 @_cdecl 导出 C 函数
@_cdecl("device_get_name_swift")
public func device_get_name_swift() -> UnsafeMutablePointer<CChar>? {
    // 调用你的 Swift 类
    let manager = DeviveInfoManager()
    let deviceName = manager.getDeviceName()

    // 转换为 C 字符串 (在堆上分配内存)
    return strdup(deviceName)
}

/// 释放内存函数 (必须!)
@_cdecl("device_free_string")
public func device_free_string(_ ptr: UnsafeMutablePointer<CChar>?) {
    guard let ptr = ptr else { return }
    free(ptr)
}
```

**关键点:**
- `@_cdecl("函数名")`: 导出符号到动态库,Dart 可以 lookup
- `strdup()`: 在 C 堆分配内存并复制字符串
- 必须提供释放函数,否则内存泄漏!

### 步骤 2: 定义 Dart 函数签名

**文件:** `magic_world_module/lib/device_info_ffi.dart`

```dart
import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';

// 定义 C 函数签名
typedef NativeGetStringFunc = ffi.Pointer<ffi.Char> Function();
typedef DartGetStringFunc = ffi.Pointer<ffi.Char> Function();

typedef NativeFreeStringFunc = ffi.Void Function(ffi.Pointer<ffi.Char> ptr);
typedef DartFreeStringFunc = void Function(ffi.Pointer<ffi.Char> ptr);
```

### 步骤 3: 绑定函数

```dart
class DeviceInfoFFI {
  late final ffi.DynamicLibrary _dylib;
  late final DartGetStringFunc _deviceGetNameSwift;
  late final DartFreeStringFunc _deviceFreeString;

  DeviceInfoFFI() {
    // iOS/macOS 使用 process() 加载主程序符号
    _dylib = ffi.DynamicLibrary.process();

    // lookup 查找符号
    _deviceGetNameSwift = _dylib
        .lookup<ffi.NativeFunction<NativeGetStringFunc>>(
            'device_get_name_swift')
        .asFunction();

    _deviceFreeString = _dylib
        .lookup<ffi.NativeFunction<NativeFreeStringFunc>>(
            'device_free_string')
        .asFunction();
  }
}
```

### 步骤 4: 创建高级 API

```dart
String getDeviceName() {
  ffi.Pointer<ffi.Char>? ptr;

  try {
    // 1. 调用 Swift 函数
    ptr = _deviceGetNameSwift();

    // 2. 检查指针有效性
    if (ptr.address == 0) {
      return '';
    }

    // 3. 转换为 Dart String (复制数据)
    return ptr.cast<Utf8>().toDartString();
  } finally {
    // 4. 释放 Swift 分配的内存
    if (ptr != null && ptr.address != 0) {
      _deviceFreeString(ptr);
    }
  }
}
```

---

## 💡 完整示例

### Swift 端实现

```swift
// DeviceInfoBridge.swift

import Foundation
import UIKit

// ===== 简单示例: 返回字符串 =====
@_cdecl("device_get_name_swift")
public func device_get_name_swift() -> UnsafeMutablePointer<CChar>? {
    let manager = DeviveInfoManager()
    return strdup(manager.getDeviceName())
}

// ===== 带参数示例 =====
@_cdecl("device_format_info")
public func device_format_info(_ format: UnsafePointer<CChar>?) -> UnsafeMutablePointer<CChar>? {
    guard let format = format else {
        return strdup("Invalid format")
    }

    let formatString = String(cString: format)
    let manager = DeviveInfoManager()
    let result = formatString.replacingOccurrences(of: "{device}",
                                                    with: manager.getDeviceName())
    return strdup(result)
}

// ===== 返回 JSON 示例 =====
@_cdecl("device_get_full_info")
public func device_get_full_info() -> UnsafeMutablePointer<CChar>? {
    let info: [String: Any] = [
        "name": UIDevice.current.name,
        "model": UIDevice.current.model,
        "version": UIDevice.current.systemVersion
    ]

    if let jsonData = try? JSONSerialization.data(withJSONObject: info),
       let jsonString = String(data: jsonData, encoding: .utf8) {
        return strdup(jsonString)
    }

    return strdup("{}")
}

// ===== 必须: 释放内存 =====
@_cdecl("device_free_string")
public func device_free_string(_ ptr: UnsafeMutablePointer<CChar>?) {
    guard let ptr = ptr else { return }
    free(ptr)
}
```

### Dart 端使用

```dart
// main.dart

import 'package:magic_world_module/device_info_ffi.dart';

void main() {
  // 调用 Swift 的 DeviceInfoManager.getDeviceName()
  final name = deviceInfoFFI.getDeviceName();
  print('Device name: $name');  // 输出: Device name: iPhone

  // 获取真实设备名称
  final realName = deviceInfoFFI.getRealDeviceName();
  print('Real name: $realName');  // 输出: Real name: 张三的 iPhone

  // 获取完整信息 (JSON)
  final info = deviceInfoFFI.getFullDeviceInfo();
  print('Full info: $info');
  // 输出: Full info: {"name":"张三的 iPhone","model":"iPhone","version":"17.0"}

  // 格式化信息
  final formatted = deviceInfoFFI.formatDeviceInfo("当前设备: {device}");
  print(formatted);  // 输出: 当前设备: iPhone
}
```

---

## 🔍 内存管理详解

### 内存流程图

```
步骤 1: Swift 创建字符串
┌──────────────────┐
│ Swift 堆         │
│ "iPhone"         │
└──────────────────┘

步骤 2: strdup 复制到 C 堆
         ↓
┌──────────────────┐
│ C 堆 (malloc)    │
│ "iPhone\0"       │  ← 指针地址: 0x12345678
└──────────────────┘

步骤 3: 返回指针给 Dart
         ↓
┌──────────────────┐
│ Dart             │
│ Pointer(0x12345678) │
└──────────────────┘

步骤 4: toDartString() 复制到 Dart 堆
         ↓
┌──────────────────┐
│ Dart 堆 (GC管理) │
│ "iPhone"         │
└──────────────────┘

步骤 5: 释放 C 堆内存
         ↓
┌──────────────────┐
│ C 堆             │
│ [已释放]         │  ← free(0x12345678)
└──────────────────┘
```

### 关键点

1. **Swift 端**: 使用 `strdup()` 分配内存
2. **Dart 端**: 使用 `toDartString()` 复制数据
3. **清理**: 必须调用 `device_free_string()` 释放 C 堆内存
4. **安全**: 使用 `try-finally` 确保内存总是被释放

---

## ⚠️ 常见问题

### 1. 找不到符号 (Symbol not found)

**错误:**
```
[ERROR] Failed to lookup symbol 'device_get_name_swift'
```

**原因:**
- 忘记添加 `@_cdecl("函数名")`
- 函数名拼写错误
- Swift 文件没有被编译进项目

**解决:**
```swift
// ❌ 错误: 没有 @_cdecl
public func device_get_name_swift() -> UnsafeMutablePointer<CChar>? {
    ...
}

// ✅ 正确
@_cdecl("device_get_name_swift")
public func device_get_name_swift() -> UnsafeMutablePointer<CChar>? {
    ...
}
```

### 2. 内存泄漏

**问题:**
```dart
// ❌ 错误: 没有释放内存
String getDeviceName() {
  final ptr = _deviceGetNameSwift();
  return ptr.cast<Utf8>().toDartString();
  // 内存泄漏! C 堆的字符串永远不会被释放
}

// ✅ 正确
String getDeviceName() {
  ffi.Pointer<ffi.Char>? ptr;
  try {
    ptr = _deviceGetNameSwift();
    return ptr.cast<Utf8>().toDartString();
  } finally {
    if (ptr != null && ptr.address != 0) {
      _deviceFreeString(ptr);  // 释放内存
    }
  }
}
```

### 3. 空指针崩溃

**问题:**
```dart
// ❌ 危险: 没有检查空指针
String getDeviceName() {
  final ptr = _deviceGetNameSwift();
  return ptr.cast<Utf8>().toDartString();  // 如果 ptr 为 null 会崩溃
}

// ✅ 安全
String getDeviceName() {
  final ptr = _deviceGetNameSwift();
  if (ptr.address == 0) {  // 检查指针有效性
    return '';
  }
  return ptr.cast<Utf8>().toDartString();
}
```

### 4. 字符编码问题

**问题:** 中文或特殊字符显示乱码

**解决:**
```swift
// ✅ 确保使用 UTF-8 编码
@_cdecl("device_get_name")
public func device_get_name() -> UnsafeMutablePointer<CChar>? {
    let name = "张三的 iPhone"
    // strdup 会保持 UTF-8 编码
    return strdup(name)
}
```

```dart
// ✅ Dart 端使用 Utf8 解码
final str = ptr.cast<Utf8>().toDartString();
```

---

## 🎓 进阶主题

### 传递复杂数据结构

**Swift 端:**
```swift
struct DeviceInfo {
    let name: String
    let model: String
    let version: String
}

@_cdecl("device_get_info_json")
public func device_get_info_json() -> UnsafeMutablePointer<CChar>? {
    let info = DeviceInfo(
        name: UIDevice.current.name,
        model: UIDevice.current.model,
        version: UIDevice.current.systemVersion
    )

    let dict: [String: String] = [
        "name": info.name,
        "model": info.model,
        "version": info.version
    ]

    if let jsonData = try? JSONSerialization.data(withJSONObject: dict),
       let jsonString = String(data: jsonData, encoding: .utf8) {
        return strdup(jsonString)
    }

    return strdup("{}")
}
```

**Dart 端:**
```dart
import 'dart:convert';

Map<String, dynamic> getDeviceInfo() {
  final jsonStr = _getStringFromNative(_deviceGetInfoJson);
  return jsonDecode(jsonStr) as Map<String, dynamic>;
}

// 使用
final info = deviceInfoFFI.getDeviceInfo();
print(info['name']);     // 张三的 iPhone
print(info['model']);    // iPhone
print(info['version']);  // 17.0
```

### 异步调用

**Swift 端:**
```swift
@_cdecl("device_get_name_async")
public func device_get_name_async(callback: @escaping @convention(c) (UnsafeMutablePointer<CChar>?) -> Void) {
    DispatchQueue.main.async {
        let manager = DeviveInfoManager()
        let name = strdup(manager.getDeviceName())
        callback(name)
    }
}
```

**Dart 端:**
```dart
// 需要使用 NativeCallable (Dart 2.18+)
// 这是高级主题,通常用同步调用即可
```

---

## 📝 总结

### 核心要点

1. **@_cdecl**: Swift 导出 C 符号的关键
2. **strdup**: 在 C 堆分配内存
3. **lookup + asFunction**: Dart 查找并绑定函数
4. **toDartString**: 复制到 Dart 堆
5. **释放函数**: 必须提供,避免内存泄漏
6. **try-finally**: 确保内存安全

### 性能考虑

- **开销**: 每次调用需要复制字符串 (Dart ↔ C ↔ Swift)
- **优化**: 如果频繁调用,考虑缓存结果
- **替代**: 对于简单场景,可以使用 MethodChannel (但性能较低)

### 何时使用 FFI vs MethodChannel

**使用 FFI:**
- ✅ 需要高性能
- ✅ 频繁调用
- ✅ 已有 C/C++ 库
- ✅ 同步调用

**使用 MethodChannel:**
- ✅ 简单调用
- ✅ 异步操作
- ✅ 不关心性能
- ✅ 需要跨平台统一 API

---

## 🔗 相关文件

- **Swift 桥接层**: `MagicWorld/MagicWorld/DeviceInfoBridge.swift`
- **Dart FFI 封装**: `magic_world_module/lib/device_info_ffi.dart`
- **原始 Swift 类**: `MagicWorld/MagicWorld/DeviceInfoManager.swift`
- **FFI 原理说明**: `magic_world_module/lib/native_ffi.dart`

---

**祝你成功调用 Swift 方法! 🎉**
