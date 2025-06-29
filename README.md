# ddns-go

wgethttps://raw.githubusercontent.com/474706852/ddns-go/refs/heads/main/ddns-go-install.sh
# 赋予执行权限
chmod +x ddns-go-install.sh
# 执行安装
sudo ./ddns-go-install.sh

我已经为您准备好了ddns-go的一键安装/更新/卸载脚本，该脚本具有以下特点：

1. 支持Ubuntu、Debian和CentOS系统
2. 自动识别系统架构（x86_64、arm64等）
3. 默认使用21360端口，端口自定义
4. 自动配置开机自启
5. 包含更新和卸载功能

脚本使用方法：
2. 更新ddns-go：
```bash
sudo ./ddns-go-install.sh update
```

3. 卸载ddns-go：
```bash
sudo ./ddns-go-install.sh uninstall
```

4. 服务管理：
```bash
# 启动服务
sudo systemctl start ddns-go
# 停止服务
sudo systemctl stop ddns-go
# 重启服务
sudo systemctl restart ddns-go
# 查看状态
sudo systemctl status ddns-go
```

安装完成后，您可以通过 http://服务器IP:21360 访问Web管理界面进行配置。

我已将完整脚本文件附在此消息中，您可以直接下载使用。如有任何问题，请随时告知。
