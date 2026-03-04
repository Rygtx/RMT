#include "RMT_OpenCv.h"
#include <opencv2/opencv.hpp>
#include <windows.h>

// 捕获屏幕指定区域的函数
cv::Mat captureScreen(int x, int y, int width, int height)
{
	HDC hDesktopDC = GetDC(NULL);
	HDC hCaptureDC = CreateCompatibleDC(hDesktopDC);
	HBITMAP hBitmap = CreateCompatibleBitmap(hDesktopDC, width, height);
	SelectObject(hCaptureDC, hBitmap);

	BitBlt(hCaptureDC, 0, 0, width, height, hDesktopDC, x, y, SRCCOPY | CAPTUREBLT);

	BITMAPINFOHEADER bi;
	bi.biSize = sizeof(BITMAPINFOHEADER);
	bi.biWidth = width;
	bi.biHeight = -height;  // 负值表示从上到下扫描
	bi.biPlanes = 1;
	bi.biBitCount = 32;
	bi.biCompression = BI_RGB;
	bi.biSizeImage = 0;
	bi.biXPelsPerMeter = 0;
	bi.biYPelsPerMeter = 0;
	bi.biClrUsed = 0;
	bi.biClrImportant = 0;

	cv::Mat mat(height, width, CV_8UC4);
	GetDIBits(hCaptureDC, hBitmap, 0, height, mat.data, (BITMAPINFO*)&bi, DIB_RGB_COLORS);

	DeleteObject(hBitmap);
	DeleteDC(hCaptureDC);
	ReleaseDC(NULL, hDesktopDC);
	cv::imwrite("screenshot.png", mat); //测试
	return mat;
}

cv::Mat captureScreen(int hwnd, int x, int y, int width, int height) {
	HWND targetHwnd = (HWND)hwnd;
	HDC hDesktopDC = NULL;
	HDC hCaptureDC = NULL;
	HBITMAP hBitmap = NULL;
	cv::Mat mat;

	// 获取桌面DC - 始终使用CreateDCA来获取真实的屏幕DC
	hDesktopDC = CreateDCA("DISPLAY", NULL, NULL, NULL);

	if (hDesktopDC == NULL) {
		return cv::Mat(); // 返回空Mat表示失败
	}

	// 如果没有指定宽高，使用屏幕尺寸
	if (width <= 0 || height <= 0) {
		width = ::GetDeviceCaps(hDesktopDC, HORZRES);
		height = ::GetDeviceCaps(hDesktopDC, VERTRES);
	}

	// 创建兼容DC和位图
	hCaptureDC = ::CreateCompatibleDC(hDesktopDC);
	hBitmap = ::CreateCompatibleBitmap(hDesktopDC, width, height);
	HBITMAP hOldBitmap = (HBITMAP)::SelectObject(hCaptureDC, hBitmap);

	// 判断是否为窗口句柄
	if (targetHwnd != NULL && targetHwnd != ::GetDesktopWindow()) {
		// 对于窗口，尝试使用PrintWindow
		BOOL bret = ::PrintWindow(targetHwnd, hCaptureDC, 0); // 使用0而不是PW_CLIENTONLY来捕获整个窗口

		if (!bret) {
			// 如果PrintWindow失败，需要特殊处理
			// 获取窗口位置和大小
			RECT windowRect;
			::GetWindowRect(targetHwnd, &windowRect);

			// 计算窗口在屏幕上的位置
			int windowX = windowRect.left;
			int windowY = windowRect.top;
			int windowWidth = windowRect.right - windowRect.left;
			int windowHeight = windowRect.bottom - windowRect.top;

			// 使用BitBlt从桌面DC复制窗口区域
			::BitBlt(hCaptureDC, 0, 0, windowWidth, windowHeight,
				hDesktopDC, windowX, windowY, SRCCOPY);
		}
	}
	else {
		// 桌面截图
		::BitBlt(hCaptureDC, 0, 0, width, height, hDesktopDC, x, y, SRCCOPY);
	}

	// 准备BITMAPINFO结构体
	BITMAPINFO bi = { 0 };
	bi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
	bi.bmiHeader.biWidth = width;
	bi.bmiHeader.biHeight = -height; // 负值表示从上到下存储，与OpenCV兼容
	bi.bmiHeader.biPlanes = 1;
	bi.bmiHeader.biBitCount = 32;     // 32位颜色，对应CV_8UC4
	bi.bmiHeader.biCompression = BI_RGB;
	bi.bmiHeader.biSizeImage = 0;

	// 创建OpenCV Mat (4通道，BGRA格式)
	mat = cv::Mat(height, width, CV_8UC4);

	// 获取位图数据到Mat
	if (::GetDIBits(hCaptureDC, hBitmap, 0, height, mat.data, &bi, DIB_RGB_COLORS) == 0) {
		// 如果获取失败，返回空Mat
		mat = cv::Mat();
	}

	// 清理资源
	::SelectObject(hCaptureDC, hOldBitmap);
	::DeleteObject(hBitmap);
	::DeleteDC(hCaptureDC);
	::DeleteDC(hDesktopDC); // 对于CreateDCA，使用DeleteDC

	// 测试：保存为PNG文件
	if (!mat.empty()) {
		cv::imwrite("screenshot.png", mat);
	}

	return mat;
}


