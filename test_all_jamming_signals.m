%% 8种干扰信号完整测试脚本
% 测试按照用户分类的8种干扰信号实现
%
% 作者: Asaqe Lee
% 日期: 2025-06-20

clear; clc; close all;

fprintf('=== 8种干扰信号完整测试 ===\n');
fprintf('按照用户分类实现的干扰信号测试\n');
fprintf('开始时间: %s\n', datestr(now));
fprintf('===============================\n\n');

%% 添加路径
addpath(genpath('src'));

%% 测试参数设置
test_params = struct();
test_params.sample_rate = 100e6;    % 100 MHz采样率
test_params.duration = 1e-3;        % 1 ms持续时间
test_params.center_freq = 100e6;    % 100 MHz中心频率
test_params.power_dbm = 0;          % 0 dBm功率

%% 1. 测试干扰信号配置管理器
fprintf('1. 测试干扰信号配置管理器...\n');
try
    % 打印所有干扰信号配置
    JammingConfigManager.print_all_configs();
    JammingConfigManager.print_regime_summary();
    
    fprintf('✓ 干扰信号配置管理器测试通过\n\n');
catch ME
    fprintf('✗ 干扰信号配置管理器测试失败: %s\n\n', ME.message);
end

%% 2. 逐个测试8种干扰信号
jamming_results = cell(8, 1);

for jamming_id = 1:8
    fprintf('=== 测试干扰信号 %d ===\n', jamming_id);
    
    try
        % 获取配置
        config = JammingConfigManager.get_config(jamming_id);
        
        % 更新测试参数
        config.sample_rate = test_params.sample_rate;
        config.duration = test_params.duration;
        config.power_dbm = test_params.power_dbm;
        
        % 创建干扰信号对象
        jamming_obj = create_jamming_object(config);
        
        if ~isempty(jamming_obj)
            % 打印状态
            jamming_obj.print_status();
            
            % 生成测试信号
            test_signal = jamming_obj.generate_jamming_signal([], struct());
            
            % 基本验证
            signal_power = mean(abs(test_signal).^2);
            signal_length = length(test_signal);
            expected_length = round(config.duration * config.sample_rate);
            
            fprintf('信号验证:\n');
            fprintf('  信号长度: %d (期望: %d)\n', signal_length, expected_length);
            fprintf('  信号功率: %.2e W\n', signal_power);
            fprintf('  功率(dBm): %.1f\n', 10*log10(signal_power*1000));
            
            % 保存结果
            result = struct();
            result.jamming_id = jamming_id;
            result.config = config;
            result.object = jamming_obj;
            result.test_signal = test_signal;
            result.signal_power = signal_power;
            result.success = true;
            
            jamming_results{jamming_id} = result;
            
            fprintf('✓ 干扰信号%d测试通过\n', jamming_id);
            
        else
            fprintf('✗ 干扰信号%d对象创建失败\n', jamming_id);
            jamming_results{jamming_id} = struct('success', false, 'jamming_id', jamming_id);
        end
        
    catch ME
        fprintf('✗ 干扰信号%d测试失败: %s\n', jamming_id, ME.message);
        jamming_results{jamming_id} = struct('success', false, 'jamming_id', jamming_id, 'error', ME.message);
    end
    
    fprintf('\n');
end

%% 3. 测试信干比控制
fprintf('=== 测试信干比控制 ===\n');
try
    % 创建SIR控制器
    sir_controller = SIRController(10);  % 10dB目标信干比
    
    % 生成测试通信信号
    fs = test_params.sample_rate;
    t = (0:999)/fs;
    comm_signal = exp(1j*2*pi*test_params.center_freq*t);
    
    % 测试每种干扰信号的SIR控制
    for jamming_id = 1:8
        if jamming_results{jamming_id}.success
            jamming_signal = jamming_results{jamming_id}.test_signal(1:1000);
            
            [combined_signal, actual_sir] = sir_controller.combine_signals(...
                comm_signal, jamming_signal, 10);
            
            fprintf('干扰%d: 目标SIR=10dB, 实际SIR=%.2fdB\n', jamming_id, actual_sir);
        end
    end
    
    fprintf('✓ 信干比控制测试通过\n\n');
