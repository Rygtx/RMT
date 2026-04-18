using System;
using System.IO;
using System.Net.Http;

namespace RMT
{
    public class Http
    {
        public bool IsForbid()
        {
            string deviceId = Device.GetDeviceId();
            if (deviceId == "")
                return false;

            try
            {
                string Url = $"http://39.108.96.160:3000/blackkey?id={deviceId}";
                using (var httpClient = new HttpClient())
                {
                    var response = httpClient.GetAsync(Url).Result;
                    response.EnsureSuccessStatusCode();
                    string result = response.Content.ReadAsStringAsync().Result;
                    return result == "true";
                }
            }
            catch
            {
                return false;
            }
        }

        /// <summary>
        /// 同步上传文件到服务器
        /// </summary>
        /// <param name="filePath">要上传的本地文件路径</param>
        /// <param name="formDataName">表单字段名称，默认为"file"</param>
        /// <returns>上传结果消息</returns>
        public string UploadFile(string filePath)
        {
            string uploadUrl = "http://39.108.96.160:3000/upload";
            string formDataName = "file";
            string deviceId = Device.GetDeviceId();

            if (string.IsNullOrEmpty(filePath))
                return "文件路径不能为空";

            if (!File.Exists(filePath))
                return $"文件不存在: {filePath}";

            if (deviceId == "")
                return "信息不完整，请通过软件交流群共享上传配置";

            try
            {
                using (var httpClient = new HttpClient())
                using (var formData = new MultipartFormDataContent())
                using (var fileStream = File.OpenRead(filePath))
                {
                    // 创建文件内容
                    var fileContent = new StreamContent(fileStream);

                    // 获取文件名
                    string fileName = Path.GetFileName(filePath);

                    // 添加文件到表单数据
                    formData.Add(fileContent, formDataName, fileName);
                    formData.Add(new StringContent(deviceId), "deviceId");

                    // 发送POST请求
                    var response = httpClient.PostAsync(uploadUrl, formData).Result;

                    // 确保请求成功
                    response.EnsureSuccessStatusCode();

                    // 读取响应内容
                    string result = response.Content.ReadAsStringAsync().Result;
                    return result;
                }
            }
            catch (AggregateException ex)
            {
                throw new Exception($"网络请求失败: {ex.InnerException?.Message ?? ex.Message}", ex);
            }
            catch (Exception ex)
            {
                throw new Exception($"上传文件时发生错误: {ex.Message}", ex);
            }
        }
    }
}
