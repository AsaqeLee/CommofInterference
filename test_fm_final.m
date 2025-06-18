%% FM调制最终优化测试
% 使用最佳实践参数测试FM调制
%
% 作者: Asaqe Lee
% 日期: 2025-06-18

clear; clc; close all;

% 添加路径
addpath('src/waveforms/base');
addpath('src/waveforms/analog');

fprintf('=== FM调制最终优化测试开始 ===\n');

%% 1. 创建FM调制器
try
    fm_mod = FM();
    fprintf('✓ FM调制器创建成功\n');
catch ME
    fprintf('✗ FM调制器创建失败: %s\n', ME.message);
    return;
end

%% 2. 配置最佳FM参数
config = struct();
config.center_frequency = 10e3;         % 10 kHz载波频率
config.frequency_deviation = 500;       % 500 Hz频偏（较小的频偏）
config.baseband_bandwidth = 200;        % 200 Hz基带带宽
config.sample_rate = 50e3;              % 50 kHz采样率
config.snr_db = 30;                     % 30 dB信噪比
config.preemphasis_enabled = false;     % 禁用预加重
config.deemphasis_enabled = false;      % 禁用去加重（简化）

try
    fm_mod.configure(config);
    fprintf('✓ FM参数配置成功\n');
    
    % 显示配置信息
    info = fm_mod.get_waveform_info();
    fprintf('  载波频率: %.1f kHz\n', config.center_frequency/1000);
    fprintf('  频偏: %.0f Hz\n', info.frequency_deviation);
    fprintf('  调制指数: %.2f\n', info.modulation_index);
    fprintf('  FM带宽: %.1f kHz\n', info.fm_bandwidth/1000);
    
catch ME
    fprintf('✗ FM参数配置失败: %s\n', ME.message);
    return;
end

%% 3. 生成理想测试信号
fs = config.sample_rate;
t_duration = 0.2;   % 200ms
t = (0:1/fs:t_duration-1/fs)';

% 创建低频正弦波（远低于基带带宽）
f_mod = 50;   % 50 Hz调制频率
modulating_signal = sin(2*pi*f_mod*t);

fprintf('✓ 理想测试信号生成完成\n');
fprintf('  调制频率: %d Hz\n', f_mod);
fprintf('  信号长度: %d 样本\n', length(modulating_signal));

%% 4. FM调制（无噪声）
params = struct();
params.add_noise = false;  % 不加噪声
params.normalize = true;
params.amplitude = 1;

try
    tic;
    fm_signal = fm_mod.generate_signal(modulating_signal, params);
    modulation_time = toc;
    fprintf('✓ FM调制完成，耗时: %.3f ms\n', modulation_time * 1000);
catch ME
    fprintf('✗ FM调制失败: %s\n', ME.message);
    return;
end

%% 5. 希尔伯特变换解调
fprintf('\n--- 希尔伯特变换解调 ---\n');

try
    demod_params = struct();
    demod_params.demod_method = 'hilbert';
    
    tic;
    recovered_signal = fm_mod.recover_data(fm_signal, demod_params);
    demod_time = toc;
    
    % 性能分析
    mse = fm_mod.calculate_ber(modulating_signal, recovered_signal);
    correlation = corrcoef(modulating_signal, recovered_signal);
    corr_coeff = correlation(1,2);
    
    fprintf('✓ 希尔伯特变换解调完成\n');
    fprintf('  解调时间: %.3f ms\n', demod_time * 1000);
    fprintf('  MSE: %.6f\n', mse);
    fprintf('  相关系数: %.4f\n', corr_coeff);
    
catch ME
    fprintf('✗ 希尔伯特变换解调失败: %s\n', ME.message);
    return;
end

