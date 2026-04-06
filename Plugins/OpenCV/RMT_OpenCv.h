#pragma once
#ifdef IMAGEFINDER_EXPORTS
#define IMAGEFINDER_API __declspec(dllexport)
#else
#define IMAGEFINDER_API __declspec(dllimport)
#endif

extern "C" IMAGEFINDER_API void* __cdecl CaptureWinMat(     // 返回的Mat对象
    int hwnd,                   // 窗口句柄
    int x,                      // 捕获区域左上角X坐标
    int y,                      // 捕获区域左上角Y坐标
    int width,                  // 捕获区域宽度
    int height);                // 捕获区域高度     

// 释放 Mat
extern "C" IMAGEFINDER_API void __cdecl ReleaseMat(void* matPtr);

extern "C" IMAGEFINDER_API int __cdecl FindImage(
    const char* targetPath,     // 图片路径
    int searchX,                // 搜索区域左上角X坐标
    int searchY,                // 搜索区域左上角Y坐标
    int searchW,                // 搜索区域宽度
    int searchH,                // 搜索区域高度
    int matchThreshold,         // 匹配阈值
    int* x,                     // 匹配到的X坐标
    int* y);                    // 匹配到的Y坐标

extern "C" IMAGEFINDER_API int __cdecl FindWinImage(
    const char* targetPath,     // 图片路径
    int hwnd,                   // 窗口句柄
    int matchThreshold,         // 匹配阈值
    int* x,                     // 匹配到的X坐标
    int* y);                    // 匹配到的Y坐标

extern "C" IMAGEFINDER_API int __cdecl FindWinAreaImage(
    const char* targetPath,     // 图片路径
    int hwnd,                   // 窗口句柄
    int searchX,                // 搜索区域左上角X坐标
    int searchY,                // 搜索区域左上角Y坐标
    int searchW,                // 搜索区域宽度
    int searchH,                // 搜索区域高度
    int matchThreshold,         // 匹配阈值
    int* x,                     // 匹配到的X坐标
    int* y);                    // 匹配到的Y坐标