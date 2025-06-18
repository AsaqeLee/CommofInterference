
    % main - 通信系统抗干扰能力仿真平台主程序
    % 演示平台的基本功能和使用方法
    %
    % 作者: Asaqe Lee
    % 日期: 2025-06-18
    
    clc;
    clear;
    close all;
    
    fprintf('========================================\n');
    fprintf('  通信系统抗干扰能力仿真平台\n');
    fprintf('========================================\n\n');
    
    % 添加路径
    addpath(genpath('src'));
    addpath(genpath('config'));
    addpath(genpath('tests'));
    
    try
        % 1. 系统初始化
        fprintf('1. 系统初始化...\n');
        initialize_system();
        
        % 2. 演示波形工厂功能
        fprintf('\n2. 演示波形工厂功能...\n');
        demo_waveform_factory();
        
        % 3. 演示基础调制波形
        fprintf('\n3. 演示基础调制波形...\n');
        demo_basic_modulations();
        
        % 4. 演示配置管理
        fprintf('\n4. 演示配置管理...\n');
        demo_configuration_management();
        
        % 5. 运行基础测试
        fprintf('\n5. 运行基础测试...\n');
        run_basic_tests();
        
        fprintf('\n========================================\n');
        fprintf('  演示完成！\n');
        fprintf('========================================\n');
        
    catch ME
        fprintf('\n错误: %s\n', ME.message);
        fprintf('详细信息: %s\n', ME.getReport());
    end


function initialize_system()
    % 系统初始化
    
    % 检查必要的目录
    required_dirs = {'src', 'config', 'data/output', 'tests'};
    
    for i = 1:length(required_dirs)
        if ~exist(required_dirs{i}, 'dir')
            fprintf('  警告: 目录 %s 不存在\n', required_dirs{i});
        else
            fprintf('  ✓ 目录 %s 存在\n', required_dirs{i});
        end
    end
    
    % 检查核心类文件
    core_files = {'src/waveforms/base/WaveformBase.m', ...
                  'src/waveforms/base/WaveformFactory.m', ...
                  'src/waveforms/base/WaveformConfig.m'};
    
    for i = 1:length(core_files)
        if exist(core_files{i}, 'file')
            fprintf('  ✓ 核心文件 %s 存在\n', core_files{i});
        else
            fprintf('  ✗ 核心文件 %s 缺失\n', core_files{i});
        end
    end
    
    fprintf('  系统初始化完成\n');
end

function demo_waveform_factory()
    % 演示波形工厂功能
    
    fprintf('  创建波形工厂实例...\n');
    factory = WaveformFactory.getInstance();
    
    fprintf('  支持的波形类型:\n');
    factory.print_supported_waveforms();
    
    fprintf('  验证波形可用性...\n');
    factory.validate_all_waveforms();
end

function demo_basic_modulations()
    % 演示基础调制波形
    
    % 生成测试数据
    num_bits = 100;
    test_data = randi([0, 1], num_bits, 1);
    
    % 测试BPSK
    fprintf('  测试BPSK波形:\n');
    demo_single_waveform('BPSK', test_data);
    
    % 测试QPSK
    fprintf('  测试QPSK波形:\n');
    demo_single_waveform('QPSK', test_data);
    
    % 测试16QAM
    fprintf('  测试16QAM波形:\n');
    demo_single_waveform('QAM16', test_data);
end

function demo_single_waveform(waveform_type, test_data)
    % 演示单个波形的功能
    % 输入: waveform_type - 波形类型
    %      test_data - 测试数据
    
    try
        % 创建波形实例
        if exist(waveform_type, 'class')
            waveform = feval(waveform_type);
        else
            fprintf('    ✗ 波形类 %s 不存在\n', waveform_type);
            return;
        end
        
        % 配置波形
        config = struct();
        config.center_frequency = 1e9;    % 1 GHz
        config.sample_rate = 10e6;        % 10 MHz
        config.symbol_rate = 1e6;         % 1 Msps
        config.snr_db = 15;               % 15 dB
        
        waveform.configure(config);
        
        % 获取波形信息
        info = waveform.get_waveform_info();
        fprintf('    波形ID: %d\n', info.waveform_id);
        fprintf('    调制类型: %s\n', info.modulation_type);
        fprintf('    调制阶数: %d\n', info.modulation_order);
        fprintf('    每符号比特数: %d\n', info.bits_per_symbol);
        
        % 调制
        fprintf('    执行调制...\n');
        modulated_signal = waveform.generate_signal(test_data);
        fprintf('    调制信号长度: %d 采样点\n', length(modulated_signal));
        
        % 解调
        fprintf('    执行解调...\n');
        recovered_data = waveform.recover_data(modulated_signal);
        fprintf('    恢复数据长度: %d 比特\n', length(recovered_data));
        
        % 计算误码率
        ber = waveform.calculate_ber(test_data, recovered_data);
        fprintf('    误码率: %.6f\n', ber);
        
        % 频谱分析
        fprintf('    执行频谱分析...\n');
        spectrum = waveform.get_spectrum(modulated_signal);
        fprintf('    频谱点数: %d\n', length(spectrum.frequencies));
        
        fprintf('    ✓ %s 演示完成\n', waveform_type);
        
    catch ME
        fprintf('    ✗ %s 演示失败: %s\n', waveform_type, ME.message);
    end
