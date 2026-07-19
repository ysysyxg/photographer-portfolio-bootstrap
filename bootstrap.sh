#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

PRIV_REPO_URL="git@github.com:ysysyxg/photographer-portfolio.git"

echo ""
echo "========================================="
echo "  摄影师独立站 · 宝塔面板部署引导"
echo "========================================="
echo ""

echo ""
echo "┌─────────────────────────────────────────┐"
echo "│  前置准备清单（宝塔面板环境）            │"
echo "├─────────────────────────────────────────┤"
echo "│  1. 已安装宝塔面板                      │"
echo "│  2. 已安装 Node.js 20.x LTS            │"
echo "│  3. 已安装 PM2                         │"
echo "│  4. 已创建空白数据库（如：portfolio）   │"
echo "│  5. 已创建数据库用户（如：dbuser）      │"
echo "│  6. 已添加 SSH 公钥到 GitHub Deploy Keys│"
echo "└─────────────────────────────────────────┘"
echo ""

log_info "如何创建数据库："
log_info "  1. 登录宝塔面板 → 数据库 → 添加数据库"
log_info "  2. 数据库名：portfolio（或自定义）"
log_info "  3. 用户名：dbuser（或自定义）"
log_info "  4. 设置密码并记录下来"
echo ""

log_info "如何添加 SSH 公钥到 GitHub："
log_info "  1. 在宝塔面板终端执行：cat ~/.ssh/id_ed25519.pub"
log_info "  2. 复制公钥内容"
log_info "  3. 打开 https://github.com/ysysyxg/photographer-portfolio/settings/keys"
log_info "  4. 点击 Add deploy key，粘贴公钥，勾选 Allow write access"
echo ""

log_info "是否已完成以上前置准备？(y/n)"
read -r READY_CHECK

if [ "$READY_CHECK" != "y" ] && [ "$READY_CHECK" != "Y" ]; then
    log_info "请先完成前置准备，然后重新运行本脚本"
    log_info "部署引导程序退出"
    exit 0
fi

log_success "前置准备确认完成"
echo ""

log_info "正在收集部署信息..."

log_info "请输入要部署的域名（如：example.com）："
read -r DOMAIN
while [ -z "$DOMAIN" ] || ! echo "$DOMAIN" | grep -qE '^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*$'; do
    if [ -z "$DOMAIN" ]; then
        log_error "域名不能为空"
    else
        log_error "域名格式不正确: $DOMAIN"
        log_error "正确格式示例: example.com, xiaofan.live"
    fi
    read -r DOMAIN
done

log_success "部署信息收集完成"
log_success "域名：${DOMAIN}"
echo ""

log_info "正在检查系统环境..."

MISSING_DEPS=()

if ! command -v node &> /dev/null; then
    MISSING_DEPS+=("nodejs")
else
    NODE_VERSION=$(node --version 2>/dev/null | cut -d'v' -f2 | cut -d'.' -f1)
    if [ "$NODE_VERSION" -lt 20 ]; then
        log_warn "当前 Node.js 版本 v${NODE_VERSION}.x，推荐使用 v20.x LTS"
        log_info "请在宝塔面板软件商店中升级 Node.js"
    else
        log_success "Node.js v${NODE_VERSION}.x 已安装"
    fi
fi

if ! command -v npm &> /dev/null; then
    MISSING_DEPS+=("npm")
else
    log_success "npm 已安装"
fi

if ! command -v git &> /dev/null; then
    MISSING_DEPS+=("git")
else
    log_success "git 已安装"
fi

if ! command -v pm2 &> /dev/null; then
    log_warn "PM2 未安装，正在安装..."
    npm install -g pm2
    log_success "PM2 安装完成"
fi

if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    log_error "缺少必要依赖: ${MISSING_DEPS[*]}"
    log_info "请在宝塔面板软件商店中安装以上依赖"
    exit 1
fi

log_info "系统环境检查完成"
echo ""

log_info "正在验证 SSH 密钥授权..."

mkdir -p ~/.ssh
chmod 700 ~/.ssh

ssh-keyscan -t ed25519 github.com >> ~/.ssh/known_hosts 2>/dev/null || true

MAX_RETRIES=5
RETRY_DELAY=5
AUTH_SUCCESS=false

for ((i=1; i<=MAX_RETRIES; i++)); do
    if ssh -T git@github.com -o StrictHostKeyChecking=no 2>&1 | grep -q "successfully authenticated"; then
        log_success "SSH 密钥授权验证成功"
        AUTH_SUCCESS=true
        break
    fi
    if [ $i -lt $MAX_RETRIES ]; then
        log_warn "SSH 认证失败，第 ${i}/${MAX_RETRIES} 次尝试，等待 ${RETRY_DELAY} 秒后重试..."
        sleep $RETRY_DELAY
    fi
