%% FM调制集成测试
% 测试FM调制与系统的集成
%
% 作者: Asaqe Lee
% 日期: 2025-06-18

clear; clc; close all;

% 添加路径
addpath('src/waveforms/base');
addpath('src/waveforms/analog');

fprintf('=== FM调制集成测试开始 ===\n');

%% 1. 测试WaveformFactory创建FM实例
try
    factory = WaveformFactory.getInstance();
    fprintf('✓ WaveformFactory实例获取成功\n');
    
    % 检查FM是否在支持列表中
    supported_waveforms = factory.get_supported_waveforms();
    if ismember('FM', supported_waveforms)
        fprintf('✓ FM在支持的波形列表中\n');
    else
        fprintf('✗ FM不在支持的波形列表中\n');
        return;
    end
    
    % 获取模拟调制波形列表
    analog_waveforms = factory.get_waveforms_by_category('analog');
    fprintf('✓ 模拟调制波形: %s\n', strjoin(analog_waveforms, ', '));
    
catch ME
    fprintf('✗ WaveformFactory测试失败: %s\n', ME.message);
    return;
end

%% 2. 通过工厂创建FM实例
try
    fm_waveform = factory.create_waveform('FM');
    fprintf('✓ 通过工厂创建FM实例成功\n');
    
    % 获取波形信息
    info = fm_waveform.get_waveform_info();
    fprintf('  波形ID: %d\n', info.waveform_id);
    fprintf('  波形名称: %s\n', info.waveform_name);
    fprintf('  调制类型: %s\n', info.modulation_type);
    fprintf('  类别: %s\n', info.category);
    
catch ME
    fprintf('✗ 工厂创建FM实例失败: %s\n', ME.message);
    return;
end

%% 3. 配置FM参数
config = struct();
config.center_frequency = 10e3;         % 10 kHz载波频率
config.frequency_deviation = 1e3;       % 1 kHz频偏
config.baseband_bandwidth = 5e3;        % 5 kHz基带带宽
config.sample_rate = 100e3;             % 100 kHz采样率
config.snr_db = 25;                     % 25 dB信噪比
config.preemphasis_enabled = false;     % 禁用预加重
config.deemphasis_enabled = false;      % 禁用去加重

try
    fm_waveform.configure(config);
    fprintf('✓ FM参数配置成功\n');
    
    % 验证配置
    fm_info = fm_waveform.get_waveform_info();
    fprintf('  载波频率: %.1f kHz\n', config.center_frequency/1000);
    fprintf('  频偏: %.1f kHz\n', fm_info.frequency_deviation/1000);
    fprintf('  采样率: %.1f kHz\n', config.sample_rate/1000);
    
catch ME
    fprintf('✗ FM参数配置失败: %s\n', ME.message);
    return;
end

%% 4. 生成测试数据和调制
% 生成测试信号
fs = config.sample_rate;
t_duration = 0.05;  % 50ms
t = (0:1/fs:t_duration-1/fs)';
test_signal = sin(2*pi*200*t);  % 200 Hz正弦波

try
    % 调制
    params = struct();
    params.add_noise = true;
    params.normalize = true;
    
    tic;
    modulated_signal = fm_waveform.generate_signal(test_signal, params);
    modulation_time = toc;
    
    fprintf('✓ FM调制成功\n');
    fprintf('  调制时间: %.3f ms\n', modulation_time * 1000);
    fprintf('  输入长度: %d 样本\n', length(test_signal));
    fprintf('  输出长度: %d 样本\n', length(modulated_signal));
    
catch ME
    fprintf('✗ FM调制失败: %s\n', ME.message);
    return;
end

%% 5. 解调和性能分析
try
    % 解调
    demod_params = struct();
    demod_params.demod_method = 'hilbert';
    
    tic;
    recovered_signal = fm_waveform.recover_data(modulated_signal, demod_params);
    demodulation_time = toc;
    
    fprintf('✓ FM解调成功\n');
    fprintf('  解调时间: %.3f ms\n', demodulation_time * 1000);
    fprintf('  恢复信号长度: %d 样本\n', length(recovered_signal));
    
    % 性能分析
    mse = fm_waveform.calculate_ber(test_signal, recovered_signal);
    
    % 计算相关系数
    correlation = corrcoef(test_signal, recovered_signal);
    corr_coeff = correlation(1,2);
    
    fprintf('✓ 性能分析完成\n');
    fprintf('  均方误差: %.6f\n', mse);
    fprintf('  相关系数: %.4f\n', corr_coeff);
    
catch ME
    fprintf('✗ FM解调失败: %s\n', ME.message);
    return;
end

%% 6. 频谱分析
try
    spectrum = fm_waveform.get_spectrum(modulated_signal);
    fprintf('✓ 频谱分析完成\n');
    fprintf('  频谱点数: %d\n', length(spectrum.frequencies));
    fprintf('  FM带宽: %.1f kHz\n', spectrum.bandwidth/1000);
    
