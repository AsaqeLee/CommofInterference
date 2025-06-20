# 贡献指南 (Contributing Guide)

感谢您对通信干扰对抗仿真系统的关注！我们欢迎各种形式的贡献。

## 🤝 如何贡献

### 报告问题 (Bug Reports)

如果您发现了bug，请创建一个issue并包含以下信息：

- **问题描述**: 清晰简洁的问题描述
- **重现步骤**: 详细的重现步骤
- **期望行为**: 您期望发生什么
- **实际行为**: 实际发生了什么
- **环境信息**: MATLAB版本、操作系统等
- **错误信息**: 完整的错误消息和堆栈跟踪

### 功能请求 (Feature Requests)

如果您有新功能的想法，请创建一个issue并包含：

- **功能描述**: 详细描述新功能
- **使用场景**: 为什么需要这个功能
- **实现建议**: 如果有的话，提供实现思路

### 代码贡献 (Code Contributions)

1. **Fork 仓库**
   ```bash
   git clone https://github.com/asaqe/CommOfInterference.git
   cd CommOfInterference
   ```

2. **创建分支**
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **进行更改**
   - 遵循代码规范
   - 添加必要的测试
   - 更新文档

4. **提交更改**
   ```bash
   git add .
   git commit -m "Add: 简洁的提交信息"
   ```

5. **推送分支**
   ```bash
   git push origin feature/your-feature-name
   ```

6. **创建 Pull Request**

## 📝 代码规范

### MATLAB代码规范

#### 命名约定
- **类名**: 使用PascalCase，如 `SingleToneJamming`
- **方法名**: 使用camelCase，如 `generateJammingSignal`
- **变量名**: 使用snake_case，如 `center_frequency`
- **常量**: 使用UPPER_CASE，如 `DEFAULT_SAMPLE_RATE`

#### 代码结构
```matlab
classdef ClassName < BaseClass
    % ClassName - 简短描述
    % 详细描述类的功能和用途
    %
    % 作者: Your Name
    % 日期: YYYY-MM-DD
    
    properties (Constant)
        % 常量定义
    end
    
    properties (Access = private)
        % 私有属性
    end
    
    methods
        function obj = ClassName(config)
            % 构造函数
            % 输入: config - 配置参数
        end
        
        function result = publicMethod(obj, input)
            % 公共方法
            % 输入: input - 输入参数
            % 输出: result - 输出结果
        end
    end
    
    methods (Access = protected)
        function privateMethod(obj)
            % 受保护方法
        end
    end
end
```

#### 注释规范
- 每个类和方法都要有详细的注释
- 使用中文注释，保持一致性
- 包含输入输出参数说明
- 添加使用示例（如果适用）

#### 错误处理
```matlab
% 参数验证
assert(frequency > 0, 'ClassName:InvalidFreq', '频率必须大于0');

% 错误抛出
if condition
    error('ClassName:ErrorType', '错误描述: %s', details);
end

% 警告
if warning_condition
    warning('ClassName:WarningType', '警告信息');
end
```

### 测试规范

#### 测试文件命名
- 测试文件以 `test_` 开头
- 功能测试: `test_功能名称.m`
- 单元测试: `test_类名.m`

#### 测试结构
```matlab
%% 测试标题
% 测试描述

clear; clc; close all;

%% 测试准备
% 设置测试环境

%% 测试用例1
fprintf('测试用例1: 描述\n');
try
    % 测试代码
    fprintf('✓ 测试通过\n');
catch ME
    fprintf('✗ 测试失败: %s\n', ME.message);
end

%% 测试总结
% 输出测试结果
```

## 🔧 开发环境设置

### 必需软件
- MATLAB R2020a 或更高版本
- Signal Processing Toolbox
- Communications Toolbox (推荐)

### 推荐工具
- MATLAB Editor (内置)
- Git for Windows
- Visual Studio Code (可选，用于文档编辑)

### 项目设置
```matlab
% 添加项目路径
addpath(genpath('src'));

% 运行测试
run('test_all_jamming_signals.m');
```

## 📚 文档贡献

### 文档类型
- **API文档**: 代码中的注释
- **用户指南**: `docs/` 目录下的markdown文件
- **示例代码**: `examples/` 目录
- **README**: 项目根目录

### 文档规范
- 使用Markdown格式
- 中英文混合，以中文为主
- 包含代码示例
- 添加适当的图表和截图

## 🧪 测试指南

### 测试类型
1. **单元测试**: 测试单个类或方法
2. **集成测试**: 测试模块间交互
3. **系统测试**: 测试完整流程
4. **性能测试**: 测试系统性能

### 测试要求
- 新功能必须包含测试
- 测试覆盖率 > 80%
- 所有测试必须通过
- 包含边界条件测试

### 运行测试
```matlab
% 运行所有测试
run_all_tests();

% 运行特定测试
run('test_specific_feature.m');
```

## 🚀 发布流程

### 版本控制
- 遵循语义化版本控制 (SemVer)
- 格式: MAJOR.MINOR.PATCH
- 更新 `CHANGELOG.md`

### 发布检查清单
- [ ] 所有测试通过
- [ ] 文档更新完整
- [ ] 版本号正确
- [ ] CHANGELOG更新
- [ ] 性能测试通过

## 📞 联系方式

如果您有任何问题或建议，可以通过以下方式联系：

- **GitHub Issues**: 创建issue讨论
- **Email**: asaqe@example.com
- **讨论区**: GitHub Discussions

## 🙏 致谢

感谢所有贡献者的努力！您的贡献让这个项目变得更好。

### 贡献者列表
- **Asaqe Lee** - 项目创建者和维护者

---

**注意**: 通过贡献代码，您同意您的贡献将在MIT许可证下发布。
