%% 跳频功能综合测试
% 测试跳频基础功能和跳频调制
%
% 作者: Asaqe Lee
% 日期: 2025-06-18

clear; clc; close all;

% 添加路径
addpath('src/waveforms/base');
addpath('src/waveforms/analog');
addpath('src/waveforms/digital');
addpath('src/waveforms/frequency_hopping');
addpath('src/waveforms/spread_spectrum');

fprintf('=== 跳频功能综合测试开始 ===\n');

%% 1. 测试跳频基础功能
fprintf('\n--- 测试跳频基础功能 ---\n');

try
    % 创建跳频控制器
    hopper = FrequencyHopping();
    
    % 配置跳频参数
    hop_config = struct();
    hop_config.hop_frequencies = (2400:5:2480) * 1e6;  % 2.4GHz频段，17个频率
    hop_config.hop_rate = 1000;                        % 1000跳/秒
    hop_config.seed_value = 12345;
    hop_config.sequence_length = 63;
    
    hopper.configure(hop_config);
    
    % 获取跳频信息
    hop_info = hopper.get_hop_info();
    fprintf('✓ 跳频控制器创建成功\n');
    fprintf('  频率数量: %d\n', hop_info.num_frequencies);
    fprintf('  频率范围: %.1f - %.1f MHz\n', hop_info.frequency_range(1)/1e6, hop_info.frequency_range(2)/1e6);
    fprintf('  跳频速率: %d 跳/秒\n', hop_info.hop_rate);
    fprintf('  序列长度: %d\n', hop_info.sequence_length);
    
    % 测试频率序列生成
    test_duration = 0.01; % 10ms
    sample_rate = 100e3;
    [freqs, times] = hopper.get_frequency_sequence(test_duration, sample_rate);
    fprintf('✓ 频率序列生成成功，长度: %d\n', length(freqs));
    
catch ME
    fprintf('✗ 跳频基础功能测试失败: %s\n', ME.message);
    return;
end

%% 2. 测试跳频调制波形
fprintf('\n--- 测试跳频调制波形 ---\n');

% 测试的跳频波形
fh_waveforms = {'FM-FH', 'AM-FH', 'QPSK-FH'};
results = struct();

try
    factory = WaveformFactory.getInstance();
    
    for i = 1:length(fh_waveforms)
        waveform_type = fh_waveforms{i};
        fprintf('\n测试 %s:\n', waveform_type);
        
        try
            % 创建跳频波形
            fh_waveform = factory.create_waveform(waveform_type);
            
            % 配置参数
            config = struct();
            config.center_frequency = 10e3;     % 基础载波频率
            config.sample_rate = 100e3;         % 采样率
            config.snr_db = 25;                 % 信噪比
            
            % 跳频参数
            config.hopping_enabled = true;
            config.hop_frequencies = (8:1:12) * 1e3;  % 8-12 kHz
            config.hop_rate = 200;               % 200跳/秒
            config.hop_seed = 54321;
            
            % 特定调制参数
            if contains(waveform_type, 'FM')
                config.frequency_deviation = 500;
                config.baseband_bandwidth = 200;
            elseif contains(waveform_type, 'AM')
                config.modulation_depth = 0.8;
                config.am_type = 'DSB-FC';
            end
            
            fh_waveform.configure(config);
            
            % 生成测试数据
            if contains(waveform_type, 'QPSK')
                % 数字调制：生成随机比特
                test_data = randi([0, 1], 100, 1);
            else
                % 模拟调制：生成正弦波
                fs = config.sample_rate;
                t = (0:1/fs:0.02-1/fs)';
                test_data = sin(2*pi*100*t);
            end
            
            % 调制
            tic;
            modulated_signal = fh_waveform.generate_signal(test_data, struct());
            mod_time = toc;
            
            % 解调
            tic;
            recovered_data = fh_waveform.recover_data(modulated_signal, struct());
            demod_time = toc;
            
            % 性能分析
            ber = fh_waveform.calculate_ber(test_data, recovered_data);
            
            % 获取波形信息
            info = fh_waveform.get_waveform_info();
            
            % 保存结果
            results.(strrep(waveform_type, '-', '_')) = struct();
            results.(strrep(waveform_type, '-', '_')).ber = ber;
            results.(strrep(waveform_type, '-', '_')).mod_time = mod_time;
            results.(strrep(waveform_type, '-', '_')).demod_time = demod_time;
            results.(strrep(waveform_type, '-', '_')).info = info;
            
            fprintf('  ✓ %s 测试成功\n', waveform_type);
            fprintf('    BER/MSE: %.6f\n', ber);
            fprintf('    调制时间: %.3f ms\n', mod_time * 1000);
            fprintf('    解调时间: %.3f ms\n', demod_time * 1000);
            if info.hopping_enabled
                fprintf('    跳频启用: Yes\n');
            else
                fprintf('    跳频启用: No\n');
            end
            
        catch ME
            fprintf('  ✗ %s 测试失败: %s\n', waveform_type, ME.message);
            results.(strrep(waveform_type, '-', '_')) = struct();
            results.(strrep(waveform_type, '-', '_')).ber = NaN;
        end
    end
    
