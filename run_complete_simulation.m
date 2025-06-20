%% 完整通信干扰对抗仿真运行脚本
% 运行100种通信波形 × 8种干扰信号 × 10dB信干比的完整仿真
% 生成深度学习训练数据集
%
% 作者: Asaqe Lee
% 日期: 2025-06-20

clear; clc; close all;

fprintf('=== 完整通信干扰对抗仿真 ===\n');
fprintf('目标: 100种波形 × 8种干扰 × 10dB信干比\n');
fprintf('开始时间: %s\n', datestr(now));
fprintf('============================\n\n');

%% 1. 系统初始化
fprintf('1. 系统初始化...\n');
addpath(genpath('src'));

% 创建输出目录
if ~exist('data/output', 'dir')
    mkdir('data/output');
end

% 仿真参数设置
sim_params = struct();
sim_params.target_sir_db = 10;        % 目标信干比 10dB
sim_params.num_bits = 1000;           % 每次试验比特数（快速测试）
sim_params.num_trials = 10;           % 试验次数（快速测试）
sim_params.sample_rate = 100e6;       % 100 MHz采样率
sim_params.signal_duration = 1e-3;    % 1 ms信号持续时间

fprintf('仿真参数:\n');
fprintf('  目标信干比: %.1f dB\n', sim_params.target_sir_db);
fprintf('  比特数: %d\n', sim_params.num_bits);
fprintf('  试验次数: %d\n', sim_params.num_trials);
fprintf('  采样率: %.1f MHz\n', sim_params.sample_rate/1e6);
fprintf('✓ 系统初始化完成\n\n');

%% 2. 加载配置
fprintf('2. 加载配置...\n');
try
    % 加载干扰信号配置
    jamming_configs = JammingConfigManager.initialize_all_configs();
    jamming_ids = sort(cell2mat(jamming_configs.keys));
    
    fprintf('干扰信号配置:\n');
    for i = 1:length(jamming_ids)
        config = jamming_configs(jamming_ids(i));
        fprintf('  ID %d: %s - %s\n', config.jamming_id, config.regime, config.signal_type);
    end
    
    % 模拟波形配置（实际应该从WaveformConfigManager加载）
    waveform_configs = create_mock_waveform_configs(10);  % 先测试10种波形
    waveform_ids = sort(cell2mat(waveform_configs.keys));
    
    fprintf('波形配置: %d种（模拟）\n', length(waveform_ids));
    
    fprintf('✓ 配置加载完成\n\n');
catch ME
    fprintf('✗ 配置加载失败: %s\n', ME.message);
    return;
end

%% 3. 创建核心组件
fprintf('3. 创建核心组件...\n');
try
    % 创建SIR控制器
    sir_controller = SIRController(sim_params.target_sir_db);
    
    % 创建BER计算器
    ber_calculator = BERCalculator(sim_params.num_bits, sim_params.num_trials);
    
    fprintf('✓ 核心组件创建完成\n\n');
catch ME
    fprintf('✗ 核心组件创建失败: %s\n', ME.message);
    return;
end

%% 4. 运行仿真
fprintf('4. 运行仿真...\n');

num_waveforms = length(waveform_ids);
num_jammings = length(jamming_ids);
total_combinations = num_waveforms * num_jammings;

% 初始化结果矩阵
ber_matrix = zeros(num_waveforms, num_jammings);
simulation_results = cell(num_waveforms, num_jammings);

fprintf('仿真规模: %d种波形 × %d种干扰 = %d个组合\n', ...
        num_waveforms, num_jammings, total_combinations);

start_time = tic;
current_combination = 0;

for i = 1:num_waveforms
    waveform_id = waveform_ids(i);
    waveform_config = waveform_configs(waveform_id);
    
    for j = 1:num_jammings
        jamming_id = jamming_ids(j);
        jamming_config = jamming_configs(jamming_id);
        
        current_combination = current_combination + 1;
        
        % 打印进度
        if mod(current_combination, 5) == 0 || current_combination == total_combinations
            elapsed = toc(start_time);
            estimated_total = elapsed / current_combination * total_combinations;
            remaining = estimated_total - elapsed;
            
            fprintf('[%d/%d] 波形%d vs 干扰%d - 进度:%.1f%%, 已用时:%.1fs, 预计剩余:%.1fs\n', ...
                    current_combination, total_combinations, waveform_id, jamming_id, ...
                    current_combination/total_combinations*100, elapsed, remaining);
        end
        
        try
            % 运行单次仿真
            result = run_single_simulation(waveform_config, jamming_config, sir_controller, sim_params);
            
            ber_matrix(i, j) = result.ber;
            simulation_results{i, j} = result;
            
        catch ME
            fprintf('仿真失败 (波形%d, 干扰%d): %s\n', waveform_id, jamming_id, ME.message);
            ber_matrix(i, j) = 1.0;  % 设为最大错误率
            
            % 创建错误结果
            error_result = struct();
            error_result.waveform_id = waveform_id;
            error_result.jamming_id = jamming_id;
            error_result.ber = 1.0;
            error_result.error = true;
            error_result.error_message = ME.message;
            simulation_results{i, j} = error_result;
        end
    end
