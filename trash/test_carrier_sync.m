% test_carrier_sync - 测试载波同步功能
% 验证载波同步算法的有效性

clc;
clear;

fprintf('=== 载波同步测试 ===\n');

% 添加路径
addpath(genpath('src'));

try
    % 创建BPSK实例
    fprintf('创建BPSK实例...\n');
    bpsk = BPSK();
    
    % 配置参数
    config = struct();
    config.center_frequency = 1e6;       % 1 MHz载波
    config.sample_rate = 10e6;           % 10 MHz采样率
    config.symbol_rate = 1e6;            % 1 Msps
    config.snr_db = 15;                  % 15 dB信噪比
    
    bpsk.configure(config);
    fprintf('BPSK配置完成\n');
    
    % 测试1: 无载波偏移的理想情况
    fprintf('\n=== 测试1: 理想载波同步 ===\n');
    test_data_1 = randi([0, 1], 100, 1);
    
    % 调制
    modulated_signal_1 = bpsk.generate_signal(test_data_1, 'add_noise', true);
    fprintf('  调制完成，信号长度: %d\n', length(modulated_signal_1));
    
    % 解调
    recovered_data_1 = bpsk.recover_data(modulated_signal_1);
    fprintf('  解调完成，数据长度: %d\n', length(recovered_data_1));
    
    % 计算误码率
    min_len = min(length(test_data_1), length(recovered_data_1));
    ber_1 = bpsk.calculate_ber(test_data_1(1:min_len), recovered_data_1(1:min_len));
    fprintf('  误码率: %.6f\n', ber_1);
    
    % 测试2: 添加频率偏移
    fprintf('\n=== 测试2: 频率偏移测试 ===\n');
    test_data_2 = randi([0, 1], 100, 1);
    
    % 调制
    modulated_signal_2 = bpsk.generate_signal(test_data_2, 'add_noise', true);
    
    % 人为添加频率偏移
    freq_offset = 1000;  % 1 kHz频率偏移
    t = (0:length(modulated_signal_2)-1) / config.sample_rate;
    freq_offset_signal = modulated_signal_2 .* exp(1j * 2*pi*freq_offset*t);
    
    fprintf('  添加 %d Hz 频率偏移\n', freq_offset);
    
    % 解调
    recovered_data_2 = bpsk.recover_data(freq_offset_signal);
    fprintf('  解调完成，数据长度: %d\n', length(recovered_data_2));
    
    % 计算误码率
    min_len = min(length(test_data_2), length(recovered_data_2));
    ber_2 = bpsk.calculate_ber(test_data_2(1:min_len), recovered_data_2(1:min_len));
    fprintf('  误码率: %.6f\n', ber_2);
    
    % 测试3: 添加相位偏移
    fprintf('\n=== 测试3: 相位偏移测试 ===\n');
    test_data_3 = randi([0, 1], 100, 1);
    
    % 调制
    modulated_signal_3 = bpsk.generate_signal(test_data_3, 'add_noise', true);
    
    % 人为添加相位偏移
    phase_offset = pi/4;  % 45度相位偏移
    phase_offset_signal = modulated_signal_3 * exp(1j * phase_offset);
    
    fprintf('  添加 %.1f 度相位偏移\n', phase_offset * 180/pi);
    
    % 解调
    recovered_data_3 = bpsk.recover_data(phase_offset_signal);
    fprintf('  解调完成，数据长度: %d\n', length(recovered_data_3));
    
    % 计算误码率
    min_len = min(length(test_data_3), length(recovered_data_3));
    ber_3 = bpsk.calculate_ber(test_data_3(1:min_len), recovered_data_3(1:min_len));
    fprintf('  误码率: %.6f\n', ber_3);
    
    % 测试4: 同时添加频率和相位偏移
    fprintf('\n=== 测试4: 频率+相位偏移测试 ===\n');
    test_data_4 = randi([0, 1], 200, 1);
    
    % 调制
    modulated_signal_4 = bpsk.generate_signal(test_data_4, 'add_noise', true);
    
    % 同时添加频率和相位偏移
    freq_offset = 500;    % 500 Hz频率偏移
    phase_offset = pi/6;  % 30度相位偏移
    t = (0:length(modulated_signal_4)-1) / config.sample_rate;
    combined_offset_signal = modulated_signal_4 .* exp(1j * (2*pi*freq_offset*t + phase_offset));
    
    fprintf('  添加 %d Hz 频率偏移 + %.1f 度相位偏移\n', freq_offset, phase_offset * 180/pi);
    
    % 解调
    recovered_data_4 = bpsk.recover_data(combined_offset_signal);
    fprintf('  解调完成，数据长度: %d\n', length(recovered_data_4));
    
    % 计算误码率
    min_len = min(length(test_data_4), length(recovered_data_4));
    ber_4 = bpsk.calculate_ber(test_data_4(1:min_len), recovered_data_4(1:min_len));
    fprintf('  误码率: %.6f\n', ber_4);
    
    % 测试5: 不同信噪比下的性能
    fprintf('\n=== 测试5: 不同信噪比性能测试 ===\n');
    snr_values = [5, 10, 15, 20];
    ber_results = zeros(size(snr_values));
    
    test_data_5 = randi([0, 1], 500, 1);
    
    for i = 1:length(snr_values)
        snr_db = snr_values(i);
        config.snr_db = snr_db;
        bpsk.configure(config);
        
        % 调制
        modulated_signal_5 = bpsk.generate_signal(test_data_5, 'add_noise', true);
        
        % 添加载波偏移
        freq_offset = 200;  % 200 Hz频率偏移
        t = (0:length(modulated_signal_5)-1) / config.sample_rate;
        offset_signal = modulated_signal_5 .* exp(1j * 2*pi*freq_offset*t);
        
        % 解调
        recovered_data_5 = bpsk.recover_data(offset_signal);
        
        % 计算误码率
        min_len = min(length(test_data_5), length(recovered_data_5));
        ber_results(i) = bpsk.calculate_ber(test_data_5(1:min_len), recovered_data_5(1:min_len));
        
        fprintf('  SNR = %2d dB: BER = %.6f\n', snr_db, ber_results(i));
    end
    
    % 测试载波同步工具的直接调用
    fprintf('\n=== 测试6: 载波同步工具直接测试 ===\n');
    
    % 生成测试信号
    test_signal = [1, -1, 1, -1, 1, -1] + 0.1 * (randn(1,6) + 1j*randn(1,6));
    sample_rate = 1000;
    
    % 测试平方环算法
    try
        [recovered_sq, freq_est_sq, phase_est_sq] = ...
            CarrierSync.recover_carrier_bpsk(test_signal, sample_rate, 'algorithm', 'squaring');
        fprintf('  平方环算法: 频率偏移 = %.2f Hz, 相位偏移 = %.3f rad\n', ...
            freq_est_sq, phase_est_sq);
    catch ME
        fprintf('  平方环算法失败: %s\n', ME.message);
    end
    
    % 测试Costas环算法
    try
        [recovered_costas, freq_est_costas, phase_est_costas] = ...
            CarrierSync.recover_carrier_bpsk(test_signal, sample_rate, 'algorithm', 'costas');
        fprintf('  Costas环算法: 频率偏移 = %.2f Hz, 相位偏移 = %.3f rad\n', ...
            freq_est_costas, phase_est_costas);
    catch ME
        fprintf('  Costas环算法失败: %s\n', ME.message);
    end
    
    % 总结测试结果
    fprintf('\n=== 测试总结 ===\n');
    
    if ber_1 < 0.1
        fprintf('✓ 理想情况测试通过 (BER = %.6f)\n', ber_1);
    else
        fprintf('✗ 理想情况测试失败 (BER = %.6f)\n', ber_1);
    end
    
    if ber_2 < 0.2
        fprintf('✓ 频率偏移测试通过 (BER = %.6f)\n', ber_2);
    else
        fprintf('✗ 频率偏移测试失败 (BER = %.6f)\n', ber_2);
    end
    
    if ber_3 < 0.2
        fprintf('✓ 相位偏移测试通过 (BER = %.6f)\n', ber_3);
    else
        fprintf('✗ 相位偏移测试失败 (BER = %.6f)\n', ber_3);
    end
    
    if ber_4 < 0.3
        fprintf('✓ 组合偏移测试通过 (BER = %.6f)\n', ber_4);
    else
        fprintf('✗ 组合偏移测试失败 (BER = %.6f)\n', ber_4);
    end
    
    % 检查SNR性能趋势
    if all(diff(ber_results) <= 0)  % BER应该随SNR增加而减少
        fprintf('✓ SNR性能趋势正确\n');
    else
        fprintf('✗ SNR性能趋势异常\n');
    end
    
catch ME
    fprintf('错误: %s\n', ME.message);
    fprintf('详细信息: %s\n', ME.getReport());
end

fprintf('\n=== 载波同步测试完成 ===\n');
