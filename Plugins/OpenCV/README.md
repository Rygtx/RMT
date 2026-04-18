###  编译OpenCV插件

1. 安装OpenCV Windows版本（推荐4.8.0）

2. 设置环境变量 OpenCV_DIR 指向OpenCV的build目录（例如：C:\opencv\build）

3. 将OpenCV的二进制目录（例如：C:\opencv\build\x64\vc16\bin）添加到系统PATH环境变量

### 编译项目环境设置

1. 创建新项目 搜索dll 选择动态链接库（dll） C++

2. 删除所有的头文件和源文件

3. 源文件 添加 现有项 RMT_OpenCv.cpp | 添加头文件 RMT_OpenCv.h

4. 项目 Debug 改成 Release  | x86 改成 x64
（如果忘记这一步，后续修改这个，下面的配置都需要重新配置）

5. （解决方案 和 RMT_OpenCv.cpp） 属性 C/C++ 预编译头 不使用预编译头

6. 属性 C/C++ 常规 附加包含目录 添加 D:\opencv\build\include（opencv的include目录）

7. 属性 链接器 常规 附加库目录 添加 D:\opencv\build\x64\vc16\lib（opencv的lib目录）

8. 属性 链接器 输入 附加依赖项 添加 opencv_world481.lib

9. 属性 C/C++ 预处理器 预处理器定义 添加 IMAGEFINDER_EXPORTS

10. 编译

### 不用visual studio（IDE）

1. 安装 Build Tools + C++ 桌面开发 (https://visualstudio.microsoft.com/zh-hans/visual-cpp-build-tools/)

2. 安装 「使用 C++ 的桌面开发」和 当前电脑对应的SDK

3. 执行buildDll.bat，完成后在 Plugins\OpenCV\build\Release 目录下会生成 RMT_OpenCv.dll