done

if [ "$AUTH_SUCCESS" = false ]; then
    log_error "SSH 密钥授权验证失败"
    log_info "请检查："
    log_info "  1. 服务器公钥是否已添加到 GitHub Deploy Keys"
    log_info "  2. 是否勾选了 Allow write access"
    log_info "  3. SSH 密钥是否设置了密码（本脚本不支持有密码的密钥）"
    log_info ""
    log_info "在宝塔面板终端执行以下命令生成新密钥："
    log_info "  ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N \"\""
    log_info "  cat ~/.ssh/id_ed25519.pub"
    exit 1
fi

log_info "正在验证私有库访问权限..."
if git ls-remote "$PRIV_REPO_URL" >/dev/null 2>&1; then
    log_success "私有库访问权限验证成功"
else
    log_error "无法访问私有库"
    log_info "请确保 GitHub Deploy Key 已添加到仓库："
    log_info "  https://github.com/ysysyxg/photographer-portfolio/settings/keys"
    exit 1
fi

echo ""
log_info "正在拉取核心代码..."

DEST_DIR="/www/wwwroot/${DOMAIN}"

if [ -d "$DEST_DIR" ]; then
    log_warn "目录 $DEST_DIR 已存在，是否覆盖？(y/n)"
    read -r OVERWRITE
    if [ "$OVERWRITE" = "y" ] || [ "$OVERWRITE" = "Y" ]; then
        rm -rf "$DEST_DIR"
    else
        log_info "退出部署"
        exit 0
    fi
fi

git clone "$PRIV_REPO_URL" "$DEST_DIR"

if [ ! -d "$DEST_DIR" ]; then
    log_error "代码拉取失败"
    exit 1
fi

log_success "核心代码拉取成功"

echo ""
log_info "正在验证代码完整性..."

cd "$DEST_DIR"

REQUIRED_FILES=(
    "server/dist/main.js"
    "web/.output/public/index.html"
    "version.json"
    "deploy/bt-deploy.sh"
)

MISSING_FILES=()

for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        MISSING_FILES+=("$file")
        log_error "缺失文件: $file"
    else
        log_success "验证通过: $file"
    fi
done

if [ ${#MISSING_FILES[@]} -gt 0 ]; then
    log_error "代码完整性验证失败，缺失 ${#MISSING_FILES[@]} 个关键文件"
    log_info "请联系开发者检查私有仓库"
    exit 1
else
    log_success "代码完整性验证通过"
fi

echo ""
log_info "正在收集数据库配置..."

log_info "请输入数据库类型（mysql/sqlite，默认：mysql）："
read -r DB_TYPE
DB_TYPE=${DB_TYPE:-mysql}

if [ "$DB_TYPE" = "mysql" ]; then
    log_info "请输入数据库主机（默认：localhost）："
    read -r DB_HOST
    DB_HOST=${DB_HOST:-localhost}

    log_info "请输入数据库端口（默认：3306）："
    read -r DB_PORT
    DB_PORT=${DB_PORT:-3306}

    log_info "请输入数据库名称："
    read -r DB_NAME
    while [ -z "$DB_NAME" ]; do
        log_error "数据库名称不能为空"
        read -r DB_NAME
    done

    log_info "请输入数据库用户名："
    read -r DB_USER
    while [ -z "$DB_USER" ]; do
        log_error "数据库用户名不能为空"
        read -r DB_USER
    done

    log_info "请输入数据库密码（输入时不显示）："
    read -s -r DB_PASSWORD
    echo ""
    while [ -z "$DB_PASSWORD" ]; do
        log_error "数据库密码不能为空"
        read -s -r DB_PASSWORD
        echo ""
    done
fi

echo ""
log_info "正在执行宝塔面板部署..."

if [ -f "deploy/bt-deploy.sh" ]; then
    bash deploy/bt-deploy.sh "$DOMAIN" "$DB_NAME" "$DB_USER" "$DB_PASSWORD"
else
    log_error "宝塔面板部署脚本未找到，请联系开发者"
    exit 1
fi

echo ""
echo "========================================="
echo "  🎉 部署完成！"
echo "========================================="
echo ""
echo "请访问以下地址完成系统初始化配置："
echo ""
echo "  🚀 https://${DOMAIN}/setup"
echo ""
echo "初始化配置完成后，管理后台地址："
echo ""
echo "  🔐 https://${DOMAIN}/admin"
echo ""
echo "详细文档请参考: ${DEST_DIR}/deploy/DEPLOY.md"