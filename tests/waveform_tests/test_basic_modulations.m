function test_basic_modulations()
    % test_basic_modulations - 测试基础调制波形
    % 验证BPSK、QPSK、16QAM等基础调制波形的功能
    %
    % 作者: 通信干扰仿真平台开发团队
    % 日期: 2025-06-18
    
    fprintf('=== 基础调制波形测试 ===\n\n');
    
    % 添加路径
    addpath(genpath('../../src'));
    
    % 测试参数
    test_params = struct();
    test_params.num_bits = 1000;
    test_params.snr_range = 0:2:20;  % dB
    test_params.center_frequency = 1e9;  % 1 GHz
    test_params.sample_rate = 10e6;      % 10 MHz
    test_params.symbol_rate = 1e6;       % 1 Msps
    
    % 生成测试数据
    test_data = randi([0, 1], test_params.num_bits, 1);
    
    % 测试波形列表
    waveforms_to_test = {'BPSK', 'QPSK', 'QAM16'};
    
    % 存储测试结果
    test_results = struct();
    
    for i = 1:length(waveforms_to_test)
        waveform_type = waveforms_to_test{i};
        fprintf('测试 %s 波形...\n', waveform_type);
        
        try
            % 测试波形创建和配置
            result = test_waveform_basic(waveform_type, test_data, test_params);
            test_results.(waveform_type) = result;
            
            if result.success
                fprintf('  ✓ %s 测试通过\n', waveform_type);
            else
                fprintf('  ✗ %s 测试失败: %s\n', waveform_type, result.error_message);
            end
            
        catch ME
            fprintf('  ✗ %s 测试异常: %s\n', waveform_type, ME.message);
            test_results.(waveform_type) = struct('success', false, 'error_message', ME.message);
        end
    end
    
    % 打印测试总结
    fprintf('\n=== 测试总结 ===\n');
    success_count = 0;
    total_count = length(waveforms_to_test);
    
    for i = 1:length(waveforms_to_test)
        waveform_type = waveforms_to_test{i};
        if isfield(test_results, waveform_type) && test_results.(waveform_type).success
            success_count = success_count + 1;
        end
    end
    
    fprintf('通过测试: %d/%d\n', success_count, total_count);
    fprintf('测试完成率: %.1f%%\n', 100 * success_count / total_count);
    
    % 如果所有测试都通过，进行性能测试
    if success_count == total_count
        fprintf('\n所有基础测试通过，开始性能测试...\n');
        performance_test_results = test_waveform_performance(test_results, test_params);
        plot_performance_results(performance_test_results);
    end
    
    fprintf('\n=== 测试结束 ===\n');
end

function result = test_waveform_basic(waveform_type, test_data, params)
    % 测试单个波形的基础功能
    % 输入: waveform_type - 波形类型
    %      test_data - 测试数据
    %      params - 测试参数
    % 输出: result - 测试结果结构体
    
    result = struct();
    result.success = false;
    result.error_message = '';
    result.waveform_type = waveform_type;
    
    try
        % 1. 创建波形实例
        waveform = feval(waveform_type);
        
        % 2. 配置波形参数
        config = struct();
        config.center_frequency = params.center_frequency;
        config.sample_rate = params.sample_rate;
        config.symbol_rate = params.symbol_rate;
        config.snr_db = 10;  % 10dB测试信噪比
        
        waveform.configure(config);
        
        % 3. 测试调制
        modulated_signal = waveform.generate_signal(test_data);
        
        if isempty(modulated_signal)
            result.error_message = '调制信号为空';
            return;
        end
        
        % 4. 测试解调
        recovered_data = waveform.recover_data(modulated_signal);
        
        if isempty(recovered_data)
            result.error_message = '解调数据为空';
            return;
        end
        
        % 5. 计算误码率
        ber = waveform.calculate_ber(test_data, recovered_data);
        
        % 6. 测试频谱分析
        spectrum = waveform.get_spectrum(modulated_signal);
        
        if ~isfield(spectrum, 'frequencies') || ~isfield(spectrum, 'power_density')
            result.error_message = '频谱分析结果不完整';
            return;
        end
        
        % 7. 测试波形信息获取
        info = waveform.get_waveform_info();
        
        if ~isfield(info, 'waveform_name') || ~strcmp(info.waveform_name, waveform_type)
            result.error_message = '波形信息不正确';
            return;
        end
        
        % 保存测试结果
        result.success = true;
        result.ber = ber;
        result.signal_length = length(modulated_signal);
        result.spectrum_points = length(spectrum.frequencies);
        result.waveform_info = info;
        result.modulated_signal = modulated_signal;
        result.recovered_data = recovered_data;
        
        % 验证误码率在合理范围内（10dB SNR下应该较低）
        if ber > 0.1  % 10%误码率阈值
            result.error_message = sprintf('误码率过高: %.4f', ber);
            result.success = false;
        end
        
    catch ME
        result.error_message = ME.message;
    end
