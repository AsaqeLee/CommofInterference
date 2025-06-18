%% AM调制集成测试
% 测试AM调制与系统的集成
%
% 作者: Asaqe Lee
% 日期: 2025-06-18

clear; clc; close all;

% 添加路径
addpath('src/waveforms/base');
addpath('src/waveforms/analog');

fprintf('=== AM调制集成测试开始 ===\n');

%% 1. 测试WaveformFactory创建AM实例
try
    factory = WaveformFactory.getInstance();
    fprintf('✓ WaveformFactory实例获取成功\n');
    
    % 检查AM是否在支持列表中
    supported_waveforms = factory.get_supported_waveforms();
    if ismember('AM', supported_waveforms)
        fprintf('✓ AM在支持的波形列表中\n');
    else
        fprintf('✗ AM不在支持的波形列表中\n');
        return;
    end
    
    % 获取模拟调制波形列表
    analog_waveforms = factory.get_waveforms_by_category('analog');
    fprintf('✓ 模拟调制波形: %s\n', strjoin(analog_waveforms, ', '));
    
catch ME
    fprintf('✗ WaveformFactory测试失败: %s\n', ME.message);
    return;
end

%% 2. 通过工厂创建AM实例
try
    am_waveform = factory.create_waveform('AM');
    fprintf('✓ 通过工厂创建AM实例成功\n');
    
    % 获取波形信息
    info = am_waveform.get_waveform_info();
    fprintf('  波形ID: %d\n', info.waveform_id);
    fprintf('  波形名称: %s\n', info.waveform_name);
    fprintf('  调制类型: %s\n', info.modulation_type);
    fprintf('  类别: %s\n', info.category);
    
catch ME
    fprintf('✗ 工厂创建AM实例失败: %s\n', ME.message);
    return;
end

%% 3. 配置AM参数
config = struct();
config.center_frequency = 10e3;         % 10 kHz载波频率
config.modulation_depth = 0.8;          % 80%调制深度
config.carrier_amplitude = 1.0;         % 载波幅度
config.baseband_bandwidth = 2e3;        % 2 kHz基带带宽
config.sample_rate = 100e3;             % 100 kHz采样率
config.snr_db = 25;                     % 25 dB信噪比
config.am_type = 'DSB-FC';              % 双边带全载波

try
    am_waveform.configure(config);
    fprintf('✓ AM参数配置成功\n');
    
    % 验证配置
    am_info = am_waveform.get_waveform_info();
    fprintf('  载波频率: %.1f kHz\n', config.center_frequency/1000);
    fprintf('  调制深度: %.1f%%\n', am_info.modulation_depth * 100);
    fprintf('  AM类型: %s\n', am_info.am_type);
    fprintf('  采样率: %.1f kHz\n', config.sample_rate/1000);
    
catch ME
    fprintf('✗ AM参数配置失败: %s\n', ME.message);
    return;
end

%% 4. 生成测试数据和调制
% 生成测试信号
fs = config.sample_rate;
t_duration = 0.02;  % 20ms
t = (0:1/fs:t_duration-1/fs)';
test_signal = 0.5 * sin(2*pi*500*t) + 0.3 * sin(2*pi*1200*t);  % 复合音频信号

try
    % 调制
    params = struct();
    params.add_noise = true;
    params.normalize = true;
    
    tic;
    modulated_signal = am_waveform.generate_signal(test_signal, params);
    modulation_time = toc;
    
    fprintf('✓ AM调制成功\n');
    fprintf('  调制时间: %.3f ms\n', modulation_time * 1000);
    fprintf('  输入长度: %d 样本\n', length(test_signal));
    fprintf('  输出长度: %d 样本\n', length(modulated_signal));
    
catch ME
    fprintf('✗ AM调制失败: %s\n', ME.message);
    return;
end

%% 5. 解调和性能分析
try
    % 解调（使用包络检波，对DSB-FC最适合）
    demod_params = struct();
    demod_params.demod_method = 'envelope';
    
    tic;
    recovered_signal = am_waveform.recover_data(modulated_signal, demod_params);
    demodulation_time = toc;
    
    fprintf('✓ AM解调成功\n');
    fprintf('  解调时间: %.3f ms\n', demodulation_time * 1000);
    fprintf('  恢复信号长度: %d 样本\n', length(recovered_signal));
    
    % 性能分析
    mse = am_waveform.calculate_ber(test_signal, recovered_signal);
    
    % 计算相关系数
    correlation = corrcoef(test_signal, recovered_signal);
    corr_coeff = correlation(1,2);
    
    fprintf('✓ 性能分析完成\n');
    fprintf('  均方误差: %.6f\n', mse);
    fprintf('  相关系数: %.4f\n', corr_coeff);
    
catch ME
    fprintf('✗ AM解调失败: %s\n', ME.message);
    return;
end

