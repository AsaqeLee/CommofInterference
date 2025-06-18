# 通信波形生成模块快速开始指南

## 🚀 快速开始

本指南将帮助您在5分钟内开始使用通信波形生成模块。

## 📋 系统要求

- **MATLAB版本**: R2020a或更高版本
- **操作系统**: Windows 10/11, macOS, Linux
- **内存**: 建议4GB以上
- **硬盘空间**: 100MB

## 🛠️ 安装步骤

### 1. 下载项目
```bash
# 如果使用Git
git clone <repository-url>

# 或直接下载ZIP文件并解压
```

### 2. 启动MATLAB
打开MATLAB并导航到项目目录：
```matlab
cd('path/to/CommOfInterference')
```

### 3. 添加路径
```matlab
addpath(genpath('src'));
addpath(genpath('config'));
```

### 4. 验证安装
运行快速测试：
```matlab
% 测试波形工厂
factory = WaveformFactory.getInstance();
fprintf('支持的波形数量: %d\n', length(factory.get_supported_waveforms()));
```

## 🎯 5分钟教程

### 步骤1: 创建QPSK波形 (1分钟)
```matlab
% 创建QPSK实例
qpsk = QPSK();

% 配置基本参数
config = struct();
config.center_frequency = 2.4e9;    % 2.4 GHz
config.sample_rate = 20e6;          % 20 MHz
config.symbol_rate = 1e6;           % 1 Msps
config.snr_db = 15;                 % 15 dB

qpsk.configure(config);
fprintf('✓ QPSK波形创建完成\n');
```

### 步骤2: 生成测试数据 (30秒)
```matlab
% 生成1000比特随机数据
data = randi([0, 1], 1000, 1);
fprintf('✓ 生成了 %d 比特测试数据\n', length(data));
```

### 步骤3: 调制信号 (30秒)
```matlab
% 调制生成信号
modulated_signal = qpsk.generate_signal(data, 'add_noise', true);
fprintf('✓ 调制完成，信号长度: %d 采样点\n', length(modulated_signal));
```

### 步骤4: 解调恢复 (1分钟)
```matlab
% 解调恢复数据
recovered_data = qpsk.recover_data(modulated_signal);
fprintf('✓ 解调完成，恢复了 %d 比特数据\n', length(recovered_data));
```

### 步骤5: 性能分析 (2分钟)
```matlab
% 计算误码率
min_len = min(length(data), length(recovered_data));
ber = qpsk.calculate_ber(data(1:min_len), recovered_data(1:min_len));
fprintf('✓ 误码率: %.6f\n', ber);

% 绘制星座图
figure('Name', 'QPSK星座图');
qpsk.plot_constellation();

% 频谱分析
spectrum = qpsk.get_spectrum(modulated_signal);
figure('Name', 'QPSK频谱');
plot(spectrum.frequencies/1e6, 10*log10(spectrum.power_density));
xlabel('频率 (MHz)');
ylabel('功率谱密度 (dB)');
title('QPSK信号频谱');
grid on;

fprintf('🎉 恭喜！您已成功完成QPSK调制解调演示\n');
```

## 📊 预期结果

运行上述代码后，您应该看到：

1. **控制台输出**:
   ```
   ✓ QPSK波形创建完成
   ✓ 生成了 1000 比特测试数据
   ✓ 调制完成，信号长度: 20000 采样点
   ✓ 解调完成，恢复了 1000 比特数据
   ✓ 误码率: 0.000000
   🎉 恭喜！您已成功完成QPSK调制解调演示
   ```

2. **QPSK星座图**: 显示4个清晰的星座点
3. **频谱图**: 显示QPSK信号的频谱特性

## 🔧 更多示例

### 示例1: 比较不同调制方式
```matlab
% 创建不同调制方式
bpsk = BPSK();
qpsk = QPSK();
qam16 = QAM16();

% 统一配置
config = struct();
config.center_frequency = 1e9;
config.sample_rate = 10e6;
config.symbol_rate = 1e6;
config.snr_db = 15;

% 配置所有波形
bpsk.configure(config);
qpsk.configure(config);
qam16.configure(config);

% 测试数据
test_data = randi([0, 1], 1000, 1);

% 性能比较
waveforms = {bpsk, qpsk, qam16};
names = {'BPSK', 'QPSK', '16QAM'};

fprintf('\n=== 调制方式性能比较 ===\n');
for i = 1:length(waveforms)
    wf = waveforms{i};
    
    % 调制解调
    signal = wf.generate_signal(test_data, 'add_noise', true);
    recovered = wf.recover_data(signal);
    
    % 计算性能
    min_len = min(length(test_data), length(recovered));
    ber = wf.calculate_ber(test_data(1:min_len), recovered(1:min_len));
    
    % 获取波形信息
    info = wf.get_waveform_info();
    
    fprintf('%s: BER=%.6f, 频谱效率=%.1f bits/symbol\n', ...
        names{i}, ber, info.bits_per_symbol);
end
```

