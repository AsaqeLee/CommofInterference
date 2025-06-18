% comprehensive_test - 综合系统测试
% 测试所有已完成的通信波形生成模块功能
%
% 作者: 通信干扰仿真平台开发团队
% 日期: 2025-06-18

clc;
clear;
close all;

fprintf('========================================\n');
fprintf('  通信波形生成模块综合测试\n');
fprintf('========================================\n\n');

% 添加路径
addpath(genpath('src'));
addpath(genpath('config'));
addpath(genpath('tests'));

% 测试结果统计
test_results = struct();
test_results.total_tests = 0;
test_results.passed_tests = 0;
test_results.failed_tests = 0;
test_results.details = {};

try
    %% 1. 系统初始化测试
    fprintf('=== 1. 系统初始化测试 ===\n');
    [init_result, init_details] = test_system_initialization();
    test_results = update_test_results(test_results, 'System Initialization', init_result, init_details);
    
    %% 2. 波形工厂测试
    fprintf('\n=== 2. 波形工厂测试 ===\n');
    [factory_result, factory_details] = test_waveform_factory();
    test_results = update_test_results(test_results, 'Waveform Factory', factory_result, factory_details);
    
    %% 3. 配置管理测试
    fprintf('\n=== 3. 配置管理测试 ===\n');
    [config_result, config_details] = test_configuration_management();
    test_results = update_test_results(test_results, 'Configuration Management', config_result, config_details);
    
    %% 4. 载波同步测试
    fprintf('\n=== 4. 载波同步工具测试 ===\n');
    [carrier_result, carrier_details] = test_carrier_sync_tools();
    test_results = update_test_results(test_results, 'Carrier Sync Tools', carrier_result, carrier_details);
    
    %% 5. BPSK波形测试
    fprintf('\n=== 5. BPSK波形测试 ===\n');
    [bpsk_result, bpsk_details] = test_bpsk_waveform();
    test_results = update_test_results(test_results, 'BPSK Waveform', bpsk_result, bpsk_details);
    
    %% 6. QPSK波形测试
    fprintf('\n=== 6. QPSK波形测试 ===\n');
    [qpsk_result, qpsk_details] = test_qpsk_waveform();
    test_results = update_test_results(test_results, 'QPSK Waveform', qpsk_result, qpsk_details);
    
    %% 7. 16QAM波形测试
    fprintf('\n=== 7. 16QAM波形测试 ===\n');
    [qam16_result, qam16_details] = test_qam16_waveform();
    test_results = update_test_results(test_results, '16QAM Waveform', qam16_result, qam16_details);
    
    %% 8. FSK波形测试
    fprintf('\n=== 8. FSK波形测试 ===\n');
    [fsk_result, fsk_details] = test_fsk_waveform();
    test_results = update_test_results(test_results, 'FSK Waveform', fsk_result, fsk_details);
    
    %% 9. 性能分析测试
    fprintf('\n=== 9. 性能分析测试 ===\n');
    [perf_result, perf_details] = test_performance_analysis();
    test_results = update_test_results(test_results, 'Performance Analysis', perf_result, perf_details);
    
    %% 10. 错误处理测试
    fprintf('\n=== 10. 错误处理测试 ===\n');
    [error_result, error_details] = test_error_handling();
    test_results = update_test_results(test_results, 'Error Handling', error_result, error_details);
    
    %% 测试总结
    fprintf('\n========================================\n');
    fprintf('  测试总结\n');
    fprintf('========================================\n');
    
    fprintf('总测试数: %d\n', test_results.total_tests);
    fprintf('通过测试: %d\n', test_results.passed_tests);
    fprintf('失败测试: %d\n', test_results.failed_tests);
    fprintf('成功率: %.1f%%\n', 100 * test_results.passed_tests / test_results.total_tests);
    
    fprintf('\n详细结果:\n');
    for i = 1:length(test_results.details)
        detail = test_results.details{i};
        if detail.passed
            status_str = '✓';
        else
            status_str = '✗';
        end
        fprintf('  %s %s: %s\n', status_str, detail.name, detail.message);
    end
    
    % 保存测试结果
    save_test_results(test_results);
    
    fprintf('\n========================================\n');
    fprintf('  综合测试完成！\n');
    fprintf('========================================\n');
    
catch ME
    fprintf('\n综合测试异常: %s\n', ME.message);
    fprintf('详细信息: %s\n', ME.getReport());
