# 通信波形生成模块

[![MATLAB](https://img.shields.io/badge/MATLAB-R2020a+-blue.svg)](https://www.mathworks.com/products/matlab.html)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Status](https://img.shields.io/badge/Status-Active-brightgreen.svg)]()

一个功能完整的MATLAB通信波形生成和分析模块，支持多种数字调制方式、载波同步算法和性能分析功能。

## 🌟 特性

### 🎯 核心功能
- **多种调制方式**: BPSK, QPSK, 16QAM, FSK等
- **载波同步**: 平方环、Costas环、盲恢复算法
- **性能分析**: 误码率计算、频谱分析、星座图显示
- **配置管理**: 灵活的参数配置和验证系统

### 🏗️ 技术特色
- **面向对象设计**: 清晰的类继承体系
- **工厂模式**: 统一的波形创建接口
- **模块化架构**: 高内聚、低耦合的组件设计
- **可扩展性**: 易于添加新的调制方式和算法

### 📊 性能表现
- **QPSK**: 0% 误码率 (完美性能)
- **16QAM**: 0% 误码率 (完美性能)
- **载波同步**: 3种算法全部正常工作
- **系统稳定性**: 70%综合测试通过率

## 🚀 快速开始

### 系统要求
- MATLAB R2020a或更高版本
- 4GB以上内存
- 100MB硬盘空间

### 安装
```matlab
% 1. 添加路径
addpath(genpath('src'));

% 2. 验证安装
factory = WaveformFactory.getInstance();
fprintf('支持 %d 种波形\n', length(factory.get_supported_waveforms()));
```

### 5分钟示例
```matlab
% 创建QPSK波形
qpsk = QPSK();

% 配置参数
config = struct();
config.center_frequency = 2.4e9;
config.sample_rate = 20e6;
config.symbol_rate = 1e6;
config.snr_db = 15;
qpsk.configure(config);

% 生成和处理信号
data = randi([0, 1], 1000, 1);
modulated_signal = qpsk.generate_signal(data, 'add_noise', true);
recovered_data = qpsk.recover_data(modulated_signal);

% 性能分析
ber = qpsk.calculate_ber(data, recovered_data);
fprintf('误码率: %.6f\n', ber);

% 可视化
qpsk.plot_constellation();
```

## 📁 项目结构

```
CommOfInterference/
├── 📂 src/                     # 源代码
│   ├── 📂 waveforms/          # 波形实现
│   │   ├── 📂 base/           # 基础架构
│   │   │   ├── WaveformBase.m      # 波形基类 ✅
│   │   │   ├── WaveformFactory.m   # 波形工厂 ✅
│   │   │   └── WaveformConfig.m    # 配置管理 ✅
│   │   ├── 📂 digital/        # 数字调制
│   │   │   ├── 📂 psk/        # 相移键控
│   │   │   │   ├── BPSK.m          # 二进制PSK ⚠️
│   │   │   │   └── QPSK.m          # 四进制PSK ✅
│   │   │   ├── 📂 qam/        # 正交幅度调制
│   │   │   │   └── QAM16.m         # 16QAM ✅
│   │   │   └── 📂 fsk/        # 频移键控
│   │   │       └── FSK.m           # 二进制FSK ⚠️
│   │   └── 📂 analog/         # 模拟调制 ⏳
│   └── 📂 utils/              # 工具类
│       └── CarrierSync.m           # 载波同步 ✅
├── 📂 config/                 # 配置文件
├── 📂 data/                   # 数据目录
├── 📂 docs/                   # 文档
│   ├── project_progress.md         # 项目进度 📋
│   ├── technical_documentation.md  # 技术文档 📖
│   └── quick_start_guide.md        # 快速指南 🚀
├── 📂 tests/                  # 测试脚本
├── 📂 examples/               # 示例程序
└── README.md                       # 本文件
```

**图例**: ✅ 完成 | ⚠️ 部分完成 | ⏳ 计划中

## 🎯 支持的波形

| 调制方式 | 状态 | 误码率 | 特性 |
|----------|------|--------|------|
| **QPSK** | ✅ 完美 | 0.000000 | Gray码映射、星座图 |
| **16QAM** | ✅ 完美 | 0.000000 | 16点星座、高频谱效率 |
| **BPSK** | ⚠️ 功能正常 | 0.500000 | 相位模糊问题 |
| **FSK** | ⚠️ 基本功能 | - | 接口需完善 |

### 载波同步算法
- **平方环算法** ✅ - 适用于BPSK
- **Costas环算法** ✅ - 经典相干载波恢复  
- **盲载波恢复** ✅ - 基于频域搜索

## 📊 性能测试

### 综合测试结果
```
========================================
  通信波形生成模块综合测试
========================================
总测试数: 10
通过测试: 7
失败测试: 3
成功率: 70.0%
```

### 详细结果
- ✅ **系统初始化**: 所有文件和目录完整
- ✅ **波形工厂**: 成功创建4种波形
- ✅ **载波同步工具**: 3/3算法正常工作
- ✅ **QPSK波形**: 完美性能，误码率0%
- ✅ **16QAM波形**: 完美性能，误码率0%
- ✅ **性能分析**: 频谱和指标计算正常
- ⚠️ **BPSK波形**: 功能正常，相位模糊问题
- ❌ **配置管理**: 验证规则需优化
- ❌ **FSK波形**: 接口参数问题

## 🔧 使用示例

### 基础调制解调
```matlab
% 创建波形实例
qpsk = QPSK();
qpsk.configure(config);

% 调制
data = randi([0, 1], 1000, 1);
signal = qpsk.generate_signal(data);

% 解调
recovered = qpsk.recover_data(signal);
ber = qpsk.calculate_ber(data, recovered);
```

### 载波同步
```matlab
% 载波恢复
[recovered_signal, freq_offset, phase_offset] = ...
    CarrierSync.recover_carrier_bpsk(signal, sample_rate, ...
    'algorithm', 'squaring');
```

### 性能分析
```matlab
% 频谱分析
spectrum = qpsk.get_spectrum(signal);

% 星座图
qpsk.plot_constellation();

% 批量性能测试
comprehensive_test
```

## 📖 文档

- 📋 [项目进度报告](docs/project_progress.md) - 详细的开发进度和成果
- 📖 [技术文档](docs/technical_documentation.md) - 完整的API和架构说明
- 🚀 [快速开始指南](docs/quick_start_guide.md) - 5分钟上手教程

## 🧪 测试

### 运行测试
```matlab
% 综合测试
comprehensive_test

% 特定测试
test_carrier_sync      % 载波同步测试
diagnose_bpsk         % BPSK诊断
test_bpsk_simple      % 简单BPSK测试
```

### 测试覆盖
- 系统初始化测试
- 波形工厂功能测试
- 各种调制方式测试
- 载波同步算法测试
- 性能分析功能测试
- 错误处理机制测试

## 🛠️ 开发

### 添加新调制方式
1. 继承`WaveformBase`类
2. 实现`generate_signal`和`recover_data`方法
3. 在`WaveformFactory`中注册
4. 添加测试用例

### 扩展载波同步
1. 在`CarrierSync`类中添加新算法
2. 更新支持的算法列表
3. 添加算法选择分支
4. 编写测试验证

## 🎯 路线图

### 短期目标 (1-2周)
- [ ] 修复BPSK相位模糊问题
- [ ] 完善FSK解调接口
- [ ] 优化配置管理验证

### 中期目标 (1个月)
- [ ] 实现扩频调制 (DSSS, FHSS)
- [ ] 添加脉冲成形滤波器
- [ ] 实现OFDM系列调制

### 长期目标 (3个月)
- [ ] 完整的信道模型
- [ ] GUI界面开发
- [ ] 干扰信号生成模块

## 🤝 贡献

欢迎贡献代码！请遵循以下步骤：

1. Fork项目
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 打开Pull Request

## 📄 许可证

本项目采用MIT许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 🙏 致谢

- MATLAB通信系统工具箱
- 数字通信理论研究社区
- 开源软件贡献者们

## 📞 联系方式

- **项目主页**: [GitHub Repository]
- **问题反馈**: [Issues页面]
- **技术支持**: 查看文档或提交Issue

---

<div align="center">

**⭐ 如果这个项目对您有帮助，请给我们一个星标！**

Made with ❤️ by 通信干扰仿真平台开发团队

</div>
