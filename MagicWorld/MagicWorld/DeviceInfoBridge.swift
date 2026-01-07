import Foundation
import UIKit

/// ==================== Swift 到 C 的桥接层 ====================
///
/// 原理:
/// Dart FFI 只能直接调用 C 函数,不能直接调用 Swift/Objective-C
/// 需要创建 C 函数作为"桥接层",在 C 函数内部调用 Swift 代码
///
/// 流程:
/// Dart -> C 函数 (FFI) -> Swift 方法 -> 返回给 C -> 返回给 Dart

// MARK: - C 桥接函数

/// @_cdecl 的作用:
/// 1. 告诉 Swift 编译器使用 C 调用约定 (C calling convention)
/// 2. 导出符号到动态库的符号表,使 Dart FFI 可以 lookup
/// 3. 防止 Swift 的名称修饰 (name mangling)
///
/// 如果不加 @_cdecl:
/// - Swift 会把函数名编译成类似 "_$s4Main20device_get_name_swiftSpys4Int8VGSgyF"
/// - Dart 无法通过 "device_get_name_swift" 找到这个函数

/// 获取设备名称 (返回 C 字符串指针)
///
/// 原理:
/// 1. Swift 创建字符串
/// 2. 转换为 UTF-8 C 字符串
/// 3. strdup 在堆上分配内存并复制
/// 4. 返回指针给 Dart
/// 5. Dart 使用完后必须调用 device_free_string 释放
@_cdecl("device_get_name_swift")
public func device_get_name_swift() -> UnsafeMutablePointer<CChar>? {
    // 创建 Swift 对象
    let manager = DeviveInfoManager()

    // 调用 Swift 方法获取设备名
    let deviceName = manager.getDeviceName()

    // 转换为 C 字符串
    // strdup: 在堆上分配内存,复制字符串,返回指针
    // 注意: 必须在 Dart 端手动释放这块内存!
    return strdup(deviceName)
}

/// 获取真实设备名称 (使用 UIDevice)
@_cdecl("device_get_real_name")
public func device_get_real_name() -> UnsafeMutablePointer<CChar>? {
    let deviceName = UIDevice.current.name
    return strdup(deviceName)
}

/// 获取设备型号 (如 "iPhone", "iPad")
@_cdecl("device_get_model")
public func device_get_model() -> UnsafeMutablePointer<CChar>? {
    let model = UIDevice.current.model
    return strdup(model)
}

/// 获取系统版本
@_cdecl("device_get_system_version")
public func device_get_system_version() -> UnsafeMutablePointer<CChar>? {
    let version = UIDevice.current.systemVersion
    return strdup(version)
}

/// 获取设备完整信息 (JSON 格式)
@_cdecl("device_get_full_info")
public func device_get_full_info() -> UnsafeMutablePointer<CChar>? {
    let manager = DeviveInfoManager()
    let device = UIDevice.current

    let info: [String: Any] = [
        "name": manager.getDeviceName(),
        "realName": device.name,
        "model": device.model,
        "systemName": device.systemName,
        "systemVersion": device.systemVersion,
        "identifierForVendor": device.identifierForVendor?.uuidString ?? "unknown"
    ]

    // 转换为 JSON
    if let jsonData = try? JSONSerialization.data(withJSONObject: info, options: []),
       let jsonString = String(data: jsonData, encoding: .utf8) {
        return strdup(jsonString)
    }

    return strdup("{}")
}

/// 释放 C 字符串内存
///
/// 原理:
/// 1. Dart 端调用完毕后,必须调用此函数释放内存
/// 2. free() 是 C 标准库函数,释放由 malloc/strdup 分配的内存
/// 3. 如果不释放会造成内存泄漏
@_cdecl("device_free_string")
public func device_free_string(_ ptr: UnsafeMutablePointer<CChar>?) {
    guard let ptr = ptr else { return }
    free(ptr)
}

// MARK: - 示例: 传递参数的桥接函数

/// 带参数的示例: 格式化设备信息
///
/// 原理:
/// 1. Dart 传递 C 字符串指针
/// 2. Swift 转换为 String
/// 3. 处理后返回新的 C 字符串
@_cdecl("device_format_info")
public func device_format_info(_ format: UnsafePointer<CChar>?) -> UnsafeMutablePointer<CChar>? {
    guard let format = format else {
        return strdup("Invalid format")
    }

    // 转换 C 字符串为 Swift String
    let formatString = String(cString: format)

    let manager = DeviveInfoManager()
    let deviceName = manager.getDeviceName()

    // 格式化输出
    let result = formatString.replacingOccurrences(of: "{device}", with: deviceName)

    return strdup(result)
}
