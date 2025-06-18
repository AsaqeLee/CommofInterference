%% FM调制优化测试脚本
% 测试优化后的FM调制和解调功能
%
% 作者: Asaqe Lee
% 日期: 2025-06-18

clear; clc; close all;

% 添加路径
addpath('src/waveforms/base');
addpath('src/waveforms/analog');

fprintf('=== FM调制优化测试开始 ===\n');

%% 1. 创建优化的FM调制器
try
    fm_mod = FM();
    fprintf('✓ 优化FM调制器创建成功\n');
catch ME
    fprintf('✗ 优化FM调制器创建失败: %s\n', ME.message);
    return;
end

%% 2. 配置优化的FM参数
config = struct();
config.center_frequency = 10e3;         % 10 kHz载波频率
config.frequency_deviation = 2e3;       % 2 kHz频偏（降低以匹配测试信号）
config.baseband_bandwidth = 1e3;        % 1 kHz基带带宽
config.sample_rate = 100e3;             % 100 kHz采样率
config.snr_db = 30;                     % 30 dB信噪比（提高信噪比）
config.preemphasis_enabled = false;     % 禁用预加重（简化）
config.deemphasis_enabled = true;       % 启用去加重

try
    fm_mod.configure(config);
    fprintf('✓ 优化FM参数配置成功\n');
catch ME
    fprintf('✗ 优化FM参数配置失败: %s\n', ME.message);
    return;
end

%% 3. 生成优化的测试信号
% 生成简单的正弦波作为调制信号
fs = config.sample_rate;
t_duration = 0.02;   % 20ms
t = (0:1/fs:t_duration-1/fs)';

% 创建简单的正弦波测试信号（频率在基带带宽内）
f1 = 200;   % 200 Hz
f2 = 500;   % 500 Hz

modulating_signal = 0.6 * sin(2*pi*f1*t) + 0.4 * sin(2*pi*f2*t);

fprintf('✓ 优化测试信号生成完成，长度: %d 样本\n', length(modulating_signal));

%% 4. FM调制
params = struct();
params.add_noise = true;
params.normalize = true;
params.amplitude = 1;

try
    tic;
    fm_signal = fm_mod.generate_signal(modulating_signal, params);
    modulation_time = toc;
    fprintf('✓ 优化FM调制完成，耗时: %.3f ms\n', modulation_time * 1000);
    fprintf('  调制信号长度: %d 样本\n', length(fm_signal));
catch ME
    fprintf('✗ 优化FM调制失败: %s\n', ME.message);
    return;
end

%% 5. 测试所有解调方法
demod_methods = {'discriminator', 'hilbert', 'pll'};
results = struct();

for i = 1:length(demod_methods)
    method = demod_methods{i};
    fprintf('\n--- 测试 %s 解调方法 ---\n', method);
    
    try
        demod_params = struct();
        demod_params.demod_method = method;
        
        tic;
        recovered_signal = fm_mod.recover_data(fm_signal, demod_params);
        demod_time = toc;
        
        % 性能分析
        mse = fm_mod.calculate_ber(modulating_signal, recovered_signal);
        correlation = corrcoef(modulating_signal, recovered_signal);
        corr_coeff = correlation(1,2);
        
        % 保存结果
        results.(method) = struct();
        results.(method).recovered_signal = recovered_signal;
        results.(method).mse = mse;
        results.(method).correlation = corr_coeff;
        results.(method).demod_time = demod_time;
        
        fprintf('✓ %s解调完成，耗时: %.3f ms\n', method, demod_time * 1000);
        fprintf('  MSE: %.6f\n', mse);
        fprintf('  相关系数: %.4f\n', corr_coeff);
        
    catch ME
        fprintf('✗ %s解调失败: %s\n', method, ME.message);
        results.(method) = struct();
        results.(method).mse = NaN;
        results.(method).correlation = NaN;
    end
end

%% 6. 性能对比分析
fprintf('\n=== 解调方法性能对比 ===\n');

