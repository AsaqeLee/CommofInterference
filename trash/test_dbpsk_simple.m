% test_dbpsk_simple - 简单差分编码BPSK测试
% 验证差分编码的基本功能
%
% 作者: Asaqe Lee
% 日期: 2025-06-18

clc;
clear;

fprintf('=== 简单差分编码BPSK测试 ===\n');

% 添加路径
addpath(genpath('src'));

try
    % 创建DBPSK实例
    dbpsk = BPSK();
    
    % 配置差分编码
    config = struct();
    config.center_frequency = 1e6;
    config.sample_rate = 10e6;
    config.symbol_rate = 1e6;
    config.snr_db = 25;  % 高信噪比
    config.use_differential_encoding = true;
    
    dbpsk.configure(config);
    fprintf('✓ DBPSK配置完成\n');
    
    % 测试1: 简单数据
    fprintf('\n--- 测试1: 简单数据 ---\n');
    test_data_1 = [0; 1; 0; 1];
    fprintf('原始数据: [%s]\n', sprintf('%d ', test_data_1));
    
    % 调制
    signal_1 = dbpsk.generate_signal(test_data_1, 'add_noise', false);
    fprintf('调制完成，信号长度: %d\n', length(signal_1));
    
    % 解调
    recovered_1 = dbpsk.recover_data(signal_1);
    fprintf('解调完成，恢复数据长度: %d\n', length(recovered_1));
    
    % 比较结果（注意长度可能不同）
    min_len_1 = min(length(test_data_1), length(recovered_1));
    fprintf('比较长度: %d\n', min_len_1);
    fprintf('原始数据: [%s]\n', sprintf('%d ', test_data_1(1:min_len_1)));
    fprintf('恢复数据: [%s]\n', sprintf('%d ', recovered_1(1:min_len_1)));
    
    % 计算误码率
    ber_1 = dbpsk.calculate_ber(test_data_1(1:min_len_1), recovered_1(1:min_len_1));
    fprintf('误码率: %.6f\n', ber_1);
    
    % 测试2: 添加180度相位偏移
    fprintf('\n--- 测试2: 180度相位偏移 ---\n');
    phase_shifted_signal = signal_1 * exp(1j * pi);
    
    recovered_2 = dbpsk.recover_data(phase_shifted_signal);
    min_len_2 = min(length(test_data_1), length(recovered_2));
    
    fprintf('原始数据: [%s]\n', sprintf('%d ', test_data_1(1:min_len_2)));
    fprintf('恢复数据: [%s]\n', sprintf('%d ', recovered_2(1:min_len_2)));
    
    ber_2 = dbpsk.calculate_ber(test_data_1(1:min_len_2), recovered_2(1:min_len_2));
    fprintf('180度偏移误码率: %.6f\n', ber_2);
    
    % 测试3: 对比传统BPSK
    fprintf('\n--- 测试3: 对比传统BPSK ---\n');
    
    % 创建传统BPSK
    bpsk_trad = BPSK();
    config.use_differential_encoding = false;
    bpsk_trad.configure(config);
    
    % 传统BPSK + 180度相位偏移
    signal_trad = bpsk_trad.generate_signal(test_data_1, 'add_noise', false);
    phase_shifted_signal_trad = signal_trad * exp(1j * pi);
    recovered_trad = bpsk_trad.recover_data(phase_shifted_signal_trad);
    
    min_len_trad = min(length(test_data_1), length(recovered_trad));
    ber_trad = bpsk_trad.calculate_ber(test_data_1(1:min_len_trad), recovered_trad(1:min_len_trad));
    
    fprintf('传统BPSK + 180度偏移误码率: %.6f\n', ber_trad);
    fprintf('差分BPSK + 180度偏移误码率: %.6f\n', ber_2);
    
    % 测试4: 波形信息
    fprintf('\n--- 测试4: 波形信息 ---\n');
    info = dbpsk.get_waveform_info();
    fprintf('波形名称: %s\n', info.waveform_name);
    fprintf('差分编码: %s\n', mat2str(info.use_differential_encoding));
    fprintf('描述: %s\n', info.description);
    
    % 总结
    fprintf('\n=== 测试总结 ===\n');
    
    if ber_1 <= 0.1
        fprintf('✓ 理想情况测试通过 (BER = %.6f)\n', ber_1);
    else
        fprintf('✗ 理想情况测试失败 (BER = %.6f)\n', ber_1);
    end
    
    if ber_2 <= 0.1
        fprintf('✓ 相位偏移测试通过 (BER = %.6f)\n', ber_2);
        fprintf('🎉 差分编码成功解决相位模糊问题！\n');
    else
        fprintf('✗ 相位偏移测试失败 (BER = %.6f)\n', ber_2);
    end
    
    if exist('ber_trad', 'var') && ber_2 < ber_trad
        improvement = (ber_trad - ber_2) / ber_trad * 100;
        fprintf('相比传统BPSK改善: %.1f%%\n', improvement);
    end
    
catch ME
    fprintf('❌ 测试失败: %s\n', ME.message);
    fprintf('详细信息: %s\n', ME.getReport());
end

fprintf('\n=== 测试完成 ===\n');