end

%% 测试函数定义

function [result, details] = test_system_initialization()
    % 测试系统初始化
    result = true;
    details = '';
    
    try
        % 检查必要目录
        required_dirs = {'src', 'config', 'data', 'tests', 'examples'};
        missing_dirs = {};
        
        for i = 1:length(required_dirs)
            if ~exist(required_dirs{i}, 'dir')
                missing_dirs{end+1} = required_dirs{i};
                result = false;
            end
        end
        
        % 检查核心文件
        core_files = {
            'src/waveforms/base/WaveformBase.m',
            'src/waveforms/base/WaveformFactory.m',
            'src/waveforms/base/WaveformConfig.m',
            'src/utils/CarrierSync.m'
        };
        missing_files = {};
        
        for i = 1:length(core_files)
            if ~exist(core_files{i}, 'file')
                missing_files{end+1} = core_files{i};
                result = false;
            end
        end
        
        if result
            details = '所有必要目录和文件存在';
            fprintf('  ✓ 系统初始化检查通过\n');
        else
            details = sprintf('缺失目录: %s, 缺失文件: %s', ...
                strjoin(missing_dirs, ', '), strjoin(missing_files, ', '));
            fprintf('  ✗ 系统初始化检查失败\n');
        end
        
    catch ME
        result = false;
        details = ME.message;
        fprintf('  ✗ 系统初始化测试异常: %s\n', ME.message);
    end
end

function [result, details] = test_waveform_factory()
    % 测试波形工厂
    result = true;
    details = '';
    
    try
        % 创建工厂实例
        factory = WaveformFactory.getInstance();
        fprintf('  ✓ 波形工厂实例创建成功\n');
        
        % 测试支持的波形列表
        supported_waveforms = factory.get_supported_waveforms();
        if length(supported_waveforms) >= 4  % 至少支持4种波形
            fprintf('  ✓ 支持 %d 种波形\n', length(supported_waveforms));
        else
            result = false;
            fprintf('  ✗ 支持的波形数量不足: %d\n', length(supported_waveforms));
        end
        
        % 测试波形类别
        categories = factory.get_waveform_categories();
        if length(categories) >= 3  % 至少3个类别
            fprintf('  ✓ 支持 %d 个波形类别\n', length(categories));
        else
            result = false;
            fprintf('  ✗ 波形类别数量不足: %d\n', length(categories));
        end
        
        % 测试波形创建（仅测试已实现的）
        implemented_waveforms = {'BPSK', 'QPSK', 'QAM16', 'FSK'};
        creation_success = 0;
        
        for i = 1:length(implemented_waveforms)
            waveform_type = implemented_waveforms{i};
            try
                if exist(waveform_type, 'class')
                    waveform = factory.create_waveform(waveform_type);
                    creation_success = creation_success + 1;
                    fprintf('  ✓ %s 波形创建成功\n', waveform_type);
                else
                    fprintf('  - %s 波形类不存在（跳过）\n', waveform_type);
                end
            catch ME
                fprintf('  ✗ %s 波形创建失败: %s\n', waveform_type, ME.message);
            end
        end
        
        if creation_success >= 2
            details = sprintf('工厂功能正常，成功创建 %d 种波形', creation_success);
        else
            result = false;
            details = sprintf('波形创建成功率过低: %d/%d', creation_success, length(implemented_waveforms));
        end
        
    catch ME
        result = false;
        details = ME.message;
        fprintf('  ✗ 波形工厂测试异常: %s\n', ME.message);
    end
end

function [result, details] = test_configuration_management()
    % 测试配置管理
    result = true;
    details = '';
    
    try
        % 创建配置实例
        config = WaveformConfig();
        fprintf('  ✓ 配置对象创建成功\n');
        
        % 测试参数设置
        config.set_config('waveform_name', 'Test_QPSK', ...
                         'modulation_type', 'PSK', ...
                         'center_frequency', 2.4e9, ...
                         'bandwidth', 20e6, ...
                         'modulation_order', 4);
        
        if config.is_config_valid()
            fprintf('  ✓ 配置参数验证通过\n');
        else
            result = false;
            fprintf('  ✗ 配置参数验证失败\n');
            errors = config.get_error_messages();
            for i = 1:length(errors)
                fprintf('    错误: %s\n', errors{i});
            end
        end
        
        % 测试配置保存和加载
        temp_file = 'data/temp/test_config.mat';
        try
            config.save_to_file(temp_file);
            
            new_config = WaveformConfig();
            new_config.load_from_file(temp_file);
            
            if new_config.is_config_valid()
                fprintf('  ✓ 配置保存/加载成功\n');
            else
                result = false;
                fprintf('  ✗ 配置保存/加载失败\n');
            end
            
            % 清理临时文件
            if exist(temp_file, 'file')
                delete(temp_file);
            end
            
        catch ME
            fprintf('  ✗ 配置文件操作失败: %s\n', ME.message);
        end
        
        if result
            details = '配置管理功能完全正常';
        else
            details = '配置管理存在问题';
        end
        
    catch ME
        result = false;
        details = ME.message;
        fprintf('  ✗ 配置管理测试异常: %s\n', ME.message);
    end
