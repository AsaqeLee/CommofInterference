% test_dbpsk - 测试差分编码BPSK (DBPSK)
% 验证差分编码解决相位模糊问题的效果
%
% 作者: Asaqe Lee
% 日期: 2025-06-18

clc;
clear;

fprintf('========================================\n');
fprintf('  差分编码BPSK (DBPSK) 测试\n');
fprintf('========================================\n\n');

% 添加路径
addpath(genpath('src'));

%% 测试1: 传统BPSK vs 差分编码BPSK对比
fprintf('=== 测试1: 传统BPSK vs DBPSK对比 ===\n');

try
    % 创建两个BPSK实例
    bpsk_traditional = BPSK();
    bpsk_differential = BPSK();
    
    % 配置参数
    config = struct();
    config.center_frequency = 1e6;
    config.sample_rate = 10e6;
    config.symbol_rate = 1e6;
    config.snr_db = 20;
    
    % 配置传统BPSK（关闭差分编码）
    config.use_differential_encoding = false;
    bpsk_traditional.configure(config);
    
    % 配置差分编码BPSK（启用差分编码）
    config.use_differential_encoding = true;
    bpsk_differential.configure(config);
    
    fprintf('✓ 两种BPSK配置完成\n');
    
    % 测试数据
    test_data = [0; 1; 0; 1; 1; 0; 1; 0; 0; 1; 1; 1; 0; 0; 1; 0];
    fprintf('测试数据长度: %d 比特\n', length(test_data));
    fprintf('测试数据: [%s]\n', sprintf('%d', test_data));
    
    %% 测试1.1: 理想情况（无相位偏移）
    fprintf('\n--- 测试1.1: 理想情况 ---\n');
    
    % 传统BPSK
    signal_trad = bpsk_traditional.generate_signal(test_data, 'add_noise', false);
    recovered_trad = bpsk_traditional.recover_data(signal_trad);
    ber_trad_ideal = bpsk_traditional.calculate_ber(test_data, recovered_trad(1:length(test_data)));
    
    % 差分编码BPSK
    signal_diff = bpsk_differential.generate_signal(test_data, 'add_noise', false);
    recovered_diff = bpsk_differential.recover_data(signal_diff);
    ber_diff_ideal = bpsk_differential.calculate_ber(test_data, recovered_diff(1:length(test_data)));
    
    fprintf('传统BPSK误码率: %.6f\n', ber_trad_ideal);
    fprintf('差分BPSK误码率: %.6f\n', ber_diff_ideal);
    
    %% 测试1.2: 180度相位偏移
    fprintf('\n--- 测试1.2: 180度相位偏移 ---\n');
    
    % 添加180度相位偏移
    phase_shift = exp(1j * pi);
    
    % 传统BPSK + 相位偏移
    signal_trad_shifted = signal_trad * phase_shift;
    recovered_trad_shifted = bpsk_traditional.recover_data(signal_trad_shifted);
    ber_trad_shifted = bpsk_traditional.calculate_ber(test_data, recovered_trad_shifted(1:length(test_data)));
    
    % 差分编码BPSK + 相位偏移
    signal_diff_shifted = signal_diff * phase_shift;
    recovered_diff_shifted = bpsk_differential.recover_data(signal_diff_shifted);
    ber_diff_shifted = bpsk_differential.calculate_ber(test_data, recovered_diff_shifted(1:length(test_data)));
    
    fprintf('传统BPSK + 180°偏移误码率: %.6f\n', ber_trad_shifted);
    fprintf('差分BPSK + 180°偏移误码率: %.6f\n', ber_diff_shifted);
    
    %% 测试1.3: 随机相位偏移
    fprintf('\n--- 测试1.3: 随机相位偏移测试 ---\n');
    
    phase_offsets = [pi/6, pi/4, pi/3, pi/2, 2*pi/3, 3*pi/4, 5*pi/6, pi];
    
    fprintf('相位偏移(度) | 传统BPSK BER | 差分BPSK BER\n');
    fprintf('-------------|--------------|-------------\n');
    
    for i = 1:length(phase_offsets)
        phase_offset = phase_offsets(i);
        phase_shift = exp(1j * phase_offset);
        
        % 传统BPSK
        signal_trad_test = signal_trad * phase_shift;
        recovered_trad_test = bpsk_traditional.recover_data(signal_trad_test);
        ber_trad_test = bpsk_traditional.calculate_ber(test_data, recovered_trad_test(1:length(test_data)));
        
        % 差分编码BPSK
        signal_diff_test = signal_diff * phase_shift;
        recovered_diff_test = bpsk_differential.recover_data(signal_diff_test);
        ber_diff_test = bpsk_differential.calculate_ber(test_data, recovered_diff_test(1:length(test_data)));
        
        fprintf('%11.0f | %12.6f | %11.6f\n', phase_offset*180/pi, ber_trad_test, ber_diff_test);
    end
    
    fprintf('\n✓ 相位偏移测试完成\n');
    
catch ME
    fprintf('✗ 测试1失败: %s\n', ME.message);
end

%% 测试2: 差分编码原理验证
fprintf('\n=== 测试2: 差分编码原理验证 ===\n');