// 计算两个矩形的交并比（IOU）
double computeIOU(const cv::Rect& rect1, const cv::Rect& rect2)
{
	// 计算交集区域
	cv::Rect intersection = rect1 & rect2;
	if (intersection.empty())
		return 0.0;

	double interArea = intersection.area();
	double unionArea = rect1.area() + rect2.area() - interArea;
	return interArea / unionArea;
}

// 非极大值抑制（NMS）算法
std::vector<cv::Rect> nonMaximumSuppression(const std::vector<cv::Rect>& rects,
	const std::vector<float>& scores,
	double scoreThreshold,
	double iouThreshold)
{
	std::vector<int> indices;
	for (int i = 0; i < scores.size(); ++i)
	{
		if (scores[i] >= scoreThreshold)
		{
			indices.push_back(i);
		}
	}

	// 按匹配分数降序排序
	std::sort(indices.begin(), indices.end(), [&](int a, int b) {
		return scores[a] > scores[b];
		});

	std::vector<bool> suppressed(indices.size(), false);
	std::vector<cv::Rect> selected;

	for (int i = 0; i < indices.size(); ++i)
	{
		if (suppressed[i])
			continue;

		int current = indices[i];
		selected.push_back(rects[current]);

		for (int j = i + 1; j < indices.size(); ++j)
		{
			if (suppressed[j])
				continue;

			int next = indices[j];
			if (computeIOU(rects[current], rects[next]) > iouThreshold)
			{
				suppressed[j] = true;
			}
		}
	}

	return selected;
}

extern "C" IMAGEFINDER_API int __cdecl FindImage(const char* targetPath,
	int searchX,
	int searchY,
	int searchW,
	int searchH,
	int matchThreshold,
	int* x,
	int* y)
{
	if (matchThreshold > 100)
		matchThreshold = 100;
	else if (matchThreshold < 0)
		matchThreshold = 0;
	// 匹配分数阈值
	double scoreThreshold = matchThreshold / 100.0;

	// 1. 加载模板图像
	cv::Mat templateImage = cv::imread(targetPath, cv::IMREAD_UNCHANGED);
	if (templateImage.empty())
	{
		std::cerr << "Could not open or find the template image." << std::endl;
		return 0;
	}

	// 截取屏幕区域
	cv::Mat capturedImage = captureScreen(searchX, searchY, searchW, searchH);
	if (capturedImage.empty())
	{
		std::cerr << "Failed to capture screen region." << std::endl;
		return 0;
	}

	// 2. 转换为灰度图（提高处理速度）
	cv::Mat grayLarge, graySmall;
	// 相似度98及其以上，不做灰度处理
	if (matchThreshold >= 98)
	{
		grayLarge = capturedImage;
		graySmall = templateImage;
	}
	else
	{
		cv::cvtColor(capturedImage, grayLarge, cv::COLOR_BGR2GRAY);
		cv::cvtColor(templateImage, graySmall, cv::COLOR_BGR2GRAY);
	}

	// 3. 模板匹配
	cv::Mat result;
	cv::matchTemplate(grayLarge, graySmall, result, cv::TM_CCOEFF_NORMED);

	// 4. 设置阈值并查找匹配位置
	// NMS重叠阈值
	const double nmsThreshold = 0.3;

	std::vector<cv::Rect> rects;
	std::vector<float> scores;

	// 遍历所有匹配结果
	for (int y = 0; y < result.rows; y++)
	{
		for (int x = 0; x < result.cols; x++)
		{
			float score = result.at<float>(y, x);
			if (score >= scoreThreshold)
			{
				rects.push_back(cv::Rect(x, y, templateImage.cols, templateImage.rows));
				scores.push_back(score);
			}
		}
	}

	// 5. 检查是否有匹配结果
	if (rects.empty())
	{
		std::cout << "no find" << std::endl;
		return 0;
	}

	// 6. 应用非极大值抑制
	std::vector<cv::Rect> selected = nonMaximumSuppression(rects, scores, scoreThreshold, nmsThreshold);

	// 7. 检查NMS后是否有结果
	if (selected.empty())
	{
		std::cout << "not find" << std::endl;
		return 0;
	}

	cv::Rect& rect = selected.front();
	// 计算模板在屏幕上的实际中心坐标
	cv::Point topLeft(rect.x + searchX, rect.y + searchY);
	cv::Point center(topLeft.x + templateImage.cols / 2, topLeft.y + templateImage.rows / 2);

	// 打印模板在屏幕上的中心坐标
	std::cout << "Template found at center coordinates: (" << center.x << ", " << center.y << ")" << std::endl;

	// 移动鼠标到模板中心位置
	// SetCursorPos(center.x, center.y);

	*x = static_cast<int>(topLeft.x);
	*y = static_cast<int>(topLeft.y);

	return 1;
}


