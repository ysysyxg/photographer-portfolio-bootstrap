#!/usr/bin/env bash

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

fail() {
    log_error "$1"
    exit 1
}

PRIV_REPO_URL="git@github.com:ysysyxg/photographer-portfolio.git"
PROJECT_NAME="photographer-portfolio"
DB_TYPE="mysql"
DB_HOST="localhost"
DB_PORT="3306"

find_node_path() {
    local NODE_PATHS=(
        "/www/server/nodejs/v20*/bin"
        "/www/server/nodejs/v18*/bin"
        "/www/server/nodejs/latest/bin"
        "/usr/local/nodejs/bin"
        "/usr/local/bin"
        "/usr/bin"
    )

    for NODE_PATH in "${NODE_PATHS[@]}"; do
        if ls -d $NODE_PATH 2>/dev/null | head -n 1 | grep -q .; then
            local ACTUAL_PATH=$(ls -d $NODE_PATH 2>/dev/null | head -n 1)
            if [ -f "${ACTUAL_PATH}/node" ] && [ -f "${ACTUAL_PATH}/npm" ]; then
                export PATH="${ACTUAL_PATH}:$PATH"
                log_success "已自动配置 Node.js 路径: ${ACTUAL_PATH}"
                return 0
            fi
        fi
    done

    log_warn "未找到 Node.js 安装路径，正在自动安装..."

    if command -v apt &> /dev/null; then
        curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
        apt-get install -y nodejs
        log_success "Node.js 20.x 安装完成（apt）"
    elif command -v yum &> /dev/null; then
        curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
        yum install -y nodejs
        log_success "Node.js 20.x 安装完成（yum）"
    else
        log_error "无法自动安装 Node.js，请在宝塔面板软件商店中手动安装 Node.js 20.x LTS"
        return 1
    fi

    export PATH="/usr/bin:$PATH"
    if command -v node &> /dev/null; then
        local NODE_VERSION=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
        log_success "Node.js v${NODE_VERSION}.x 已安装"
        return 0
    else
        log_error "Node.js 安装后仍无法检测，请检查 PATH 环境变量"
        return 1
    fi
}

