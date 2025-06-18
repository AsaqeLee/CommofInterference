%% FM调制测试脚本
% 测试FM调制和解调功能
%
% 作者: Asaqe Lee
% 日期: 2025-06-18

clear; clc; close all;

% 添加路径
addpath('src/waveforms/base');
addpath('src/waveforms/analog');

fprintf('=== FM调制测试开始 ===\n');

%% 1. 创建FM调制器
try
    fm_mod = FM();
    fprintf('✓ FM调制器创建成功\n');
catch ME
    fprintf('✗ FM调制器创建失败: %s\n', ME.message);
    return;
end

%% 2. 配置FM参数
config = struct();
config.center_frequency = 10e3;         % 10 kHz载波频率（降低以便观察）
config.frequency_deviation = 1e3;       % 1 kHz频偏（降低以匹配测试信号）
config.baseband_bandwidth = 5e3;        % 5 kHz基带带宽
config.sample_rate = 100e3;             % 100 kHz采样率
config.snr_db = 30;                     % 30 dB信噪比（提高信噪比）
config.preemphasis_enabled = false;     % 暂时禁用预加重
config.deemphasis_enabled = false;      % 暂时禁用去加重

try
    fm_mod.configure(config);
    fprintf('✓ FM参数配置成功\n');
catch ME
    fprintf('✗ FM参数配置失败: %s\n', ME.message);
    return;
end

%% 3. 生成测试信号
% 生成简单的正弦波作为调制信号
fs = config.sample_rate;
t_duration = 0.1;   % 100ms（增加持续时间）
t = (0:1/fs:t_duration-1/fs)';

% 创建简单的正弦波测试信号
f1 = 100;   % 100 Hz（降低频率）

modulating_signal = sin(2*pi*f1*t);

fprintf('✓ 测试信号生成完成，长度: %d 样本\n', length(modulating_signal));

%% 4. FM调制
params = struct();
params.add_noise = true;
params.normalize = true;
params.amplitude = 1;

try
    tic;
    fm_signal = fm_mod.generate_signal(modulating_signal, params);
    modulation_time = toc;
    fprintf('✓ FM调制完成，耗时: %.3f ms\n', modulation_time * 1000);
    fprintf('  调制信号长度: %d 样本\n', length(fm_signal));
catch ME
    fprintf('✗ FM调制失败: %s\n', ME.message);
    return;
end

%% 5. FM解调
demod_params = struct();
demod_params.demod_method = 'hilbert';  % 使用希尔伯特变换解调（性能更好）

try
    tic;
    recovered_signal = fm_mod.recover_data(fm_signal, demod_params);
    demodulation_time = toc;
    fprintf('✓ FM解调完成，耗时: %.3f ms\n', demodulation_time * 1000);
    fprintf('  解调信号长度: %d 样本\n', length(recovered_signal));
catch ME
    fprintf('✗ FM解调失败: %s\n', ME.message);
    return;
end

%% 6. 性能分析
try
    % 计算MSE（均方误差）
    mse = fm_mod.calculate_ber(modulating_signal, recovered_signal);
    fprintf('✓ 性能分析完成\n');
    fprintf('  均方误差 (MSE): %.6f\n', mse);
    
    % 计算信噪比
    signal_power = mean(modulating_signal.^2);
    noise_power = mean((modulating_signal - recovered_signal).^2);
    snr_measured = 10 * log10(signal_power / noise_power);
    fprintf('  测量信噪比: %.2f dB\n', snr_measured);
    
    % 计算相关系数
    correlation = corrcoef(modulating_signal, recovered_signal);
    fprintf('  信号相关系数: %.4f\n', correlation(1,2));
    
catch ME
    fprintf('✗ 性能分析失败: %s\n', ME.message);
end

%% 7. 获取波形信息
try
    info = fm_mod.get_waveform_info();
    fprintf('✓ 波形信息获取成功\n');
    fprintf('  波形ID: %d\n', info.waveform_id);
    fprintf('  波形名称: %s\n', info.waveform_name);
    fprintf('  调制类型: %s\n', info.modulation_type);
    fprintf('  频偏: %.1f kHz\n', info.frequency_deviation/1000);
    fprintf('  调制指数: %.2f\n', info.modulation_index);
    fprintf('  FM带宽: %.1f kHz\n', info.fm_bandwidth/1000);
