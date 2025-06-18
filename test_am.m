%% AM调制测试脚本
% 测试AM调制和解调功能
%
% 作者: Asaqe Lee
% 日期: 2025-06-18

clear; clc; close all;

% 添加路径
addpath('src/waveforms/base');
addpath('src/waveforms/analog');

fprintf('=== AM调制测试开始 ===\n');

%% 1. 创建AM调制器
try
    am_mod = AM();
    fprintf('✓ AM调制器创建成功\n');
catch ME
    fprintf('✗ AM调制器创建失败: %s\n', ME.message);
    return;
end

%% 2. 配置AM参数
config = struct();
config.center_frequency = 10e3;         % 10 kHz载波频率
config.modulation_depth = 0.8;          % 80%调制深度
config.carrier_amplitude = 1.0;         % 载波幅度
config.baseband_bandwidth = 2e3;        % 2 kHz基带带宽
config.sample_rate = 100e3;             % 100 kHz采样率
config.snr_db = 25;                     % 25 dB信噪比
config.am_type = 'DSB-FC';              % 双边带全载波

try
    am_mod.configure(config);
    fprintf('✓ AM参数配置成功\n');
catch ME
    fprintf('✗ AM参数配置失败: %s\n', ME.message);
    return;
end

%% 3. 生成测试信号
% 生成复合音频信号作为调制信号
fs = config.sample_rate;
t_duration = 0.05;  % 50ms
t = (0:1/fs:t_duration-1/fs)';

% 创建包含多个频率分量的测试信号
f1 = 300;   % 300 Hz
f2 = 800;   % 800 Hz
f3 = 1500;  % 1.5 kHz

modulating_signal = 0.4 * sin(2*pi*f1*t) + ...
                   0.3 * sin(2*pi*f2*t) + ...
                   0.2 * sin(2*pi*f3*t);

fprintf('✓ 测试信号生成完成，长度: %d 样本\n', length(modulating_signal));

%% 4. AM调制
params = struct();
params.add_noise = true;
params.normalize = true;
params.amplitude = 1;

try
    tic;
    am_signal = am_mod.generate_signal(modulating_signal, params);
    modulation_time = toc;
    fprintf('✓ AM调制完成，耗时: %.3f ms\n', modulation_time * 1000);
    fprintf('  调制信号长度: %d 样本\n', length(am_signal));
catch ME
    fprintf('✗ AM调制失败: %s\n', ME.message);
    return;
end

%% 5. AM解调测试 - 包络检波
demod_params = struct();
demod_params.demod_method = 'envelope';

try
    tic;
    recovered_signal_env = am_mod.recover_data(am_signal, demod_params);
    demod_time_env = toc;
    fprintf('✓ 包络检波解调完成，耗时: %.3f ms\n', demod_time_env * 1000);
    
    % 性能分析
    mse_env = am_mod.calculate_ber(modulating_signal, recovered_signal_env);
    correlation_env = corrcoef(modulating_signal, recovered_signal_env);
    corr_coeff_env = correlation_env(1,2);
    
    fprintf('  包络检波MSE: %.6f\n', mse_env);
    fprintf('  包络检波相关系数: %.4f\n', corr_coeff_env);
    
catch ME
    fprintf('✗ 包络检波解调失败: %s\n', ME.message);
    return;
end

%% 6. AM解调测试 - 相干解调
demod_params.demod_method = 'coherent';

try
    tic;
    recovered_signal_coh = am_mod.recover_data(am_signal, demod_params);
    demod_time_coh = toc;
    fprintf('✓ 相干解调完成，耗时: %.3f ms\n', demod_time_coh * 1000);
    
    % 性能分析
    mse_coh = am_mod.calculate_ber(modulating_signal, recovered_signal_coh);
    correlation_coh = corrcoef(modulating_signal, recovered_signal_coh);
    corr_coeff_coh = correlation_coh(1,2);
    
    fprintf('  相干解调MSE: %.6f\n', mse_coh);
    fprintf('  相干解调相关系数: %.4f\n', corr_coeff_coh);
    
