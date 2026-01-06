#include "native_ffi.h"
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include <stdio.h>

// 简单的加法函数
int32_t native_add(int32_t a, int32_t b) {
    return a + b;
}

// 字符串处理函数 - 返回字符串长度
int32_t native_string_length(const char* str) {
    if (str == NULL) {
        return 0;
    }
    return (int32_t)strlen(str);
}

// 获取问候语
const char* native_get_greeting(const char* name) {
    if (name == NULL) {
        name = "World";
    }

    // 动态分配内存
    size_t greeting_size = strlen("Hello, ") + strlen(name) + strlen("!") + 1;
    char* greeting = (char*)malloc(greeting_size);

    if (greeting != NULL) {
        snprintf(greeting, greeting_size, "Hello, %s!", name);
    }

    return greeting;
}

// 数组求和
int32_t native_sum_array(const int32_t* array, int32_t length) {
    if (array == NULL || length <= 0) {
        return 0;
    }

    int32_t sum = 0;
    for (int32_t i = 0; i < length; i++) {
        sum += array[i];
    }

    return sum;
}

// 释放字符串内存
void native_free_string(char* str) {
    if (str != NULL) {
        free(str);
    }
}

// 获取系统信息
SystemInfo* native_get_system_info(void) {
    SystemInfo* info = (SystemInfo*)malloc(sizeof(SystemInfo));
    if (info == NULL) {
        return NULL;
    }

    // 分配并设置平台信息
    char* platform = (char*)malloc(4);
    strcpy(platform, "iOS");
    info->platform = platform;

    // 分配并设置版本信息
    char* version = (char*)malloc(6);
    strcpy(version, "1.0.0");
    info->version = version;

    // 设置时间戳
    info->timestamp = (int64_t)time(NULL);

    return info;
}

void native_free_system_info(SystemInfo* info) {
    if (info != NULL) {
        if (info->platform != NULL) {
            free((void*)info->platform);
        }
        if (info->version != NULL) {
            free((void*)info->version);
        }
        free(info);
    }
}
