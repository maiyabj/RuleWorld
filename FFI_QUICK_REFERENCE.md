# Dart FFI 调用 Swift 快速参考

## 🚀 一分钟快速上手

### 1️⃣ Swift 端 (创建桥接函数)

```swift
// 文件: DeviceInfoBridge.swift

import Foundation

@_cdecl("device_get_name_swift")
public func device_get_name_swift() -> UnsafeMutablePointer<CChar>? {
    let manager = DeviveInfoManager()
    return strdup(manager.getDeviceName())  // ← 调用你的 Swift 方法
}

@_cdecl("device_free_string")
public func device_free_string(_ ptr: UnsafeMutablePointer<CChar>?) {
    free(ptr)  // ← 必须提供释放函数!
}
```

### 2️⃣ Dart 端 (FFI 绑定)

```dart
// 文件: device_info_ffi.dart

import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';

// 定义类型
typedef NativeGetStringFunc = ffi.Pointer<ffi.Char> Function();
typedef DartGetStringFunc = ffi.Pointer<ffi.Char> Function();

class DeviceInfoFFI {
  late final DartGetStringFunc _getNameSwift;
  late final DartFreeStringFunc _freeString;

  DeviceInfoFFI() {
    final dylib = ffi.DynamicLibrary.process();

    _getNameSwift = dylib
        .lookup<ffi.NativeFunction<NativeGetStringFunc>>('device_get_name_swift')
        .asFunction();

    _freeString = dylib
        .lookup<ffi.NativeFunction<NativeFreeStringFunc>>('device_free_string')
        .asFunction();
  }

  String getDeviceName() {
    ffi.Pointer<ffi.Char>? ptr;
    try {
      ptr = _getNameSwift();
      if (ptr.address == 0) return '';
      return ptr.cast<Utf8>().toDartString();
    } finally {
      if (ptr != null && ptr.address != 0) {
        _freeString(ptr);  // ← 释放内存
      }
    }
  }
}

final deviceInfoFFI = DeviceInfoFFI();
```

### 3️⃣ 使用

```dart
import 'package:magic_world_module/device_info_ffi.dart';

void main() {
  final name = deviceInfoFFI.getDeviceName();
  print('Device: $name');  // ✅ 成功调用 Swift 方法!
}
```

---

## 📊 数据流程图

```
┌─────────────────────────────────────────────────────┐
│ Dart: deviceInfoFFI.getDeviceName()                 │
└──────────────────┬──────────────────────────────────┘
                   │
                   │ 1. lookup("device_get_name_swift")
                   ↓
┌─────────────────────────────────────────────────────┐
│ C 桥接: device_get_name_swift()                     │
└──────────────────┬──────────────────────────────────┘
                   │
                   │ 2. 调用 Swift 方法
                   ↓
┌─────────────────────────────────────────────────────┐
│ Swift: DeviveInfoManager.getDeviceName()            │
│ 返回: "iPhone"                                      │
└──────────────────┬──────────────────────────────────┘
                   │
                   │ 3. strdup("iPhone") → C 堆内存
                   ↓
┌─────────────────────────────────────────────────────┐
│ C 堆: "iPhone\0" (地址: 0x12345678)                 │
└──────────────────┬──────────────────────────────────┘
                   │
                   │ 4. 返回指针
                   ↓
┌─────────────────────────────────────────────────────┐
│ Dart: Pointer<Char>(0x12345678)                     │
│       ↓ toDartString()                              │
│ Dart 堆: "iPhone"                                   │
└──────────────────┬──────────────────────────────────┘
                   │
                   │ 5. finally: _freeString(ptr)
                   ↓
┌─────────────────────────────────────────────────────┐
│ C 堆: [已释放]                                      │
└─────────────────────────────────────────────────────┘
```

---

## 🔑 关键点速查

| 问题 | 解决方案 |
|------|---------|
| **如何让 Dart 找到 Swift 函数?** | 使用 `@_cdecl("函数名")` 导出 C 符号 |
| **如何返回字符串?** | 使用 `strdup()` 在 C 堆分配内存 |
| **如何避免内存泄漏?** | 提供 `free()` 函数,在 Dart 端 `finally` 中调用 |
| **如何加载动态库?** | iOS/macOS 使用 `DynamicLibrary.process()` |
| **如何处理空指针?** | 检查 `ptr.address == 0` |
| **如何传递参数?** | Swift: `UnsafePointer<CChar>?`, Dart: `toNativeUtf8()` |

---

## ⚡ 完整示例对照表

### 无参数返回字符串

| Swift | Dart |
|-------|------|
| `@_cdecl("func_name")`<br>`func func_name() -> UnsafeMutablePointer<CChar>?` | `typedef Native = ffi.Pointer<ffi.Char> Function();`<br>`typedef Dart = ffi.Pointer<ffi.Char> Function();` |
| `return strdup("result")` | `final ptr = func(); return ptr.cast<Utf8>().toDartString();` |

