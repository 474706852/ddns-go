#!/bin/bash

# ddns-go 一键安装/更新/卸载脚本
# 支持系统: Ubuntu/Debian/CentOS
# 默认端口: 21360

# 颜色定义
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[36m"
PLAIN="\033[0m"

# 版本信息
VERSION="v6.9.3" # 默认版本，如果获取最新版本失败则使用此版本
PORT="21360" # 默认端口

# 获取最新版本号
get_latest_version() {
    echo -e "${BLUE}正在获取ddns-go最新版本号...${PLAIN}"
    LATEST_VERSION=$(curl -s https://api.github.com/repos/jeessy2/ddns-go/releases/latest | grep 'tag_name' | cut -d\" -f4)
    if [ -z "$LATEST_VERSION" ]; then
        echo -e "${YELLOW}获取最新版本失败，将使用默认版本: $VERSION${PLAIN}"
    else
        VERSION="$LATEST_VERSION"
        echo -e "${GREEN}获取到最新版本: $VERSION${PLAIN}"
    fi
}

# 获取用户自定义端口
get_custom_port() {
    read -p "请输入ddns-go服务监听端口 (默认: $PORT): " CUSTOM_PORT
    if [ -n "$CUSTOM_PORT" ]; then
        # 检查端口是否为数字
        if [[ $CUSTOM_PORT =~ ^[0-9]+$ ]]; then
            PORT="$CUSTOM_PORT"
            echo -e "${GREEN}将使用自定义端口: $PORT${PLAIN}"
        else
            echo -e "${RED}端口号无效，将使用默认端口: $PORT${PLAIN}"
        fi
    else
        echo -e "${YELLOW}未输入端口号，将使用默认端口: $PORT${PLAIN}"
    fi
}

# 检查是否为root用户
check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}错误: 必须使用root用户运行此脚本!${PLAIN}"
        exit 1
    fi
}

# 检查系统类型
check_sys() {
    # 检测是否为Linux系统
    if [[ $(uname -s) != Linux ]]; then
        echo -e "${RED}错误: 本脚本仅支持Linux系统!${PLAIN}"
        exit 1
    fi

    # 检测Linux发行版
    if [[ -f /etc/redhat-release ]]; then
        release="centos"
    elif cat /etc/issue | grep -q -E -i "debian"; then
        release="debian"
    elif cat /etc/issue | grep -q -E -i "ubuntu"; then
        release="ubuntu"
    elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
        release="centos"
    elif cat /proc/version | grep -q -E -i "debian"; then
        release="debian"
    elif cat /proc/version | grep -q -E -i "ubuntu"; then
        release="ubuntu"
    elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
        release="centos"
    else
        echo -e "${RED}未检测到系统版本，请联系脚本作者!${PLAIN}"
        exit 1
    fi

    # 检测系统架构
    arch=$(uname -m)
    case $arch in
        x86_64)
            arch="x86_64"
            ;;
        aarch64)
            arch="arm64"
            ;;
        armv7l)
            arch="armv7"
            ;;
        armv6l)
            arch="armv6"
            ;;
        armv5l)
            arch="armv5"
            ;;
        i686|i386)
            arch="i386"
            ;;
        *)
            echo -e "${RED}不支持的架构: $arch${PLAIN}"
            exit 1
            ;;
    esac

    echo -e "${GREEN}系统: $release, 架构: $arch${PLAIN}"
}

# 安装依赖
install_dependencies() {
    echo -e "${BLUE}正在安装依赖...${PLAIN}"
    
    if [[ $release == "centos" ]]; then
        yum install -y wget curl tar
    else
        apt-get update
        apt-get install -y wget curl tar
    fi
    
    echo -e "${GREEN}依赖安装完成${PLAIN}"
}

# 下载ddns-go
download_ddns() {
    echo -e "${BLUE}正在下载ddns-go $VERSION...${PLAIN}"
    
    # 创建临时目录
    TMP_DIR=$(mktemp -d)
    cd $TMP_DIR
    
    # 下载对应架构的文件
    BASE_URL="https://github.com/jeessy2/ddns-go/releases/download/$VERSION"
    DOWNLOAD_URL="$BASE_URL/ddns-go_${VERSION#v}_linux_$arch.tar.gz"
    echo -e "${YELLOW}下载链接: $DOWNLOAD_URL${PLAIN}"
    
    wget -q --show-progress $DOWNLOAD_URL -O ddns-go.tar.gz
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}下载失败，请检查网络或稍后再试${PLAIN}"
        rm -rf $TMP_DIR
        exit 1
    fi
    
    # 解压文件
    tar -zxf ddns-go.tar.gz
    
    # 检查是否解压成功
    if [ ! -f "ddns-go" ]; then
        echo -e "${RED}解压失败，请稍后再试${PLAIN}"
        rm -rf $TMP_DIR
        exit 1
    fi
    
    # 移动到/usr/local/bin/
    mv ddns-go /usr/local/bin/
    chmod +x /usr/local/bin/ddns-go
    
    # 清理临时文件
    cd - > /dev/null
    rm -rf $TMP_DIR
    
    echo -e "${GREEN}ddns-go下载完成${PLAIN}"
}