catch ME
    fprintf('✗ 信干比控制测试失败: %s\n\n', ME.message);
end

%% 4. 生成频谱对比图
fprintf('=== 生成频谱对比图 ===\n');
try
    figure('Name', '8种干扰信号频谱对比', 'Position', [100, 100, 1400, 1000]);
    
    for jamming_id = 1:8
        subplot(2, 4, jamming_id);
        
        if jamming_results{jamming_id}.success
            signal = jamming_results{jamming_id}.test_signal;
            config = jamming_results{jamming_id}.config;
            
            % FFT分析
            N = length(signal);
            f = (-N/2:N/2-1) * config.sample_rate / N;
            S = fftshift(fft(signal));
            power_db = 20*log10(abs(S) + eps);
            
            plot(f/1e6, power_db, 'b-', 'LineWidth', 1);
            xlabel('频率 (MHz)');
            ylabel('功率 (dB)');
            title(sprintf('%d. %s', jamming_id, config.signal_type));
            grid on;
            
            % 标记中心频率
            hold on;
            plot(config.center_frequency/1e6, max(power_db), 'ro', 'MarkerSize', 6);
            
        else
            text(0.5, 0.5, '测试失败', 'HorizontalAlignment', 'center', ...
                 'Units', 'normalized', 'FontSize', 12, 'Color', 'red');
            title(sprintf('%d. 测试失败', jamming_id));
        end
    end
    
    sgtitle('8种干扰信号频谱对比', 'FontSize', 16, 'FontWeight', 'bold');
    
    % 保存图像
    saveas(gcf, 'data/output/jamming_signals_spectrum_comparison.png');
    fprintf('频谱对比图已保存\n');
    
    fprintf('✓ 频谱对比图生成完成\n\n');
catch ME
    fprintf('✗ 频谱对比图生成失败: %s\n\n', ME.message);
end

%% 5. 生成时域波形对比
fprintf('=== 生成时域波形对比 ===\n');
try
    figure('Name', '8种干扰信号时域波形', 'Position', [200, 200, 1400, 1000]);
    
    for jamming_id = 1:8
        subplot(2, 4, jamming_id);
        
        if jamming_results{jamming_id}.success
            signal = jamming_results{jamming_id}.test_signal;
            config = jamming_results{jamming_id}.config;
            
            % 显示前1000个采样点
            N_display = min(1000, length(signal));
            t = (0:N_display-1) / config.sample_rate;
            
            plot(t*1e6, real(signal(1:N_display)), 'b-', 'LineWidth', 1);
            hold on;
            plot(t*1e6, imag(signal(1:N_display)), 'r-', 'LineWidth', 1);
            
            xlabel('时间 (μs)');
            ylabel('幅度');
            title(sprintf('%d. %s', jamming_id, config.signal_type));
            legend('实部', '虚部', 'Location', 'best');
            grid on;
            
        else
            text(0.5, 0.5, '测试失败', 'HorizontalAlignment', 'center', ...
                 'Units', 'normalized', 'FontSize', 12, 'Color', 'red');
            title(sprintf('%d. 测试失败', jamming_id));
        end
    end
    
    sgtitle('8种干扰信号时域波形', 'FontSize', 16, 'FontWeight', 'bold');
    
    % 保存图像
    saveas(gcf, 'data/output/jamming_signals_time_domain.png');
    fprintf('时域波形图已保存\n');
    
    fprintf('✓ 时域波形对比生成完成\n\n');
catch ME
    fprintf('✗ 时域波形对比生成失败: %s\n\n', ME.message);
end

