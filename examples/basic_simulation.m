function basic_simulation()
    % basic_simulation - 基础仿真示例
    % 演示通信波形生成模块的基本使用方法
    %
    % 作者: 通信干扰仿真平台开发团队
    % 日期: 2025-06-18
    
    clc;
    clear;
    close all;
    
    fprintf('========================================\n');
    fprintf('  通信波形基础仿真示例\n');
    fprintf('========================================\n\n');
    
    % 添加路径
    addpath(genpath('../src'));
    
    try
        % 1. 演示波形工厂使用
        fprintf('1. 演示波形工厂使用\n');
        demo_waveform_factory();
        
        % 2. 演示BPSK调制解调
        fprintf('\n2. 演示BPSK调制解调\n');
        demo_bpsk_modulation();
        
        % 3. 演示QPSK调制解调
        fprintf('\n3. 演示QPSK调制解调\n');
        demo_qpsk_modulation();
        
        % 4. 演示16QAM调制解调
        fprintf('\n4. 演示16QAM调制解调\n');
        demo_16qam_modulation();
        
        % 5. 演示FSK调制解调
        fprintf('\n5. 演示FSK调制解调\n');
        demo_fsk_modulation();
        
        % 6. 性能比较
        fprintf('\n6. 性能比较\n');
        compare_modulation_performance();
        
        fprintf('\n========================================\n');
        fprintf('  仿真示例完成！\n');
        fprintf('========================================\n');
        
    catch ME
        fprintf('\n错误: %s\n', ME.message);
        fprintf('详细信息: %s\n', ME.getReport());
    end
end

function demo_waveform_factory()
    % 演示波形工厂的使用
    
    fprintf('  创建波形工厂实例...\n');
    factory = WaveformFactory.getInstance();
    
    fprintf('  获取支持的波形列表:\n');
    supported_waveforms = factory.get_supported_waveforms();
    for i = 1:min(5, length(supported_waveforms))  % 只显示前5个
        fprintf('    %d. %s\n', i, supported_waveforms{i});
    end
    
    fprintf('  创建BPSK波形实例...\n');
    try
        bpsk_waveform = factory.create_waveform('BPSK');
        fprintf('    ✓ BPSK波形创建成功\n');
    catch ME
        fprintf('    ✗ BPSK波形创建失败: %s\n', ME.message);
    end
end

function demo_bpsk_modulation()
    % 演示BPSK调制解调
    
    fprintf('  创建BPSK波形实例...\n');
    bpsk = BPSK();
    
    % 配置参数
    config = struct();
    config.center_frequency = 1e9;    % 1 GHz
    config.sample_rate = 10e6;        % 10 MHz
    config.symbol_rate = 1e6;         % 1 Msps
    config.snr_db = 10;               % 10 dB
    
    bpsk.configure(config);
    fprintf('  BPSK波形配置完成\n');
    
    % 生成测试数据
    num_bits = 100;
    test_data = randi([0, 1], num_bits, 1);
    fprintf('  生成 %d 比特测试数据\n', num_bits);
    
    % 调制
    fprintf('  执行BPSK调制...\n');
    modulated_signal = bpsk.generate_signal(test_data);
    fprintf('    调制信号长度: %d 采样点\n', length(modulated_signal));
    
    % 解调
    fprintf('  执行BPSK解调...\n');
    recovered_data = bpsk.recover_data(modulated_signal);
    fprintf('    恢复数据长度: %d 比特\n', length(recovered_data));
    
    % 计算误码率
    ber = bpsk.calculate_ber(test_data, recovered_data);
    fprintf('    误码率: %.6f\n', ber);
    
    % 绘制信号
    plot_signal_comparison(test_data(1:20), modulated_signal(1:200), 'BPSK');
end

function demo_qpsk_modulation()
    % 演示QPSK调制解调
    
    fprintf('  创建QPSK波形实例...\n');
    qpsk = QPSK();
    
    % 配置参数
    config = struct();
    config.center_frequency = 1e9;    % 1 GHz
    config.sample_rate = 10e6;        % 10 MHz
    config.symbol_rate = 1e6;         % 1 Msps
    config.snr_db = 10;               % 10 dB
    
    qpsk.configure(config);
    fprintf('  QPSK波形配置完成\n');
    
    % 生成测试数据
    num_bits = 100;
    test_data = randi([0, 1], num_bits, 1);
    fprintf('  生成 %d 比特测试数据\n', num_bits);
    
    % 调制
    fprintf('  执行QPSK调制...\n');
    modulated_signal = qpsk.generate_signal(test_data);
    fprintf('    调制信号长度: %d 采样点\n', length(modulated_signal));
    
    % 解调
    fprintf('  执行QPSK解调...\n');
    recovered_data = qpsk.recover_data(modulated_signal);
    fprintf('    恢复数据长度: %d 比特\n', length(recovered_data));
    
    % 计算误码率
    ber = qpsk.calculate_ber(test_data, recovered_data);
    fprintf('    误码率: %.6f\n', ber);
    
    % 绘制星座图
    plot_constellation_demo(qpsk, test_data);