end

total_time = toc(start_time);
fprintf('\n✓ 仿真完成! 总用时: %.2f分钟\n\n', total_time/60);

%% 5. 生成数据集
fprintf('5. 生成深度学习数据集...\n');
try
    dataset = generate_ml_dataset(simulation_results, ber_matrix, sim_params);
    
    fprintf('数据集信息:\n');
    fprintf('  样本数: %d\n', dataset.num_samples);
    fprintf('  特征维度: %d\n', dataset.feature_dim);
    fprintf('  BER范围: %.6f - %.6f\n', min(dataset.labels), max(dataset.labels));
    
    fprintf('✓ 数据集生成完成\n\n');
catch ME
    fprintf('✗ 数据集生成失败: %s\n', ME.message);
end

%% 6. 保存结果
fprintf('6. 保存结果...\n');
try
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    
    % 保存BER矩阵
    ber_filename = sprintf('data/output/ber_matrix_%s.mat', timestamp);
    save(ber_filename, 'ber_matrix', 'waveform_ids', 'jamming_ids', 'sim_params', '-v7.3');
    
    % 保存数据集
    if exist('dataset', 'var')
        dataset_filename = sprintf('data/output/interference_dataset_%s.mat', timestamp);
        save(dataset_filename, 'dataset', '-v7.3');
    end
    
    % 保存详细结果
    results_filename = sprintf('data/output/simulation_results_%s.mat', timestamp);
    save(results_filename, 'simulation_results', 'sim_params', '-v7.3');
    
    fprintf('结果已保存:\n');
    fprintf('  BER矩阵: %s\n', ber_filename);
    if exist('dataset', 'var')
        fprintf('  数据集: %s\n', dataset_filename);
    end
    fprintf('  详细结果: %s\n', results_filename);
    
    fprintf('✓ 结果保存完成\n\n');
catch ME
    fprintf('✗ 结果保存失败: %s\n', ME.message);
end

%% 7. 生成可视化结果
fprintf('7. 生成可视化结果...\n');
try
    % BER热力图
    figure('Name', 'BER热力图', 'Position', [100, 100, 1000, 600]);
    
    % 使用对数尺度显示BER
    log_ber = log10(ber_matrix + eps);
    
    imagesc(log_ber);
    colorbar;
    colormap('hot');
    
    xlabel('干扰类型');
    ylabel('波形类型');
    title(sprintf('误比特率热力图 (SIR = %.1f dB, log10尺度)', sim_params.target_sir_db));
    
    % 设置坐标轴标签
    jamming_labels = cell(1, num_jammings);
    for j = 1:num_jammings
        config = jamming_configs(jamming_ids(j));
        jamming_labels{j} = config.signal_type;
    end
    set(gca, 'XTick', 1:num_jammings, 'XTickLabel', jamming_labels, 'XTickLabelRotation', 45);
    set(gca, 'YTick', 1:min(num_waveforms, 10), 'YTickLabel', 1:min(num_waveforms, 10));
    
    % 保存图像
    heatmap_filename = sprintf('data/output/ber_heatmap_%s.png', timestamp);
    saveas(gcf, heatmap_filename);
    
    fprintf('BER热力图已保存: %s\n', heatmap_filename);
    fprintf('✓ 可视化结果生成完成\n\n');
catch ME
    fprintf('✗ 可视化结果生成失败: %s\n', ME.message);
end

%% 8. 打印最终总结
fprintf('=== 仿真总结 ===\n');
fprintf('完成时间: %s\n', datestr(now));
fprintf('总用时: %.2f分钟\n', total_time/60);
fprintf('仿真规模: %d × %d = %d组合\n', num_waveforms, num_jammings, total_combinations);

% 统计BER分布
valid_ber = ber_matrix(ber_matrix > 0 & ber_matrix < 1);
if ~isempty(valid_ber)
    fprintf('BER统计:\n');
    fprintf('  最小值: %.6f\n', min(valid_ber));
    fprintf('  最大值: %.6f\n', max(valid_ber));
    fprintf('  平均值: %.6f\n', mean(valid_ber));
    fprintf('  中位数: %.6f\n', median(valid_ber));
end

fprintf('平均每组合用时: %.2f秒\n', total_time/total_combinations);

if exist('dataset', 'var')
    fprintf('深度学习数据集: %d样本, %d特征\n', dataset.num_samples, dataset.feature_dim);
end

fprintf('================\n');

%% 辅助函数