%% 6. 频谱分析
try
    spectrum = am_waveform.get_spectrum(modulated_signal);
    fprintf('✓ 频谱分析完成\n');
    fprintf('  频谱点数: %d\n', length(spectrum.frequencies));
    fprintf('  AM带宽: %.1f kHz\n', spectrum.bandwidth/1000);
    
catch ME
    fprintf('✗ 频谱分析失败: %s\n', ME.message);
end

%% 7. 测试不同AM类型的集成
fprintf('\n--- 测试不同AM类型集成 ---\n');

am_types = {'DSB-FC', 'DSB-SC', 'SSB-USB', 'SSB-LSB'};
type_performance = struct();

for i = 1:length(am_types)
    try
        % 配置AM类型
        config.am_type = am_types{i};
        am_waveform.configure(config);
        
        % 调制
        mod_signal = am_waveform.generate_signal(test_signal, params);
        
        % 选择合适的解调方法
        if strcmp(am_types{i}, 'DSB-FC')
            demod_params.demod_method = 'envelope';
        else
            demod_params.demod_method = 'coherent';
        end
        
        % 解调
        rec_signal = am_waveform.recover_data(mod_signal, demod_params);
        mse_type = am_waveform.calculate_ber(test_signal, rec_signal);
        
        % 保存结果
        field_name = strrep(am_types{i}, '-', '_');
        type_performance.(field_name) = mse_type;
        
        fprintf('✓ %s: MSE = %.6f\n', am_types{i}, mse_type);
        
    catch ME
        fprintf('✗ %s 集成测试失败: %s\n', am_types{i}, ME.message);
    end
end

%% 8. 绘制集成测试结果
try
    figure('Name', 'AM集成测试结果', 'Position', [100, 100, 1200, 800]);
    
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
    
    % AM调制信号
    subplot(2,3,2);
    plot(t(1:500)*1000, modulated_signal(1:500), 'g-', 'LineWidth', 1);
    xlabel('时间 (ms)');
    ylabel('幅度');
    title('AM调制信号');
    grid on;
    
    % 频谱
    subplot(2,3,3);
    plot(spectrum.frequencies/1000, 10*log10(spectrum.power_density), 'b-', 'LineWidth', 1);
    xlabel('频率 (kHz)');
    ylabel('功率谱密度 (dB)');
    title('AM信号频谱');
    grid on;
    xlim([5, 15]);
    
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
    
    % AM类型性能对比
    subplot(2,3,6);
    if ~isempty(fieldnames(type_performance))
        field_names = fieldnames(type_performance);
        mse_values = zeros(length(field_names), 1);
        for i = 1:length(field_names)
            mse_values(i) = type_performance.(field_names{i});
        end
        
        bar(mse_values);
        display_names = strrep(field_names, '_', '-');
        set(gca, 'XTickLabel', display_names);
        ylabel('MSE');
        title('AM类型性能对比');
        grid on;
    end
    
    fprintf('✓ 集成测试结果绘制完成\n');
    
catch ME
    fprintf('✗ 结果绘制失败: %s\n', ME.message);
end

%% 9. 验证工厂功能
try
    fprintf('\n--- 验证工厂功能 ---\n');
    
    % 获取AM信息
    am_factory_info = factory.get_waveform_info('AM');
    fprintf('✓ 获取AM信息成功\n');
    fprintf('  类名: %s\n', am_factory_info.class_name);
    fprintf('  类别: %s\n', am_factory_info.category);
    
    % 验证模拟调制波形
    fprintf('\n验证模拟调制波形:\n');
    for i = 1:length(analog_waveforms)
        waveform_type = analog_waveforms{i};
        try
            if exist(waveform_type, 'class') == 8
                fprintf('  ✓ %s\n', waveform_type);
            else
                fprintf('  ✗ %s (类文件不存在)\n', waveform_type);
            end
        catch
            fprintf('  ✗ %s (创建失败)\n', waveform_type);
        end
    end
    
catch ME
    fprintf('✗ 工厂功能验证失败: %s\n', ME.message);
end

%% 10. 测试总结
fprintf('\n=== AM集成测试总结 ===\n');

% 判断测试是否通过
test_passed = true;
test_results = {};

if mse < 0.1
    fprintf('✓ 调制解调性能测试通过 (MSE: %.6f < 0.1)\n', mse);
    test_results{end+1} = 'PASS: 调制解调性能';
else
    fprintf('✗ 调制解调性能测试失败 (MSE: %.6f >= 0.1)\n', mse);
    test_results{end+1} = 'FAIL: 调制解调性能';
    test_passed = false;
end

if corr_coeff > 0.9
    fprintf('✓ 信号相关性测试通过 (相关系数: %.4f > 0.9)\n', corr_coeff);
    test_results{end+1} = 'PASS: 信号相关性';
else
    fprintf('✗ 信号相关性测试失败 (相关系数: %.4f <= 0.9)\n', corr_coeff);
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

fprintf('=== AM集成测试结束 ===\n');