// 暂时无用，因为后台截图一直是黑屏
extern "C" IMAGEFINDER_API int __cdecl FindWinAreaImage(
	const char* targetPath,
	int hwndInt,
	int searchX,
	int searchY,
	int searchW,
	int searchH,
	int matchThreshold,
	int* x,
	int* y)
{
	HWND hwnd = (HWND)(uintptr_t)hwndInt;

	if (matchThreshold > 100) matchThreshold = 100;
	else if (matchThreshold < 0) matchThreshold = 0;
	double scoreThreshold = matchThreshold / 100.0;

	// 1. 加载模板图像
	cv::Mat templateImage = cv::imread(targetPath, cv::IMREAD_UNCHANGED);
	if (templateImage.empty())
	{
		std::cerr << "Could not open or find the template image." << std::endl;
		return 0;
	}

	// 2. 截取窗口区域
	cv::Mat capturedImage = captureScreen(hwndInt, searchX, searchY, searchW, searchH);
	if (capturedImage.empty())
	{
		std::cerr << "Failed to capture window region." << std::endl;
		return 0;
	}

	// 3. 转灰度（非高分相似度）
	cv::Mat grayLarge, graySmall;
	if (matchThreshold >= 98)
	{
		grayLarge = capturedImage;
		graySmall = templateImage;
	}
	else
	{
		cv::cvtColor(capturedImage, grayLarge, cv::COLOR_BGR2GRAY);
		cv::cvtColor(templateImage, graySmall, cv::COLOR_BGR2GRAY);
	}

	// 4. 模板匹配
	cv::Mat result;
	cv::matchTemplate(grayLarge, graySmall, result, cv::TM_CCOEFF_NORMED);

	const double nmsThreshold = 0.3;
	std::vector<cv::Rect> rects;
	std::vector<float> scores;

	for (int yRow = 0; yRow < result.rows; yRow++)
	{
		for (int xCol = 0; xCol < result.cols; xCol++)
		{
			float score = result.at<float>(yRow, xCol);
			if (score >= scoreThreshold)
			{
				rects.push_back(cv::Rect(xCol, yRow, templateImage.cols, templateImage.rows));
				scores.push_back(score);
			}
		}
	}

	if (rects.empty()) return 0;

	std::vector<cv::Rect> selected = nonMaximumSuppression(rects, scores, scoreThreshold, nmsThreshold);
	if (selected.empty()) return 0;

	cv::Rect& rect = selected.front();
	cv::Point topLeft(rect.x + searchX, rect.y + searchY);
	*x = topLeft.x;
	*y = topLeft.y;

	return 1;
}

// 暂时无用，因为后台截图一直是黑屏
extern "C" IMAGEFINDER_API int __cdecl FindWinImage(
	const char* targetPath,
	int hwndInt,
	int matchThreshold,
	int* x,
	int* y)
{
	HWND hwnd = (HWND)(uintptr_t)hwndInt;

	RECT rc;
	GetClientRect(hwnd, &rc);
	int width = rc.right - rc.left;
	int height = rc.bottom - rc.top;

	// 直接调用 FindWinAreaImage 遍历整个窗口
	return FindWinAreaImage(
		targetPath,
		hwndInt,
		0, 0,
		width, height,
		matchThreshold,
		x, y
	);
}