try
    % 创建DBPSK实例
    dbpsk = BPSK();
    config.use_differential_encoding = true;
    dbpsk.configure(config);
    
    % 简单测试数据
    simple_data = [0; 1; 0; 1];
    fprintf('原始数据: [%s]\n', sprintf('%d ', simple_data));
    
    % 手动验证差分编码过程
    fprintf('\n--- 手动差分编码验证 ---\n');
    fprintf('初始符号: +1\n');
    
    encoded_symbols = [1];  % 初始符号
    for i = 1:length(simple_data)
        if simple_data(i) == 0
            % 数据位0：无相位变化
            next_symbol = encoded_symbols(end) * 1;
            fprintf('数据位%d=0: 无相位变化, 符号: %+d\n', i, next_symbol);
        else
            % 数据位1：180度相位变化
            next_symbol = encoded_symbols(end) * (-1);
            fprintf('数据位%d=1: 180度相位变化, 符号: %+d\n', i, next_symbol);
        end
        encoded_symbols(end+1) = next_symbol;
    end
    
    fprintf('编码符号序列: [%s]\n', sprintf('%+d ', encoded_symbols));
    
    % 使用DBPSK生成信号
    signal = dbpsk.generate_signal(simple_data, 'add_noise', false);
    recovered = dbpsk.recover_data(signal);
    
    fprintf('\n--- DBPSK系统验证 ---\n');
    fprintf('恢复数据: [%s]\n', sprintf('%d ', recovered(1:length(simple_data))));
    
    ber = dbpsk.calculate_ber(simple_data, recovered(1:length(simple_data)));
    fprintf('误码率: %.6f\n', ber);
    
    if ber == 0
        fprintf('✓ 差分编码工作正常\n');
    else
        fprintf('✗ 差分编码存在问题\n');
    end
    
catch ME
    fprintf('✗ 测试2失败: %s\n', ME.message);
end

%% 测试3: 噪声环境下的性能
fprintf('\n=== 测试3: 噪声环境下的性能 ===\n');

try
    % SNR性能测试
    snr_range = [5, 10, 15, 20];
    test_data_noise = randi([0, 1], 200, 1);
    
    fprintf('SNR(dB) | 传统BPSK BER | 差分BPSK BER\n');
    fprintf('--------|--------------|-------------\n');
    
    for snr_db = snr_range
        % 配置SNR
        config.snr_db = snr_db;
        
        % 传统BPSK
        config.use_differential_encoding = false;
        bpsk_traditional.configure(config);
        signal_trad_noise = bpsk_traditional.generate_signal(test_data_noise, 'add_noise', true);
        recovered_trad_noise = bpsk_traditional.recover_data(signal_trad_noise);
        ber_trad_noise = bpsk_traditional.calculate_ber(test_data_noise, recovered_trad_noise(1:length(test_data_noise)));
        
        % 差分编码BPSK
        config.use_differential_encoding = true;
        bpsk_differential.configure(config);
        signal_diff_noise = bpsk_differential.generate_signal(test_data_noise, 'add_noise', true);
        recovered_diff_noise = bpsk_differential.recover_data(signal_diff_noise);
        ber_diff_noise = bpsk_differential.calculate_ber(test_data_noise, recovered_diff_noise(1:length(test_data_noise)));
        
        fprintf('%7d | %12.6f | %11.6f\n', snr_db, ber_trad_noise, ber_diff_noise);
    end
    
    fprintf('\n✓ 噪声性能测试完成\n');
    
catch ME
    fprintf('✗ 测试3失败: %s\n', ME.message);
end

%% 测试4: 波形信息验证
fprintf('\n=== 测试4: 波形信息验证 ===\n');

try
    % 传统BPSK信息
    config.use_differential_encoding = false;
    bpsk_traditional.configure(config);
    info_trad = bpsk_traditional.get_waveform_info();
    
    % 差分编码BPSK信息
    config.use_differential_encoding = true;
    bpsk_differential.configure(config);
    info_diff = bpsk_differential.get_waveform_info();
    
    fprintf('传统BPSK:\n');
    fprintf('  波形名称: %s\n', info_trad.waveform_name);
    fprintf('  差分编码: %s\n', mat2str(info_trad.use_differential_encoding));
    fprintf('  描述: %s\n', info_trad.description);
    
    fprintf('\n差分编码BPSK:\n');
    fprintf('  波形名称: %s\n', info_diff.waveform_name);
    fprintf('  差分编码: %s\n', mat2str(info_diff.use_differential_encoding));
    fprintf('  描述: %s\n', info_diff.description);
    
    fprintf('\n✓ 波形信息验证完成\n');
    
catch ME
    fprintf('✗ 测试4失败: %s\n', ME.message);
end

%% 测试总结
fprintf('\n========================================\n');
fprintf('  差分编码BPSK测试总结\n');
fprintf('========================================\n');

if exist('ber_diff_ideal', 'var') && exist('ber_diff_shifted', 'var')
    fprintf('差分编码BPSK性能:\n');
    fprintf('  理想情况误码率: %.6f\n', ber_diff_ideal);
    fprintf('  180度偏移误码率: %.6f\n', ber_diff_shifted);
    
    if ber_diff_ideal <= 0.1 && ber_diff_shifted <= 0.1
        fprintf('  ✓ 差分编码成功解决相位模糊问题！\n');
    elseif ber_diff_shifted < 0.4  % 明显改善
        fprintf('  ⚠ 差分编码显著改善了相位模糊问题\n');
    else
        fprintf('  ✗ 差分编码效果不明显\n');
    end
    
    if exist('ber_trad_shifted', 'var')
        improvement = (ber_trad_shifted - ber_diff_shifted) / ber_trad_shifted * 100;
        fprintf('  相位偏移下的改善程度: %.1f%%\n', improvement);
    end
else
    fprintf('✗ 测试未完成，无法评估性能\n');
end

fprintf('\n========================================\n');
fprintf('  差分编码BPSK测试完成！\n');
fprintf('========================================\n');