catch ME
    fprintf('✗ 相干解调失败: %s\n', ME.message);
end

%% 7. AM解调测试 - 希尔伯特变换
demod_params.demod_method = 'hilbert';

try
    tic;
    recovered_signal_hil = am_mod.recover_data(am_signal, demod_params);
    demod_time_hil = toc;
    fprintf('✓ 希尔伯特变换解调完成，耗时: %.3f ms\n', demod_time_hil * 1000);
    
    % 性能分析
    mse_hil = am_mod.calculate_ber(modulating_signal, recovered_signal_hil);
    correlation_hil = corrcoef(modulating_signal, recovered_signal_hil);
    corr_coeff_hil = correlation_hil(1,2);
    
    fprintf('  希尔伯特解调MSE: %.6f\n', mse_hil);
    fprintf('  希尔伯特解调相关系数: %.4f\n', corr_coeff_hil);
    
catch ME
    fprintf('✗ 希尔伯特变换解调失败: %s\n', ME.message);
end

%% 8. 获取波形信息
try
    info = am_mod.get_waveform_info();
    fprintf('✓ 波形信息获取成功\n');
    fprintf('  波形ID: %d\n', info.waveform_id);
    fprintf('  波形名称: %s\n', info.waveform_name);
    fprintf('  调制类型: %s\n', info.modulation_type);
    fprintf('  AM类型: %s\n', info.am_type);
    fprintf('  调制深度: %.1f%%\n', info.modulation_depth * 100);
    fprintf('  AM带宽: %.1f kHz\n', info.am_bandwidth/1000);
catch ME
    fprintf('✗ 波形信息获取失败: %s\n', ME.message);
end

%% 9. 绘制结果
try
    figure('Name', 'AM调制测试结果', 'Position', [100, 100, 1400, 900]);
    
    % 时域信号对比
    subplot(3,4,1);
    plot(t*1000, modulating_signal, 'b-', 'LineWidth', 2);
    xlabel('时间 (ms)');
    ylabel('幅度');
    title('原始调制信号');
    grid on;
    
    % AM调制信号
    subplot(3,4,2);
    plot(t(1:1000)*1000, am_signal(1:1000), 'g-', 'LineWidth', 1);
    xlabel('时间 (ms)');
    ylabel('幅度');
    title('AM调制信号');
    grid on;
    
    % 包络检波结果
    subplot(3,4,3);
    plot(t*1000, modulating_signal, 'b-', 'LineWidth', 2);
    hold on;
    plot(t*1000, recovered_signal_env, 'r--', 'LineWidth', 1.5);
    xlabel('时间 (ms)');
    ylabel('幅度');
    title('包络检波结果');
    legend('原始', '恢复', 'Location', 'best');
    grid on;
    
    % 相干解调结果
    subplot(3,4,4);
    plot(t*1000, modulating_signal, 'b-', 'LineWidth', 2);
    hold on;
    plot(t*1000, recovered_signal_coh, 'm--', 'LineWidth', 1.5);
    xlabel('时间 (ms)');
    ylabel('幅度');
    title('相干解调结果');
    legend('原始', '恢复', 'Location', 'best');
    grid on;
    
    % 频谱分析
    subplot(3,4,5);
    spectrum = am_mod.get_spectrum(am_signal);
    plot(spectrum.frequencies/1000, 10*log10(spectrum.power_density), 'b-', 'LineWidth', 1);
    xlabel('频率 (kHz)');
    ylabel('功率谱密度 (dB)');
    title('AM信号频谱');
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
    
    % 误差分析 - 包络检波
    subplot(3,4,7);
    error_env = modulating_signal - recovered_signal_env;
    plot(t*1000, error_env, 'r-', 'LineWidth', 1);
    xlabel('时间 (ms)');
    ylabel('误差');
    title('包络检波误差');
    grid on;
    
    % 误差分析 - 相干解调
    subplot(3,4,8);
    error_coh = modulating_signal - recovered_signal_coh;
    plot(t*1000, error_coh, 'm-', 'LineWidth', 1);
    xlabel('时间 (ms)');
    ylabel('误差');
    title('相干解调误差');
    grid on;
    
    % 性能对比
    subplot(3,4,9);
    methods = {'包络检波', '相干解调', '希尔伯特'};
    mse_values = [mse_env, mse_coh, mse_hil];
    bar(mse_values);
    set(gca, 'XTickLabel', methods);
    ylabel('MSE');
    title('解调方法MSE对比');
    grid on;
    
    % 相关系数对比
    subplot(3,4,10);
    corr_values = [corr_coeff_env, corr_coeff_coh, corr_coeff_hil];
    bar(corr_values);
    set(gca, 'XTickLabel', methods);
    ylabel('相关系数');
    title('解调方法相关系数对比');
    grid on;
    
    % 散点图 - 包络检波
    subplot(3,4,11);
    scatter(modulating_signal(1:10:end), recovered_signal_env(1:10:end), 10, 'filled');
    xlabel('原始信号');
    ylabel('恢复信号');
    title('包络检波散点图');
    grid on;
    axis equal;
    
    % 散点图 - 相干解调
    subplot(3,4,12);
    scatter(modulating_signal(1:10:end), recovered_signal_coh(1:10:end), 10, 'filled');
    xlabel('原始信号');
    ylabel('恢复信号');
    title('相干解调散点图');
    grid on;
    axis equal;
    
    fprintf('✓ 结果绘制完成\n');
    