end

function demo_16qam_modulation()
    % 演示16QAM调制解调
    
    fprintf('  创建16QAM波形实例...\n');
    qam16 = QAM16();
    
    % 配置参数
    config = struct();
    config.center_frequency = 1e9;    % 1 GHz
    config.sample_rate = 10e6;        % 10 MHz
    config.symbol_rate = 1e6;         % 1 Msps
    config.snr_db = 15;               % 15 dB (QAM需要更高SNR)
    
    qam16.configure(config);
    fprintf('  16QAM波形配置完成\n');
    
    % 生成测试数据
    num_bits = 100;
    test_data = randi([0, 1], num_bits, 1);
    fprintf('  生成 %d 比特测试数据\n', num_bits);
    
    % 调制
    fprintf('  执行16QAM调制...\n');
    modulated_signal = qam16.generate_signal(test_data);
    fprintf('    调制信号长度: %d 采样点\n', length(modulated_signal));
    
    % 解调
    fprintf('  执行16QAM解调...\n');
    recovered_data = qam16.recover_data(modulated_signal);
    fprintf('    恢复数据长度: %d 比特\n', length(recovered_data));
    
    % 计算误码率
    ber = qam16.calculate_ber(test_data, recovered_data);
    fprintf('    误码率: %.6f\n', ber);
    
    % 绘制星座图
    plot_constellation_demo(qam16, test_data);
end

function demo_fsk_modulation()
    % 演示FSK调制解调
    
    fprintf('  创建FSK波形实例...\n');
    fsk = FSK();
    
    % 配置参数
    config = struct();
    config.center_frequency = 1e9;      % 1 GHz
    config.sample_rate = 10e6;          % 10 MHz
    config.symbol_rate = 1e6;           % 1 Msps
    config.frequency_deviation = 500e3; % 500 kHz频偏
    config.snr_db = 10;                 % 10 dB
    
    fsk.configure(config);
    fprintf('  FSK波形配置完成\n');
    
    % 生成测试数据
    num_bits = 100;
    test_data = randi([0, 1], num_bits, 1);
    fprintf('  生成 %d 比特测试数据\n', num_bits);
    
    % 调制
    fprintf('  执行FSK调制...\n');
    modulated_signal = fsk.generate_signal(test_data);
    fprintf('    调制信号长度: %d 采样点\n', length(modulated_signal));
    
    % 相干解调
    fprintf('  执行FSK相干解调...\n');
    recovered_data_coherent = fsk.recover_data(modulated_signal, 'method', 'coherent');
    ber_coherent = fsk.calculate_ber(test_data, recovered_data_coherent);
    fprintf('    相干解调误码率: %.6f\n', ber_coherent);
    
    % 非相干解调
    fprintf('  执行FSK非相干解调...\n');
    recovered_data_noncoherent = fsk.recover_data(modulated_signal, 'method', 'noncoherent');
    ber_noncoherent = fsk.calculate_ber(test_data, recovered_data_noncoherent);
    fprintf('    非相干解调误码率: %.6f\n', ber_noncoherent);
    
    % 绘制频率响应
    fsk.plot_frequency_response();
end

