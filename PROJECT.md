# 摄影师独立站 - 部署引导程序 · 项目管理文档

> 版本：v1.0  
> 日期：2026-07-14  
> 仓库：https://github.com/ysysyxg/photographer-portfolio-bootstrap

---

## 一、项目概述

### 1.1 项目定位

本项目是摄影师独立站的**公开部署引导程序**，负责：
- 提供公开的部署入口（任何人都可获取）
- 验证用户部署权限（Deploy Key）
- 拉取私有仓库核心代码
- 执行初始化引导流程

### 1.2 架构设计

```
┌─────────────────────────────────────────────────────────────┐
│                    公开仓库 (Public)                        │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  bootstrap.sh  - 引导脚本（环境检查 + 密钥验证）      │    │
│  │  README.md     - 部署说明                          │    │
│  │  LICENSE       - MIT 协议                          │    │
│  │  PROJECT.md    - 项目管理文档                      │    │
│  └─────────────────────────────────────────────────────┘    │
│                          ↓ 用户获取引导脚本                     │
│                          ↓ 输入部署密钥                         │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  bootstrap.sh 执行流程:                             │    │
│  │    1. 系统环境检查                                  │    │
│  │    2. 依赖安装（自动）                               │    │
│  │    3. SSH 密钥配置                                 │    │
│  │    4. GitHub 连接测试                              │    │
│  │    5. 拉取私有仓库                                  │    │
│  │    6. 代码完整性验证                                │    │
│  │    7. 执行初始化脚本                                │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
                          ↓ 密钥验证通过
┌─────────────────────────────────────────────────────────────┐
│                    私有仓库 (Private)                       │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  server/dist/   - 后端构建产物                      │    │
│  │  web/.output/   - 前端构建产物                      │    │
│  │  deploy/        - 部署脚本                         │    │
│  │  version.json   - 版本管理                         │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

---

## 二、文件结构

### 2.1 当前文件清单

| 文件 | 大小 | 说明 |
|------|------|------|
| `bootstrap.sh` | ~200 行 | 部署引导脚本（核心） |
| `README.md` | ~80 行 | 部署说明文档 |
| `LICENSE` | MIT | 开源协议 |
| `PROJECT.md` | - | 项目管理文档 |

### 2.2 bootstrap.sh 功能模块

| 模块 | 行号 | 功能 |
|------|------|------|
| 日志函数 | 11-25 | 彩色日志输出 |
| 配置常量 | 27-28 | 仓库地址配置 |
| 依赖检查 | 30-52 | 检查/安装系统依赖 |
| 环境检查 | 60-93 | Node.js 版本检测与升级 |
| 密钥配置 | 99-136 | SSH 密钥配置与连接测试 |
| 代码拉取 | 138-160 | Git 克隆私有仓库 |
| 完整性验证 | 162-188 | 关键文件校验 |
| 初始化执行 | 190-217 | 执行部署脚本 |

---

## 三、代码完整性验证

### 3.1 验证文件列表

| 文件路径 | 验证目的 |
|----------|----------|
| `server/dist/index.js` | 后端构建产物 |
| `web/.output/public/index.html` | 前端构建产物 |
| `version.json` | 版本管理文件 |
| `deploy/init.sh` | 部署初始化脚本 |

### 3.2 验证逻辑

```bash
# 逐个检查文件是否存在
REQUIRED_FILES=(
    "server/dist/index.js"
    "web/.output/public/index.html"
    "version.json"
    "deploy/init.sh"
)

# 如果有缺失，提示用户并询问是否继续
```

---

## 四、部署流程

### 4.1 用户操作流程

```
1. 获取引导脚本
   git clone https://github.com/ysysyxg/photographer-portfolio-bootstrap.git
   
2. 运行引导程序
   cd photographer-portfolio-bootstrap
   bash bootstrap.sh

3. 输入部署密钥
   引导脚本提示输入 Deploy Key

4. 等待部署完成
   脚本自动执行环境检查、代码拉取、初始化

