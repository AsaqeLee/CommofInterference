% test_bpsk_simple_fix - 简单BPSK修复测试
% 验证BPSK相位模糊检测的修复效果
%
% 作者: Asaqe Lee
% 日期: 2025-06-18

clc;
clear;

fprintf('=== BPSK简单修复测试 ===\n');

% 添加路径
addpath(genpath('src'));

try
    % 创建BPSK实例
    bpsk = BPSK();
    
    % 配置参数
    config = struct();
    config.center_frequency = 1e6;
    config.sample_rate = 10e6;
    config.symbol_rate = 1e6;
    config.snr_db = 25;  % 高信噪比
    
    bpsk.configure(config);
    fprintf('✓ BPSK配置成功\n');
    
    % 测试1: 理想情况
    fprintf('\n--- 测试1: 理想情况 ---\n');
    test_data_1 = [0; 1; 0; 1; 0; 1; 0; 1; 0; 1];  % 简单交替模式
    
    signal_1 = bpsk.generate_signal(test_data_1, 'add_noise', false);
    recovered_1 = bpsk.recover_data(signal_1);
    
    ber_1 = bpsk.calculate_ber(test_data_1, recovered_1(1:length(test_data_1)));
    
    fprintf('原始数据: [%s]\n', sprintf('%d ', test_data_1));
    fprintf('恢复数据: [%s]\n', sprintf('%d ', recovered_1(1:length(test_data_1))));
    fprintf('误码率: %.6f\n', ber_1);
    
    % 测试2: 180度相位偏移
    fprintf('\n--- 测试2: 180度相位偏移 ---\n');
    test_data_2 = [0; 1; 0; 1; 0; 1; 0; 1; 0; 1];
    
    signal_2 = bpsk.generate_signal(test_data_2, 'add_noise', false);
    % 添加180度相位偏移
    phase_shifted_signal = signal_2 * exp(1j * pi);
    
    recovered_2 = bpsk.recover_data(phase_shifted_signal);
    
    ber_2 = bpsk.calculate_ber(test_data_2, recovered_2(1:length(test_data_2)));
    
    fprintf('原始数据: [%s]\n', sprintf('%d ', test_data_2));
    fprintf('恢复数据: [%s]\n', sprintf('%d ', recovered_2(1:length(test_data_2))));
    fprintf('误码率: %.6f\n', ber_2);
    
    % 测试3: 随机数据
    fprintf('\n--- 测试3: 随机数据 ---\n');
    test_data_3 = randi([0, 1], 20, 1);
    
    signal_3 = bpsk.generate_signal(test_data_3, 'add_noise', false);
    recovered_3 = bpsk.recover_data(signal_3);
    
    ber_3 = bpsk.calculate_ber(test_data_3, recovered_3(1:length(test_data_3)));
    
    fprintf('随机数据测试，数据长度: %d\n', length(test_data_3));
    fprintf('误码率: %.6f\n', ber_3);
    
    % 测试4: 随机数据 + 180度相位偏移
    fprintf('\n--- 测试4: 随机数据 + 180度相位偏移 ---\n');
    test_data_4 = randi([0, 1], 20, 1);
    
    signal_4 = bpsk.generate_signal(test_data_4, 'add_noise', false);
    phase_shifted_signal_4 = signal_4 * exp(1j * pi);
    
    recovered_4 = bpsk.recover_data(phase_shifted_signal_4);
    
    ber_4 = bpsk.calculate_ber(test_data_4, recovered_4(1:length(test_data_4)));
    
    fprintf('随机数据 + 相位偏移测试，数据长度: %d\n', length(test_data_4));
    fprintf('误码率: %.6f\n', ber_4);
    
    % 测试总结
    fprintf('\n=== 测试总结 ===\n');
    
    if ber_1 <= 0.1
        fprintf('✓ 理想情况测试通过 (BER = %.6f)\n', ber_1);
    else
        fprintf('✗ 理想情况测试失败 (BER = %.6f)\n', ber_1);
    end
    
    if ber_2 <= 0.1
        fprintf('✓ 180度相位偏移测试通过 (BER = %.6f)\n', ber_2);
    else
        fprintf('✗ 180度相位偏移测试失败 (BER = %.6f)\n', ber_2);
    end
    
    if ber_3 <= 0.1
        fprintf('✓ 随机数据测试通过 (BER = %.6f)\n', ber_3);
    else
        fprintf('✗ 随机数据测试失败 (BER = %.6f)\n', ber_3);
    end
    
    if ber_4 <= 0.1
        fprintf('✓ 随机数据相位偏移测试通过 (BER = %.6f)\n', ber_4);
    else
        fprintf('✗ 随机数据相位偏移测试失败 (BER = %.6f)\n', ber_4);
    end
    
    % 整体评估
    total_tests = 4;
    passed_tests = sum([ber_1 <= 0.1, ber_2 <= 0.1, ber_3 <= 0.1, ber_4 <= 0.1]);
    
    fprintf('\n总体结果: %d/%d 测试通过 (%.1f%%)\n', passed_tests, total_tests, 100*passed_tests/total_tests);
    
    if passed_tests >= 3
        fprintf('🎉 BPSK相位模糊检测修复效果良好！\n');
    elseif passed_tests >= 2
        fprintf('⚠️ BPSK相位模糊检测有所改善，但仍需优化\n');
    else
        fprintf('❌ BPSK相位模糊检测修复效果不佳\n');
    end
    
catch ME
    fprintf('❌ 测试失败: %s\n', ME.message);
    fprintf('详细信息: %s\n', ME.getReport());
end

fprintf('\n=== 测试完成 ===\n');