end

function performance_results = test_waveform_performance(test_results, params)
    % 测试波形性能
    % 输入: test_results - 基础测试结果
    %      params - 测试参数
    % 输出: performance_results - 性能测试结果
    
    fprintf('\n--- 性能测试 ---\n');
    
    waveform_types = fieldnames(test_results);
    performance_results = struct();
    
    % 生成测试数据
    test_data = randi([0, 1], params.num_bits, 1);
    
    for i = 1:length(waveform_types)
        waveform_type = waveform_types{i};
        
        if ~test_results.(waveform_type).success
            continue;
        end
        
        fprintf('测试 %s 性能曲线...\n', waveform_type);
        
        % 创建波形实例
        waveform = feval(waveform_type);
        
        % 配置基础参数
        config = struct();
        config.center_frequency = params.center_frequency;
        config.sample_rate = params.sample_rate;
        config.symbol_rate = params.symbol_rate;
        
        % 测试不同信噪比下的性能
        ber_measured = zeros(size(params.snr_range));
        
        for j = 1:length(params.snr_range)
            snr_db = params.snr_range(j);
            config.snr_db = snr_db;
            waveform.configure(config);
            
            % 多次测试取平均
            num_trials = 5;
            ber_trials = zeros(1, num_trials);
            
            for trial = 1:num_trials
                % 生成新的随机数据
                trial_data = randi([0, 1], params.num_bits, 1);
                
                % 调制和解调
                modulated_signal = waveform.generate_signal(trial_data);
                recovered_data = waveform.recover_data(modulated_signal);
                
                % 计算误码率
                ber_trials(trial) = waveform.calculate_ber(trial_data, recovered_data);
            end
            
            ber_measured(j) = mean(ber_trials);
        end
        
        % 获取理论误码率
        info = waveform.get_waveform_info();
        if isfield(info, 'theoretical_ber')
            ber_theoretical = info.theoretical_ber(params.snr_range);
        else
            ber_theoretical = [];
        end
        
        % 保存性能结果
        performance_results.(waveform_type) = struct();
        performance_results.(waveform_type).snr_range = params.snr_range;
        performance_results.(waveform_type).ber_measured = ber_measured;
        performance_results.(waveform_type).ber_theoretical = ber_theoretical;
        performance_results.(waveform_type).waveform_info = info;
    end
end

function plot_performance_results(performance_results)
    % 绘制性能测试结果
    % 输入: performance_results - 性能测试结果
    
    if isempty(performance_results)
        return;
    end
    
    figure('Name', '波形性能比较', 'Position', [100, 100, 800, 600]);
    
    waveform_types = fieldnames(performance_results);
    colors = {'b', 'r', 'g', 'm', 'c', 'k'};
    
    hold on;
    legend_entries = {};
    
    for i = 1:length(waveform_types)
        waveform_type = waveform_types{i};
        result = performance_results.(waveform_type);
        
        color = colors{mod(i-1, length(colors)) + 1};
        
        % 绘制测量的误码率
        semilogy(result.snr_range, result.ber_measured, ...
            [color 'o-'], 'LineWidth', 2, 'MarkerSize', 6);
        legend_entries{end+1} = sprintf('%s (测量)', waveform_type);
        
        % 绘制理论误码率（如果有）
        if ~isempty(result.ber_theoretical)
            semilogy(result.snr_range, result.ber_theoretical, ...
                [color '--'], 'LineWidth', 1.5);
            legend_entries{end+1} = sprintf('%s (理论)', waveform_type);
        end
    end
    
    xlabel('信噪比 (dB)');
    ylabel('误码率 (BER)');
    title('数字调制波形性能比较');
    grid on;
    legend(legend_entries, 'Location', 'southwest');
    ylim([1e-6, 1]);
    
    % 保存图像
    saveas(gcf, '../../data/output/analysis/waveform_performance.png');
    fprintf('性能曲线已保存到: data/output/analysis/waveform_performance.png\n');
end