5. 完成配置
   访问 http://domain.com/setup 完成站点初始化
```

### 4.2 脚本执行流程

```
开始
  ↓
环境检查（Node.js、npm、Git）
  ↓
依赖安装（自动）
  ↓
Node.js 版本检测（<20.x 提示升级）
  ↓
输入部署密钥（Deploy Key）
  ↓
SSH 密钥配置
  ↓
GitHub 连接测试
  ↓
拉取私有仓库代码
  ↓
代码完整性验证
  ↓
执行 deploy/init.sh
  ↓
完成
```

---

## 五、安全策略

### 5.1 密钥管理

| 密钥类型 | 使用场景 | 权限范围 |
|----------|----------|----------|
| **Deploy Key** | 拉取私有仓库 | 只读权限 |
| **GitHub PAT** | SSH 失败时备选 | 仓库读写权限 |

### 5.2 安全措施

1. **密钥输入保护**：用户手动输入密钥，脚本不保存到日志
2. **权限控制**：SSH 私钥文件权限设置为 600
3. **连接测试**：先测试再拉取，避免无效操作
4. **完整性验证**：拉取后验证关键文件，防止代码篡改

---

## 六、版本管理

### 6.1 版本号规则

```
v{主版本}.{次版本}.{修订版本}
```

| 版本号 | 说明 |
|--------|------|
| v1.0.0 | 初始版本 |
| v1.0.1 | 修复 bug |
| v1.1.0 | 新增功能 |

### 6.2 更新流程

```
1. 修改 bootstrap.sh
2. 更新 README.md（如需要）
3. 更新 PROJECT.md（如需要）
4. 提交代码
5. 创建 Release
```

---

## 七、维护指南

### 7.1 更新引导脚本

```bash
# 拉取最新代码
git pull origin master

# 修改 bootstrap.sh
# ...

# 提交
git add bootstrap.sh
git commit -m "feat: 更新引导脚本"
git push origin master
```

### 7.2 修改私有仓库地址

编辑 `bootstrap.sh` 第 27-28 行：

```bash
PRIV_REPO_URL="git@github.com:ysysyxg/photographer-portfolio.git"
PRIV_REPO_HTTPS="https://github.com/ysysyxg/photographer-portfolio.git"
```

### 7.3 新增验证文件

编辑 `bootstrap.sh` 的 `REQUIRED_FILES` 数组：

```bash
REQUIRED_FILES=(
    "server/dist/index.js"
    "web/.output/public/index.html"
    "version.json"
    "deploy/init.sh"
    "新增文件路径"
)
```

---

## 八、常见问题

### 8.1 SSH 连接失败

**现象**：`ssh -T git@github.com` 失败

**解决**：
1. 检查 Deploy Key 是否已添加到 GitHub 仓库的 Deploy keys
2. 确保密钥格式正确（以 `-----BEGIN RSA PRIVATE KEY-----` 开头）
3. 使用 HTTPS 方式（输入 GitHub PAT）

### 8.2 代码拉取失败

**现象**：`git clone` 失败

**解决**：
1. 检查网络连接
2. 检查 Deploy Key 是否有仓库访问权限
3. 检查仓库地址是否正确

### 8.3 代码完整性验证失败

**现象**：提示缺失关键文件

**解决**：
1. 检查私有仓库是否包含构建产物
2. 确认 `npm run generate` 和 `npm run build` 已执行
3. 确认构建产物已提交到仓库

---

## 九、变更记录

| 日期 | 版本 | 变更内容 |
|------|------|----------|
| 2026-07-14 | v1.0.0 | 初始版本，创建引导脚本、README、LICENSE |
| 2026-07-14 | v1.0.1 | 添加代码完整性验证功能 |

---

## 十、联系信息

- **仓库地址**：https://github.com/ysysyxg/photographer-portfolio-bootstrap
- **私有仓库**：https://github.com/ysysyxg/photographer-portfolio
- **开发者**：ysysyxg