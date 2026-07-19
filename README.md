# 摄影师独立站 - 宝塔面板部署引导

> 这是摄影师独立站的公开引导仓库，用于在宝塔面板环境下部署项目。

## 📋 前置准备

在运行部署引导程序之前，请确保已完成以下准备工作：

### 1. 服务器要求

| 项目 | 要求 |
|------|------|
| 操作系统 | Ubuntu 20.04+ / CentOS 7+ |
| 宝塔面板 | 7.8+ |
| Node.js | v20.x LTS |
| PM2 | 全局安装 |
| Git | 最新版本 |

### 2. 在宝塔面板中安装必要软件

1. 登录宝塔面板 → **软件商店**
2. 安装 **Nginx**（已预装）
3. 安装 **MySQL 8.0+**（或使用 SQLite）
4. 安装 **Node.js 20.x LTS**
5. 通过终端安装 PM2：
   ```bash
   npm install -g pm2
   ```

### 3. 创建空白数据库

1. 登录宝塔面板 → **数据库** → **添加数据库**
2. 填写以下信息：
   - **数据库名**：`portfolio`（或自定义）
   - **用户名**：`dbuser`（或自定义）
   - **密码**：设置一个安全的密码并记录下来
3. 点击 **提交**

### 4. 配置 SSH 密钥

> 这是部署的关键步骤，用于拉取私有仓库代码。

#### 方法 A：生成新密钥（推荐）

1. 登录宝塔面板 → **终端**
2. 执行以下命令生成 SSH 密钥：
   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""
   cat ~/.ssh/id_ed25519.pub
   ```
3. 复制输出的公钥内容

#### 方法 B：使用已有密钥

如果服务器已有 SSH 密钥，直接查看公钥：
```bash
cat ~/.ssh/id_ed25519.pub
```

#### 添加公钥到 GitHub

1. 打开 [GitHub 私有仓库 Deploy Keys](https://github.com/ysysyxg/photographer-portfolio/settings/keys)
2. 点击 **Add deploy key**
3. **Title**：输入服务器标识（如 `server-xiaofan-live`）
4. **Key**：粘贴复制的公钥内容
5. **Allow write access**：勾选（需要推送升级）
6. 点击 **Add key**

### 5. 开放端口

在宝塔面板 **安全** 中确保开放以下端口：
- `80` / `443` - HTTP/HTTPS（宝塔默认开放）
- `3000` - 后端服务端口

## 🚀 一键部署

### 步骤 1：获取引导脚本

在宝塔面板终端中执行：

```bash
cd /www/wwwroot
git clone https://github.com/ysysyxg/photographer-portfolio-bootstrap.git
cd photographer-portfolio-bootstrap
```

### 步骤 2：运行部署引导

```bash
bash bootstrap.sh
```

### 步骤 3：按照提示操作

1. 确认前置准备已完成（输入 `y`）
2. 输入部署域名（如 `xiaofan.live`）
3. 等待环境检查和 SSH 密钥验证
4. 输入数据库配置信息
5. 等待部署完成

### 步骤 4：完成初始化

部署完成后，访问以下地址：

- **初始化配置**：`https://your-domain.com/setup`
- **管理后台**：`https://your-domain.com/admin`

## 🔧 手动部署（备用）

如果一键部署脚本出现问题，可以手动执行以下步骤：

### 1. 拉取核心代码

```bash
cd /www/wwwroot
git clone git@github.com:ysysyxg/photographer-portfolio.git your-domain.com
cd your-domain.com
```

### 2. 配置环境变量

```bash
cp server/.env.example server/.env
```

编辑 `server/.env` 文件：

```env
PORT=3000
HOST=0.0.0.0
NODE_ENV=production

DB_TYPE=mysql
DB_HOST=localhost
DB_PORT=3306
DB_NAME=portfolio
DB_USER=dbuser
DB_PASSWORD=your_password

ADMIN_EMAIL=admin@your-domain.com

JWT_SECRET=your-secret-key
JWT_EXPIRES_IN=7d

MAX_UPLOAD_SIZE=209715200
UPLOAD_DIR=./server/uploads

LOG_LEVEL=info
```

### 3. 配置 Nginx

在宝塔面板 → **网站** → **添加网站**

- **域名**：输入你的域名
- **根目录**：`/www/wwwroot/your-domain.com/web/.output/public`
- **PHP版本**：纯静态（不选 PHP）

添加反向代理配置：

```nginx
location /api/ {
    proxy_pass http://127.0.0.1:3000/api/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}

location /socket.io/ {
    proxy_pass http://127.0.0.1:3000/socket.io/;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
}
```

### 4. 启动后端服务

```bash
cd /www/wwwroot/your-domain.com/server
npm install --only=production
pm2 start dist/main.js --name photographer-portfolio-api
```

### 5. 保存 PM2 配置

```bash
pm2 save
pm2 startup
```

## 📝 更新升级

### 方式一：终端升级（推荐）

在宝塔面板终端中执行：

```bash
cd /www/wwwroot/your-domain.com
bash deploy/upgrade.sh
```

升级脚本会自动完成以下操作：
1. 创建回滚备份（数据库、上传目录、静态站点）
2. 拉取最新代码
3. 执行数据库迁移
4. 重启服务
5. 升级失败自动回滚

### 方式二：手动升级

```bash
cd /www/wwwroot/your-domain.com

# 创建备份
bash deploy/upgrade.sh backup

# 拉取最新代码
git pull origin main

# 执行数据库迁移
cd server
npx tsx src/database/migrate.ts

# 重启服务
pm2 restart photographer-portfolio-api
```

## 📁 仓库结构

```
photographer-portfolio-bootstrap/
├── bootstrap.sh           # 一键部署脚本（支持宝塔面板/全新服务器两种模式）
├── version.json           # 版本信息
├── README.md              # 部署说明
└── LICENSE                # 开源协议
```

## ❓ 常见问题

### Q1：SSH 密钥验证失败？

```bash
# 检查密钥是否存在
ls -la ~/.ssh/

# 检查密钥权限
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_ed25519

# 测试连接
ssh -T git@github.com -o StrictHostKeyChecking=no
```

### Q2：无法拉取私有仓库？

确保：
1. SSH 公钥已添加到 GitHub Deploy Keys
2. 已勾选 **Allow write access**
3. 使用的是 SSH 协议（`git@github.com:...`）而非 HTTPS

### Q3：后端服务启动失败？

```bash
# 查看 PM2 日志
pm2 logs photographer-portfolio-api

# 检查端口占用
lsof -i :3000

# 手动启动测试
cd server
node dist/main.js
```

### Q4：前端页面无法访问？

1. 检查 Nginx 配置是否正确
2. 检查前端构建产物是否存在：
   ```bash
   ls -la web/.output/public/
   ```
3. 检查 Nginx 日志：
   ```bash
   tail -f /www/wwwlogs/your-domain.com.log
   ```

### Q5：如何配置 SSL？

在宝塔面板 → **网站** → **SSL** → **Let's Encrypt** → **申请证书**

## 📞 联系我们

如有任何问题，请联系开发者。

## 📄 许可证

MIT License