% 提取有效结果
valid_methods = {};
mse_values = [];
corr_values = [];
time_values = [];

for i = 1:length(demod_methods)
    method = demod_methods{i};
    if isfield(results.(method), 'mse') && ~isnan(results.(method).mse)
        valid_methods{end+1} = method;
        mse_values(end+1) = results.(method).mse;
        corr_values(end+1) = results.(method).correlation;
        time_values(end+1) = results.(method).demod_time * 1000;
    end
end

% 性能排名
if ~isempty(mse_values)
    [~, mse_rank] = sort(mse_values);
    [~, corr_rank] = sort(corr_values, 'descend');
    
    fprintf('MSE排名 (越小越好):\n');
    for i = 1:length(mse_rank)
        idx = mse_rank(i);
        fprintf('  %d. %s: %.6f\n', i, valid_methods{idx}, mse_values(idx));
    end
    
    fprintf('\n相关系数排名 (越大越好):\n');
    for i = 1:length(corr_rank)
        idx = corr_rank(i);
        fprintf('  %d. %s: %.4f\n', i, valid_methods{idx}, corr_values(idx));
    end
    
    % 找出最佳方法
    [best_mse, best_idx] = min(mse_values);
    best_method = valid_methods{best_idx};
    best_corr = corr_values(best_idx);
    
    fprintf('\n最佳解调方法: %s\n', best_method);
    fprintf('最佳MSE: %.6f\n', best_mse);
    fprintf('最佳相关系数: %.4f\n', best_corr);
end

%% 7. 获取波形信息
try
    info = fm_mod.get_waveform_info();
    fprintf('\n✓ 优化波形信息获取成功\n');
    fprintf('  波形ID: %d\n', info.waveform_id);
    fprintf('  波形名称: %s\n', info.waveform_name);
    fprintf('  调制类型: %s\n', info.modulation_type);
    fprintf('  频偏: %.1f kHz\n', info.frequency_deviation/1000);
    fprintf('  调制指数: %.2f\n', info.modulation_index);
    fprintf('  FM带宽: %.1f kHz\n', info.fm_bandwidth/1000);
catch ME
    fprintf('✗ 波形信息获取失败: %s\n', ME.message);
end