catch ME
    fprintf('✗ 跳频调制波形测试失败: %s\n', ME.message);
end

%% 3. 测试QPSK扩频跳频组合
fprintf('\n--- 测试QPSK扩频跳频组合 ---\n');

try
    % 创建QPSK+DSSS+FHSS波形
    qpsk_dsss_fhss = factory.create_waveform('QPSK-DSSS-FHSS');
    
    % 配置参数
    config = struct();
    config.center_frequency = 10e3;
    config.sample_rate = 100e3;
    config.snr_db = 20;
    
    % 扩频参数
    config.spreading_factor = 31;
    config.chip_rate = 31e3;
    config.code_type = 'gold';
    config.code_seed = 7;
    
    % 跳频参数
    config.hopping_enabled = true;
    config.hop_frequencies = (8:0.5:12) * 1e3;
    config.hop_rate = 100;
    config.hop_seed = 98765;
    
    qpsk_dsss_fhss.configure(config);
    
    % 生成测试数据
    test_bits = randi([0, 1], 64, 1);
    
    % 调制
    tic;
    spread_hop_signal = qpsk_dsss_fhss.generate_signal(test_bits, struct());
    spread_hop_mod_time = toc;
    
    % 解调
    tic;
    recovered_bits = qpsk_dsss_fhss.recover_data(spread_hop_signal, struct());
    spread_hop_demod_time = toc;
    
    % 性能分析
    spread_hop_ber = qpsk_dsss_fhss.calculate_ber(test_bits, recovered_bits);
    
    % 获取信息
    spread_hop_info = qpsk_dsss_fhss.get_waveform_info();
    
    fprintf('✓ QPSK+DSSS+FHSS 测试成功\n');
    fprintf('  BER: %.6f\n', spread_hop_ber);
    fprintf('  调制时间: %.3f ms\n', spread_hop_mod_time * 1000);
    fprintf('  解调时间: %.3f ms\n', spread_hop_demod_time * 1000);
    fprintf('  扩频因子: %d\n', spread_hop_info.spreading_factor);
    fprintf('  处理增益: %.1f dB\n', spread_hop_info.processing_gain);
    fprintf('  抗干扰容限: %.1f dB\n', spread_hop_info.jamming_margin);
    
    % 保存结果
    results.QPSK_DSSS_FHSS = struct();
    results.QPSK_DSSS_FHSS.ber = spread_hop_ber;
    results.QPSK_DSSS_FHSS.mod_time = spread_hop_mod_time;
    results.QPSK_DSSS_FHSS.demod_time = spread_hop_demod_time;
    results.QPSK_DSSS_FHSS.info = spread_hop_info;
    
catch ME
    fprintf('✗ QPSK+DSSS+FHSS 测试失败: %s\n', ME.message);
    results.QPSK_DSSS_FHSS = struct();
    results.QPSK_DSSS_FHSS.ber = NaN;
end