%% 6. 绘制详细结果
try
    figure('Name', 'FM最终优化测试结果', 'Position', [100, 100, 1400, 900]);
    
    % 原始调制信号
    subplot(3,3,1);
    plot(t*1000, modulating_signal, 'b-', 'LineWidth', 2);
    xlabel('时间 (ms)');
    ylabel('幅度');
    title('原始调制信号');
    grid on;
    
    % FM调制信号（局部）
    subplot(3,3,2);
    t_zoom = t(1:2000);
    fm_zoom = fm_signal(1:2000);
    plot(t_zoom*1000, fm_zoom, 'g-', 'LineWidth', 1);
    xlabel('时间 (ms)');
    ylabel('幅度');
    title('FM调制信号（局部）');
    grid on;
    
    % 解调结果对比
    subplot(3,3,3);
    plot(t*1000, modulating_signal, 'b-', 'LineWidth', 2);
    hold on;
    plot(t*1000, recovered_signal, 'r--', 'LineWidth', 1.5);
    xlabel('时间 (ms)');
    ylabel('幅度');
    title('解调结果对比');
    legend('原始', '解调', 'Location', 'best');
    grid on;
    
    % 瞬时频率分析
    subplot(3,3,4);
    analytic_signal = hilbert(fm_signal);
    instantaneous_phase = unwrap(angle(analytic_signal));
    instantaneous_freq = diff(instantaneous_phase) * fs / (2*pi);
    t_freq = t(1:end-1);
    plot(t_freq*1000, instantaneous_freq/1000, 'g-', 'LineWidth', 1);
    xlabel('时间 (ms)');
    ylabel('瞬时频率 (kHz)');
    title('FM信号瞬时频率');
    grid on;
    
    % 频偏分析
    subplot(3,3,5);
    freq_deviation = instantaneous_freq - config.center_frequency;
    plot(t_freq*1000, freq_deviation, 'm-', 'LineWidth', 1);
    xlabel('时间 (ms)');
    ylabel('频偏 (Hz)');
    title('频率偏移');
    grid on;
    
    % 误差分析
    subplot(3,3,6);
    error_signal = modulating_signal - recovered_signal;
    plot(t*1000, error_signal, 'r-', 'LineWidth', 1);
    xlabel('时间 (ms)');
    ylabel('误差');
    title('解调误差');
    grid on;
    
    % 频谱分析
    subplot(3,3,7);
    spectrum = fm_mod.get_spectrum(fm_signal);
    plot(spectrum.frequencies/1000, 10*log10(spectrum.power_density), 'b-', 'LineWidth', 1);
    xlabel('频率 (kHz)');
    ylabel('功率谱密度 (dB)');
    title('FM信号频谱');
    grid on;
    xlim([8, 12]);
    
    % 散点图
    subplot(3,3,8);
    scatter(modulating_signal(1:50:end), recovered_signal(1:50:end), 20, 'filled');
    xlabel('原始信号');
    ylabel('解调信号');
    title('信号散点图');
    grid on;
    axis equal;
    
    % 性能指标
    subplot(3,3,9);
    metrics = {'MSE', '相关系数', '调制指数'};
    values = [mse, corr_coeff, info.modulation_index];
    bar(values);
    set(gca, 'XTickLabel', metrics);
    ylabel('数值');
    title('性能指标');
    grid on;
    
    fprintf('✓ 详细结果绘制完成\n');
    
catch ME
    fprintf('✗ 结果绘制失败: %s\n', ME.message);
end

%% 7. 最终性能评估
fprintf('\n=== 最终性能评估 ===\n');

% 性能分级
if mse < 0.01 && corr_coeff > 0.99
    grade = 'A+';
    description = '极优秀';
elseif mse < 0.05 && corr_coeff > 0.95
    grade = 'A';
    description = '优秀';
elseif mse < 0.1 && corr_coeff > 0.9
    grade = 'B';
    description = '良好';
elseif mse < 0.2 && corr_coeff > 0.8
    grade = 'C';
    description = '可接受';
elseif mse < 0.5 && corr_coeff > 0.5
    grade = 'D';
    description = '需要改进';
else
    grade = 'F';
    description = '不合格';
end

fprintf('FM调制性能等级: %s (%s)\n', grade, description);
fprintf('MSE: %.6f\n', mse);
fprintf('相关系数: %.4f\n', corr_coeff);

% 与目标性能对比
target_mse = 0.1;
target_corr = 0.8;

if mse <= target_mse && corr_coeff >= target_corr
    fprintf('✓ 达到目标性能要求\n');
    final_result = 'PASS';
else
    fprintf('✗ 未达到目标性能要求\n');
    final_result = 'FAIL';
end

% 与之前性能对比
original_mse = 0.159821;
original_corr = 0.6474;

if mse < original_mse
    improvement_mse = (original_mse - mse) / original_mse * 100;
    fprintf('MSE改进: %.1f%% (从 %.6f 到 %.6f)\n', improvement_mse, original_mse, mse);
else
    degradation_mse = (mse - original_mse) / original_mse * 100;
    fprintf('MSE变化: +%.1f%% (从 %.6f 到 %.6f)\n', degradation_mse, original_mse, mse);
end

if corr_coeff > original_corr
    improvement_corr = (corr_coeff - original_corr) / original_corr * 100;
    fprintf('相关系数改进: %.1f%% (从 %.4f 到 %.4f)\n', improvement_corr, original_corr, corr_coeff);
else
    degradation_corr = (original_corr - corr_coeff) / original_corr * 100;
    fprintf('相关系数变化: -%.1f%% (从 %.4f 到 %.4f)\n', degradation_corr, original_corr, corr_coeff);
end

%% 8. 优化建议
fprintf('\n=== 优化建议 ===\n');

if strcmp(final_result, 'PASS')
    fprintf('✓ FM调制性能已达标，建议：\n');
    fprintf('  - 可以尝试更高的调制指数\n');
    fprintf('  - 可以添加预加重/去加重处理\n');
    fprintf('  - 可以测试更复杂的调制信号\n');
else
    fprintf('✗ FM调制性能需要进一步优化，建议：\n');
    fprintf('  - 降低调制指数（当前: %.2f）\n', info.modulation_index);
    fprintf('  - 使用更低的调制频率\n');
    fprintf('  - 优化滤波器设计\n');
    fprintf('  - 检查载波频率设置\n');
end

fprintf('\n最终结果: %s\n', final_result);
fprintf('性能等级: %s\n', grade);
fprintf('=== FM调制最终优化测试结束 ===\n');