### 示例2: 载波同步演示
```matlab
% 创建BPSK实例
bpsk = BPSK();
config = struct();
config.center_frequency = 1e6;
config.sample_rate = 10e6;
config.symbol_rate = 1e6;
config.snr_db = 20;
bpsk.configure(config);

% 生成信号
data = [0; 1; 0; 1; 0; 1; 0; 1];
signal = bpsk.generate_signal(data, 'add_noise', false);

% 添加载波偏移
freq_offset = 1000; % 1kHz偏移
phase_offset = pi/4; % 45度相位偏移
t = (0:length(signal)-1) / config.sample_rate;
offset_signal = signal .* exp(1j * (2*pi*freq_offset*t + phase_offset));

fprintf('\n=== 载波同步演示 ===\n');
fprintf('添加载波偏移: 频率=%.0f Hz, 相位=%.1f度\n', ...
    freq_offset, phase_offset*180/pi);

% 载波恢复
[recovered_signal, est_freq, est_phase] = ...
    CarrierSync.recover_carrier_bpsk(offset_signal, config.sample_rate);

fprintf('估计载波偏移: 频率=%.1f Hz, 相位=%.1f度\n', ...
    est_freq, est_phase*180/pi);
```

### 示例3: 批量性能测试
```matlab
% SNR vs BER性能测试
snr_range = 0:2:20;
qpsk = QPSK();

config = struct();
config.center_frequency = 1e9;
config.sample_rate = 10e6;
config.symbol_rate = 1e6;

fprintf('\n=== QPSK性能测试 ===\n');
ber_results = zeros(size(snr_range));

for i = 1:length(snr_range)
    config.snr_db = snr_range(i);
    qpsk.configure(config);
    
    % 生成大量测试数据
    test_data = randi([0, 1], 10000, 1);
    
    % 调制解调
    modulated = qpsk.generate_signal(test_data, 'add_noise', true);
    recovered = qpsk.recover_data(modulated);
    
    % 计算误码率
    min_len = min(length(test_data), length(recovered));
    ber_results(i) = qpsk.calculate_ber(test_data(1:min_len), recovered(1:min_len));
    
    fprintf('SNR=%2d dB: BER=%.6f\n', snr_range(i), ber_results(i));
end

% 绘制性能曲线
figure('Name', 'QPSK BER性能');
semilogy(snr_range, ber_results, 'o-', 'LineWidth', 2);
xlabel('SNR (dB)');
ylabel('误码率 (BER)');
title('QPSK误码率性能曲线');
grid on;
```

## 🧪 运行综合测试

验证系统完整性：
```matlab
% 运行综合测试
comprehensive_test
```

这将测试所有主要功能并生成详细报告。

## 📁 项目结构

```
CommOfInterference/
├── src/                    # 源代码
│   ├── waveforms/         # 波形实现
│   │   ├── base/          # 基础类
│   │   ├── digital/       # 数字调制
│   │   └── analog/        # 模拟调制
│   └── utils/             # 工具类
├── config/                # 配置文件
├── data/                  # 数据文件
│   ├── input/            # 输入数据
│   ├── output/           # 输出结果
│   └── temp/             # 临时文件
├── docs/                  # 文档
├── tests/                 # 测试脚本
└── examples/              # 示例程序
```

## 🔍 故障排除

### 常见问题

#### 1. 路径问题
**错误**: `Undefined function or variable 'QPSK'`
**解决**: 确保添加了正确的路径
```matlab
addpath(genpath('src'));
```

#### 2. 配置错误
**错误**: 配置验证失败
**解决**: 检查参数设置
```matlab
% 确保采样率足够高
config.sample_rate = 10 * config.symbol_rate; % 至少10倍过采样
```

#### 3. 内存不足
**错误**: 处理大数据时内存不足
**解决**: 减少数据量或分块处理
```matlab
% 使用较小的数据量进行测试
test_data = randi([0, 1], 1000, 1); % 而不是100000
```

### 获取帮助

1. **查看函数帮助**:
   ```matlab
   help QPSK
   help WaveformFactory
   ```

2. **运行示例**:
   ```matlab
   % 查看examples目录下的示例文件
   ```

3. **查看文档**:
   - `docs/technical_documentation.md` - 技术文档
   - `docs/project_progress.md` - 项目进度

## 🎯 下一步

现在您已经掌握了基础用法，可以：

1. **探索更多调制方式**: 尝试BPSK、16QAM、FSK等
2. **深入载波同步**: 学习不同的同步算法
3. **性能分析**: 进行详细的性能评估
4. **扩展功能**: 添加新的调制方式或算法
5. **实际应用**: 将模块集成到您的项目中

## 📞 支持

如果遇到问题：
1. 查看文档和示例
2. 运行诊断脚本
3. 检查MATLAB版本兼容性
4. 参考技术文档中的故障排除部分

---

**祝您使用愉快！** 🎉

*快速开始指南版本: v1.0*  
*最后更新: 2025年6月18日*