%% 8. 绘制优化结果
try
    figure('Name', 'FM调制优化测试结果', 'Position', [100, 100, 1400, 1000]);
    
    % 时域信号对比
    subplot(3,4,1);
    plot(t*1000, modulating_signal, 'b-', 'LineWidth', 2);
    xlabel('时间 (ms)');
    ylabel('幅度');
    title('原始调制信号');
    grid on;
    
    % FM调制信号
    subplot(3,4,2);
    plot(t(1:800)*1000, fm_signal(1:800), 'g-', 'LineWidth', 1);
    xlabel('时间 (ms)');
    ylabel('幅度');
    title('优化FM调制信号');
    grid on;
    
    % 解调结果对比
    colors = {'r', 'm', 'c'};
    subplot(3,4,3);
    plot(t*1000, modulating_signal, 'b-', 'LineWidth', 2);
    hold on;
    for i = 1:length(valid_methods)
        method = valid_methods{i};
        if isfield(results.(method), 'recovered_signal')
            plot(t*1000, results.(method).recovered_signal, ...
                 [colors{i} '--'], 'LineWidth', 1.5);
        end
    end
    xlabel('时间 (ms)');
    ylabel('幅度');
    title('解调结果对比');
    legend(['原始', valid_methods], 'Location', 'best');
    grid on;
    
    % MSE对比
    subplot(3,4,4);
    if ~isempty(mse_values)
        bar(mse_values);
        set(gca, 'XTickLabel', valid_methods);
        ylabel('MSE');
        title('MSE对比');
        grid on;
    end
    
    % 相关系数对比
    subplot(3,4,5);
    if ~isempty(corr_values)
        bar(corr_values);
        set(gca, 'XTickLabel', valid_methods);
        ylabel('相关系数');
        title('相关系数对比');
        grid on;
    end
    
    % 处理时间对比
    subplot(3,4,6);
    if ~isempty(time_values)
        bar(time_values);
        set(gca, 'XTickLabel', valid_methods);
        ylabel('时间 (ms)');
        title('解调时间对比');
        grid on;
    end
    
    % 频谱分析
    subplot(3,4,7);
    spectrum = fm_mod.get_spectrum(fm_signal);
    plot(spectrum.frequencies/1000, 10*log10(spectrum.power_density), 'b-', 'LineWidth', 1);
    xlabel('频率 (kHz)');
    ylabel('功率谱密度 (dB)');
    title('优化FM信号频谱');
    grid on;
    xlim([config.center_frequency/1000 - 5, config.center_frequency/1000 + 5]);
    
    % 原始信号频谱
    subplot(3,4,8);
    [P_orig, f_orig] = pwelch(modulating_signal, [], [], [], fs);
    semilogx(f_orig, 10*log10(P_orig), 'b-', 'LineWidth', 1.5);
    xlabel('频率 (Hz)');
    ylabel('功率谱密度 (dB/Hz)');
    title('原始信号频谱');
    grid on;
    
    % 散点图对比
    for i = 1:min(3, length(valid_methods))
        subplot(3,4,8+i);
        method = valid_methods{i};
        if isfield(results.(method), 'recovered_signal')
            scatter(modulating_signal(1:10:end), results.(method).recovered_signal(1:10:end), ...
                    10, colors{i}, 'filled');
            xlabel('原始信号');
            ylabel('恢复信号');
            title([method ' 散点图']);
            grid on;
            axis equal;
        end
    end
    
    % 性能汇总
    subplot(3,4,12);
    axis off;
    if ~isempty(valid_methods)
        summary_text = {'FM优化结果汇总:', ''};
        for i = 1:length(valid_methods)
            method = valid_methods{i};
            summary_text{end+1} = sprintf('%s:', method);
            summary_text{end+1} = sprintf('  MSE: %.6f', mse_values(i));
            summary_text{end+1} = sprintf('  相关系数: %.4f', corr_values(i));
            summary_text{end+1} = sprintf('  时间: %.1f ms', time_values(i));
            summary_text{end+1} = '';
        end
        text(0.1, 0.9, summary_text, 'FontSize', 10, 'VerticalAlignment', 'top');
    end
    title('性能汇总');
    
    fprintf('✓ 优化结果绘制完成\n');
    
catch ME
    fprintf('✗ 结果绘制失败: %s\n', ME.message);
end

%% 9. 优化效果评估
fprintf('\n=== FM优化效果评估 ===\n');

if ~isempty(mse_values)
    % 与之前的性能对比
    previous_mse = 0.159821;  % 之前的MSE
    previous_corr = 0.6474;   % 之前的相关系数
    
    improvement_mse = (previous_mse - best_mse) / previous_mse * 100;
    improvement_corr = (best_corr - previous_corr) / previous_corr * 100;
    
    fprintf('性能改进情况:\n');
    fprintf('  MSE改进: %.1f%% (从 %.6f 到 %.6f)\n', improvement_mse, previous_mse, best_mse);
    fprintf('  相关系数改进: %.1f%% (从 %.4f 到 %.4f)\n', improvement_corr, previous_corr, best_corr);
    
    % 判断优化是否成功
    if best_mse < 0.1 && best_corr > 0.8
        fprintf('✓ FM优化成功！性能显著提升\n');
        optimization_result = 'SUCCESS';
    elseif best_mse < previous_mse && best_corr > previous_corr
        fprintf('✓ FM优化有效，性能有所提升\n');
        optimization_result = 'IMPROVED';
    else
        fprintf('✗ FM优化效果有限\n');
        optimization_result = 'LIMITED';
    end
else
    fprintf('✗ 无法评估优化效果\n');
    optimization_result = 'FAILED';
end

fprintf('\n优化结果: %s\n', optimization_result);
fprintf('推荐解调方法: %s\n', best_method);
fprintf('=== FM调制优化测试结束 ===\n');
