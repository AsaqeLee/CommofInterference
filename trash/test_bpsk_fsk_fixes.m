% test_bpsk_fsk_fixes - 测试BPSK和FSK的修复效果
% 验证相位模糊检测和FSK接口修复
%
% 作者: Asaqe Lee
% 日期: 2025-06-18

clc;
clear;

fprintf('========================================\n');
fprintf('  BPSK和FSK修复效果测试\n');
fprintf('========================================\n\n');

% 添加路径
addpath(genpath('src'));

%% 测试1: BPSK相位模糊修复
fprintf('=== 测试1: BPSK相位模糊修复 ===\n');

try
    % 创建BPSK实例
    bpsk = BPSK();
    
    % 配置参数
    config = struct();
    config.center_frequency = 1e6;
    config.sample_rate = 10e6;
    config.symbol_rate = 1e6;
    config.snr_db = 20;  % 高信噪比测试
    
    bpsk.configure(config);
    fprintf('✓ BPSK配置成功\n');
    
    % 测试1.1: 理想情况（无相位偏移）
    fprintf('\n--- 测试1.1: 理想情况 ---\n');
    test_data_1 = randi([0, 1], 100, 1);
    
    signal_1 = bpsk.generate_signal(test_data_1, 'add_noise', false);
    recovered_1 = bpsk.recover_data(signal_1);
    
    min_len = min(length(test_data_1), length(recovered_1));
    ber_1 = bpsk.calculate_ber(test_data_1(1:min_len), recovered_1(1:min_len));
    
    fprintf('  原始数据长度: %d\n', length(test_data_1));
    fprintf('  恢复数据长度: %d\n', length(recovered_1));
    fprintf('  误码率: %.6f\n', ber_1);
    
    % 测试1.2: 添加180度相位偏移
    fprintf('\n--- 测试1.2: 180度相位偏移 ---\n');
    test_data_2 = randi([0, 1], 100, 1);
    
    signal_2 = bpsk.generate_signal(test_data_2, 'add_noise', false);
    % 添加180度相位偏移
    phase_shifted_signal = signal_2 * exp(1j * pi);
    
    recovered_2 = bpsk.recover_data(phase_shifted_signal);
    
    min_len = min(length(test_data_2), length(recovered_2));
    ber_2 = bpsk.calculate_ber(test_data_2(1:min_len), recovered_2(1:min_len));
    
    fprintf('  添加180度相位偏移\n');
    fprintf('  误码率: %.6f\n', ber_2);
    
    % 测试1.3: 随机相位偏移
    fprintf('\n--- 测试1.3: 随机相位偏移 ---\n');
    phase_offsets = [pi/6, pi/4, pi/3, pi/2, 2*pi/3, 3*pi/4, 5*pi/6, pi];
    
    for i = 1:length(phase_offsets)
        phase_offset = phase_offsets(i);
        test_data_3 = randi([0, 1], 50, 1);
        
        signal_3 = bpsk.generate_signal(test_data_3, 'add_noise', false);
        phase_shifted_signal_3 = signal_3 * exp(1j * phase_offset);
        
        recovered_3 = bpsk.recover_data(phase_shifted_signal_3);
        
        min_len = min(length(test_data_3), length(recovered_3));
        ber_3 = bpsk.calculate_ber(test_data_3(1:min_len), recovered_3(1:min_len));
        
        fprintf('  相位偏移 %3.0f度: BER = %.6f\n', phase_offset*180/pi, ber_3);
    end
    
    % 测试1.4: 带噪声的相位模糊测试
    fprintf('\n--- 测试1.4: 带噪声测试 ---\n');
    config.snr_db = 15;  % 降低信噪比
    bpsk.configure(config);
    
    test_data_4 = randi([0, 1], 200, 1);
    signal_4 = bpsk.generate_signal(test_data_4, 'add_noise', true);
    
    % 添加相位偏移
    phase_shifted_signal_4 = signal_4 * exp(1j * pi);
    
    recovered_4 = bpsk.recover_data(phase_shifted_signal_4);
    
    min_len = min(length(test_data_4), length(recovered_4));
    ber_4 = bpsk.calculate_ber(test_data_4(1:min_len), recovered_4(1:min_len));
    
    fprintf('  SNR = 15dB, 180度相位偏移\n');
    fprintf('  误码率: %.6f\n', ber_4);
    
    fprintf('\n✓ BPSK测试完成\n');
    
catch ME
    fprintf('✗ BPSK测试失败: %s\n', ME.message);
end

%% 测试2: FSK接口修复
fprintf('\n=== 测试2: FSK接口修复 ===\n');

