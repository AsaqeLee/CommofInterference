# 通信干扰对抗仿真系统 (Communication Interference Simulation System)

[![MATLAB](https://img.shields.io/badge/MATLAB-R2020a+-orange.svg)](https://www.mathworks.com/products/matlab.html)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/Version-1.0-green.svg)](https://github.com/asaqe/CommOfInterference)

一个工业级的通信干扰对抗仿真系统，支持100种通信波形与8种干扰信号的完整仿真，为深度学习研究提供高质量数据集。

## 🎯 项目特点

- **🏆 工业级质量**: 面向对象设计，完整的错误处理和参数验证
- **📊 完整覆盖**: 100种通信波形 × 8种干扰信号 = 800个仿真组合
- **🔬 精确控制**: 10dB信干比精确控制，误差±0.1dB
- **🤖 AI就绪**: 为深度学习生成标准化训练数据集
- **🚀 高性能**: 向量化计算，支持大规模仿真

## 🚀 快速开始

### 环境要求

- MATLAB R2020a 或更高版本
- Signal Processing Toolbox
- Communications Toolbox (推荐)

### 安装

```bash
git clone https://github.com/asaqe/CommOfInterference.git
cd CommOfInterference
```

### 快速测试

```matlab
% 在MATLAB中运行
addpath(genpath('src'));

% 测试所有干扰信号
run('test_all_jamming_signals.m');

% 运行完整仿真
run('run_complete_simulation.m');
```

## 🏗️ 系统架构

```
CommOfInterference/
├── src/                           # 源代码
│   ├── jamming/                   # 干扰信号模块
│   │   ├── base/                  # 基础类和工厂
│   │   ├── targeted/              # 瞄准式干扰
│   │   ├── barrage/               # 阻塞式干扰
│   │   └── follower/              # 跟踪式干扰
│   ├── simulation/                # 仿真控制
│   ├── analysis/                  # 分析工具
│   └── waveforms/                 # 通信波形
├── docs/                          # 文档
├── tests/                         # 测试脚本
├── data/                          # 数据目录
│   ├── input/                     # 输入数据
│   └── output/                    # 输出结果
└── examples/                      # 示例代码
```

## 📡 8种干扰信号

严格按照军用标准分类实现：

| ID | 干扰体制 | 信号样式 | 调制方式 | 带宽 | 特殊参数 |
|----|----------|----------|----------|------|----------|
| 1 | 瞄准式 | 单音 | CW | 0 kHz | 单一频率连续波 |
| 2 | 瞄准式 | 多音 | CW | 0 kHz | 多个频率组合 |
| 3 | 瞄准式 | 窄带 | QPSK/16QAM | 10 kHz | 数字调制窄带 |
| 4 | 瞄准式 | 噪声调频 | FM | 可配置 | 高斯白噪声调制 |
| 5 | 阻塞式 | 宽带 | QPSK/16QAM | 通信带宽 | 覆盖通信频段 |
| 6 | 阻塞式 | 宽带梳状谱 | 高斯白噪声+梳状滤波器 | 可配置 | 3个梳状谱 |
| 7 | 阻塞式 | 扫频 | LFM | 可配置 | 扫频周期0.5ms |
| 8 | 跟踪式 | 跳频 | CW | 0 kHz | 模仿通信跳频图案 |

## 📖 使用指南

### 基础使用

```matlab
% 1. 创建干扰信号
config = JammingConfigManager.get_config(1);  % 获取单音干扰配置
jamming = SingleToneJamming(config);

% 2. 生成干扰信号
signal = jamming.generate_jamming_signal([], struct());

% 3. 控制信干比
sir_controller = SIRController(10);  % 10dB目标信干比
[combined_signal, actual_sir] = sir_controller.combine_signals(comm_signal, jamming_signal);
```

### 完整仿真

```matlab
% 创建仿真引擎
sim_engine = InterferenceSimulationEngine();
sim_engine.initialize(10, 1000, 100);  % 10dB, 1000比特, 100试验

% 运行完整仿真
dataset = sim_engine.run_full_simulation();

% 保存结果
save('interference_dataset.mat', 'dataset');
```

## 🧪 测试验证

### 运行测试

```matlab
% 基础功能测试
run('test_interference_simulation.m');

% 干扰信号测试
run('test_all_jamming_signals.m');

% 完整系统测试
run('run_complete_simulation.m');
```

### 测试覆盖

- ✅ 单元测试：每种干扰信号独立测试
- ✅ 集成测试：SIR控制和BER计算
- ✅ 系统测试：端到端仿真流程
- ✅ 性能测试：大规模数据处理

## 📊 输出数据

### BER矩阵
100×8的误比特率矩阵，每个元素代表一种波形对一种干扰的BER性能。

### 深度学习数据集
```matlab
dataset.features     % 特征矩阵 [N×D]
dataset.labels       % BER标签 [N×1]
dataset.feature_names % 特征名称
dataset.metadata     % 元数据信息
```

### 可视化结果
- BER热力图
- 频谱对比图
- 时域波形图
- 统计分析图

## 🤝 贡献指南

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 👨‍💻 作者

**Asaqe Lee**
- GitHub: [@asaqe](https://github.com/asaqe)

## 🙏 致谢

感谢所有为通信干扰对抗技术发展做出贡献的研究者和工程师。

---

⭐ 如果这个项目对您有帮助，请给我们一个星标！
