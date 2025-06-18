%% PM调制测试脚本
% 测试PM调制和解调功能
%
% 作者: Asaqe Lee
% 日期: 2025-06-18

clear; clc; close all;

% 添加路径
addpath('src/waveforms/base');
addpath('src/waveforms/analog');

fprintf('=== PM调制测试开始 ===\n');

%% 1. 创建PM调制器
try
    pm_mod = PM();
    fprintf('✓ PM调制器创建成功\n');
catch ME
    fprintf('✗ PM调制器创建失败: %s\n', ME.message);
    return;
end

%% 2. 配置PM参数
config = struct();
config.center_frequency = 10e3;         % 10 kHz载波频率
config.phase_deviation = pi/3;          % π/3弧度相位偏移
config.carrier_amplitude = 1.0;         % 载波幅度
config.baseband_bandwidth = 2e3;        % 2 kHz基带带宽
config.sample_rate = 100e3;             % 100 kHz采样率
config.snr_db = 25;                     % 25 dB信噪比

try
    pm_mod.configure(config);
    fprintf('✓ PM参数配置成功\n');
catch ME
    fprintf('✗ PM参数配置失败: %s\n', ME.message);
    return;
end

%% 3. 生成测试信号
% 生成简单的正弦波作为调制信号
fs = config.sample_rate;
t_duration = 0.05;  % 50ms
t = (0:1/fs:t_duration-1/fs)';

% 创建测试信号
f1 = 500;   % 500 Hz
f2 = 1200;  % 1.2 kHz

modulating_signal = 0.6 * sin(2*pi*f1*t) + 0.4 * sin(2*pi*f2*t);

fprintf('✓ 测试信号生成完成，长度: %d 样本\n', length(modulating_signal));

%% 4. PM调制
params = struct();
params.add_noise = true;
params.normalize = true;
params.amplitude = 1;

try
    tic;
    pm_signal = pm_mod.generate_signal(modulating_signal, params);
    modulation_time = toc;
    fprintf('✓ PM调制完成，耗时: %.3f ms\n', modulation_time * 1000);
    fprintf('  调制信号长度: %d 样本\n', length(pm_signal));
catch ME
    fprintf('✗ PM调制失败: %s\n', ME.message);
    return;
end

%% 5. PM解调测试 - 相位检测器
demod_params = struct();
demod_params.demod_method = 'phase_detector';

try
    tic;
    recovered_signal_pd = pm_mod.recover_data(pm_signal, demod_params);
    demod_time_pd = toc;
    fprintf('✓ 相位检测器解调完成，耗时: %.3f ms\n', demod_time_pd * 1000);
    
    % 性能分析
    mse_pd = pm_mod.calculate_ber(modulating_signal, recovered_signal_pd);
    correlation_pd = corrcoef(modulating_signal, recovered_signal_pd);
    corr_coeff_pd = correlation_pd(1,2);
    
    fprintf('  相位检测器MSE: %.6f\n', mse_pd);
    fprintf('  相位检测器相关系数: %.4f\n', corr_coeff_pd);
    
catch ME
    fprintf('✗ 相位检测器解调失败: %s\n', ME.message);
    return;
end

%% 6. PM解调测试 - 希尔伯特变换
demod_params.demod_method = 'hilbert';

try
    tic;
    recovered_signal_hil = pm_mod.recover_data(pm_signal, demod_params);
    demod_time_hil = toc;
    fprintf('✓ 希尔伯特变换解调完成，耗时: %.3f ms\n', demod_time_hil * 1000);
    
    % 性能分析
    mse_hil = pm_mod.calculate_ber(modulating_signal, recovered_signal_hil);
    correlation_hil = corrcoef(modulating_signal, recovered_signal_hil);
    corr_coeff_hil = correlation_hil(1,2);
    
    fprintf('  希尔伯特变换MSE: %.6f\n', mse_hil);
    fprintf('  希尔伯特变换相关系数: %.4f\n', corr_coeff_hil);
    
catch ME
    fprintf('✗ 希尔伯特变换解调失败: %s\n', ME.message);
end

%% 7. PM解调测试 - 差分解调
demod_params.demod_method = 'differential';