try
    % 创建FSK实例
    fsk = FSK();
    
    % 配置参数
    config = struct();
    config.center_frequency = 1e6;
    config.sample_rate = 10e6;
    config.symbol_rate = 1e6;
    config.frequency_deviation = 500e3;
    config.snr_db = 15;
    
    fsk.configure(config);
    fprintf('✓ FSK配置成功\n');
    
    % 测试2.1: 相干解调
    fprintf('\n--- 测试2.1: 相干解调 ---\n');
    test_data_fsk_1 = randi([0, 1], 50, 1);
    
    signal_fsk_1 = fsk.generate_signal(test_data_fsk_1, 'add_noise', true);
    fprintf('  调制完成，信号长度: %d\n', length(signal_fsk_1));
    
    % 使用新的recover_data接口
    recovered_fsk_1 = fsk.recover_data(signal_fsk_1, 'method', 'coherent');
    fprintf('  相干解调完成，数据长度: %d\n', length(recovered_fsk_1));
    
    min_len = min(length(test_data_fsk_1), length(recovered_fsk_1));
    ber_fsk_1 = fsk.calculate_ber(test_data_fsk_1(1:min_len), recovered_fsk_1(1:min_len));
    
    fprintf('  相干解调误码率: %.6f\n', ber_fsk_1);
    
    % 测试2.2: 非相干解调
    fprintf('\n--- 测试2.2: 非相干解调 ---\n');
    test_data_fsk_2 = randi([0, 1], 50, 1);
    
    signal_fsk_2 = fsk.generate_signal(test_data_fsk_2, 'add_noise', true);
    
    try
        recovered_fsk_2 = fsk.recover_data(signal_fsk_2, 'method', 'noncoherent');
        fprintf('  非相干解调完成，数据长度: %d\n', length(recovered_fsk_2));
        
        min_len = min(length(test_data_fsk_2), length(recovered_fsk_2));
        ber_fsk_2 = fsk.calculate_ber(test_data_fsk_2(1:min_len), recovered_fsk_2(1:min_len));
        
        fprintf('  非相干解调误码率: %.6f\n', ber_fsk_2);
    catch ME
        fprintf('  非相干解调失败: %s\n', ME.message);
    end
    
    % 测试2.3: 默认参数测试
    fprintf('\n--- 测试2.3: 默认参数测试 ---\n');
    test_data_fsk_3 = randi([0, 1], 50, 1);
    
    signal_fsk_3 = fsk.generate_signal(test_data_fsk_3, 'add_noise', true);
    
    % 不指定method参数，应该使用默认的coherent
    recovered_fsk_3 = fsk.recover_data(signal_fsk_3);
    fprintf('  默认解调完成，数据长度: %d\n', length(recovered_fsk_3));
    
    min_len = min(length(test_data_fsk_3), length(recovered_fsk_3));
    ber_fsk_3 = fsk.calculate_ber(test_data_fsk_3(1:min_len), recovered_fsk_3(1:min_len));
    
    fprintf('  默认解调误码率: %.6f\n', ber_fsk_3);
    
    % 测试2.4: 频率响应绘制
    fprintf('\n--- 测试2.4: 频率响应测试 ---\n');
    try
        fsk.plot_frequency_response();
        close(gcf);  % 关闭图形窗口
        fprintf('  ✓ 频率响应绘制成功\n');
    catch ME
        fprintf('  ✗ 频率响应绘制失败: %s\n', ME.message);
    end
    
    % 测试2.5: 波形信息获取
    fprintf('\n--- 测试2.5: 波形信息测试 ---\n');
    try
        info = fsk.get_waveform_info();
        fprintf('  ✓ 波形信息获取成功\n');
        fprintf('    波形名称: %s\n', info.waveform_name);
        fprintf('    调制类型: %s\n', info.modulation_type);
        fprintf('    频偏: %.1f kHz\n', info.frequency_deviation/1000);
        fprintf('    调制指数: %.2f\n', info.modulation_index);
    catch ME
        fprintf('  ✗ 波形信息获取失败: %s\n', ME.message);
    end
    
    fprintf('\n✓ FSK测试完成\n');
    
catch ME
    fprintf('✗ FSK测试失败: %s\n', ME.message);
end

%% 测试总结
fprintf('\n========================================\n');
fprintf('  测试总结\n');
fprintf('========================================\n');

fprintf('BPSK修复效果:\n');
if exist('ber_1', 'var') && exist('ber_2', 'var')
    % 取最后一个误码率值（因为可能有多个输出）
    if length(ber_1) > 1
        ber_1_final = ber_1(end);
    else
        ber_1_final = ber_1;
    end

    if length(ber_2) > 1
        ber_2_final = ber_2(end);
    else
        ber_2_final = ber_2;
    end

    if ber_1_final <= 0.1 && ber_2_final <= 0.1
        fprintf('  ✓ 相位模糊检测工作正常\n');
    elseif ber_1_final <= 0.1
        fprintf('  ⚠ 理想情况正常，但相位模糊检测需要改进\n');
    else
        fprintf('  ✗ BPSK仍存在问题\n');
    end

    fprintf('  - 理想情况误码率: %.6f\n', ber_1_final);
    fprintf('  - 180度偏移误码率: %.6f\n', ber_2_final);
    if exist('ber_4', 'var')
        if length(ber_4) > 1
            ber_4_final = ber_4(end);
        else
            ber_4_final = ber_4;
        end
        fprintf('  - 带噪声180度偏移误码率: %.6f\n', ber_4_final);
    end
else
    fprintf('  ✗ BPSK测试未完成\n');
end

fprintf('\nFSK修复效果:\n');
if exist('ber_fsk_1', 'var')
    if ber_fsk_1 <= 0.2
        fprintf('  ✓ FSK接口修复成功\n');
    else
        fprintf('  ⚠ FSK接口可用但性能需要改进\n');
    end
    
    fprintf('  - 相干解调误码率: %.6f\n', ber_fsk_1);
    if exist('ber_fsk_2', 'var')
        fprintf('  - 非相干解调误码率: %.6f\n', ber_fsk_2);
    end
    if exist('ber_fsk_3', 'var')
        fprintf('  - 默认解调误码率: %.6f\n', ber_fsk_3);
    end
else
    fprintf('  ✗ FSK测试未完成\n');
end

fprintf('\n========================================\n');
fprintf('  修复测试完成！\n');
fprintf('========================================\n');