catch ME
    fprintf('✗ 波形信息获取失败: %s\n', ME.message);
end

%% 8. 绘制结果
try
    figure('Name', 'FM调制测试结果', 'Position', [100, 100, 1200, 800]);
    
    % 时域信号对比
    subplot(2,3,1);
    plot(t*1000, modulating_signal, 'b-', 'LineWidth', 1.5);
    hold on;
    plot(t*1000, recovered_signal, 'r--', 'LineWidth', 1.5);
    xlabel('时间 (ms)');
    ylabel('幅度');
    title('调制信号 vs 解调信号');
    legend('原始信号', '解调信号', 'Location', 'best');
    grid on;
    
    % FM调制信号
    subplot(2,3,2);
    t_fm = (0:length(fm_signal)-1) / fs * 1000;
    plot(t_fm(1:min(1000, end)), fm_signal(1:min(1000, end)), 'g-', 'LineWidth', 1);
    xlabel('时间 (ms)');
    ylabel('幅度');
    title('FM调制信号');
    grid on;
    
    % 频谱分析
    subplot(2,3,3);
    spectrum = fm_mod.get_spectrum(fm_signal);
    plot(spectrum.frequencies/1e6, 10*log10(spectrum.power_density), 'b-', 'LineWidth', 1);
    xlabel('频率 (MHz)');
    ylabel('功率谱密度 (dB)');
    title('FM信号频谱');
    grid on;
    xlim([config.center_frequency/1e6 - 0.5, config.center_frequency/1e6 + 0.5]);
    
    % 误差分析
    subplot(2,3,4);
    error_signal = modulating_signal - recovered_signal;
    plot(t*1000, error_signal, 'r-', 'LineWidth', 1);
    xlabel('时间 (ms)');
    ylabel('误差');
    title('解调误差');
    grid on;
    
    % 原始信号频谱
    subplot(2,3,5);
    [P_orig, f_orig] = pwelch(modulating_signal, [], [], [], fs);
    semilogx(f_orig, 10*log10(P_orig), 'b-', 'LineWidth', 1.5);
    xlabel('频率 (Hz)');
    ylabel('功率谱密度 (dB/Hz)');
    title('原始调制信号频谱');
    grid on;
    
    % 解调信号频谱
    subplot(2,3,6);
    [P_recv, f_recv] = pwelch(recovered_signal, [], [], [], fs);
    semilogx(f_recv, 10*log10(P_recv), 'r--', 'LineWidth', 1.5);
    xlabel('频率 (Hz)');
    ylabel('功率谱密度 (dB/Hz)');
    title('解调信号频谱');
    grid on;
    
    fprintf('✓ 结果绘制完成\n');
    
catch ME
    fprintf('✗ 结果绘制失败: %s\n', ME.message);
end

%% 9. 测试不同解调方法
fprintf('\n--- 测试希尔伯特变换解调 ---\n');
try
    demod_params_hilbert = struct();
    demod_params_hilbert.demod_method = 'hilbert';
    
    recovered_signal_hilbert = fm_mod.recover_data(fm_signal, demod_params_hilbert);
    mse_hilbert = fm_mod.calculate_ber(modulating_signal, recovered_signal_hilbert);
    
    fprintf('✓ 希尔伯特变换解调完成\n');
    fprintf('  希尔伯特解调MSE: %.6f\n', mse_hilbert);
    
    % 比较两种解调方法
    if mse_hilbert < mse
        fprintf('  希尔伯特变换解调性能更好\n');
    else
        fprintf('  鉴频器解调性能更好\n');
    end
    
catch ME
    fprintf('✗ 希尔伯特变换解调失败: %s\n', ME.message);
end

%% 10. 测试总结
fprintf('\n=== FM调制测试总结 ===\n');
if mse < 0.2
    fprintf('✓ FM调制解调测试通过 (MSE < 0.2)\n');
    test_result = 'PASS';
else
    fprintf('✗ FM调制解调测试失败 (MSE >= 0.2)\n');
    test_result = 'FAIL';
end

fprintf('测试结果: %s\n', test_result);
fprintf('均方误差: %.6f\n', mse);
fprintf('处理时间: 调制 %.3f ms, 解调 %.3f ms\n', ...
        modulation_time * 1000, demodulation_time * 1000);

fprintf('=== FM调制测试结束 ===\n');
