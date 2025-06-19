%% 简化FM调制优化测试
% 使用更合适的参数测试FM调制
%
% 作者: Asaqe Lee
% 日期: 2025-06-18

clear; clc; close all;

% 添加路径
addpath('src/waveforms/base');
addpath('src/waveforms/analog');

fprintf('=== 简化FM调制优化测试开始 ===\n');

%% 1. 创建FM调制器
try
    fm_mod = FM();
    fprintf('✓ FM调制器创建成功\n');
catch ME
    fprintf('✗ FM调制器创建失败: %s\n', ME.message);
    return;
end

%% 2. 配置合适的FM参数
config = struct();
config.center_frequency = 10e3;         % 10 kHz载波频率
config.frequency_deviation = 1e3;       % 1 kHz频偏（适中的频偏）
config.baseband_bandwidth = 500;        % 500 Hz基带带宽
config.sample_rate = 50e3;              % 50 kHz采样率（降低采样率）
config.snr_db = 30;                     % 30 dB信噪比
config.preemphasis_enabled = false;     % 禁用预加重
config.deemphasis_enabled = true;       % 启用去加重

try
    fm_mod.configure(config);
    fprintf('✓ FM参数配置成功\n');
    
    % 显示配置信息
    info = fm_mod.get_waveform_info();
    fprintf('  载波频率: %.1f kHz\n', config.center_frequency/1000);
    fprintf('  频偏: %.1f kHz\n', info.frequency_deviation/1000);
    fprintf('  调制指数: %.2f\n', info.modulation_index);
    fprintf('  FM带宽: %.1f kHz\n', info.fm_bandwidth/1000);
    
catch ME
    fprintf('✗ FM参数配置失败: %s\n', ME.message);
    return;
end

%% 3. 生成简单测试信号
fs = config.sample_rate;
t_duration = 0.1;   % 100ms
t = (0:1/fs:t_duration-1/fs)';

% 创建单一频率的正弦波（在基带带宽内）
f_mod = 100;   % 100 Hz调制频率
modulating_signal = sin(2*pi*f_mod*t);

fprintf('✓ 简单测试信号生成完成\n');
fprintf('  调制频率: %d Hz\n', f_mod);
fprintf('  信号长度: %d 样本\n', length(modulating_signal));

%% 4. FM调制
params = struct();
params.add_noise = false;  % 先不加噪声
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

%% 5. 测试希尔伯特变换解调
fprintf('\n--- 测试希尔伯特变换解调 ---\n');

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

%% 6. 测试鉴频器解调
fprintf('\n--- 测试鉴频器解调 ---\n');

try
    demod_params.demod_method = 'discriminator';
    
    tic;
    recovered_signal_disc = fm_mod.recover_data(fm_signal, demod_params);
    demod_time_disc = toc;
    
    % 性能分析
    mse_disc = fm_mod.calculate_ber(modulating_signal, recovered_signal_disc);
    correlation_disc = corrcoef(modulating_signal, recovered_signal_disc);
    corr_coeff_disc = correlation_disc(1,2);
    
    fprintf('✓ 鉴频器解调完成\n');
    fprintf('  解调时间: %.3f ms\n', demod_time_disc * 1000);
    fprintf('  MSE: %.6f\n', mse_disc);
    fprintf('  相关系数: %.4f\n', corr_coeff_disc);
    
catch ME
    fprintf('✗ 鉴频器解调失败: %s\n', ME.message);
end

