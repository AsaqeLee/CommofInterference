%% 模拟调制综合测试套件
% 测试FM、AM、PM三种模拟调制的集成和性能对比
%
% 作者: Asaqe Lee
% 日期: 2025-06-18

clear; clc; close all;

% 添加路径
addpath('src/waveforms/base');
addpath('src/waveforms/analog');

fprintf('=== 模拟调制综合测试开始 ===\n');

%% 1. 初始化测试参数
test_config = struct();
test_config.center_frequency = 10e3;    % 10 kHz载波频率
test_config.sample_rate = 100e3;        % 100 kHz采样率
test_config.snr_db = 25;                % 25 dB信噪比
test_config.baseband_bandwidth = 2e3;   % 2 kHz基带带宽

% 生成统一的测试信号
fs = test_config.sample_rate;
t_duration = 0.02;  % 20ms
t = (0:1/fs:t_duration-1/fs)';
test_signal = 0.5 * sin(2*pi*300*t) + 0.3 * sin(2*pi*800*t);

fprintf('✓ 测试参数初始化完成\n');
fprintf('  测试信号长度: %d 样本\n', length(test_signal));

%% 2. 创建和配置调制器
modulation_types = {'FM', 'AM', 'PM'};
modulators = struct();
results = struct();

try
    factory = WaveformFactory.getInstance();
    fprintf('✓ WaveformFactory实例获取成功\n');
    
    for i = 1:length(modulation_types)
        mod_type = modulation_types{i};
        
        % 创建调制器
        modulators.(mod_type) = factory.create_waveform(mod_type);
        
        % 配置参数
        config = test_config;
        switch mod_type
            case 'FM'
                config.frequency_deviation = 1e3;      % 1 kHz频偏
                config.preemphasis_enabled = false;
                config.deemphasis_enabled = false;
            case 'AM'
                config.modulation_depth = 0.8;         % 80%调制深度
                config.am_type = 'DSB-FC';
            case 'PM'
                config.phase_deviation = pi/3;         % 60度相位偏移
        end
        
        modulators.(mod_type).configure(config);
        fprintf('✓ %s调制器创建和配置成功\n', mod_type);
    end
    
catch ME
    fprintf('✗ 调制器初始化失败: %s\n', ME.message);
    return;
end

%% 3. 执行调制和解调测试
params = struct();
params.add_noise = true;
params.normalize = true;

for i = 1:length(modulation_types)
    mod_type = modulation_types{i};
    fprintf('\n--- 测试 %s 调制 ---\n', mod_type);
    
    try
        % 调制
        tic;
        modulated_signal = modulators.(mod_type).generate_signal(test_signal, params);
        modulation_time = toc;
        
        % 选择最佳解调方法
        demod_params = struct();
        switch mod_type
            case 'FM'
                demod_params.demod_method = 'hilbert';
            case 'AM'
                demod_params.demod_method = 'envelope';
            case 'PM'
                demod_params.demod_method = 'phase_detector';
        end
        
        % 解调
        tic;
        recovered_signal = modulators.(mod_type).recover_data(modulated_signal, demod_params);
        demodulation_time = toc;
        
        % 性能分析
        mse = modulators.(mod_type).calculate_ber(test_signal, recovered_signal);
        correlation = corrcoef(test_signal, recovered_signal);
        corr_coeff = correlation(1,2);
        
        % 频谱分析
        spectrum = modulators.(mod_type).get_spectrum(modulated_signal);
        
        % 保存结果
        results.(mod_type) = struct();
        results.(mod_type).modulated_signal = modulated_signal;
        results.(mod_type).recovered_signal = recovered_signal;
        results.(mod_type).mse = mse;
        results.(mod_type).correlation = corr_coeff;
        results.(mod_type).modulation_time = modulation_time;
        results.(mod_type).demodulation_time = demodulation_time;
        results.(mod_type).spectrum = spectrum;
        results.(mod_type).demod_method = demod_params.demod_method;
        
        fprintf('✓ %s调制测试完成\n', mod_type);
        fprintf('  MSE: %.6f\n', mse);
        fprintf('  相关系数: %.4f\n', corr_coeff);
        fprintf('  调制时间: %.3f ms\n', modulation_time * 1000);
        fprintf('  解调时间: %.3f ms\n', demodulation_time * 1000);
        
    catch ME
        fprintf('✗ %s调制测试失败: %s\n', mod_type, ME.message);
        results.(mod_type) = struct();
        results.(mod_type).mse = NaN;
        results.(mod_type).correlation = NaN;
    end
