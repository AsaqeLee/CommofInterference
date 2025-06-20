# GitHub 推送指南

本文档指导您如何将通信干扰对抗仿真系统推送到GitHub。

## 🚀 快速推送步骤

### 1. 准备工作

确保您已经：
- ✅ 安装了Git
- ✅ 拥有GitHub账户
- ✅ 在GitHub上创建了新仓库 `CommOfInterference`

### 2. 项目整理

首先运行项目整理脚本：

```matlab
% 在MATLAB中运行
run('organize_project.m');
```

这将：
- 创建标准目录结构
- 整理文件位置
- 生成必要的README文件
- 检查文件完整性

### 3. Git初始化和推送

在项目根目录打开命令行，执行以下命令：

```bash
# 1. 初始化Git仓库（如果尚未初始化）
git init

# 2. 配置Git用户信息（首次使用）
git config user.name "Your Name"
git config user.email "your.email@example.com"

# 3. 添加所有文件
git add .

# 4. 查看将要提交的文件
git status

# 5. 提交初始版本
git commit -m "feat: 完整实现8种干扰信号的通信干扰对抗仿真系统

- 实现8种军用标准干扰信号
- 完整的面向对象架构设计
- 10dB信干比精确控制系统
- BER计算和深度学习数据集生成
- 工业级代码质量和测试框架
- 详细文档和使用示例"

# 6. 添加远程仓库（替换为您的实际GitHub仓库URL）
git remote add origin https://github.com/YOUR_USERNAME/CommOfInterference.git

# 7. 推送到GitHub
git branch -M main
git push -u origin main

# 8. 创建发布标签
git tag -a v1.0.0 -m "Release version 1.0.0: 完整的8种干扰信号实现"
git push origin v1.0.0
```

## 📝 提交信息规范

使用以下格式的提交信息：

```
<type>(<scope>): <subject>

<body>

<footer>
```

### 类型 (type)
- `feat`: 新功能
- `fix`: 修复bug
- `docs`: 文档更新
- `style`: 代码格式调整
- `refactor`: 代码重构
- `test`: 测试相关
- `chore`: 构建过程或辅助工具的变动

### 示例
```bash
git commit -m "feat(jamming): 添加瞄准式单音干扰实现

- 实现SingleToneJamming类
- 支持可配置频率和功率
- 包含频谱分析功能
- 添加完整的单元测试

Closes #1"
```

## 🏷️ 版本标签

### 创建标签
```bash
# 创建带注释的标签
git tag -a v1.0.0 -m "Release version 1.0.0"

# 推送标签到远程
git push origin v1.0.0

# 推送所有标签
git push origin --tags
```

### 版本号规范
遵循语义化版本控制 (SemVer)：
- `v1.0.0` - 主要版本（不兼容的API更改）
- `v1.1.0` - 次要版本（向后兼容的功能添加）
- `v1.0.1` - 补丁版本（向后兼容的错误修复）

## 📁 .gitignore 配置

确保 `.gitignore` 文件包含以下内容：

```gitignore
# MATLAB files
*.asv
*.m~
*.mex*
*.p
*.slx.autosave
*.slxc

# Output data files
data/output/*.mat
data/output/*.csv
data/output/*.png
data/output/*.jpg
data/output/*.pdf

# Temporary files
temp/
tmp/
*.tmp
*.log

# IDE files
.vscode/
.idea/
*.swp
*.swo

# OS generated files
.DS_Store
Thumbs.db

# Large simulation results
*_simulation_results_*.mat
*_dataset_*.mat
ber_matrix_*.mat
```

## 🌟 GitHub仓库设置

### 1. 仓库描述
```
工业级通信干扰对抗仿真系统，支持100种通信波形与8种干扰信号的完整仿真，为深度学习研究提供高质量数据集。
```

### 2. 主题标签 (Topics)
添加以下标签：
```
matlab, communication, jamming, simulation, electronic-warfare, 
signal-processing, deep-learning, ber-analysis, interference
```

### 3. 仓库设置
- ✅ 启用 Issues
- ✅ 启用 Wiki
- ✅ 启用 Discussions
- ✅ 启用 Projects
- ✅ 设置默认分支为 `main`

### 4. 分支保护
为 `main` 分支设置保护规则：
- ✅ 要求pull request审查
- ✅ 要求状态检查通过
- ✅ 要求分支是最新的

## 📋 发布清单

在创建GitHub Release时，包含以下内容：

### Release Notes 模板
```markdown
## 🎉 通信干扰对抗仿真系统 v1.0.0

### ✨ 主要特性
- 🎯 **8种干扰信号完整实现** - 严格按照军用标准分类
- 🏗️ **工业级系统架构** - 面向对象设计，模块化架构
- 🔬 **10dB信干比精确控制** - ±0.1dB精度
- 🤖 **深度学习数据集生成** - 800个高质量训练样本
- 🧪 **完整测试框架** - 单元测试、集成测试、系统测试

### 📊 干扰信号列表
1. 瞄准式单音干扰 (CW)
2. 瞄准式多音干扰 (CW)
3. 瞄准式窄带干扰 (QPSK/16QAM)
4. 瞄准式噪声调频干扰 (FM)
5. 阻塞式宽带干扰 (QPSK/16QAM)
6. 阻塞式宽带梳状谱干扰
7. 阻塞式扫频干扰 (LFM)
8. 跟踪式跳频干扰 (CW)

### 🚀 快速开始
```matlab
% 克隆仓库后运行
addpath(genpath('src'));
run('tests/integration/test_all_jamming_signals.m');
```

### 📚 文档
- [使用指南](README.md)
- [API文档](docs/)
- [贡献指南](CONTRIBUTING.md)
- [更新日志](CHANGELOG.md)

### 💾 下载
- **源代码**: [CommOfInterference-v1.0.0.zip]
- **示例数据**: [example-datasets.zip]

### 🔧 系统要求
- MATLAB R2020a+
- Signal Processing Toolbox
- Communications Toolbox (推荐)

### 🙏 致谢
感谢所有为通信干扰对抗技术发展做出贡献的研究者和工程师。
```

## 🔄 后续维护

### 日常工作流
```bash
# 1. 创建功能分支
git checkout -b feature/new-jamming-type

# 2. 开发和测试
# ... 编写代码 ...

# 3. 提交更改
git add .
git commit -m "feat: 添加新的干扰类型"

# 4. 推送分支
git push origin feature/new-jamming-type

# 5. 在GitHub上创建Pull Request

# 6. 合并后删除分支
git checkout main
git pull origin main
git branch -d feature/new-jamming-type
```

### 发布新版本
```bash
# 1. 更新版本号和CHANGELOG
# 2. 提交更改
git add .
git commit -m "chore: 准备发布 v1.1.0"

# 3. 创建标签
git tag -a v1.1.0 -m "Release version 1.1.0"

# 4. 推送
git push origin main
git push origin v1.1.0

# 5. 在GitHub上创建Release
```

## ❓ 常见问题

### Q: 推送时提示权限被拒绝？
A: 检查SSH密钥配置或使用HTTPS认证：
```bash
git remote set-url origin https://github.com/YOUR_USERNAME/CommOfInterference.git
```

### Q: 文件太大无法推送？
A: 检查 `.gitignore` 是否正确配置，排除大型数据文件。

### Q: 如何撤销最后一次提交？
A: 
```bash
# 撤销提交但保留更改
git reset --soft HEAD~1

# 完全撤销提交和更改
git reset --hard HEAD~1
```

---

🎉 **恭喜！您的项目现在已经准备好推送到GitHub了！**