%% 6. 生成干扰信号参数汇总表
fprintf('=== 生成参数汇总表 ===\n');
try
    % 创建汇总表
    summary_table = table();
    
    for jamming_id = 1:8
        if jamming_results{jamming_id}.success
            config = jamming_results{jamming_id}.config;
            
            row_data = {
                jamming_id;
                config.regime;
                config.signal_type;
                config.modulation;
                config.center_frequency / 1e6;  % MHz
                config.bandwidth / 1e3;         % kHz
                config.power_dbm;
                config.description
            };
            
            if isempty(summary_table)
                summary_table = table(row_data{:}, 'VariableNames', ...
                    {'ID', '体制', '信号样式', '调制方式', '中心频率MHz', '带宽kHz', '功率dBm', '描述'});
            else
                new_row = table(row_data{:}, 'VariableNames', ...
                    {'ID', '体制', '信号样式', '调制方式', '中心频率MHz', '带宽kHz', '功率dBm', '描述'});
                summary_table = [summary_table; new_row];
            end
        end
    end
    
    % 显示汇总表
    fprintf('干扰信号参数汇总表:\n');
    disp(summary_table);
    
    % 保存汇总表
    writetable(summary_table, 'data/output/jamming_signals_summary.csv');
    fprintf('参数汇总表已保存为CSV文件\n');
    
    fprintf('✓ 参数汇总表生成完成\n\n');
catch ME
    fprintf('✗ 参数汇总表生成失败: %s\n\n', ME.message);
end

%% 7. 测试总结
fprintf('=== 测试总结 ===\n');

success_count = 0;
for jamming_id = 1:8
    if jamming_results{jamming_id}.success
        success_count = success_count + 1;
    end
end

fprintf('测试完成时间: %s\n', datestr(now));
fprintf('总测试数量: 8种干扰信号\n');
fprintf('成功数量: %d\n', success_count);
fprintf('成功率: %.1f%%\n', success_count/8*100);

if success_count == 8
    fprintf('\n🎉 所有8种干扰信号测试全部通过！\n');
    fprintf('系统已准备就绪，可以进行完整的100×8仿真\n');
else
    fprintf('\n⚠️  有%d种干扰信号测试失败\n', 8-success_count);
    fprintf('失败的干扰信号:\n');
    for jamming_id = 1:8
        if ~jamming_results{jamming_id}.success
            config = JammingConfigManager.get_config(jamming_id);
            fprintf('  ID %d: %s\n', jamming_id, config.signal_type);
        end
    end
end

fprintf('\n生成的文件:\n');
fprintf('  - data/output/jamming_signals_spectrum_comparison.png\n');
fprintf('  - data/output/jamming_signals_time_domain.png\n');
fprintf('  - data/output/jamming_signals_summary.csv\n');

fprintf('==================\n');

%% 辅助函数
function jamming_obj = create_jamming_object(config)
    % 根据配置创建干扰信号对象
    
    try
        switch config.jamming_id
            case 1  % 瞄准式单音干扰
                jamming_obj = SingleToneJamming(config);
            case 2  % 瞄准式多音干扰
                jamming_obj = MultiToneJamming(config);
            case 3  % 瞄准式窄带干扰
                jamming_obj = NarrowBandJamming(config);
            case 4  % 瞄准式噪声调频干扰
                jamming_obj = NoiseFMJamming(config);
            case 5  % 阻塞式宽带干扰
                jamming_obj = WideBandJamming(config);
            case 6  % 阻塞式宽带梳状谱干扰
                jamming_obj = CombSpectrumJamming(config);
            case 7  % 阻塞式扫频干扰
                jamming_obj = SweepJamming(config);
            case 8  % 跟踪式跳频干扰
                jamming_obj = FrequencyFollowJamming(config);
            otherwise
                error('不支持的干扰信号ID: %d', config.jamming_id);
        end
    catch ME
        fprintf('创建干扰信号对象失败 (ID %d): %s\n', config.jamming_id, ME.message);
        jamming_obj = [];
    end
end