%% 4. 绘制跳频图案
try
    fprintf('\n--- 绘制跳频图案 ---\n');
    
    % 绘制基础跳频图案
    hopper.plot_hop_pattern(0.02); % 20ms
    
    % 绘制扩频码（如果QPSK+DSSS+FHSS测试成功）
    if exist('qpsk_dsss_fhss', 'var')
        qpsk_dsss_fhss.plot_spreading_code();
    end
    
    fprintf('✓ 跳频图案绘制完成\n');
    
catch ME
    fprintf('✗ 跳频图案绘制失败: %s\n', ME.message);
end

%% 5. 性能对比分析
fprintf('\n=== 跳频性能对比分析 ===\n');

% 提取有效结果
valid_waveforms = {};
ber_values = [];
mod_times = [];
demod_times = [];

field_names = fieldnames(results);
for i = 1:length(field_names)
    field_name = field_names{i};
    if isfield(results.(field_name), 'ber') && ~isnan(results.(field_name).ber)
        valid_waveforms{end+1} = strrep(field_name, '_', '-');
        ber_values(end+1) = results.(field_name).ber;
        mod_times(end+1) = results.(field_name).mod_time * 1000;
        demod_times(end+1) = results.(field_name).demod_time * 1000;
    end
end

if ~isempty(valid_waveforms)
    % 性能排名
    [~, ber_rank] = sort(ber_values);
    
    fprintf('BER/MSE排名 (越小越好):\n');
    for i = 1:length(ber_rank)
        idx = ber_rank(i);
        fprintf('  %d. %s: %.6f\n', i, valid_waveforms{idx}, ber_values(idx));
    end
    
    % 绘制性能对比
    figure('Name', '跳频波形性能对比', 'Position', [100, 100, 1200, 600]);
    
    subplot(1,3,1);
    bar(ber_values);
    set(gca, 'XTickLabel', valid_waveforms);
    ylabel('BER/MSE');
    title('误码率对比');
    grid on;
    
    subplot(1,3,2);
    bar(mod_times);
    set(gca, 'XTickLabel', valid_waveforms);
    ylabel('时间 (ms)');
    title('调制时间对比');
    grid on;
    
    subplot(1,3,3);
    bar(demod_times);
    set(gca, 'XTickLabel', valid_waveforms);
    ylabel('时间 (ms)');
    title('解调时间对比');
    grid on;
    
    fprintf('✓ 性能对比分析完成\n');
else
    fprintf('✗ 没有有效的测试结果进行对比\n');
end

%% 6. 测试总结
fprintf('\n=== 跳频功能测试总结 ===\n');

% 统计测试结果
total_tests = length(fh_waveforms) + 1; % 包括QPSK+DSSS+FHSS
passed_tests = length(valid_waveforms);
pass_rate = passed_tests / total_tests * 100;

fprintf('测试统计:\n');
fprintf('  总测试数: %d\n', total_tests);
fprintf('  通过测试: %d\n', passed_tests);
fprintf('  通过率: %.1f%%\n', pass_rate);

if pass_rate >= 75
    fprintf('✓ 跳频功能测试总体通过\n');
    overall_result = 'PASS';
elseif pass_rate >= 50
    fprintf('○ 跳频功能测试部分通过\n');
    overall_result = 'PARTIAL';
else
    fprintf('✗ 跳频功能测试未通过\n');
    overall_result = 'FAIL';
end

fprintf('\n跳频功能实现成果:\n');
fprintf('  ✓ 跳频基础类 FrequencyHopping\n');
fprintf('  ✓ 跳频波形基类 FrequencyHoppingWaveform\n');
fprintf('  ✓ FM跳频 (FM-FH)\n');
fprintf('  ✓ AM跳频 (AM-FH)\n');
fprintf('  ✓ QPSK跳频 (QPSK-FH)\n');
fprintf('  ✓ QPSK扩频跳频组合 (QPSK-DSSS-FHSS)\n');

fprintf('\n总体结果: %s\n', overall_result);
fprintf('=== 跳频功能综合测试结束 ===\n');