install_system_deps() {
    log_info "检测系统依赖..."
    
    local REQUIRED_SYSTEM_DEPS=(
        "git"
        "curl"
        "wget"
        "openssl"
    )

    local MISSING_SYSTEM_DEPS=()
    for dep in "${REQUIRED_SYSTEM_DEPS[@]}"; do
        if ! command -v $dep &> /dev/null; then
            MISSING_SYSTEM_DEPS+=("$dep")
        else
            log_success "系统依赖 $dep 已安装"
        fi
    done

    if [ ${#MISSING_SYSTEM_DEPS[@]} -gt 0 ]; then
        log_info "缺少系统依赖，正在安装: ${MISSING_SYSTEM_DEPS[*]}"
        if command -v apt &> /dev/null; then
            apt update -y && apt install -y "${MISSING_SYSTEM_DEPS[@]}"
        elif command -v yum &> /dev/null; then
            yum update -y && yum install -y "${MISSING_SYSTEM_DEPS[@]}"
        else
            fail "无法安装系统依赖，请手动安装: ${MISSING_SYSTEM_DEPS[*]}"
        fi
        log_success "系统依赖安装完成"
    fi
}

install_node_deps() {
    local PROJECT_DIR=$1
    local INSTALL_DIR=$2
    
    log_info "安装项目依赖..."

    if [ ! -d "${PROJECT_DIR}/${INSTALL_DIR}/node_modules" ]; then
        cd "${PROJECT_DIR}/${INSTALL_DIR}"
        log_info "正在安装 ${INSTALL_DIR} 依赖..."
        
        if [ -f "package-lock.json" ]; then
            npm ci --only=production 2>/dev/null || npm install --only=production
        else
            npm install --only=production
        fi
        
        if [ -d "node_modules" ]; then
            log_success "${INSTALL_DIR} 依赖安装完成"
        else
            log_error "${INSTALL_DIR} 依赖安装失败"
            return 1
        fi
    else
        log_success "${INSTALL_DIR} 依赖已存在，跳过安装"
    fi
    
    return 0
}

echo ""
echo "========================================================"
echo "  🎬 摄影师独立站 - 一键部署脚本"
echo "========================================================"
echo ""

log_info "请选择部署模式："
log_info "  1) 宝塔面板模式（推荐）- 服务器已安装宝塔面板，环境已配置"
log_info "  2) 全新服务器模式 - 从头安装所有依赖（需要 root 权限）"
read -r DEPLOY_MODE
DEPLOY_MODE=${DEPLOY_MODE:-1}

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

PROJECT_DIR="/www/wwwroot/${DOMAIN}"

log_success "部署信息收集完成"
log_success "域名：${DOMAIN}"
log_success "部署目录：${PROJECT_DIR}"
echo ""

if [ "$DEPLOY_MODE" = "2" ]; then
    log_info "========================================================"
    log_info "  模式2：全新服务器部署"
    log_info "========================================================"
    echo ""

    if [[ $EUID -ne 0 ]]; then
        fail "请使用 root 用户执行此脚本（全新服务器模式需要 root 权限）"
    fi

    log_info "步骤1/7: 更新系统并安装基础依赖..."
    apt update -y && apt upgrade -y
    apt install -y git curl wget nginx openssl
    log_success "系统更新完成"

    log_info "步骤2/7: 安装 Node.js 20.x LTS..."
    if command -v node >/dev/null 2>&1; then
        NODE_VERSION=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
        if [[ "${NODE_VERSION}" -ge 20 ]]; then
            log_success "Node.js v${NODE_VERSION} 已安装"
        else
            log_warn "当前 Node.js 版本 v${NODE_VERSION}，需要升级到 v20.x"
            curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
            apt-get install -y nodejs
            log_success "Node.js 20.x 安装完成"
        fi
    else
        curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
        apt-get install -y nodejs
        log_success "Node.js 20.x 安装完成"
    fi

    log_info "步骤3/7: 安装 PM2..."
    npm install -g pm2
    log_success "PM2 安装完成"

    log_info "步骤4/7: 配置 SSH 密钥..."

    mkdir -p /root/.ssh
    chmod 700 /root/.ssh

    if [[ ! -f /root/.ssh/id_ed25519 ]]; then
        ssh-keygen -t ed25519 -f /root/.ssh/id_ed25519 -N "" -C "server@${DOMAIN}"
        log_success "SSH 密钥生成完成"
    else
        log_success "SSH 密钥已存在"
    fi

    echo ""
    log_warn "============================================"
    log_warn "请将以下公钥添加到 GitHub Deploy Keys:"
    log_warn "仓库: https://github.com/ysysyxg/photographer-portfolio/settings/keys"
    log_warn "勾选: Allow write access"
    log_warn "============================================"
    cat /root/.ssh/id_ed25519.pub
    echo ""
    log_warn "============================================"

    read -p "公钥已添加到 GitHub 后，请按回车继续..."

    KEY_CHECK_DIR="/root/.ssh"
else
    log_info "========================================================"
    log_info "  模式1：宝塔面板部署"
    log_info "========================================================"
    echo ""

    echo ""
    echo "┌─────────────────────────────────────────┐"
    echo "│  前置准备清单（宝塔面板环境）            │"
    echo "├─────────────────────────────────────────┤"
    echo "│  1. 已安装宝塔面板                      │"
    echo "│  2. 已安装 Node.js 20.x LTS            │"
    echo "│  3. 已安装 MySQL 数据库                 │"
    echo "│  4. 已创建空白数据库（如：portfolio）   │"
    echo "│  5. 已创建数据库用户（如：dbuser）      │"
    echo "└─────────────────────────────────────────┘"
    echo ""

    log_info "如何创建数据库："
    log_info "  1. 登录宝塔面板 → 数据库 → 添加数据库"
    log_info "  2. 数据库名：portfolio（或自定义）"
    log_info "  3. 用户名：dbuser（或自定义）"
    log_info "  4. 设置密码并记录下来"
    echo ""

    log_info "步骤1/6: 生成 SSH 部署密钥..."

    mkdir -p ~/.ssh
    chmod 700 ~/.ssh

    if [[ ! -f ~/.ssh/id_ed25519 ]]; then
        ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N "" -C "deploy@${DOMAIN}"
        log_success "SSH 密钥生成完成"
    else
        log_warn "SSH 密钥已存在，是否重新生成？(y/n)"
        read -r REGEN_KEY
        if [ "$REGEN_KEY" = "y" ] || [ "$REGEN_KEY" = "Y" ]; then
            ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N "" -C "deploy@${DOMAIN}"
            log_success "SSH 密钥已重新生成"
        else
            log_success "使用现有 SSH 密钥"
        fi
    fi

    echo ""
    log_warn "============================================"
    log_warn "请将以下公钥添加到 GitHub Deploy Keys:"
    log_warn "仓库: https://github.com/ysysyxg/photographer-portfolio/settings/keys"
    log_warn "勾选: Allow write access"
    log_warn "============================================"
    cat ~/.ssh/id_ed25519.pub
    echo ""
    log_warn "============================================"

    read -p "公钥已添加到 GitHub 后，请按回车继续..."

    log_success "前置准备确认完成"
    echo ""

    log_info "步骤2/6: 检测系统依赖..."
    install_system_deps

    log_info "步骤3/6: 检测并配置 Node.js 路径..."
    find_node_path

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
        NPM_VERSION=$(npm --version)
        log_success "npm v${NPM_VERSION} 已安装"
    fi

    if ! command -v pm2 &> /dev/null; then
        log_warn "PM2 未安装，正在安装..."
        npm install -g pm2
        log_success "PM2 安装完成"
    else
        PM2_VERSION=$(pm2 --version)
        log_success "PM2 v${PM2_VERSION} 已安装"
    fi

    if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
        fail "缺少必要依赖: ${MISSING_DEPS[*]}，请在宝塔面板软件商店中安装"
    fi

    log_success "系统环境检查完成"
    echo ""

    KEY_CHECK_DIR="~/.ssh"
fi

log_info "步骤$(if [ "$DEPLOY_MODE" = "2" ]; then echo "5"; else echo "4"; fi)/$(if [ "$DEPLOY_MODE" = "2" ]; then echo "7"; else echo "6"; fi): 验证 SSH 密钥授权..."

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
    log_info "在终端执行以下命令生成新密钥："
    log_info "  ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N \"\""
    log_info "  cat ~/.ssh/id_ed25519.pub"
    exit 1
fi

log_info "正在验证私有库访问权限..."
if git ls-remote "$PRIV_REPO_URL" >/dev/null 2>&1; then
    log_success "私有库访问权限验证成功"
else
    fail "无法访问私有库，请确保 GitHub Deploy Key 已添加到仓库"
fi

echo ""
log_info "步骤$(if [ "$DEPLOY_MODE" = "2" ]; then echo "6"; else echo "5"; fi)/$(if [ "$DEPLOY_MODE" = "2" ]; then echo "7"; else echo "6"; fi): 拉取核心代码..."

mkdir -p /www/wwwroot
cd /www/wwwroot

if [ -d "$PROJECT_DIR" ]; then
    log_warn "目录 $PROJECT_DIR 已存在，是否覆盖？(y/n)"
    read -r OVERWRITE
    if [ "$OVERWRITE" = "y" ] || [ "$OVERWRITE" = "Y" ]; then
        rm -rf "$PROJECT_DIR"
    else
        log_info "退出部署"
        exit 0
    fi
fi

git clone "$PRIV_REPO_URL" "$DOMAIN"

if [ ! -d "$PROJECT_DIR" ]; then
    fail "代码拉取失败"
fi

log_success "核心代码拉取成功"

echo ""
log_info "正在验证代码完整性..."

cd "$PROJECT_DIR"

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
    fail "代码完整性验证失败，缺失 ${#MISSING_FILES[@]} 个关键文件，请联系开发者"
else
    log_success "代码完整性验证通过"
fi

log_info "步骤$(if [ "$DEPLOY_MODE" = "2" ]; then echo "6"; else echo "5"; fi)/$(if [ "$DEPLOY_MODE" = "2" ]; then echo "7"; else echo "6"; fi): 安装项目依赖..."

install_node_deps "$PROJECT_DIR" "server"
install_node_deps "$PROJECT_DIR" "web"

echo ""
log_info "正在收集数据库配置..."

if [ "$DEPLOY_MODE" = "2" ]; then
    if [[ -n "${DB_NAME}" && -n "${DB_USER}" && -n "${DB_PASSWORD}" ]]; then
        log_info "使用命令行参数配置数据库..."
    else
        read -p "数据库名称: " DB_NAME
        while [[ -z "${DB_NAME}" ]]; do
            log_error "数据库名称不能为空"
            read -p "数据库名称: " DB_NAME
        done

        read -p "数据库用户名: " DB_USER
        while [[ -z "${DB_USER}" ]]; do
            log_error "数据库用户名不能为空"
            read -p "数据库用户名: " DB_USER
        done

        echo "提示：密码输入时默认不显示，直接输入后按回车即可"
        read -s -p "数据库密码: " DB_PASSWORD
        echo ""
        while [[ -z "${DB_PASSWORD}" ]]; do
            log_error "数据库密码不能为空"
            read -s -p "数据库密码: " DB_PASSWORD
            echo ""
        done
    fi

    log_info "正在测试数据库连接..."
    if command -v mysql >/dev/null 2>&1; then
        if mysql -h"${DB_HOST}" -P"${DB_PORT}" -u"${DB_USER}" -p"${DB_PASSWORD}" -e "USE ${DB_NAME};" >/dev/null 2>&1; then
            log_success "数据库连接成功"
        else
            fail "数据库连接失败，请检查配置"
        fi
    else
        log_warn "未安装 mysql 客户端，跳过连接测试"
    fi

    cat > "${PROJECT_DIR}/server/.env" <<EOF
PORT=3000
HOST=0.0.0.0
NODE_ENV=production

DB_TYPE=${DB_TYPE}
DB_HOST=${DB_HOST:-localhost}
DB_PORT=${DB_PORT:-3306}
DB_NAME=${DB_NAME:-portfolio}
DB_USER=${DB_USER:-portfolio}
DB_PASSWORD=${DB_PASSWORD}

ADMIN_EMAIL=admin@${DOMAIN}

JWT_SECRET=$(openssl rand -hex 32)
JWT_EXPIRES_IN=7d

MAX_UPLOAD_SIZE=209715200
UPLOAD_DIR=./server/uploads

LOG_LEVEL=info
EOF

    log_success ".env 配置文件已创建"

    log_info "正在配置 Nginx 和 SSL..."
    bash "${PROJECT_DIR}/deploy/nginx-setup.sh" "${DOMAIN}" "3000"
    log_success "Nginx 配置完成"

    log_info "正在启动服务..."
    bash "${PROJECT_DIR}/deploy/restart.sh"

    sleep 3

    if pm2 status 2>/dev/null | grep -q "photographer-portfolio-api"; then
        log_success "服务启动成功"
    else
        log_warn "PM2 状态检查失败，请手动检查"
        log_warn "命令: pm2 status"
    fi
else
    log_info "请输入数据库类型（mysql/sqlite，默认：mysql）："
    read -r DB_TYPE_INPUT
    DB_TYPE=${DB_TYPE_INPUT:-mysql}

    if [ "$DB_TYPE" = "mysql" ]; then
        log_info "请输入数据库主机（默认：localhost）："
        read -r DB_HOST_INPUT
        DB_HOST=${DB_HOST_INPUT:-localhost}

        log_info "请输入数据库端口（默认：3306）："
        read -r DB_PORT_INPUT
        DB_PORT=${DB_PORT_INPUT:-3306}

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

    log_info "步骤6/6: 执行宝塔面板部署..."
    if [ -f "deploy/bt-deploy.sh" ]; then
        bash deploy/bt-deploy.sh "$DOMAIN" "$DB_NAME" "$DB_USER" "$DB_PASSWORD"
    else
        fail "宝塔面板部署脚本未找到，请联系开发者"
    fi
fi

echo ""
echo "========================================================"
echo "  🎉 部署完成！"
echo "========================================================"
echo ""
echo "数据库表结构会在服务首次启动时自动创建和迁移。"
echo ""
echo "请访问以下地址完成系统初始化配置："
echo ""
echo "  🚀 https://${DOMAIN}/setup"
echo ""
echo "初始化配置完成后，管理后台地址："
echo ""
echo "  🔐 https://${DOMAIN}/admin"
echo ""
echo "详细部署文档请参考: ${PROJECT_DIR}/deploy/DEPLOY.md"