catch ME
    fprintf('✗ 结果绘制失败: %s\n', ME.message);
end

%% 10. 测试不同AM类型
fprintf('\n--- 测试不同AM类型 ---\n');

am_types = {'DSB-FC', 'DSB-SC', 'SSB-USB', 'SSB-LSB'};
type_results = struct();

for i = 1:length(am_types)
    try
        % 配置AM类型
        config.am_type = am_types{i};
        am_mod.configure(config);
        
        % 调制和解调
        am_signal_type = am_mod.generate_signal(modulating_signal, params);
        
        % 选择合适的解调方法
        if strcmp(am_types{i}, 'DSB-FC')
            demod_params.demod_method = 'envelope';
        else
            demod_params.demod_method = 'coherent';
        end
        
        recovered_type = am_mod.recover_data(am_signal_type, demod_params);
        mse_type = am_mod.calculate_ber(modulating_signal, recovered_type);
        
        % 将字段名转换为有效的MATLAB字段名
        field_name = strrep(am_types{i}, '-', '_');
        type_results.(field_name) = mse_type;
        fprintf('✓ %s: MSE = %.6f\n', am_types{i}, mse_type);

    catch ME
        fprintf('✗ %s 测试失败: %s\n', am_types{i}, ME.message);
        field_name = strrep(am_types{i}, '-', '_');
        type_results.(field_name) = NaN;
    end
end

%% 11. 测试总结
fprintf('\n=== AM调制测试总结 ===\n');

% 选择最佳解调方法
best_mse = min([mse_env, mse_coh, mse_hil]);
if best_mse == mse_env
    best_method = '包络检波';
    best_corr = corr_coeff_env;
elseif best_mse == mse_coh
    best_method = '相干解调';
    best_corr = corr_coeff_coh;
else
    best_method = '希尔伯特变换';
    best_corr = corr_coeff_hil;
end

fprintf('最佳解调方法: %s\n', best_method);
fprintf('最佳MSE: %.6f\n', best_mse);
fprintf('最佳相关系数: %.4f\n', best_corr);

% 判断测试是否通过
if best_mse < 0.3 && best_corr > 0.7
    fprintf('✓ AM调制解调测试通过\n');
    test_result = 'PASS';
else
    fprintf('✗ AM调制解调测试失败\n');
    test_result = 'FAIL';
end

fprintf('测试结果: %s\n', test_result);
fprintf('处理时间: 调制 %.3f ms, 解调 %.3f ms\n', ...
        modulation_time * 1000, demod_time_env * 1000);

fprintf('=== AM调制测试结束 ===\n');