# 配置systemd服务
config_service() {
    echo -e "${BLUE}正在配置systemd服务...${PLAIN}"
    
    # 创建服务文件
    cat > /etc/systemd/system/ddns-go.service << EOF
[Unit]
Description=DDNS-GO Service
After=network.target
Wants=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/ddns-go -l :$PORT
Restart=on-failure
RestartSec=10
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
    
    # 重载systemd
    systemctl daemon-reload
    
    # 设置开机自启
    systemctl enable ddns-go
    
    echo -e "${GREEN}systemd服务配置完成${PLAIN}"
}

# 配置防火墙
config_firewall() {
    echo -e "${BLUE}正在配置防火墙...${PLAIN}"
    
    if [[ $release == "centos" ]]; then
        # 检查是否安装了firewalld
        if command -v firewall-cmd &> /dev/null; then
            firewall-cmd --permanent --add-port=$PORT/tcp
            firewall-cmd --reload
        # 检查是否安装了iptables
        elif command -v iptables &> /dev/null; then
            iptables -I INPUT -p tcp --dport $PORT -j ACCEPT
            if command -v iptables-save &> /dev/null; then
                iptables-save > /etc/sysconfig/iptables
            fi
        fi
    else
        # 检查是否安装了ufw
        if command -v ufw &> /dev/null; then
            ufw allow $PORT/tcp
        fi
    fi
    
    echo -e "${GREEN}防火墙配置完成${PLAIN}"
}

# 启动服务
start_service() {
    echo -e "${BLUE}正在启动ddns-go服务...${PLAIN}"
    
    systemctl start ddns-go
    
    # 检查服务状态
    sleep 2
    if systemctl is-active --quiet ddns-go; then
        echo -e "${GREEN}ddns-go服务启动成功${PLAIN}"
    else
        echo -e "${RED}ddns-go服务启动失败，请检查日志${PLAIN}"
        echo -e "${YELLOW}可以使用 systemctl status ddns-go 查看服务状态${PLAIN}"
    fi
}

# 显示安装信息
show_info() {
    echo -e "${GREEN}ddns-go安装成功!${PLAIN}"
    echo -e "${YELLOW}-------------------------------------${PLAIN}"
    echo -e "${YELLOW}版本: $VERSION${PLAIN}"
    echo -e "${YELLOW}Web管理界面: http://$(curl -s ifconfig.me):$PORT${PLAIN}"
    echo -e "${YELLOW}本机访问地址: http://127.0.0.1:$PORT${PLAIN}"
    echo -e "${YELLOW}-------------------------------------${PLAIN}"
    echo -e "${GREEN}使用方法:${PLAIN}"
    echo -e "${BLUE}启动: ${PLAIN}systemctl start ddns-go"
    echo -e "${BLUE}停止: ${PLAIN}systemctl stop ddns-go"
    echo -e "${BLUE}重启: ${PLAIN}systemctl restart ddns-go"
    echo -e "${BLUE}状态: ${PLAIN}systemctl status ddns-go"
    echo -e "${BLUE}卸载: ${PLAIN}bash $0 uninstall"
    echo -e "${BLUE}更新: ${PLAIN}bash $0 update"
    echo -e "${YELLOW}-------------------------------------${PLAIN}"
    echo -e "${GREEN}请访问Web管理界面进行配置${PLAIN}"
}

# 卸载ddns-go
uninstall() {
    echo -e "${YELLOW}正在卸载ddns-go...${PLAIN}"
    
    # 停止服务
    systemctl stop ddns-go
    
    # 禁用开机自启
    systemctl disable ddns-go
    
    # 删除服务文件
    rm -f /etc/systemd/system/ddns-go.service
    
    # 重载systemd
    systemctl daemon-reload
    
    # 删除二进制文件
    rm -f /usr/local/bin/ddns-go
    
    echo -e "${GREEN}ddns-go卸载完成${PLAIN}"
}

# 更新ddns-go
update() {
    echo -e "${YELLOW}正在更新ddns-go...${PLAIN}"
    
    # 停止服务
    systemctl stop ddns-go
    
    # 获取最新版本
    get_latest_version
    
    # 下载新版本
    download_ddns
    
    # 启动服务
    systemctl start ddns-go
    
    echo -e "${GREEN}ddns-go更新完成${PLAIN}"
    
    # 显示版本信息
    echo -e "${YELLOW}当前版本: $VERSION${PLAIN}"
    echo -e "${YELLOW}Web管理界面: http://$(curl -s ifconfig.me):$PORT${PLAIN}"
}

# 主函数
main() {
    case $1 in
        uninstall)
            check_root
            uninstall
            ;;
        update)
            check_root
            check_sys
            update
            ;;
        *)
            check_root
            check_sys
            install_dependencies
            get_latest_version # 在下载前获取最新版本
            get_custom_port # 在配置服务前获取自定义端口
            download_ddns
            config_service
            config_firewall
            start_service
            show_info
            ;;
    esac
}

# 执行主函数
main "$@"