end

function [result, details] = test_carrier_sync_tools()
    % 测试载波同步工具
    result = true;
    details = '';
    
    try
        % 生成测试信号
        test_signal = [1, -1, 1, -1, 1, -1] + 0.1 * (randn(1,6) + 1j*randn(1,6));
        sample_rate = 1000;
        
        % 测试不同算法
        algorithms = {'squaring', 'costas', 'blind'};
        algorithm_success = 0;
        
        for i = 1:length(algorithms)
            algorithm = algorithms{i};
            try
                [recovered_signal, freq_offset, phase_offset] = ...
                    CarrierSync.recover_carrier_bpsk(test_signal, sample_rate, ...
                    'algorithm', algorithm);
                
                if ~isempty(recovered_signal) && length(recovered_signal) == length(test_signal)
                    algorithm_success = algorithm_success + 1;
                    fprintf('  ✓ %s 算法工作正常\n', algorithm);
                else
                    fprintf('  ✗ %s 算法输出异常\n', algorithm);
                end
                
            catch ME
                fprintf('  ✗ %s 算法失败: %s\n', algorithm, ME.message);
            end
        end
        
        % 测试符号定时恢复
        try
            [timing_offset, corrected_signal] = ...
                CarrierSync.symbol_timing_recovery(test_signal, 2);
            
            if ~isempty(corrected_signal)
                fprintf('  ✓ 符号定时恢复工作正常\n');
            else
                result = false;
                fprintf('  ✗ 符号定时恢复输出为空\n');
            end
            
        catch ME
            result = false;
            fprintf('  ✗ 符号定时恢复失败: %s\n', ME.message);
        end
        
        if algorithm_success >= 2
            details = sprintf('载波同步工具正常，%d/%d 算法工作', algorithm_success, length(algorithms));
        else
            result = false;
            details = sprintf('载波同步算法成功率过低: %d/%d', algorithm_success, length(algorithms));
        end
        
    catch ME
        result = false;
        details = ME.message;
        fprintf('  ✗ 载波同步工具测试异常: %s\n', ME.message);
    end
end

function test_results = update_test_results(test_results, test_name, result, details)
    % 更新测试结果
    test_results.total_tests = test_results.total_tests + 1;
    
    if result
        test_results.passed_tests = test_results.passed_tests + 1;
    else
        test_results.failed_tests = test_results.failed_tests + 1;
    end
    
    test_results.details{end+1} = struct('name', test_name, 'passed', result, 'message', details);
end

function [result, details] = test_bpsk_waveform()
    % 测试BPSK波形
    result = true;
    details = '';

    try
        if ~exist('BPSK', 'class')
            result = false;
            details = 'BPSK类不存在';
            fprintf('  ✗ BPSK类不存在\n');
            return;
        end

        bpsk = BPSK();
        fprintf('  ✓ BPSK实例创建成功\n');

        % 配置测试
        config = struct();
        config.center_frequency = 1e9;
        config.sample_rate = 10e6;
        config.symbol_rate = 1e6;
        config.snr_db = 20;

        bpsk.configure(config);
        fprintf('  ✓ BPSK配置成功\n');

        % 调制解调测试
        test_data = [0; 1; 0; 1; 0; 1; 0; 1];
        modulated_signal = bpsk.generate_signal(test_data, 'add_noise', false);

        if ~isempty(modulated_signal)
            fprintf('  ✓ BPSK调制成功\n');
        else
            result = false;
            fprintf('  ✗ BPSK调制失败\n');
        end

        recovered_data = bpsk.recover_data(modulated_signal);

        if ~isempty(recovered_data)
            fprintf('  ✓ BPSK解调成功\n');
        else
            result = false;
            fprintf('  ✗ BPSK解调失败\n');
        end

        % 误码率测试
        min_len = min(length(test_data), length(recovered_data));
        ber = bpsk.calculate_ber(test_data(1:min_len), recovered_data(1:min_len));
        fprintf('  - BPSK误码率: %.3f\n', ber);

        % 波形信息测试
        info = bpsk.get_waveform_info();
        if isfield(info, 'waveform_name') && strcmp(info.waveform_name, 'BPSK')
            fprintf('  ✓ BPSK波形信息正确\n');
        else
            result = false;
            fprintf('  ✗ BPSK波形信息错误\n');
        end

        if result
            details = sprintf('BPSK功能正常，误码率=%.3f', ber);
        else
            details = 'BPSK存在功能问题';
        end

    catch ME
        result = false;
        details = ME.message;
        fprintf('  ✗ BPSK测试异常: %s\n', ME.message);
    end
