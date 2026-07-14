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
PRIV_REPO_HTTPS="https://github.com/ysysyxg/photographer-portfolio.git"

check_dependency() {
    if command -v "$1" &> /dev/null; then
        log_success "$1 已安装"
        return 0
    else
        log_error "$1 未安装"
        return 1
    fi
}

install_dependency() {
    if [ -f /etc/debian_version ]; then
        log_info "检测到 Debian/Ubuntu 系统"
        sudo apt update -y
        sudo apt install -y "$1"
    elif [ -f /etc/redhat-release ]; then
        log_info "检测到 CentOS/RHEL 系统"
        sudo yum install -y "$1"
    else
        log_error "不支持的操作系统"
        exit 1
    fi
}

echo ""
echo "========================================="
echo "  摄影师独立站 · 部署引导程序"
echo "========================================="
echo ""

echo ""
echo "┌─────────────────────────────────────────┐"
echo "│  前置准备清单                           │"
echo "├─────────────────────────────────────────┤"
echo "│  1. 已安装 MySQL 8.0+                   │"
echo "│  2. 已创建空白数据库（如：portfolio）   │"
echo "│  3. 已创建数据库用户（如：dbuser）      │"
echo "│  4. 已获取部署密钥（Deploy Key）        │"
echo "│  5. 服务器端口 3000/3001 已开放         │"
echo "└─────────────────────────────────────────┘"
echo ""

log_info "如何获取部署密钥（Deploy Key）："
log_info "  1. 联系开发者获取 SSH 私钥"
log_info "  2. 或在 GitHub 仓库 Settings → Deploy keys 添加您的公钥"
log_info "  3. 确保密钥具有仓库读取权限"
echo ""

log_info "如何创建空白数据库："
log_info "  MySQL 命令："
log_info "    CREATE DATABASE portfolio DEFAULT CHARACTER SET utf8mb4;"
log_info "    CREATE USER 'dbuser'@'localhost' IDENTIFIED BY 'your_password';"
log_info "    GRANT ALL PRIVILEGES ON portfolio.* TO 'dbuser'@'localhost';"
log_info "    FLUSH PRIVILEGES;"
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

log_info "正在检查系统环境..."

MISSING_DEPS=()

check_dependency "node" || MISSING_DEPS+=("nodejs")
check_dependency "npm" || MISSING_DEPS+=("npm")
check_dependency "git" || MISSING_DEPS+=("git")
check_dependency "mysql" || log_warn "MySQL 未安装，请确保已安装并创建空数据库"

if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    log_info "正在安装缺失的依赖: ${MISSING_DEPS[*]}"
    for dep in "${MISSING_DEPS[@]}"; do
        install_dependency "$dep"
    done
fi

log_info "正在检查 Node.js 版本..."
NODE_VERSION=$(node --version 2>/dev/null | cut -d'v' -f2 | cut -d'.' -f1)
if [ -z "$NODE_VERSION" ]; then
    log_error "Node.js 未安装或版本获取失败"
    exit 1
fi

if [ "$NODE_VERSION" -lt 20 ]; then
    log_warn "当前 Node.js 版本 v${NODE_VERSION}.x，推荐使用 v20.x LTS"
    log_info "是否升级 Node.js 到 v20.x？(y/n)"
    read -r UPGRADE_NODE
    if [ "$UPGRADE_NODE" = "y" ] || [ "$UPGRADE_NODE" = "Y" ]; then
        log_info "正在升级 Node.js..."
        curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash -
        sudo apt install -y nodejs
        log_success "Node.js 升级完成"
    fi
fi

echo ""
log_info "系统环境检查完成"
echo ""

log_info "请输入您的部署密钥（SSH私钥内容）："
log_info "如果您没有部署密钥，请联系开发者获取"
log_info "提示：私钥通常以 '-----BEGIN OPENSSH PRIVATE KEY-----' 或 '-----BEGIN RSA PRIVATE KEY-----' 开头"
log_info "请粘贴完整的私钥内容，输入完成后按 Ctrl+D 结束输入"
echo ""