end

%% 4. 性能对比分析
fprintf('\n=== 性能对比分析 ===\n');

% 提取性能指标
mse_values = [];
corr_values = [];
mod_times = [];
demod_times = [];
valid_types = {};

for i = 1:length(modulation_types)
    mod_type = modulation_types{i};
    if isfield(results.(mod_type), 'mse') && ~isnan(results.(mod_type).mse)
        mse_values(end+1) = results.(mod_type).mse;
        corr_values(end+1) = results.(mod_type).correlation;
        mod_times(end+1) = results.(mod_type).modulation_time * 1000;
        demod_times(end+1) = results.(mod_type).demodulation_time * 1000;
        valid_types{end+1} = mod_type;
    end
end

% 性能排名
[~, mse_rank] = sort(mse_values);
[~, corr_rank] = sort(corr_values, 'descend');

fprintf('MSE排名 (越小越好):\n');
for i = 1:length(mse_rank)
    idx = mse_rank(i);
    fprintf('  %d. %s: %.6f\n', i, valid_types{idx}, mse_values(idx));
end

fprintf('\n相关系数排名 (越大越好):\n');
for i = 1:length(corr_rank)
    idx = corr_rank(i);
    fprintf('  %d. %s: %.4f\n', i, valid_types{idx}, corr_values(idx));
end