catch ME
    fprintf('✗ 频谱分析失败: %s\n', ME.message);
end

%% 7. 绘制结果
try
    figure('Name', 'FM集成测试结果', 'Position', [100, 100, 1200, 600]);
    
    % 时域信号对比
    subplot(2,3,1);
    plot(t*1000, test_signal, 'b-', 'LineWidth', 2);
    hold on;
    plot(t*1000, recovered_signal, 'r--', 'LineWidth', 1.5);
    xlabel('时间 (ms)');
    ylabel('幅度');
    title('信号对比');
    legend('原始', '恢复', 'Location', 'best');
    grid on;
    
    % FM调制信号
    subplot(2,3,2);
    plot(t(1:1000)*1000, modulated_signal(1:1000), 'g-', 'LineWidth', 1);
    xlabel('时间 (ms)');
    ylabel('幅度');
    title('FM调制信号');
    grid on;
    
    % 频谱
    subplot(2,3,3);
    plot(spectrum.frequencies/1000, 10*log10(spectrum.power_density), 'b-', 'LineWidth', 1);
    xlabel('频率 (kHz)');
    ylabel('功率谱密度 (dB)');
    title('FM信号频谱');
    grid on;
    
    % 误差分析
    subplot(2,3,4);
    error_signal = test_signal - recovered_signal;
    plot(t*1000, error_signal, 'r-', 'LineWidth', 1);
    xlabel('时间 (ms)');
    ylabel('误差');
    title('解调误差');
    grid on;
    
    % 散点图
    subplot(2,3,5);
    scatter(test_signal(1:10:end), recovered_signal(1:10:end), 10, 'filled');
    xlabel('原始信号');
    ylabel('恢复信号');
    title('信号散点图');
    grid on;
    axis equal;
    
    % 性能指标
    subplot(2,3,6);
    metrics = {'MSE', 'Correlation'};
    values = [mse, corr_coeff];
    bar(values);
    set(gca, 'XTickLabel', metrics);
    ylabel('数值');
    title('性能指标');
    grid on;
    
    fprintf('✓ 结果绘制完成\n');
    
catch ME
    fprintf('✗ 结果绘制失败: %s\n', ME.message);
end

%% 8. 验证工厂功能
try
    fprintf('\n--- 验证工厂功能 ---\n');
    
    % 获取FM信息
    fm_info = factory.get_waveform_info('FM');
    fprintf('✓ 获取FM信息成功\n');
    fprintf('  类名: %s\n', fm_info.class_name);
    fprintf('  类别: %s\n', fm_info.category);
    
    % 验证所有波形
    fprintf('\n验证所有波形可用性:\n');
    factory.validate_all_waveforms();
    
catch ME
    fprintf('✗ 工厂功能验证失败: %s\n', ME.message);
end

%% 9. 测试总结
fprintf('\n=== FM集成测试总结 ===\n');

% 判断测试是否通过
test_passed = true;
test_results = {};

if mse < 0.25
    fprintf('✓ 调制解调性能测试通过 (MSE: %.6f < 0.25)\n', mse);
    test_results{end+1} = 'PASS: 调制解调性能';
else
    fprintf('✗ 调制解调性能测试失败 (MSE: %.6f >= 0.25)\n', mse);
    test_results{end+1} = 'FAIL: 调制解调性能';
    test_passed = false;
end

if corr_coeff > 0.8
    fprintf('✓ 信号相关性测试通过 (相关系数: %.4f > 0.8)\n', corr_coeff);
    test_results{end+1} = 'PASS: 信号相关性';
else
    fprintf('✗ 信号相关性测试失败 (相关系数: %.4f <= 0.8)\n', corr_coeff);
    test_results{end+1} = 'FAIL: 信号相关性';
    test_passed = false;
end

if modulation_time < 0.1 && demodulation_time < 0.1
    fprintf('✓ 处理速度测试通过 (调制: %.3f ms, 解调: %.3f ms)\n', ...
            modulation_time*1000, demodulation_time*1000);
    test_results{end+1} = 'PASS: 处理速度';
else
    fprintf('✗ 处理速度测试失败 (调制: %.3f ms, 解调: %.3f ms)\n', ...
            modulation_time*1000, demodulation_time*1000);
    test_results{end+1} = 'FAIL: 处理速度';
    test_passed = false;
end

if test_passed
    fprintf('\n总体测试结果: PASS\n');
else
    fprintf('\n总体测试结果: FAIL\n');
end
fprintf('详细结果:\n');
for i = 1:length(test_results)
    fprintf('  %s\n', test_results{i});
end

fprintf('=== FM集成测试结束 ===\n');
