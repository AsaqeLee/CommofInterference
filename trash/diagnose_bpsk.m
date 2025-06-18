% diagnose_bpsk - 诊断BPSK载波同步问题
% 详细分析载波同步算法的工作状态

clc;
clear;

fprintf('=== BPSK载波同步诊断 ===\n');

% 添加路径
addpath(genpath('src'));

try
    % 创建BPSK实例
    bpsk = BPSK();
    
    % 配置参数
    config = struct();
    config.center_frequency = 1e6;       % 1 MHz载波
    config.sample_rate = 10e6;           % 10 MHz采样率
    config.symbol_rate = 1e6;            % 1 Msps
    config.snr_db = 20;                  % 高信噪比测试
    
    bpsk.configure(config);
    
    % 简单测试数据
    test_data = [0; 1; 0; 1; 0; 1; 0; 1];  % 8比特交替模式
    fprintf('测试数据: [%s]\n', sprintf('%d ', test_data));
    
    % 调制（无噪声）
    fprintf('\n=== 调制过程分析 ===\n');
    modulated_signal = bpsk.generate_signal(test_data, 'add_noise', false, 'normalize', false);
    fprintf('调制信号长度: %d\n', length(modulated_signal));
    
    % 显示调制信号的前几个采样点
    fprintf('调制信号前20个采样点的实部:\n');
    for i = 1:min(20, length(modulated_signal))
        fprintf('%.3f ', real(modulated_signal(i)));
        if mod(i, 10) == 0
            fprintf('\n');
        end
    end
    fprintf('\n');
    
    % 手动载波恢复测试
    fprintf('\n=== 载波恢复分析 ===\n');
    
    % 测试不同的载波恢复算法
    algorithms = {'squaring', 'costas', 'blind'};
    
    for alg_idx = 1:length(algorithms)
        algorithm = algorithms{alg_idx};
        fprintf('\n--- %s 算法 ---\n', upper(algorithm));
        
        try
            [recovered_signal, freq_offset, phase_offset] = ...
                CarrierSync.recover_carrier_bpsk(modulated_signal, config.sample_rate, ...
                'algorithm', algorithm);
            
            fprintf('频率偏移估计: %.2f Hz\n', freq_offset);
            fprintf('相位偏移估计: %.3f rad (%.1f 度)\n', phase_offset, phase_offset*180/pi);
            
            % 显示恢复信号的前几个采样点
            fprintf('恢复信号前10个采样点:\n');
            for i = 1:min(10, length(recovered_signal))
                fprintf('%.3f%+.3fi ', real(recovered_signal(i)), imag(recovered_signal(i)));
            end
            fprintf('\n');
            
            % 下变频到基带
            t = (0:length(modulated_signal)-1) / config.sample_rate;
            carrier = exp(-1j * 2*pi*config.center_frequency*t);
            baseband_signal = recovered_signal .* carrier;
            
            % 符号采样
            samples_per_symbol = round(config.sample_rate / config.symbol_rate);
            fprintf('每符号采样数: %d\n', samples_per_symbol);
            
            % 简单采样（中点采样）
            symbol_indices = round(samples_per_symbol/2):samples_per_symbol:length(baseband_signal);
            symbol_indices = symbol_indices(symbol_indices <= length(baseband_signal));
            symbols = baseband_signal(symbol_indices);
            
            fprintf('采样符号数量: %d\n', length(symbols));
            fprintf('采样符号:\n');
            for i = 1:min(8, length(symbols))
                fprintf('符号%d: %.3f%+.3fi (幅度=%.3f, 相位=%.1f°)\n', ...
                    i, real(symbols(i)), imag(symbols(i)), ...
                    abs(symbols(i)), angle(symbols(i))*180/pi);
            end
            
            % 符号判决
            decisions = double(real(symbols) < 0);
            fprintf('判决结果: [%s]\n', sprintf('%d ', decisions));
            
            % 计算误码率
            min_len = min(length(test_data), length(decisions));
            errors = sum(test_data(1:min_len) ~= decisions(1:min_len));
            ber = errors / min_len;
            fprintf('误码率: %.3f (%d/%d)\n', ber, errors, min_len);
            
        catch ME
            fprintf('算法失败: %s\n', ME.message);
        end
    end
    
    % 相位模糊检测
    fprintf('\n=== 相位模糊分析 ===\n');
    
    % 使用平方环算法
    [recovered_signal, freq_offset, phase_offset] = ...
        CarrierSync.recover_carrier_bpsk(modulated_signal, config.sample_rate, ...
        'algorithm', 'squaring');
    
    % 下变频
    t = (0:length(modulated_signal)-1) / config.sample_rate;
    carrier = exp(-1j * 2*pi*config.center_frequency*t);
    baseband_signal = recovered_signal .* carrier;
    
    % 符号采样
    samples_per_symbol = round(config.sample_rate / config.symbol_rate);
    symbol_indices = round(samples_per_symbol/2):samples_per_symbol:length(baseband_signal);
    symbol_indices = symbol_indices(symbol_indices <= length(baseband_signal));
    symbols = baseband_signal(symbol_indices);
    
    % 测试两种判决方式
    decisions_normal = double(real(symbols) < 0);
    decisions_inverted = double(real(symbols) > 0);
    
    min_len = min(length(test_data), length(decisions_normal));
    ber_normal = sum(test_data(1:min_len) ~= decisions_normal(1:min_len)) / min_len;
    ber_inverted = sum(test_data(1:min_len) ~= decisions_inverted(1:min_len)) / min_len;
    
    fprintf('正常判决误码率: %.3f\n', ber_normal);
    fprintf('反向判决误码率: %.3f\n', ber_inverted);
    
    if ber_inverted < ber_normal
        fprintf('检测到相位模糊！应该使用反向判决\n');
    else
        fprintf('相位正常\n');
    end
    
    % 星座图分析
    fprintf('\n=== 星座图分析 ===\n');
    
    if length(symbols) >= 4
        % 计算星座点的统计信息
        real_parts = real(symbols);
        imag_parts = imag(symbols);
        
        fprintf('实部统计: 均值=%.3f, 标准差=%.3f, 范围=[%.3f, %.3f]\n', ...
            mean(real_parts), std(real_parts), min(real_parts), max(real_parts));
        fprintf('虚部统计: 均值=%.3f, 标准差=%.3f, 范围=[%.3f, %.3f]\n', ...
            mean(imag_parts), std(imag_parts), min(imag_parts), max(imag_parts));
        
        % 检查星座点分布
        positive_real = sum(real_parts > 0);
        negative_real = sum(real_parts < 0);
        fprintf('正实部符号数: %d, 负实部符号数: %d\n', positive_real, negative_real);
        
        if positive_real == 0 || negative_real == 0
            fprintf('警告: 所有符号都在同一侧，可能存在直流偏移或载波恢复问题\n');
        end
    end
    
    fprintf('\n=== 诊断完成 ===\n');
    
catch ME
    fprintf('错误: %s\n', ME.message);
    fprintf('详细信息: %s\n', ME.getReport());
end