function compare_modulation_performance()
    % 比较不同调制方式的性能
    
    fprintf('  比较调制性能...\n');
    
    % 测试参数
    snr_range = 0:2:20;  % dB
    num_bits = 1000;
    
    % 创建波形实例
    bpsk = BPSK();
    qpsk = QPSK();
    qam16 = QAM16();
    
    % 配置参数
    config = struct();
    config.center_frequency = 1e9;
    config.sample_rate = 10e6;
    config.symbol_rate = 1e6;
    
    % 存储结果
    ber_bpsk = zeros(size(snr_range));
    ber_qpsk = zeros(size(snr_range));
    ber_qam16 = zeros(size(snr_range));
    
    fprintf('    测试不同SNR下的性能...\n');
    
    for i = 1:length(snr_range)
        snr_db = snr_range(i);
        config.snr_db = snr_db;
        
        % 生成测试数据
        test_data = randi([0, 1], num_bits, 1);
        
        % BPSK测试
        try
            bpsk.configure(config);
            signal_bpsk = bpsk.generate_signal(test_data);
            recovered_bpsk = bpsk.recover_data(signal_bpsk);
            ber_bpsk(i) = bpsk.calculate_ber(test_data, recovered_bpsk);
        catch
            ber_bpsk(i) = NaN;
        end
        
        % QPSK测试
        try
            qpsk.configure(config);
            signal_qpsk = qpsk.generate_signal(test_data);
            recovered_qpsk = qpsk.recover_data(signal_qpsk);
            ber_qpsk(i) = qpsk.calculate_ber(test_data, recovered_qpsk);
        catch
            ber_qpsk(i) = NaN;
        end
        
        % 16QAM测试
        try
            qam16.configure(config);
            signal_qam16 = qam16.generate_signal(test_data);
            recovered_qam16 = qam16.recover_data(signal_qam16);
            ber_qam16(i) = qam16.calculate_ber(test_data, recovered_qam16);
        catch
            ber_qam16(i) = NaN;
        end
        
        fprintf('      SNR = %d dB: BPSK=%.4f, QPSK=%.4f, 16QAM=%.4f\n', ...
            snr_db, ber_bpsk(i), ber_qpsk(i), ber_qam16(i));
    end
    
    % 绘制性能比较图
    plot_performance_comparison(snr_range, ber_bpsk, ber_qpsk, ber_qam16);
end

function plot_signal_comparison(data, signal, title_str)
    % 绘制信号比较图
    
    figure('Name', sprintf('%s 信号', title_str));
    
    subplot(2,1,1);
    stem(1:length(data), data, 'b', 'LineWidth', 1.5);
    xlabel('比特索引');
    ylabel('数据值');
    title(sprintf('%s - 原始数据', title_str));
    grid on;
    ylim([-0.5, 1.5]);
    
    subplot(2,1,2);
    t = (0:length(signal)-1) / 10e6;  % 假设10MHz采样率
    plot(t*1e6, real(signal), 'r', 'LineWidth', 1);
    hold on;
    plot(t*1e6, imag(signal), 'b', 'LineWidth', 1);
    xlabel('时间 (μs)');
    ylabel('幅度');
    title(sprintf('%s - 调制信号', title_str));
    legend('实部', '虚部');
    grid on;
end

function plot_constellation_demo(waveform, test_data)
    % 绘制星座图演示
    
    try
        % 生成一些符号用于星座图
        modulated_signal = waveform.generate_signal(test_data);
        
        % 简单的符号提取（用于演示）
        samples_per_symbol = 10;  % 假设值
        symbol_indices = round(samples_per_symbol/2):samples_per_symbol:length(modulated_signal);
        received_symbols = modulated_signal(symbol_indices(1:min(50, length(symbol_indices))));
        
        % 绘制星座图
        waveform.plot_constellation(received_symbols);
        
    catch ME
        fprintf('    星座图绘制失败: %s\n', ME.message);
    end
end

function plot_performance_comparison(snr_range, ber_bpsk, ber_qpsk, ber_qam16)
    % 绘制性能比较图
    
    figure('Name', '调制性能比较');
    
    semilogy(snr_range, ber_bpsk, 'bo-', 'LineWidth', 2, 'MarkerSize', 6, 'DisplayName', 'BPSK');
    hold on;
    semilogy(snr_range, ber_qpsk, 'rs-', 'LineWidth', 2, 'MarkerSize', 6, 'DisplayName', 'QPSK');
    semilogy(snr_range, ber_qam16, 'g^-', 'LineWidth', 2, 'MarkerSize', 6, 'DisplayName', '16QAM');
    
    xlabel('信噪比 (dB)');
    ylabel('误码率 (BER)');
    title('数字调制方式性能比较');
    legend('Location', 'southwest');
    grid on;
    ylim([1e-6, 1]);
    
    % 保存图像
    output_dir = '../data/output/analysis';
    if ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end
    
    try
        saveas(gcf, fullfile(output_dir, 'modulation_performance_comparison.png'));
        fprintf('    性能比较图已保存\n');
    catch
        fprintf('    性能比较图保存失败\n');
    end
end

% 如果直接运行此文件，执行主函数
if ~exist('OCTAVE_VERSION', 'builtin')
    % MATLAB环境
    if strcmp(mfilename, 'basic_simulation')
        basic_simulation();
    end
else
    % Octave环境
    basic_simulation();
end
