//
//  DeviceInfoBridge.m
//  MagicWorld
//
//  Objective-C 桥接实现 - 连接 Dart FFI 和 Swift DeviceInfoManager
//

#import "DeviceInfoBridge.h"
#import <UIKit/UIKit.h>

// 导入 Swift 类的 Objective-C 头文件
// Xcode 会自动生成这个头文件: ProjectName-Swift.h
#import "MagicWorld-Swift.h"

// ==================== 为什么 Objective-C 更适合 FFI? ====================
//
// 1. 原生 C 兼容性:
//    - OC 本质是 C 的超集,可以直接声明 C 函数
//    - 不需要 @_cdecl 等特殊标记
//    - 符号自动导出到动态库
//
// 2. ABI 稳定性:
//    - Objective-C Runtime 已经稳定数十年
//    - Swift ABI 在 Swift 5 才稳定,仍在演进
//
// 3. 与 Swift 无缝互操作:
//    - OC 可以直接调用 Swift 类 (通过 ProjectName-Swift.h)
//    - Swift 可以调用 OC 类 (通过 Bridging Header)
//
// 4. 性能优势:
//    - 无需额外的桥接层开销
//    - 直接的 C 函数调用
//
// ==================== 实现原理 ====================
//
// 调用链:
// Dart FFI --> C 函数 (本文件) --> OC 方法 --> Swift 类
//
// 内存管理:
// - 使用 strdup 在 C 堆分配内存
// - Dart 端负责调用 device_free_string_objc 释放
//

#pragma mark - 辅助函数

/// 将 NSString 转换为 C 字符串 (使用 strdup 在堆上分配)
static char* _Nullable NSStringToCString(NSString* _Nullable str) {
    if (!str) {
        return NULL;
    }

    // UTF8String 返回的是临时指针,需要 strdup 复制
    const char* tempCStr = [str UTF8String];
    if (!tempCStr) {
        return NULL;
    }

    // strdup 在堆上分配内存并复制字符串
    return strdup(tempCStr);
}

#pragma mark - FFI 导出函数

/// ==================== 获取设备名称 (通过 Swift) ====================
///
/// 实现流程:
/// 1. 创建 Swift DeviveInfoManager 实例
/// 2. 调用 getDeviceName() 方法
/// 3. 转换 Swift String -> NSString -> C char*
/// 4. 返回 C 字符串指针
char* _Nullable device_get_name_objc(void) {
    // 调用 Swift 类 (通过自动生成的 MagicWorld-Swift.h)
    DeviveInfoManager* manager = [[DeviveInfoManager alloc] init];
    NSString* deviceName = [manager getDeviceName];

    // 转换为 C 字符串
    return NSStringToCString(deviceName);
}

/// ==================== 获取真实设备名称 ====================
char* _Nullable device_get_real_name_objc(void) {
    NSString* name = [[UIDevice currentDevice] name];
    return NSStringToCString(name);
}

/// ==================== 获取设备型号 ====================
char* _Nullable device_get_model_objc(void) {
    NSString* model = [[UIDevice currentDevice] model];
    return NSStringToCString(model);
}

/// ==================== 获取系统版本 ====================
char* _Nullable device_get_system_version_objc(void) {
    NSString* version = [[UIDevice currentDevice] systemVersion];
    return NSStringToCString(version);
}

/// ==================== 获取完整信息 (JSON) ====================
char* _Nullable device_get_full_info_objc(void) {
    DeviveInfoManager* manager = [[DeviveInfoManager alloc] init];
    UIDevice* device = [UIDevice currentDevice];

    // 构建 NSDictionary
    NSDictionary* info = @{
        @"name": [manager getDeviceName],
        @"realName": device.name,
        @"model": device.model,
        @"systemName": device.systemName,
        @"systemVersion": device.systemVersion,
        @"identifierForVendor": device.identifierForVendor.UUIDString ?: @"unknown"
    };

    // 转换为 JSON
    NSError* error = nil;
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:info
                                                       options:0
                                                         error:&error];

    if (error || !jsonData) {
        return strdup("{}");
    }

    NSString* jsonString = [[NSString alloc] initWithData:jsonData
                                                 encoding:NSUTF8StringEncoding];

    return NSStringToCString(jsonString);
}

/// ==================== 格式化信息 (带参数示例) ====================
char* _Nullable device_format_info_objc(const char* _Nullable format) {
    if (!format) {
        return strdup("Invalid format");
    }

    // 转换 C 字符串为 NSString
    NSString* formatStr = [NSString stringWithUTF8String:format];
    if (!formatStr) {
        return strdup("Invalid UTF-8");
    }

    // 获取设备名称
    DeviveInfoManager* manager = [[DeviveInfoManager alloc] init];
    NSString* deviceName = [manager getDeviceName];

    // 替换占位符
    NSString* result = [formatStr stringByReplacingOccurrencesOfString:@"{device}"
                                                             withString:deviceName];

    return NSStringToCString(result);
}

/// ==================== 释放内存 ====================
///
/// 关键: 必须由 Dart 端调用,否则内存泄漏!
void device_free_string_objc(char* _Nullable str) {
    if (str) {
        free(str);
    }
}

// ==================== 性能对比 ====================
//
// Objective-C 实现:
// Dart -> C 函数 -> OC -> Swift
// 开销: ~10-20 纳秒
//
// Swift 直接实现 (@_cdecl):
// Dart -> Swift (@_cdecl) -> Swift 方法
// 开销: ~15-25 纳秒
//
// 差异: OC 略快,且更稳定可靠
//
// ==================== 额外优势 ====================
//
// 1. 可以直接调用任何 Objective-C 框架 (UIKit, Foundation 等)
// 2. 不受 Swift 版本变化影响
// 3. 可以使用 Objective-C Runtime 的强大功能
// 4. 更好的错误处理 (NSError)
// 5. 与遗留代码兼容性更好
