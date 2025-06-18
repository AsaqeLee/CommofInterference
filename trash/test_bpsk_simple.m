% test_bpsk_simple - 简单BPSK测试
% 验证BPSK调制解调的正确性

clc;
clear;

fprintf('=== BPSK修复测试 ===\n');

% 添加路径
addpath(genpath('src'));

try
    % 创建BPSK实例
    fprintf('创建BPSK实例...\n');
    bpsk = BPSK();
    
    % 配置参数
    config = struct();
    config.center_frequency = 1e9;    % 1 GHz
    config.sample_rate = 10e6;        % 10 MHz
    config.symbol_rate = 1e6;         % 1 Msps
    config.snr_db = 20;               % 20 dB (高信噪比测试)
    
    bpsk.configure(config);
    fprintf('BPSK配置完成\n');
    
    % 测试1: 简单的比特序列
    fprintf('\n测试1: 简单比特序列 [0, 1, 0, 1]\n');
    test_data_1 = [0; 1; 0; 1];
    
    % 调制
    modulated_signal_1 = bpsk.generate_signal(test_data_1, 'add_noise', false);
    fprintf('  调制完成，信号长度: %d\n', length(modulated_signal_1));
    
    % 解调
    recovered_data_1 = bpsk.recover_data(modulated_signal_1);
    fprintf('  解调完成，数据长度: %d\n', length(recovered_data_1));
    
    % 比较结果
    fprintf('  原始数据: [%s]\n', sprintf('%d ', test_data_1));
    fprintf('  恢复数据: [%s]\n', sprintf('%d ', recovered_data_1(1:length(test_data_1))));
    
    % 计算误码率
    ber_1 = bpsk.calculate_ber(test_data_1, recovered_data_1(1:length(test_data_1)));
    fprintf('  误码率: %.6f\n', ber_1);
    
    % 测试2: 符号映射验证
    fprintf('\n测试2: 符号映射验证\n');
    test_bits = [0; 1];
    symbols = bpsk.map_bits_to_symbols(test_bits);
    fprintf('  比特0 -> 符号: %.2f + %.2fi\n', real(symbols(1)), imag(symbols(1)));
    fprintf('  比特1 -> 符号: %.2f + %.2fi\n', real(symbols(2)), imag(symbols(2)));
    
    % 验证判决
    decision_0 = bpsk.symbol_decision(symbols(1));
    decision_1 = bpsk.symbol_decision(symbols(2));
    fprintf('  符号%.2f -> 判决: %d\n', real(symbols(1)), decision_0);
    fprintf('  符号%.2f -> 判决: %d\n', real(symbols(2)), decision_1);
    
    % 总结
    fprintf('\n=== 测试总结 ===\n');
    if ber_1 == 0
        fprintf('✓ 无噪声测试通过 (误码率 = 0)\n');
    else
        fprintf('✗ 无噪声测试失败 (误码率 = %.6f)\n', ber_1);
    end
    
    if decision_0 == 0 && decision_1 == 1
        fprintf('✓ 符号映射正确\n');
    else
        fprintf('✗ 符号映射错误\n');
    end
    
catch ME
    fprintf('错误: %s\n', ME.message);
    fprintf('详细信息: %s\n', ME.getReport());
end

fprintf('\n=== 测试完成 ===\n');