end

function demo_configuration_management()
    % 演示配置管理功能
    
    fprintf('  创建配置对象...\n');
    config = WaveformConfig();
    
    fprintf('  设置配置参数...\n');
    config.set_config('waveform_name', 'Demo_QPSK', ...
                     'modulation_type', 'PSK', ...
                     'center_frequency', 2.4e9, ...
                     'bandwidth', 20e6, ...
                     'data_rate', 10e6, ...
                     'sample_rate', 100e6, ...
                     'modulation_order', 4);
    
    fprintf('  验证配置...\n');
    if config.is_config_valid()
        fprintf('    ✓ 配置有效\n');
    else
        fprintf('    ✗ 配置无效\n');
        errors = config.get_error_messages();
        for i = 1:length(errors)
            fprintf('      错误: %s\n', errors{i});
        end
    end
    
    fprintf('  打印配置信息:\n');
    config.print_config();
    
    % 测试配置保存和加载
    config_file = 'data/temp/demo_config.mat';
    fprintf('  保存配置到文件: %s\n', config_file);
    
    try
        config.save_to_file(config_file);
        
        fprintf('  从文件加载配置...\n');
        new_config = WaveformConfig();
        new_config.load_from_file(config_file);
        
        fprintf('    ✓ 配置保存和加载成功\n');
        
    catch ME
        fprintf('    ✗ 配置保存/加载失败: %s\n', ME.message);
    end
end

function run_basic_tests()
    % 运行基础测试
    
    fprintf('  运行波形测试...\n');
    
    try
        % 检查测试文件是否存在
        test_file = 'tests/waveform_tests/test_basic_modulations.m';
        if exist(test_file, 'file')
            fprintf('    执行基础调制测试...\n');
            test_basic_modulations();
        else
            fprintf('    ✗ 测试文件不存在: %s\n', test_file);
        end
        
    catch ME
        fprintf('    ✗ 测试执行失败: %s\n', ME.message);
    end
end

function create_demo_plots()
    % 创建演示图表
    
    fprintf('  生成演示图表...\n');
    
    try
        % 创建QPSK星座图演示
        qpsk = QPSK();
        config = struct();
        config.center_frequency = 1e9;
        config.sample_rate = 10e6;
        config.symbol_rate = 1e6;
        config.snr_db = 10;
        qpsk.configure(config);
        
        % 生成一些符号用于星座图
        test_bits = randi([0, 1], 200, 1);
        modulated_signal = qpsk.generate_signal(test_bits);
        
        % 添加噪声并解调以获得接收符号
        noisy_signal = qpsk.generate_signal(test_bits, 'snr_db', 5);
        
        % 简单的符号提取（用于演示）
        samples_per_symbol = round(qpsk.sample_rate / qpsk.symbol_rate);
        symbol_indices = round(samples_per_symbol/2):samples_per_symbol:length(noisy_signal);
        received_symbols = noisy_signal(symbol_indices(1:min(50, length(symbol_indices))));
        
        % 绘制星座图
        qpsk.plot_constellation(received_symbols);
        
        % 保存图像
        output_dir = 'data/output/analysis';
        if ~exist(output_dir, 'dir')
            mkdir(output_dir);
        end
        
        saveas(gcf, fullfile(output_dir, 'qpsk_constellation_demo.png'));
        fprintf('    ✓ QPSK星座图已保存\n');
        
    catch ME
        fprintf('    ✗ 图表生成失败: %s\n', ME.message);
    end
end

% 如果直接运行此文件，执行主函数
if ~exist('OCTAVE_VERSION', 'builtin')
    % MATLAB环境
    if strcmp(mfilename, 'main')
        main();
    end
else
    % Octave环境
    main();
end