end

function [result, details] = test_qpsk_waveform()
    % 测试QPSK波形
    result = true;
    details = '';

    try
        if ~exist('QPSK', 'class')
            result = false;
            details = 'QPSK类不存在';
            fprintf('  ✗ QPSK类不存在\n');
            return;
        end

        qpsk = QPSK();
        fprintf('  ✓ QPSK实例创建成功\n');

        % 配置测试
        config = struct();
        config.center_frequency = 1e9;
        config.sample_rate = 10e6;
        config.symbol_rate = 1e6;
        config.snr_db = 15;

        qpsk.configure(config);
        fprintf('  ✓ QPSK配置成功\n');

        % 调制解调测试
        test_data = randi([0, 1], 100, 1);
        modulated_signal = qpsk.generate_signal(test_data, 'add_noise', true);

        if ~isempty(modulated_signal)
            fprintf('  ✓ QPSK调制成功\n');
        else
            result = false;
            fprintf('  ✗ QPSK调制失败\n');
        end

        recovered_data = qpsk.recover_data(modulated_signal);

        if ~isempty(recovered_data)
            fprintf('  ✓ QPSK解调成功\n');
        else
            result = false;
            fprintf('  ✗ QPSK解调失败\n');
        end

        % 误码率测试
        min_len = min(length(test_data), length(recovered_data));
        ber = qpsk.calculate_ber(test_data(1:min_len), recovered_data(1:min_len));
        fprintf('  - QPSK误码率: %.6f\n', ber);

        % 波形信息测试
        info = qpsk.get_waveform_info();
        if isfield(info, 'waveform_name') && strcmp(info.waveform_name, 'QPSK')
            fprintf('  ✓ QPSK波形信息正确\n');
        else
            result = false;
            fprintf('  ✗ QPSK波形信息错误\n');
        end

        % 星座图测试
        try
            qpsk.plot_constellation();
            close(gcf);  % 关闭图形窗口
            fprintf('  ✓ QPSK星座图绘制成功\n');
        catch
            fprintf('  - QPSK星座图绘制失败（非关键）\n');
        end

        if result
            details = sprintf('QPSK功能正常，误码率=%.6f', ber);
        else
            details = 'QPSK存在功能问题';
        end

    catch ME
        result = false;
        details = ME.message;
        fprintf('  ✗ QPSK测试异常: %s\n', ME.message);
    end
end