DEPLOY_KEY=$(cat)

if [ -z "$DEPLOY_KEY" ]; then
    log_error "部署密钥不能为空"
    exit 1
fi

if ! echo "$DEPLOY_KEY" | grep -qE "BEGIN (RSA|OPENSSH) PRIVATE KEY"; then
    log_warn "私钥格式可能不正确，请确保粘贴的是完整的私钥文件内容"
    log_info "是否继续？(y/n)"
    read -r CONTINUE_KEY
    if [ "$CONTINUE_KEY" != "y" ] && [ "$CONTINUE_KEY" != "Y" ]; then
        log_info "退出部署"
        exit 0
    fi
fi

log_info "正在配置 SSH 密钥..."

mkdir -p ~/.ssh
chmod 700 ~/.ssh

echo "$DEPLOY_KEY" > ~/.ssh/id_rsa
chmod 600 ~/.ssh/id_rsa

log_info "正在配置 SSH 已知主机..."
ssh-keyscan -t rsa github.com >> ~/.ssh/known_hosts 2>/dev/null || true

log_info "正在测试 GitHub 连接..."
if ssh -T git@github.com 2>&1 | grep -q "ysysyxg"; then
    log_success "GitHub 连接成功"
else
    log_warn "SSH 连接失败，尝试使用 HTTPS 方式..."
    log_info "请输入您的 GitHub Personal Access Token（用于 HTTPS 方式）："
    echo -n "PAT："
    read -r GITHUB_TOKEN
    
    if [ -n "$GITHUB_TOKEN" ]; then
        PRIV_REPO_URL="https://${GITHUB_TOKEN}@github.com/ysysyxg/photographer-portfolio.git"
    else
        log_error "无法连接到私有仓库，请检查部署密钥或提供 GitHub PAT"
        exit 1
    fi
fi

echo ""
log_info "正在拉取核心代码..."

DEST_DIR="photographer-portfolio"
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
    "deploy/init.sh"
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
    log_warn "请检查私有仓库是否包含完整的构建产物"
    log_info "是否继续部署？(y/n)"
    read -r CONTINUE_DEPLOY
    if [ "$CONTINUE_DEPLOY" != "y" ] && [ "$CONTINUE_DEPLOY" != "Y" ]; then
        log_info "退出部署"
        exit 0
    fi
else
    log_success "代码完整性验证通过"
fi

echo ""
log_info "正在收集配置信息..."

log_info "请输入您的域名（如：example.com）："
read -r DOMAIN
while [ -z "$DOMAIN" ]; do
    log_error "域名不能为空"
    read -r DOMAIN
done

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

log_info "正在保存配置信息..."

cat > "$DEST_DIR/deploy/.deploy-config" <<EOF
DOMAIN=$DOMAIN
DB_TYPE=$DB_TYPE
DB_HOST=${DB_HOST:-localhost}
DB_PORT=${DB_PORT:-3306}
DB_NAME=${DB_NAME:-}
DB_USER=${DB_USER:-}
DB_PASSWORD=${DB_PASSWORD:-}
EOF

log_success "配置信息已保存"

echo ""
log_info "正在执行初始化..."

if [ -f "$DEST_DIR/deploy/init.sh" ]; then
    log_info "执行部署初始化脚本..."
    cd "$DEST_DIR"
    bash deploy/init.sh
else
    log_info "执行标准初始化..."
    
    log_info "复制环境变量配置..."
    cp server/.env.example server/.env
    
    log_info "修改环境变量配置..."
    log_info "请手动编辑 server/.env 文件，配置数据库连接信息"
    log_info "然后运行：npm run start"
    
    log_success "部署引导完成！"
    echo ""
    echo "========================================="
    echo "  下一步操作："
    echo "========================================="
    echo "  1. 编辑 server/.env 配置数据库"
    echo "  2. 运行 npm run start 启动服务"
    echo "  3. 访问 http://localhost:3001/setup 完成初始化"
    echo "========================================="
fi