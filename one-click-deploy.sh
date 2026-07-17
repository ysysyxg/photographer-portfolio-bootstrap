#!/usr/bin/env bash
set -e

# =============================================================================
# 摄影师独立站 - 一键部署脚本
# 在全新的 Ubuntu 服务器上执行，自动完成所有部署步骤
#
# 使用方法：
#   bash <(curl -fsSL https://raw.githubusercontent.com/ysysyxg/photographer-portfolio-bootstrap/main/one-click-deploy.sh) <domain> <db_name> <db_user> <db_password>
#   或
#   bash deploy/one-click-deploy.sh your-domain.com
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] ✅ ${NC} $1"
}

fail() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ❌ ${NC} $1"
    exit 1
}

if [[ $EUID -ne 0 ]]; then
    echo "请使用 root 用户执行此脚本"
    echo "推荐命令：sudo -i 切换到 root，然后执行脚本"
    exit 1
fi

DOMAIN="${1:-}"
DB_NAME="${2:-}"
DB_USER="${3:-}"
DB_PASSWORD="${4:-}"
PROJECT_NAME="photographer-portfolio"
PROJECT_DIR="/www/wwwroot/${DOMAIN:-portfolio}"
BOOTSTRAP_REPO="https://github.com/ysysyxg/photographer-portfolio-bootstrap.git"

echo ""
echo "========================================================"
echo "  🎬 摄影师独立站 - 一键部署脚本"
echo "========================================================"
echo ""

if [[ -z "${DOMAIN}" ]]; then
    read -p "请输入您的域名（如：example.com）: " DOMAIN
    while [[ -z "${DOMAIN}" ]]; do
        error "域名不能为空"
        read -p "请输入您的域名（如：example.com）: " DOMAIN
    done
    PROJECT_DIR="/www/wwwroot/${DOMAIN}"
fi

log "部署域名: ${DOMAIN}"
log "部署目录: ${PROJECT_DIR}"
echo ""

log "步骤1/7: 更新系统并安装基础依赖..."
apt update -y && apt upgrade -y
apt install -y git curl wget nginx

success "系统更新完成"

log "步骤2/7: 安装 Node.js 20.x LTS..."
if command -v node >/dev/null 2>&1; then
    NODE_VERSION=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
    if [[ "${NODE_VERSION}" -ge 20 ]]; then
        success "Node.js v${NODE_VERSION} 已安装"
    else
        warn "当前 Node.js 版本 v${NODE_VERSION}，需要升级到 v20.x"
        curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
        apt-get install -y nodejs
        success "Node.js 20.x 安装完成"
    fi
else
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs
    success "Node.js 20.x 安装完成"
fi

log "步骤3/7: 安装 PM2..."
npm install -g pm2

success "PM2 安装完成"

log "步骤4/7: 配置 SSH 密钥并克隆代码..."

mkdir -p /root/.ssh
chmod 700 /root/.ssh

if [[ ! -f /root/.ssh/id_ed25519 ]]; then
    ssh-keygen -t ed25519 -f /root/.ssh/id_ed25519 -N "" -C "server@${DOMAIN}"
    success "SSH 密钥生成完成"
else
    success "SSH 密钥已存在"
fi

echo ""
warn "============================================"
warn "请将以下公钥添加到 GitHub Deploy Keys:"
warn "仓库: https://github.com/ysysyxg/photographer-portfolio/settings/keys"
warn "勾选: Allow write access"
warn "============================================"
cat /root/.ssh/id_ed25519.pub
echo ""
warn "============================================"

read -p "公钥已添加到 GitHub 后，请按回车继续..."

mkdir -p /www/wwwroot
cd /www/wwwroot

if [[ -d "${PROJECT_DIR}" ]]; then
    warn "目录 ${PROJECT_DIR} 已存在，将清理后重新克隆"
    rm -rf "${PROJECT_DIR}"
fi

git clone git@github.com:ysysyxg/${PROJECT_NAME}.git "${DOMAIN}"

success "代码克隆完成"

log "步骤5/7: 配置数据库..."

cd "${PROJECT_DIR}"

DB_TYPE="mysql"
DB_HOST="localhost"
DB_PORT="3306"

if [[ -n "${DB_NAME}" && -n "${DB_USER}" && -n "${DB_PASSWORD}" ]]; then
    log "使用命令行参数配置数据库..."
    log "数据库名称: ${DB_NAME}"
    log "数据库用户: ${DB_USER}"
else
    read -p "数据库名称: " DB_NAME
    while [[ -z "${DB_NAME}" ]]; do
        error "数据库名称不能为空"
        read -p "数据库名称: " DB_NAME
    done

    read -p "数据库用户名: " DB_USER
    while [[ -z "${DB_USER}" ]]; do
        error "数据库用户名不能为空"
        read -p "数据库用户名: " DB_USER
    done

    echo "提示：密码输入时默认不显示，直接输入后按回车即可"
    read -s -p "数据库密码: " DB_PASSWORD
    echo ""
    while [[ -z "${DB_PASSWORD}" ]]; do
        error "数据库密码不能为空"
        read -s -p "数据库密码: " DB_PASSWORD
        echo ""
    done
fi

log "正在测试数据库连接..."
if command -v mysql >/dev/null 2>&1; then
    if mysql -h"${DB_HOST}" -P"${DB_PORT}" -u"${DB_USER}" -p"${DB_PASSWORD}" -e "USE ${DB_NAME};" >/dev/null 2>&1; then
        success "数据库连接成功"
    else
        fail "数据库连接失败，请检查配置"
    fi
else
    warn "未安装 mysql 客户端，跳过连接测试"
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

success ".env 配置文件已创建"

log "步骤6/7: 配置 Nginx 和 SSL..."

bash "${PROJECT_DIR}/deploy/nginx-setup.sh" "${DOMAIN}" "3000"

success "Nginx 配置完成"

log "步骤7/7: 启动服务..."

bash "${PROJECT_DIR}/deploy/restart.sh"

sleep 3

if pm2 status 2>/dev/null | grep -q "photographer-portfolio-api"; then
    success "服务启动成功"
else
    warn "PM2 状态检查失败，请手动检查"
    warn "命令: pm2 status"
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