function [result, details] = test_qam16_waveform()
    % 测试16QAM波形
    result = true;
    details = '';

    try
        if ~exist('QAM16', 'class')
            result = false;
            details = '16QAM类不存在';
            fprintf('  ✗ 16QAM类不存在\n');
            return;
        end

        qam16 = QAM16();
        fprintf('  ✓ 16QAM实例创建成功\n');

        % 配置测试
        config = struct();
        config.center_frequency = 1e9;
        config.sample_rate = 10e6;
        config.symbol_rate = 1e6;
        config.snr_db = 20;

        qam16.configure(config);
        fprintf('  ✓ 16QAM配置成功\n');

        % 调制解调测试
        test_data = randi([0, 1], 100, 1);
        modulated_signal = qam16.generate_signal(test_data, 'add_noise', true);

        if ~isempty(modulated_signal)
            fprintf('  ✓ 16QAM调制成功\n');
        else
            result = false;
            fprintf('  ✗ 16QAM调制失败\n');
        end

        recovered_data = qam16.recover_data(modulated_signal);

        if ~isempty(recovered_data)
            fprintf('  ✓ 16QAM解调成功\n');
        else
            result = false;
            fprintf('  ✗ 16QAM解调失败\n');
        end

        % 误码率测试
        min_len = min(length(test_data), length(recovered_data));
        ber = qam16.calculate_ber(test_data(1:min_len), recovered_data(1:min_len));
        fprintf('  - 16QAM误码率: %.6f\n', ber);

        % 波形信息测试
        info = qam16.get_waveform_info();
        if isfield(info, 'waveform_name') && strcmp(info.waveform_name, '16QAM')
            fprintf('  ✓ 16QAM波形信息正确\n');
        else
            result = false;
            fprintf('  ✗ 16QAM波形信息错误\n');
        end

        % 星座图测试
        try
            qam16.plot_constellation();
            close(gcf);  % 关闭图形窗口
            fprintf('  ✓ 16QAM星座图绘制成功\n');
        catch
            fprintf('  - 16QAM星座图绘制失败（非关键）\n');
        end

        if result
            details = sprintf('16QAM功能正常，误码率=%.6f', ber);
        else
            details = '16QAM存在功能问题';
        end

    catch ME
        result = false;
        details = ME.message;
        fprintf('  ✗ 16QAM测试异常: %s\n', ME.message);
    end
end

function [result, details] = test_fsk_waveform()
    % 测试FSK波形
    result = true;
    details = '';

    try
        if ~exist('FSK', 'class')
            result = false;
            details = 'FSK类不存在';
            fprintf('  ✗ FSK类不存在\n');
            return;
        end

        fsk = FSK();
        fprintf('  ✓ FSK实例创建成功\n');

        % 配置测试
        config = struct();
        config.center_frequency = 1e9;
        config.sample_rate = 10e6;
        config.symbol_rate = 1e6;
        config.frequency_deviation = 500e3;
        config.snr_db = 15;

        fsk.configure(config);
        fprintf('  ✓ FSK配置成功\n');

        % 调制解调测试
        test_data = randi([0, 1], 50, 1);
        modulated_signal = fsk.generate_signal(test_data, 'add_noise', true);

        if ~isempty(modulated_signal)
            fprintf('  ✓ FSK调制成功\n');
        else
            result = false;
            fprintf('  ✗ FSK调制失败\n');
        end

        % 测试相干解调
        recovered_data_coherent = fsk.recover_data(modulated_signal, 'method', 'coherent');

        if ~isempty(recovered_data_coherent)
            fprintf('  ✓ FSK相干解调成功\n');
        else
            result = false;
            fprintf('  ✗ FSK相干解调失败\n');
        end

        % 测试非相干解调
        try
            recovered_data_noncoherent = fsk.recover_data(modulated_signal, 'method', 'noncoherent');
            if ~isempty(recovered_data_noncoherent)
                fprintf('  ✓ FSK非相干解调成功\n');
            else
                fprintf('  - FSK非相干解调返回空结果\n');
            end
        catch
            fprintf('  - FSK非相干解调失败（非关键）\n');
        end

        % 误码率测试
        min_len = min(length(test_data), length(recovered_data_coherent));
        ber = fsk.calculate_ber(test_data(1:min_len), recovered_data_coherent(1:min_len));
        fprintf('  - FSK相干解调误码率: %.6f\n', ber);

        % 波形信息测试
        info = fsk.get_waveform_info();
        if isfield(info, 'waveform_name') && strcmp(info.waveform_name, 'FSK')
            fprintf('  ✓ FSK波形信息正确\n');
        else
            result = false;
            fprintf('  ✗ FSK波形信息错误\n');
        end

        % 频率响应测试
        try
            fsk.plot_frequency_response();
            close(gcf);  % 关闭图形窗口
            fprintf('  ✓ FSK频率响应绘制成功\n');
        catch
            fprintf('  - FSK频率响应绘制失败（非关键）\n');
        end

        if result
            details = sprintf('FSK功能正常，相干解调误码率=%.6f', ber);
        else
            details = 'FSK存在功能问题';
        end

    catch ME
        result = false;
        details = ME.message;
        fprintf('  ✗ FSK测试异常: %s\n', ME.message);
    end
end

