# 摄影师独立站 - 部署引导程序

> 这是摄影师独立站的公开引导仓库，任何人都可以获取并运行部署引导脚本。

## 📋 前置准备

在运行部署引导程序之前，请确保已完成以下准备工作：

### 1. 创建空白数据库

```bash
# 登录 MySQL
mysql -u root -p

# 创建数据库
CREATE DATABASE portfolio DEFAULT CHARACTER SET utf8mb4;

# 创建数据库用户
CREATE USER 'dbuser'@'localhost' IDENTIFIED BY 'your_password';

# 授予权限
GRANT ALL PRIVILEGES ON portfolio.* TO 'dbuser'@'localhost';
FLUSH PRIVILEGES;
```

### 2. 获取部署密钥（Deploy Key）

**方法 A：联系开发者获取**
- 联系开发者获取 SSH 私钥

**方法 B：自行添加公钥到 GitHub**
1. 在本地生成 SSH 密钥：
   ```bash
   ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
   ```
2. 复制公钥：
   ```bash
   cat ~/.ssh/id_rsa.pub
   ```
3. 打开 GitHub 私有仓库 → Settings → Deploy keys
4. 点击 Add deploy key
5. 粘贴公钥，勾选 Allow write access（仅读取不需要）
6. 点击 Add key

### 3. 开放端口

确保服务器已开放以下端口：
- `3000` - 后端服务端口
- `3001` - 前端开发端口
- `80/443` - HTTP/HTTPS 端口

### 4. 安装基础依赖

```bash
# Ubuntu/Debian
sudo apt update && sudo apt install -y nodejs npm git mysql-server

# CentOS/RHEL
sudo yum install -y nodejs npm git mysql-server
```

## 🚀 快速开始

### 步骤 1：获取引导脚本

```bash
git clone https://github.com/ysysyxg/photographer-portfolio-bootstrap.git
cd photographer-portfolio-bootstrap
```

### 步骤 2：运行引导程序

```bash
bash bootstrap.sh
```

### 步骤 3：输入部署密钥

引导程序会提示您输入部署密钥（Deploy Key）。如果您没有部署密钥，请联系开发者获取。

## 📋 系统要求

| 依赖 | 版本 |
|------|------|
| Node.js | v20.x LTS（推荐） |
| npm | v10+ |
| Git | 最新版本 |
| MySQL | v8.0+（或 SQLite） |

## 🔧 部署流程

```
1. 获取引导脚本（公开仓库，无需密钥）
       ↓
2. 运行 bootstrap.sh
       ↓
3. 环境检查（Node.js、npm、Git）
       ↓
4. 输入部署密钥（Deploy Key）
       ↓
5. 验证密钥 → 拉取私有仓库
       ↓
6. 执行初始化引导（/setup）
       ↓
7. 进入系统后验证授权
```

## 📁 仓库结构

```
photographer-portfolio-bootstrap/
├── bootstrap.sh      # 部署引导脚本
├── README.md         # 部署说明
└── LICENSE           # 开源协议
```

## ❓ 常见问题

### Q1：什么是部署密钥？

部署密钥（Deploy Key）是 GitHub 仓库的 SSH 密钥，用于验证您有权限拉取私有仓库的代码。

### Q2：如何获取部署密钥？

联系开发者获取部署密钥，或者在 GitHub 仓库的 Settings → Deploy keys 中添加您的公钥。

### Q3：部署密钥和 GitHub Token 有什么区别？

- **部署密钥**：只能访问特定仓库，权限更细粒度
- **GitHub Token**：可以访问所有仓库，权限更大

### Q4：部署后如何访问后台？

部署完成后，访问 `http://your-domain.com/admin/login` 登录后台。

## 📞 联系我们

如有任何问题，请联系开发者。

## 📄 许可证

MIT License