### 带参数返回字符串

| Swift | Dart |
|-------|------|
| `@_cdecl("format_text")`<br>`func format_text(_ text: UnsafePointer<CChar>?) -> UnsafeMutablePointer<CChar>?` | `typedef Native = ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>);`<br>`typedef Dart = ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>);` |
| `let str = String(cString: text!)`<br>`return strdup(result)` | `final nativeStr = str.toNativeUtf8();`<br>`final ptr = func(nativeStr.cast());`<br>`malloc.free(nativeStr);` |

### 返回 JSON

| Swift | Dart |
|-------|------|
| `let dict = ["key": "value"]`<br>`let json = try! JSONSerialization.data(...)`<br>`let str = String(data: json, encoding: .utf8)!`<br>`return strdup(str)` | `import 'dart:convert';`<br>`final jsonStr = getJson();`<br>`final data = jsonDecode(jsonStr);` |

---

## 🛡️ 安全检查清单

在发布前检查:

- [ ] ✅ 所有 Swift 函数都有 `@_cdecl`
- [ ] ✅ 提供了 `free` 函数
- [ ] ✅ Dart 端使用 `try-finally` 释放内存
- [ ] ✅ 检查了空指针 (`ptr.address == 0`)
- [ ] ✅ 使用 UTF-8 编码 (`toNativeUtf8()` / `strdup`)
- [ ] ✅ 测试了中文/特殊字符
- [ ] ✅ 测试了边界情况 (空字符串、null)

---

## 🐛 调试技巧

### 1. 检查符号是否导出

```bash
# 查看 iOS 应用中的符号
nm -gU /path/to/YourApp.app/YourApp | grep device

# 应该看到:
# 0000000100001234 T _device_get_name_swift
# 0000000100001244 T _device_free_string
```

### 2. Dart 端打印调试

```dart
String getDeviceName() {
  print('🔍 调用 Swift 函数...');
  final ptr = _getNameSwift();
  print('📍 指针地址: ${ptr.address}');

  if (ptr.address == 0) {
    print('❌ 空指针!');
    return '';
  }

  final result = ptr.cast<Utf8>().toDartString();
  print('✅ 结果: $result');

  _freeString(ptr);
  print('🗑️ 内存已释放');

  return result;
}
```

### 3. Swift 端打印调试

```swift
@_cdecl("device_get_name_swift")
public func device_get_name_swift() -> UnsafeMutablePointer<CChar>? {
    print("🔍 Swift: 函数被调用")

    let manager = DeviveInfoManager()
    let name = manager.getDeviceName()
    print("📱 Swift: 设备名称 = \(name)")

    let ptr = strdup(name)
    print("📍 Swift: 指针地址 = \(String(describing: ptr))")

    return ptr
}
```

---

## 📚 已创建的文件

| 文件 | 说明 |
|------|------|
| `MagicWorld/MagicWorld/DeviceInfoBridge.swift` | Swift 桥接层,导出 C 函数 |
| `magic_world_module/lib/device_info_ffi.dart` | Dart FFI 封装,提供高级 API |
| `magic_world_module/lib/device_info_example.dart` | Flutter UI 示例页面 |
| `magic_world_module/lib/native_ffi.dart` | FFI 原理详细注释 (已有) |
| `SWIFT_FFI_GUIDE.md` | 完整实现指南 |
| `FFI_QUICK_REFERENCE.md` | 本文档 - 快速参考 |

---

## 🎯 下一步

### 集成到项目

1. **确保 Swift 文件被编译进项目**
   - 打开 Xcode
   - 检查 `DeviceInfoBridge.swift` 在 Target 中

2. **在 Flutter 中使用**
   ```dart
   import 'package:magic_world_module/device_info_ffi.dart';

   // 直接调用
   final name = deviceInfoFFI.getDeviceName();

   // 或使用示例页面
   Navigator.push(
     context,
     MaterialPageRoute(
       builder: (context) => const DeviceInfoExamplePage(),
     ),
   );
   ```

3. **扩展功能**
   - 参考 `DeviceInfoBridge.swift` 中的示例
   - 添加更多 `@_cdecl` 函数
   - 在 Dart 端添加对应的绑定

---

## ❓ 常见错误速查

| 错误信息 | 原因 | 解决 |
|---------|------|------|
| `Symbol not found: device_get_name_swift` | 没有 `@_cdecl` 或文件未编译 | 添加 `@_cdecl`,检查 Xcode Target |
| `Null pointer exception` | Swift 返回 nil | 检查 Swift 逻辑,Dart 检查 `ptr.address` |
| `Memory leak detected` | 忘记调用 `free` | 使用 `try-finally`,调用 `_freeString` |
| `Invalid UTF-8` | 编码问题 | 确保使用 `strdup` 和 `toDartString()` |

---

**💡 提示:** 保存这个文件作为快速参考,每次添加新的 FFI 调用时查阅!