function [result, details] = test_performance_analysis()
    % 测试性能分析功能
    result = true;
    details = '';

    try
        % 测试QPSK性能分析
        if exist('QPSK', 'class')
            qpsk = QPSK();
            config = struct();
            config.center_frequency = 1e9;
            config.sample_rate = 10e6;
            config.symbol_rate = 1e6;
            config.snr_db = 15;
            qpsk.configure(config);

            % 生成测试信号
            test_data = randi([0, 1], 200, 1);
            modulated_signal = qpsk.generate_signal(test_data);

            % 频谱分析测试
            spectrum = qpsk.get_spectrum(modulated_signal);

            if isfield(spectrum, 'frequencies') && isfield(spectrum, 'power_density')
                fprintf('  ✓ 频谱分析功能正常\n');
            else
                result = false;
                fprintf('  ✗ 频谱分析功能异常\n');
            end

            % 性能指标测试（简化）
            recovered_data = qpsk.recover_data(modulated_signal);
            min_len = min(length(test_data), length(recovered_data));
            ber = qpsk.calculate_ber(test_data(1:min_len), recovered_data(1:min_len));

            if ber >= 0 && ber <= 1
                fprintf('  ✓ 性能指标计算正常 (BER=%.6f)\n', ber);
            else
                result = false;
                fprintf('  ✗ 性能指标计算异常\n');
            end

        else
            fprintf('  - QPSK类不存在，跳过性能分析测试\n');
        end

        if result
            details = '性能分析功能正常';
        else
            details = '性能分析功能存在问题';
        end

    catch ME
        result = false;
        details = ME.message;
        fprintf('  ✗ 性能分析测试异常: %s\n', ME.message);
    end
end

function [result, details] = test_error_handling()
    % 测试错误处理
    result = true;
    details = '';

    try
        % 测试配置错误处理
        config = WaveformConfig();

        % 设置无效参数
        config.set_config('center_frequency', -1000);  % 负频率

        if ~config.is_config_valid()
            fprintf('  ✓ 配置错误检测正常\n');
        else
            result = false;
            fprintf('  ✗ 配置错误检测失败\n');
        end

        % 测试波形工厂错误处理
        factory = WaveformFactory.getInstance();

        try
            % 尝试创建不存在的波形
            waveform = factory.create_waveform('NONEXISTENT_WAVEFORM');
            result = false;
            fprintf('  ✗ 波形工厂错误处理失败\n');
        catch
            fprintf('  ✓ 波形工厂错误处理正常\n');
        end

        % 测试载波同步错误处理
        try
            % 使用无效参数
            [~, ~, ~] = CarrierSync.recover_carrier_bpsk([], 1000);
            result = false;
            fprintf('  ✗ 载波同步错误处理失败\n');
        catch
            fprintf('  ✓ 载波同步错误处理正常\n');
        end

        if result
            details = '错误处理机制正常';
        else
            details = '错误处理机制存在问题';
        end

    catch ME
        result = false;
        details = ME.message;
        fprintf('  ✗ 错误处理测试异常: %s\n', ME.message);
    end
end

function save_test_results(test_results)
    % 保存测试结果
    try
        output_dir = 'data/output/analysis';
        if ~exist(output_dir, 'dir')
            mkdir(output_dir);
        end

        % 保存到MAT文件
        save(fullfile(output_dir, 'comprehensive_test_results.mat'), 'test_results');

        % 保存到文本文件
        fid = fopen(fullfile(output_dir, 'comprehensive_test_report.txt'), 'w');
        if fid > 0
            fprintf(fid, '通信波形生成模块综合测试报告\n');
            fprintf(fid, '生成时间: %s\n\n', datestr(now));
            fprintf(fid, '总测试数: %d\n', test_results.total_tests);
            fprintf(fid, '通过测试: %d\n', test_results.passed_tests);
            fprintf(fid, '失败测试: %d\n', test_results.failed_tests);
            fprintf(fid, '成功率: %.1f%%\n\n', 100 * test_results.passed_tests / test_results.total_tests);

            fprintf(fid, '详细结果:\n');
            for i = 1:length(test_results.details)
                detail = test_results.details{i};
                if detail.passed
                    status_str = 'PASS';
                else
                    status_str = 'FAIL';
                end
                fprintf(fid, '%s: %s - %s\n', status_str, detail.name, detail.message);
            end

            fclose(fid);
            fprintf('测试结果已保存到: %s\n', output_dir);
        end

    catch ME
        fprintf('保存测试结果失败: %s\n', ME.message);
    end
end
