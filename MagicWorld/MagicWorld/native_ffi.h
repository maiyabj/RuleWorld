#ifndef NATIVE_FFI_H
#define NATIVE_FFI_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// 简单的加法函数
int32_t native_add(int32_t a, int32_t b);

// 字符串处理函数 - 返回字符串长度
int32_t native_string_length(const char* str);

// 获取问候语
const char* native_get_greeting(const char* name);

// 数组求和
int32_t native_sum_array(const int32_t* array, int32_t length);

// 释放字符串内存
void native_free_string(char* str);

// 获取系统信息
typedef struct {
    const char* platform;
    const char* version;
    int64_t timestamp;
} SystemInfo;

SystemInfo* native_get_system_info(void);
void native_free_system_info(SystemInfo* info);

#ifdef __cplusplus
}
#endif

#endif // NATIVE_FFI_H