%% 5. 绘制综合对比结果
try
    figure('Name', '模拟调制综合对比', 'Position', [100, 100, 1600, 1000]);
    
    % 时域信号对比
    subplot(3,4,1);
    plot(t*1000, test_signal, 'k-', 'LineWidth', 3);
    xlabel('时间 (ms)');
    ylabel('幅度');
    title('原始测试信号');
    grid on;
    
    % 调制信号对比
    colors = {'g', 'r', 'b'};
    subplot(3,4,2);
    for i = 1:length(valid_types)
        mod_type = valid_types{i};
        if isfield(results.(mod_type), 'modulated_signal')
            plot(t(1:500)*1000, results.(mod_type).modulated_signal(1:500), ...
                 colors{i}, 'LineWidth', 1);
            hold on;
        end
    end
    xlabel('时间 (ms)');
    ylabel('幅度');
    title('调制信号对比');
    legend(valid_types, 'Location', 'best');
    grid on;
    
    % 解调结果对比
    subplot(3,4,3);
    plot(t*1000, test_signal, 'k-', 'LineWidth', 2);
    hold on;
    for i = 1:length(valid_types)
        mod_type = valid_types{i};
        if isfield(results.(mod_type), 'recovered_signal')
            plot(t*1000, results.(mod_type).recovered_signal, ...
                 [colors{i} '--'], 'LineWidth', 1.5);
        end
    end
    xlabel('时间 (ms)');
    ylabel('幅度');
    title('解调结果对比');
    legend(['原始', valid_types], 'Location', 'best');
    grid on;
    
    % MSE对比
    subplot(3,4,4);
    bar(mse_values);
    set(gca, 'XTickLabel', valid_types);
    ylabel('MSE');
    title('均方误差对比');
    grid on;
    
    % 相关系数对比
    subplot(3,4,5);
    bar(corr_values);
    set(gca, 'XTickLabel', valid_types);
    ylabel('相关系数');
    title('信号相关系数对比');
    grid on;
    
    % 处理时间对比
    subplot(3,4,6);
    bar([mod_times; demod_times]');
    set(gca, 'XTickLabel', valid_types);
    ylabel('时间 (ms)');
    title('处理时间对比');
    legend('调制', '解调', 'Location', 'best');
    grid on;
    
    % 频谱对比
    subplot(3,4,7);
    for i = 1:length(valid_types)
        mod_type = valid_types{i};
        if isfield(results.(mod_type), 'spectrum')
            spectrum = results.(mod_type).spectrum;
            plot(spectrum.frequencies/1000, 10*log10(spectrum.power_density), ...
                 colors{i}, 'LineWidth', 1);
            hold on;
        end
    end
    xlabel('频率 (kHz)');
    ylabel('功率谱密度 (dB)');
    title('频谱对比');
    legend(valid_types, 'Location', 'best');
    grid on;
    xlim([5, 15]);
    
    % 散点图对比
    for i = 1:min(3, length(valid_types))
        subplot(3,4,7+i);
        mod_type = valid_types{i};
        if isfield(results.(mod_type), 'recovered_signal')
            scatter(test_signal(1:10:end), results.(mod_type).recovered_signal(1:10:end), ...
                    10, colors{i}, 'filled');
            xlabel('原始信号');
            ylabel('恢复信号');
            title([mod_type ' 散点图']);
            grid on;
            axis equal;
        end
    end
    
    % 综合性能雷达图
    subplot(3,4,11);
    if length(valid_types) >= 2
        % 归一化性能指标 (0-1)
        norm_mse = 1 - (mse_values - min(mse_values)) / (max(mse_values) - min(mse_values) + eps);
        norm_corr = corr_values;
        norm_speed = 1 - (mod_times + demod_times - min(mod_times + demod_times)) / ...
                     (max(mod_times + demod_times) - min(mod_times + demod_times) + eps);
        
        performance_matrix = [norm_mse; norm_corr; norm_speed];
        bar(performance_matrix');
        set(gca, 'XTickLabel', valid_types);
        ylabel('归一化性能');
        title('综合性能对比');
        legend('MSE性能', '相关性', '速度', 'Location', 'best');
        grid on;
    end
    
    % 波形信息汇总
    subplot(3,4,12);
    axis off;
    info_text = {'模拟调制性能汇总:', ''};
    for i = 1:length(valid_types)
        mod_type = valid_types{i};
        info_text{end+1} = sprintf('%s:', mod_type);
        info_text{end+1} = sprintf('  MSE: %.6f', mse_values(i));
        info_text{end+1} = sprintf('  相关系数: %.4f', corr_values(i));
        info_text{end+1} = sprintf('  解调方法: %s', results.(mod_type).demod_method);
        info_text{end+1} = '';
    end
    text(0.1, 0.9, info_text, 'FontSize', 10, 'VerticalAlignment', 'top');
    title('性能汇总');
    
    fprintf('✓ 综合对比结果绘制完成\n');
    
catch ME
    fprintf('✗ 结果绘制失败: %s\n', ME.message);
end

%% 6. 测试总结
fprintf('\n=== 模拟调制综合测试总结 ===\n');

% 判断各调制方式是否通过
pass_count = 0;
total_count = length(valid_types);

for i = 1:length(valid_types)
    mod_type = valid_types{i};
    mse = mse_values(i);
    corr = corr_values(i);
    
    if mse < 0.1 && corr > 0.9
        fprintf('✓ %s: PASS (MSE=%.6f, 相关系数=%.4f)\n', mod_type, mse, corr);
        pass_count = pass_count + 1;
    else
        fprintf('✗ %s: FAIL (MSE=%.6f, 相关系数=%.4f)\n', mod_type, mse, corr);
    end
end

fprintf('\n总体结果:\n');
fprintf('  通过率: %d/%d (%.1f%%)\n', pass_count, total_count, pass_count/total_count*100);

if pass_count == total_count
    fprintf('✓ 模拟调制综合测试全部通过！\n');
    overall_result = 'PASS';
else
    fprintf('✗ 部分模拟调制测试未通过\n');
    overall_result = 'PARTIAL';
end

% 推荐最佳调制方式
if ~isempty(valid_types)
    [~, best_idx] = min(mse_values);
    best_modulation = valid_types{best_idx};
    fprintf('\n推荐调制方式: %s (最低MSE: %.6f)\n', best_modulation, mse_values(best_idx));
end

fprintf('\n模拟调制三元组 (FM, AM, PM) 实现完成！\n');
fprintf('=== 模拟调制综合测试结束 ===\n');
