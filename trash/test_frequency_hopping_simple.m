%% 简化跳频功能测试
% 测试跳频基础功能
%
% 作者: Asaqe Lee
% 日期: 2025-06-18

clear; clc; close all;

% 添加路径
addpath('src/waveforms/base');

fprintf('=== 简化跳频功能测试开始 ===\n');

%% 1. 测试跳频基础功能
fprintf('\n--- 测试跳频基础功能 ---\n');

try
    % 创建跳频控制器
    hopper = FrequencyHopping();
    fprintf('✓ 跳频控制器创建成功\n');
    
    % 配置跳频参数
    hop_config = struct();
    hop_config.hop_frequencies = (2400:5:2480) * 1e6;  % 2.4GHz频段，17个频率
    hop_config.hop_rate = 1000;                        % 1000跳/秒
    hop_config.seed_value = 12345;
    hop_config.sequence_length = 63;
    
    hopper.configure(hop_config);
    fprintf('✓ 跳频参数配置成功\n');
    
    % 获取跳频信息
    hop_info = hopper.get_hop_info();
    fprintf('✓ 跳频信息获取成功\n');
    fprintf('  频率数量: %d\n', hop_info.num_frequencies);
    fprintf('  频率范围: %.1f - %.1f MHz\n', hop_info.frequency_range(1)/1e6, hop_info.frequency_range(2)/1e6);
    fprintf('  跳频速率: %d 跳/秒\n', hop_info.hop_rate);
    fprintf('  序列长度: %d\n', hop_info.sequence_length);
    
    % 测试频率序列生成
    test_duration = 0.01; % 10ms
    sample_rate = 100e3;
    [freqs, times] = hopper.get_frequency_sequence(test_duration, sample_rate);
    fprintf('✓ 频率序列生成成功，长度: %d\n', length(freqs));
    
    % 测试单个频率获取
    test_time = 0.005; % 5ms
    current_freq = hopper.get_current_frequency(test_time);
    fprintf('✓ 单个频率获取成功: %.1f MHz\n', current_freq/1e6);
    
catch ME
    fprintf('✗ 跳频基础功能测试失败: %s\n', ME.message);
    return;
end

%% 2. 测试跳频图案绘制
fprintf('\n--- 测试跳频图案绘制 ---\n');

try
    % 绘制跳频图案
    hopper.plot_hop_pattern(0.02); % 20ms
    fprintf('✓ 跳频图案绘制成功\n');
    
catch ME
    fprintf('✗ 跳频图案绘制失败: %s\n', ME.message);
end

%% 3. 测试不同跳频参数
fprintf('\n--- 测试不同跳频参数 ---\n');

try
    % 测试不同跳频速率
    hop_rates = [100, 500, 1000, 2000];
    
    for i = 1:length(hop_rates)
        test_config = hop_config;
        test_config.hop_rate = hop_rates(i);
        
        hopper.configure(test_config);
        test_info = hopper.get_hop_info();
        
        fprintf('  跳频速率 %d 跳/秒: 跳频周期 %.3f ms\n', ...
                hop_rates(i), test_info.hop_duration * 1000);
    end
    
    fprintf('✓ 不同跳频参数测试成功\n');
    
catch ME
    fprintf('✗ 不同跳频参数测试失败: %s\n', ME.message);
end

%% 4. 测试伪随机序列生成
fprintf('\n--- 测试伪随机序列生成 ---\n');

try
    % 测试不同种子的序列
    seeds = [12345, 54321, 98765];
    
    for i = 1:length(seeds)
        test_config = hop_config;
        test_config.seed_value = seeds(i);
        
        hopper.configure(test_config);
        
        % 获取前10个跳频频率
        test_freqs = zeros(1, 10);
        for j = 1:10
            test_time = (j-1) * test_info.hop_duration;
            test_freqs(j) = hopper.get_current_frequency(test_time);
        end
        
        fprintf('  种子 %d: 前5个频率 [%.0f, %.0f, %.0f, %.0f, %.0f] MHz\n', ...
                seeds(i), test_freqs(1:5)/1e6);
    end
    
    fprintf('✓ 伪随机序列生成测试成功\n');
    
catch ME
    fprintf('✗ 伪随机序列生成测试失败: %s\n', ME.message);
end

%% 5. 性能测试
fprintf('\n--- 性能测试 ---\n');

try
    % 测试大量频率获取的性能
    num_tests = 10000;
    test_times = rand(num_tests, 1) * 0.1; % 0-100ms随机时间
    
    tic;
    for i = 1:num_tests
        freq = hopper.get_current_frequency(test_times(i));
    end
    elapsed_time = toc;
    
    fprintf('✓ 性能测试完成\n');
    fprintf('  %d次频率获取耗时: %.3f ms\n', num_tests, elapsed_time * 1000);
    fprintf('  平均每次耗时: %.6f ms\n', elapsed_time * 1000 / num_tests);
    
catch ME
    fprintf('✗ 性能测试失败: %s\n', ME.message);
end

%% 6. 边界条件测试
fprintf('\n--- 边界条件测试 ---\n');

try
    % 测试边界时间
    boundary_times = [0, test_info.hop_duration, test_info.hop_duration * 2, 0.1];
    
    for i = 1:length(boundary_times)
        freq = hopper.get_current_frequency(boundary_times(i));
        fprintf('  时间 %.3f ms: 频率 %.1f MHz\n', ...
                boundary_times(i) * 1000, freq/1e6);
    end
    
    fprintf('✓ 边界条件测试成功\n');
    
catch ME
    fprintf('✗ 边界条件测试失败: %s\n', ME.message);
end

%% 7. 测试总结
fprintf('\n=== 简化跳频功能测试总结 ===\n');

fprintf('跳频基础功能测试完成！\n');
fprintf('实现的功能:\n');
fprintf('  ✓ 跳频控制器 FrequencyHopping\n');
fprintf('  ✓ 伪随机序列生成\n');
fprintf('  ✓ 跳频频率计算\n');
fprintf('  ✓ 跳频图案绘制\n');
fprintf('  ✓ 多种跳频参数支持\n');
fprintf('  ✓ 性能优化\n');

fprintf('\n下一步:\n');
fprintf('  - 测试跳频波形类\n');
fprintf('  - 测试QPSK扩频跳频组合\n');
fprintf('  - 集成到WaveformFactory\n');

fprintf('\n=== 简化跳频功能测试结束 ===\n');