try
    tic;
    recovered_signal_diff = pm_mod.recover_data(pm_signal, demod_params);
    demod_time_diff = toc;
    fprintf('✓ 差分解调完成，耗时: %.3f ms\n', demod_time_diff * 1000);
    
    % 性能分析
    mse_diff = pm_mod.calculate_ber(modulating_signal, recovered_signal_diff);
    correlation_diff = corrcoef(modulating_signal, recovered_signal_diff);
    corr_coeff_diff = correlation_diff(1,2);
    
    fprintf('  差分解调MSE: %.6f\n', mse_diff);
    fprintf('  差分解调相关系数: %.4f\n', corr_coeff_diff);
    
catch ME
    fprintf('✗ 差分解调失败: %s\n', ME.message);
end

%% 8. 获取波形信息
try
    info = pm_mod.get_waveform_info();
    fprintf('✓ 波形信息获取成功\n');
    fprintf('  波形ID: %d\n', info.waveform_id);
    fprintf('  波形名称: %s\n', info.waveform_name);
    fprintf('  调制类型: %s\n', info.modulation_type);
    fprintf('  相位偏移: %.2f 弧度 (%.1f 度)\n', info.phase_deviation, info.phase_deviation*180/pi);
    fprintf('  调制指数: %.2f\n', info.modulation_index);
    fprintf('  PM带宽: %.1f kHz\n', info.pm_bandwidth/1000);
catch ME
    fprintf('✗ 波形信息获取失败: %s\n', ME.message);
end

%% 9. 绘制结果
try
    figure('Name', 'PM调制测试结果', 'Position', [100, 100, 1400, 900]);
    
    % 时域信号对比
    subplot(3,4,1);
    plot(t*1000, modulating_signal, 'b-', 'LineWidth', 2);
    xlabel('时间 (ms)');
    ylabel('幅度');
    title('原始调制信号');
    grid on;
    
    % PM调制信号
    subplot(3,4,2);
    plot(t(1:1000)*1000, pm_signal(1:1000), 'g-', 'LineWidth', 1);
    xlabel('时间 (ms)');
    ylabel('幅度');
    title('PM调制信号');
    grid on;
    
    % 相位检测器结果
    subplot(3,4,3);
    plot(t*1000, modulating_signal, 'b-', 'LineWidth', 2);
    hold on;
    plot(t*1000, recovered_signal_pd, 'r--', 'LineWidth', 1.5);
    xlabel('时间 (ms)');
    ylabel('幅度');
    title('相位检测器结果');
    legend('原始', '恢复', 'Location', 'best');
    grid on;
    
    % 希尔伯特变换结果
    subplot(3,4,4);
    plot(t*1000, modulating_signal, 'b-', 'LineWidth', 2);
    hold on;
    plot(t*1000, recovered_signal_hil, 'm--', 'LineWidth', 1.5);
    xlabel('时间 (ms)');
    ylabel('幅度');
    title('希尔伯特变换结果');
    legend('原始', '恢复', 'Location', 'best');
    grid on;
    
    % 频谱分析
    subplot(3,4,5);
    spectrum = pm_mod.get_spectrum(pm_signal);
    plot(spectrum.frequencies/1000, 10*log10(spectrum.power_density), 'b-', 'LineWidth', 1);
    xlabel('频率 (kHz)');
    ylabel('功率谱密度 (dB)');
    title('PM信号频谱');
    grid on;
    xlim([config.center_frequency/1000 - 5, config.center_frequency/1000 + 5]);
    
    % 原始信号频谱
    subplot(3,4,6);
    [P_orig, f_orig] = pwelch(modulating_signal, [], [], [], fs);
    semilogx(f_orig, 10*log10(P_orig), 'b-', 'LineWidth', 1.5);
    xlabel('频率 (Hz)');
    ylabel('功率谱密度 (dB/Hz)');
    title('原始信号频谱');
    grid on;
    
    % 误差分析 - 相位检测器
    subplot(3,4,7);
    error_pd = modulating_signal - recovered_signal_pd;
    plot(t*1000, error_pd, 'r-', 'LineWidth', 1);
    xlabel('时间 (ms)');
    ylabel('误差');
    title('相位检测器误差');
    grid on;
    
    % 误差分析 - 希尔伯特变换
    subplot(3,4,8);
    error_hil = modulating_signal - recovered_signal_hil;
    plot(t*1000, error_hil, 'm-', 'LineWidth', 1);
    xlabel('时间 (ms)');
    ylabel('误差');
    title('希尔伯特变换误差');
    grid on;
    
    % 性能对比
    subplot(3,4,9);
    methods = {'相位检测器', '希尔伯特', '差分解调'};
    mse_values = [mse_pd, mse_hil, mse_diff];
    bar(mse_values);
    set(gca, 'XTickLabel', methods);
    ylabel('MSE');
    title('解调方法MSE对比');
    grid on;
    
    % 相关系数对比
    subplot(3,4,10);
    corr_values = [corr_coeff_pd, corr_coeff_hil, corr_coeff_diff];
    bar(corr_values);
    set(gca, 'XTickLabel', methods);
    ylabel('相关系数');
    title('解调方法相关系数对比');
    grid on;
    
    % 散点图 - 相位检测器
    subplot(3,4,11);
    scatter(modulating_signal(1:10:end), recovered_signal_pd(1:10:end), 10, 'filled');
    xlabel('原始信号');
    ylabel('恢复信号');
    title('相位检测器散点图');
    grid on;
    axis equal;
    
    % 瞬时相位分析
    subplot(3,4,12);
    analytic_signal = hilbert(pm_signal);
    instantaneous_phase = unwrap(angle(analytic_signal));
    plot(t(1:1000)*1000, instantaneous_phase(1:1000), 'g-', 'LineWidth', 1);
    xlabel('时间 (ms)');
    ylabel('相位 (弧度)');
    title('PM信号瞬时相位');
    grid on;
    
    fprintf('✓ 结果绘制完成\n');
    