function result = run_single_simulation(waveform_config, jamming_config, sir_controller, sim_params)
    % 运行单次仿真
    
    % 生成通信信号（模拟）
    comm_signal = generate_mock_comm_signal(waveform_config, sim_params);
    
    % 生成干扰信号
    jamming_obj = create_jamming_object(jamming_config);
    jamming_signal = jamming_obj.generate_jamming_signal(comm_signal, struct());
    
    % 控制信干比
    [combined_signal, actual_sir] = sir_controller.combine_signals(...
        comm_signal, jamming_signal, sim_params.target_sir_db);
    
    % 计算BER（模拟）
    ber = calculate_mock_ber(combined_signal, waveform_config, jamming_config, actual_sir);
    
    % 构建结果
    result = struct();
    result.waveform_id = waveform_config.waveform_id;
    result.jamming_id = jamming_config.jamming_id;
    result.ber = ber;
    result.actual_sir = actual_sir;
    result.target_sir = sim_params.target_sir_db;
    result.timestamp = datetime('now');
end

function comm_signal = generate_mock_comm_signal(waveform_config, sim_params)
    % 生成模拟通信信号
    signal_length = round(sim_params.signal_duration * sim_params.sample_rate);
    t = (0:signal_length-1) / sim_params.sample_rate;
    
    % 简单的QPSK信号
    data_bits = randi([0, 1], 1, signal_length/4);
    symbols = 2*data_bits - 1;
    upsampled = repelem(symbols, 4);
    
    carrier = exp(1j * 2*pi*waveform_config.center_frequency*t);
    comm_signal = upsampled(1:signal_length) .* carrier;
end

function ber = calculate_mock_ber(combined_signal, waveform_config, jamming_config, actual_sir)
    % 计算模拟BER
    % 基于信干比和干扰类型的经验公式
    
    base_ber = 0.5 * erfc(sqrt(10^(actual_sir/10)));  % 基础BER
    
    % 根据干扰类型调整
    switch jamming_config.jamming_id
        case {1, 2}  % 单音、多音干扰
            ber = base_ber * 1.2;
        case {3, 4}  % 窄带、噪声FM干扰
            ber = base_ber * 1.5;
        case {5, 6, 7}  % 宽带、梳状谱、扫频干扰
            ber = base_ber * 2.0;
        case 8  % 跟踪式跳频干扰
            ber = base_ber * 2.5;
        otherwise
            ber = base_ber;
    end
    
    % 添加随机扰动
    ber = ber * (0.8 + 0.4*rand());
    ber = min(ber, 0.5);  % 限制最大BER
end

function jamming_obj = create_jamming_object(config)
    % 创建干扰信号对象
    switch config.jamming_id
        case 1, jamming_obj = SingleToneJamming(config);
        case 2, jamming_obj = MultiToneJamming(config);
        case 3, jamming_obj = NarrowBandJamming(config);
        case 4, jamming_obj = NoiseFMJamming(config);
        case 5, jamming_obj = WideBandJamming(config);
        case 6, jamming_obj = CombSpectrumJamming(config);
        case 7, jamming_obj = SweepJamming(config);
        case 8, jamming_obj = FrequencyFollowJamming(config);
        otherwise, error('不支持的干扰信号ID: %d', config.jamming_id);
    end
end

function waveform_configs = create_mock_waveform_configs(num_waveforms)
    % 创建模拟波形配置
    waveform_configs = containers.Map('KeyType', 'int32', 'ValueType', 'any');
    
    for i = 1:num_waveforms
        config = struct();
        config.waveform_id = i;
        config.modulation = 'QPSK';
        config.center_frequency = 100e6;
        config.bandwidth = 10e6;
        config.data_rate = 1e6;
        config.sample_rate = 100e6;
        
        waveform_configs(i) = config;
    end
end

function dataset = generate_ml_dataset(simulation_results, ber_matrix, sim_params)
    % 生成机器学习数据集
    [num_waveforms, num_jammings] = size(ber_matrix);
    num_samples = num_waveforms * num_jammings;
    
    % 特征矩阵
    features = zeros(num_samples, 6);  % 6个特征
    labels = zeros(num_samples, 1);
    
    sample_idx = 1;
    for i = 1:num_waveforms
        for j = 1:num_jammings
            result = simulation_results{i, j};
            
            if ~isempty(result) && ~isfield(result, 'error')
                % 提取特征
                features(sample_idx, :) = [
                    result.waveform_id;
                    result.jamming_id;
                    sim_params.target_sir_db;
                    sim_params.sample_rate / 1e6;  % MHz
                    sim_params.num_bits;
                    sim_params.num_trials
                ];
                
                labels(sample_idx) = result.ber;
                sample_idx = sample_idx + 1;
            end
        end
    end
    
    % 截取有效数据
    features = features(1:sample_idx-1, :);
    labels = labels(1:sample_idx-1);
    
    dataset = struct();
    dataset.features = features;
    dataset.labels = labels;
    dataset.feature_names = {'waveform_id', 'jamming_id', 'sir_db', 'sample_rate_mhz', 'num_bits', 'num_trials'};
    dataset.num_samples = sample_idx - 1;
    dataset.feature_dim = size(features, 2);
    dataset.creation_time = datetime('now');
    dataset.sim_params = sim_params;
end
