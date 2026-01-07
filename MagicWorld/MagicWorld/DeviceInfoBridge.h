//
//  DeviceInfoBridge.h
//  MagicWorld
//
//  FFI 桥接层头文件
//

#ifndef DeviceInfoBridge_h
#define DeviceInfoBridge_h

#import <Foundation/Foundation.h>

// ==================== C 函数声明 ====================
// 这些函数可以被 Dart FFI 直接调用

#ifdef __cplusplus
extern "C" {
#endif

/// 获取设备名称 (通过 Objective-C DeviceInfoManager)
///
/// 返回: C 字符串指针,需要调用 device_free_string 释放
char* _Nullable device_get_name_objc(void);

/// 获取真实设备名称
char* _Nullable device_get_real_name_objc(void);

/// 获取设备型号
char* _Nullable device_get_model_objc(void);

/// 获取系统版本
char* _Nullable device_get_system_version_objc(void);

/// 获取完整设备信息 (JSON 格式)
char* _Nullable device_get_full_info_objc(void);

/// 格式化设备信息
char* _Nullable device_format_info_objc(const char* _Nullable format);

/// 释放字符串内存
void device_free_string_objc(char* _Nullable str);

#ifdef __cplusplus
}
#endif

#endif /* DeviceInfoBridge_h */