catch ME
    fprintf('✗ 结果绘制失败: %s\n', ME.message);
end

%% 10. 测试不同相位偏移
fprintf('\n--- 测试不同相位偏移 ---\n');

phase_deviations = [pi/6, pi/4, pi/3, pi/2];  % 30°, 45°, 60°, 90°
phase_results = struct();

for i = 1:length(phase_deviations)
    try
        % 配置相位偏移
        config.phase_deviation = phase_deviations(i);
        pm_mod.configure(config);
        
        % 调制和解调
        pm_signal_phase = pm_mod.generate_signal(modulating_signal, params);
        recovered_phase = pm_mod.recover_data(pm_signal_phase, demod_params);
        mse_phase = pm_mod.calculate_ber(modulating_signal, recovered_phase);
        
        phase_name = sprintf('phase_%.0f_deg', phase_deviations(i)*180/pi);
        phase_results.(phase_name) = mse_phase;
        fprintf('✓ %.0f度: MSE = %.6f\n', phase_deviations(i)*180/pi, mse_phase);
        
    catch ME
        fprintf('✗ %.0f度 测试失败: %s\n', phase_deviations(i)*180/pi, ME.message);
    end
end

%% 11. 测试总结
fprintf('\n=== PM调制测试总结 ===\n');

% 选择最佳解调方法
best_mse = min([mse_pd, mse_hil, mse_diff]);
if best_mse == mse_pd
    best_method = '相位检测器';
    best_corr = corr_coeff_pd;
elseif best_mse == mse_hil
    best_method = '希尔伯特变换';
    best_corr = corr_coeff_hil;
else
    best_method = '差分解调';
    best_corr = corr_coeff_diff;
end

fprintf('最佳解调方法: %s\n', best_method);
fprintf('最佳MSE: %.6f\n', best_mse);
fprintf('最佳相关系数: %.4f\n', best_corr);

% 判断测试是否通过
if best_mse < 0.3 && best_corr > 0.7
    fprintf('✓ PM调制解调测试通过\n');
    test_result = 'PASS';
else
    fprintf('✗ PM调制解调测试失败\n');
    test_result = 'FAIL';
end

fprintf('测试结果: %s\n', test_result);
fprintf('处理时间: 调制 %.3f ms, 解调 %.3f ms\n', ...
        modulation_time * 1000, demod_time_pd * 1000);

fprintf('=== PM调制测试结束 ===\n');