%% 7. 绘制结果
try
    figure('Name', '简化FM优化测试结果', 'Position', [100, 100, 1200, 800]);
    
    % 时域信号
    subplot(2,3,1);
    plot(t*1000, modulating_signal, 'b-', 'LineWidth', 2);
    xlabel('时间 (ms)');
    ylabel('幅度');
    title('原始调制信号');
    grid on;
    
    subplot(2,3,2);
    plot(t(1:1000)*1000, fm_signal(1:1000), 'g-', 'LineWidth', 1);
    xlabel('时间 (ms)');
    ylabel('幅度');
    title('FM调制信号');
    grid on;
    
    subplot(2,3,3);
    plot(t*1000, modulating_signal, 'b-', 'LineWidth', 2);
    hold on;
    plot(t*1000, recovered_signal, 'r--', 'LineWidth', 1.5);
    plot(t*1000, recovered_signal_disc, 'm:', 'LineWidth', 1.5);
    xlabel('时间 (ms)');
    ylabel('幅度');
    title('解调结果对比');
    legend('原始', '希尔伯特', '鉴频器', 'Location', 'best');
    grid on;
    
    % 频谱分析
    subplot(2,3,4);
    spectrum = fm_mod.get_spectrum(fm_signal);
    plot(spectrum.frequencies/1000, 10*log10(spectrum.power_density), 'b-', 'LineWidth', 1);
    xlabel('频率 (kHz)');
    ylabel('功率谱密度 (dB)');
    title('FM信号频谱');
    grid on;
    xlim([5, 15]);
    
    % 误差分析
    subplot(2,3,5);
    error_hil = modulating_signal - recovered_signal;
    error_disc = modulating_signal - recovered_signal_disc;
    plot(t*1000, error_hil, 'r-', 'LineWidth', 1);
    hold on;
    plot(t*1000, error_disc, 'm--', 'LineWidth', 1);
    xlabel('时间 (ms)');
    ylabel('误差');
    title('解调误差对比');
    legend('希尔伯特', '鉴频器', 'Location', 'best');
    grid on;
    
    % 性能对比
    subplot(2,3,6);
    methods = {'希尔伯特', '鉴频器'};
    mse_values = [mse, mse_disc];
    corr_values = [corr_coeff, corr_coeff_disc];
    
    yyaxis left;
    bar(1:2, mse_values, 'FaceColor', 'b', 'FaceAlpha', 0.7);
    ylabel('MSE', 'Color', 'b');
    
    yyaxis right;
    plot(1:2, corr_values, 'ro-', 'LineWidth', 2, 'MarkerSize', 8);
    ylabel('相关系数', 'Color', 'r');
    
    set(gca, 'XTickLabel', methods);
    title('性能对比');
    grid on;
    
    fprintf('✓ 结果绘制完成\n');
    
catch ME
    fprintf('✗ 结果绘制失败: %s\n', ME.message);
end

%% 8. 性能评估
fprintf('\n=== 性能评估 ===\n');

% 选择最佳方法
if mse < mse_disc && corr_coeff > corr_coeff_disc
    best_method = '希尔伯特变换';
    best_mse = mse;
    best_corr = corr_coeff;
elseif mse_disc < mse && corr_coeff_disc > corr_coeff
    best_method = '鉴频器';
    best_mse = mse_disc;
    best_corr = corr_coeff_disc;
else
    % 综合评分
    score_hil = (1 - mse) * 0.5 + corr_coeff * 0.5;
    score_disc = (1 - mse_disc) * 0.5 + corr_coeff_disc * 0.5;
    
    if score_hil > score_disc
        best_method = '希尔伯特变换';
        best_mse = mse;
        best_corr = corr_coeff;
    else
        best_method = '鉴频器';
        best_mse = mse_disc;
        best_corr = corr_coeff_disc;
    end
end

fprintf('最佳解调方法: %s\n', best_method);
fprintf('最佳MSE: %.6f\n', best_mse);
fprintf('最佳相关系数: %.4f\n', best_corr);

% 判断优化效果
if best_mse < 0.1 && best_corr > 0.8
    fprintf('✓ FM优化成功！性能优秀\n');
    result = 'EXCELLENT';
elseif best_mse < 0.2 && best_corr > 0.7
    fprintf('✓ FM优化有效，性能良好\n');
    result = 'GOOD';
elseif best_mse < 0.5 && best_corr > 0.5
    fprintf('○ FM优化一般，性能可接受\n');
    result = 'ACCEPTABLE';
else
    fprintf('✗ FM优化效果不佳\n');
    result = 'POOR';
end

fprintf('\n优化结果: %s\n', result);
fprintf('推荐解调方法: %s\n', best_method);

% 与之前性能对比
previous_mse = 0.159821;
previous_corr = 0.6474;

if best_mse < previous_mse
    improvement_mse = (previous_mse - best_mse) / previous_mse * 100;
    fprintf('MSE改进: %.1f%%\n', improvement_mse);
else
    degradation_mse = (best_mse - previous_mse) / previous_mse * 100;
    fprintf('MSE退化: %.1f%%\n', degradation_mse);
end

if best_corr > previous_corr
    improvement_corr = (best_corr - previous_corr) / previous_corr * 100;
    fprintf('相关系数改进: %.1f%%\n', improvement_corr);
else
    degradation_corr = (previous_corr - best_corr) / previous_corr * 100;
    fprintf('相关系数退化: %.1f%%\n', degradation_corr);
end

fprintf('=== 简化FM调制优化测试结束 ===\n');
