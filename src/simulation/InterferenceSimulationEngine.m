classdef InterferenceSimulationEngine < handle
    % InterferenceSimulationEngine - 通信干扰对抗仿真引擎
    % 整合100种通信波形、8种干扰信号、信干比控制和BER计算
    %
    % 作者: Asaqe Lee
    % 日期: 2025-06-20
    
    properties (Constant)
        % 仿真参数
        DEFAULT_SIR_DB = 10;            % 默认信干比 10dB
        DEFAULT_NUM_BITS = 10000;       % 默认比特数
        DEFAULT_NUM_TRIALS = 100;       % 默认试验次数
        
        % 数据集参数
        DATASET_VERSION = '1.0';        % 数据集版本
        DATASET_FORMAT = 'MAT';         % 数据格式
    end
    
    properties (Access = private)
        % 核心组件
        waveform_configs       % 波形配置管理器
        jamming_configs        % 干扰配置管理器
        sir_controller         % 信干比控制器
        ber_calculator         % BER计算器
        
        % 仿真参数
        target_sir_db          % 目标信干比
        num_bits               % 比特数
        num_trials             % 试验次数
        
        % 结果存储
        simulation_results     % 仿真结果
        ber_matrix            % BER矩阵 (100x8)
        dataset               % 深度学习数据集
        
        % 状态控制
        is_initialized        % 是否已初始化
        is_running           % 是否正在运行
        current_progress     % 当前进度
        
        % 性能监控
        start_time           % 开始时间
        total_time           % 总时间
        estimated_time       % 预计时间
    end
    
    methods
        function obj = InterferenceSimulationEngine()
            % 构造函数
            obj.initialize_components();
        end
        
        function obj = initialize(obj, sir_db, num_bits, num_trials)
            % 初始化仿真引擎
            % 输入: sir_db - 信干比 (dB)
            %      num_bits - 比特数
            %      num_trials - 试验次数
            
            if nargin < 2, sir_db = obj.DEFAULT_SIR_DB; end
            if nargin < 3, num_bits = obj.DEFAULT_NUM_BITS; end
            if nargin < 4, num_trials = obj.DEFAULT_NUM_TRIALS; end
            
            obj.target_sir_db = sir_db;
            obj.num_bits = num_bits;
            obj.num_trials = num_trials;
            
            % 初始化组件
            obj.sir_controller = SIRController(sir_db);
            obj.ber_calculator = BERCalculator(num_bits, num_trials);
            
            % 加载配置
            obj.load_configurations();
            
            obj.is_initialized = true;
            
            fprintf('仿真引擎初始化完成:\n');
            fprintf('  信干比: %.1f dB\n', sir_db);
            fprintf('  比特数: %d\n', num_bits);
            fprintf('  试验次数: %d\n', num_trials);
            fprintf('  波形数量: %d\n', length(obj.waveform_configs.keys));
            fprintf('  干扰数量: %d\n', length(obj.jamming_configs.keys));
        end
        
        function dataset = run_full_simulation(obj)
            % 运行完整仿真
            % 输出: dataset - 深度学习数据集
            
            if ~obj.is_initialized
                error('InterferenceSimulationEngine:NotInitialized', '仿真引擎未初始化');
            end
            
            fprintf('开始完整仿真: 100种波形 × 8种干扰 × %.1fdB信干比\n', obj.target_sir_db);
            
            obj.start_time = tic;
            obj.is_running = true;
            obj.current_progress = 0;
            
            % 获取配置
            waveform_ids = sort(cell2mat(obj.waveform_configs.keys));
            jamming_ids = sort(cell2mat(obj.jamming_configs.keys));
            
            num_waveforms = length(waveform_ids);
            num_jammings = length(jamming_ids);
            total_combinations = num_waveforms * num_jammings;
            
            % 初始化结果矩阵
            obj.ber_matrix = zeros(num_waveforms, num_jammings);
            obj.simulation_results = cell(num_waveforms, num_jammings);
            
            fprintf('总计算量: %d种波形 × %d种干扰 = %d个组合\n', ...
                    num_waveforms, num_jammings, total_combinations);
            
            current_combination = 0;
            
            % 主仿真循环
            for i = 1:num_waveforms
                waveform_id = waveform_ids(i);
                
                for j = 1:num_jammings
                    jamming_id = jamming_ids(j);
                    current_combination = current_combination + 1;
                    
                    % 更新进度
                    obj.current_progress = current_combination / total_combinations * 100;
                    obj.print_progress(current_combination, total_combinations, waveform_id, jamming_id);
                    
                    % 运行单次仿真
                    try
                        result = obj.run_single_simulation(waveform_id, jamming_id);
                        obj.ber_matrix(i, j) = result.ber;
                        obj.simulation_results{i, j} = result;
                        
                    catch ME
                        fprintf('仿真失败 (波形%d, 干扰%d): %s\n', waveform_id, jamming_id, ME.message);
                        obj.ber_matrix(i, j) = 1.0;  % 设为最大错误率
                        obj.simulation_results{i, j} = obj.create_error_result(waveform_id, jamming_id, ME.message);
                    end
                end
            end
            
            obj.total_time = toc(obj.start_time);
            obj.is_running = false;
            
            % 生成数据集
            dataset = obj.generate_dataset();
            obj.dataset = dataset;
            
            fprintf('\n仿真完成! 总用时: %.2f分钟\n', obj.total_time/60);
            obj.print_summary();
            
            % 保存结果
            obj.save_results();
        end
        
        function result = run_single_simulation(obj, waveform_id, jamming_id)
            % 运行单次仿真
            % 输入: waveform_id - 波形ID
            %      jamming_id - 干扰ID
            % 输出: result - 仿真结果
            
            % 获取配置
            waveform_config = obj.waveform_configs(waveform_id);
            jamming_config = obj.jamming_configs(jamming_id);
            
            % 创建对象
            waveform_obj = obj.create_waveform_object(waveform_config);
            jamming_obj = obj.create_jamming_object(jamming_config);
            
            % 计算BER
            ber = obj.ber_calculator.calculate_ber(waveform_obj, jamming_obj, obj.target_sir_db);
            
            % 生成特征数据
            features = obj.extract_features(waveform_obj, jamming_obj, waveform_config, jamming_config);
            
            % 构建结果
            result = struct();
            result.waveform_id = waveform_id;
            result.jamming_id = jamming_id;
            result.ber = ber;
            result.sir_db = obj.target_sir_db;
            result.features = features;
            result.waveform_config = waveform_config;
            result.jamming_config = jamming_config;
            result.timestamp = datetime('now');
        end
        
        function features = extract_features(obj, waveform_obj, jamming_obj, waveform_config, jamming_config)
            % 提取特征
            % 输入: waveform_obj - 波形对象
            %      jamming_obj - 干扰对象
            %      waveform_config - 波形配置
            %      jamming_config - 干扰配置
            % 输出: features - 特征向量
            
            features = struct();
            
            % 波形特征
            features.waveform_type = waveform_config.modulation;
            features.carrier_frequency = waveform_config.center_frequency;
            features.bandwidth = waveform_config.bandwidth;
            features.data_rate = waveform_config.data_rate;
            
            if isfield(waveform_config, 'hop_rate')
                features.hop_rate = waveform_config.hop_rate;
            else
                features.hop_rate = 0;
            end
            
            if isfield(waveform_config, 'spreading_factor')
                features.spreading_factor = waveform_config.spreading_factor;
            else
                features.spreading_factor = 1;
            end
            
            % 干扰特征
            features.jamming_type = jamming_config.signal_type;
            features.jamming_regime = jamming_config.regime;
            features.jamming_modulation = jamming_config.modulation;
            features.jamming_bandwidth = jamming_config.bandwidth;
            features.jamming_power = jamming_config.power_dbm;
            
            % 系统特征
            features.sir_db = obj.target_sir_db;
            features.sample_rate = waveform_config.sample_rate;
        end
        
        function dataset = generate_dataset(obj)
            % 生成深度学习数据集
            % 输出: dataset - 数据集结构体
            
            fprintf('生成深度学习数据集...\n');
            
            dataset = struct();
            dataset.version = obj.DATASET_VERSION;
            dataset.format = obj.DATASET_FORMAT;
            dataset.creation_time = datetime('now');
            dataset.sir_db = obj.target_sir_db;
            dataset.num_bits = obj.num_bits;
            dataset.num_trials = obj.num_trials;
            
            % 提取所有特征和标签
            num_samples = numel(obj.simulation_results);
            features_cell = cell(num_samples, 1);
            labels = zeros(num_samples, 1);
            
            sample_idx = 1;
            for i = 1:size(obj.simulation_results, 1)
                for j = 1:size(obj.simulation_results, 2)
                    result = obj.simulation_results{i, j};
                    if ~isempty(result) && isfield(result, 'features')
                        features_cell{sample_idx} = obj.vectorize_features(result.features);
                        labels(sample_idx) = result.ber;
                        sample_idx = sample_idx + 1;
                    end
                end
            end
            
            % 转换为矩阵
            feature_dim = length(features_cell{1});
            features_matrix = zeros(num_samples, feature_dim);
            
            for i = 1:num_samples
                if ~isempty(features_cell{i})
                    features_matrix(i, :) = features_cell{i};
                end
            end
            
            dataset.features = features_matrix;
            dataset.labels = labels;
            dataset.feature_names = obj.get_feature_names();
            dataset.ber_matrix = obj.ber_matrix;
            dataset.num_samples = num_samples;
            dataset.feature_dim = feature_dim;
            
            fprintf('数据集生成完成: %d样本, %d特征\n', num_samples, feature_dim);
        end
        
        function obj = save_results(obj)
            % 保存结果
            timestamp = datestr(now, 'yyyymmdd_HHMMSS');
            
            % 保存BER矩阵
            ber_filename = sprintf('data/output/ber_matrix_%s.mat', timestamp);
            ber_matrix = obj.ber_matrix;
            save(ber_filename, 'ber_matrix', '-v7.3');
            
            % 保存数据集
            dataset_filename = sprintf('data/output/interference_dataset_%s.mat', timestamp);
            dataset = obj.dataset;
            save(dataset_filename, 'dataset', '-v7.3');
            
            % 保存详细结果
            results_filename = sprintf('data/output/simulation_results_%s.mat', timestamp);
            simulation_results = obj.simulation_results;
            save(results_filename, 'simulation_results', '-v7.3');
            
            fprintf('结果已保存:\n');
            fprintf('  BER矩阵: %s\n', ber_filename);
            fprintf('  数据集: %s\n', dataset_filename);
            fprintf('  详细结果: %s\n', results_filename);
        end
        
        function print_summary(obj)
            % 打印仿真总结
            fprintf('\n=== 仿真总结 ===\n');
            fprintf('信干比: %.1f dB\n', obj.target_sir_db);
            fprintf('波形数量: %d\n', size(obj.ber_matrix, 1));
            fprintf('干扰数量: %d\n', size(obj.ber_matrix, 2));
            fprintf('总组合数: %d\n', numel(obj.ber_matrix));
            
            % 统计BER分布
            valid_ber = obj.ber_matrix(obj.ber_matrix > 0 & obj.ber_matrix < 1);
            if ~isempty(valid_ber)
                fprintf('BER统计:\n');
                fprintf('  最小值: %.6f\n', min(valid_ber));
                fprintf('  最大值: %.6f\n', max(valid_ber));
                fprintf('  平均值: %.6f\n', mean(valid_ber));
                fprintf('  中位数: %.6f\n', median(valid_ber));
            end
            
            fprintf('总用时: %.2f分钟\n', obj.total_time/60);
            fprintf('平均每组合: %.2f秒\n', obj.total_time/numel(obj.ber_matrix));
            fprintf('================\n');
        end
        
        function plot_ber_heatmap(obj)
            % 绘制BER热力图
            figure('Name', 'BER热力图', 'NumberTitle', 'off', 'Position', [100, 100, 1200, 800]);
            
            % 使用对数尺度显示BER
            log_ber = log10(obj.ber_matrix + eps);
            
            imagesc(log_ber);
            colorbar;
            colormap('hot');
            
            xlabel('干扰类型');
            ylabel('波形类型');
            title(sprintf('误比特率热力图 (SIR = %.1f dB, log10尺度)', obj.target_sir_db));
            
            % 设置坐标轴标签
            jamming_labels = {'单音', '多音', '窄带', '噪声FM', '宽带', '梳状谱', '扫频', '跳频'};
            set(gca, 'XTick', 1:8, 'XTickLabel', jamming_labels);
            set(gca, 'YTick', 1:10:100, 'YTickLabel', 1:10:100);
            
            % 添加数值标注
            [rows, cols] = size(obj.ber_matrix);
            for i = 1:min(rows, 20)  % 只显示前20行避免过于拥挤
                for j = 1:cols
                    if obj.ber_matrix(i, j) > 0
                        text(j, i, sprintf('%.2e', obj.ber_matrix(i, j)), ...
                             'HorizontalAlignment', 'center', 'FontSize', 8, 'Color', 'white');
                    end
                end
            end
        end
    end
    
    methods (Access = private)
        function initialize_components(obj)
            % 初始化组件
            obj.waveform_configs = containers.Map();
            obj.jamming_configs = containers.Map();
            obj.simulation_results = {};
            obj.ber_matrix = [];
            obj.dataset = struct();
            
            obj.is_initialized = false;
            obj.is_running = false;
            obj.current_progress = 0;
        end
        
        function load_configurations(obj)
            % 加载配置
            try
                obj.waveform_configs = WaveformConfigManager.initialize_all_configs();
                obj.jamming_configs = JammingConfigManager.initialize_all_configs();
                
                fprintf('配置加载完成: %d种波形, %d种干扰\n', ...
                        length(obj.waveform_configs.keys), length(obj.jamming_configs.keys));
            catch ME
                error('InterferenceSimulationEngine:ConfigLoadFailed', ...
                      '配置加载失败: %s', ME.message);
            end
        end
        
        function waveform_obj = create_waveform_object(obj, config)
            % 创建波形对象
            % 这里需要与现有的波形工厂集成
            % 暂时返回模拟对象
            waveform_obj = struct();
            waveform_obj.config = config;
        end
        
        function jamming_obj = create_jamming_object(obj, config)
            % 创建干扰对象
            % 这里需要与干扰工厂集成
            % 暂时返回模拟对象
            jamming_obj = struct();
            jamming_obj.config = config;
        end
        
        function feature_vector = vectorize_features(obj, features)
            % 将特征结构体转换为向量
            feature_vector = [
                features.carrier_frequency / 1e9;  % 归一化到GHz
                features.bandwidth / 1e6;          % 归一化到MHz
                features.data_rate / 1e6;          % 归一化到Mbps
                features.hop_rate / 1000;          % 归一化到kHz
                features.spreading_factor;
                features.jamming_bandwidth / 1e6;  % 归一化到MHz
                features.jamming_power / 100;      % 归一化功率
                features.sir_db / 50;              % 归一化信干比
            ];
        end
        
        function names = get_feature_names(obj)
            % 获取特征名称
            names = {
                'carrier_frequency_ghz';
                'bandwidth_mhz';
                'data_rate_mbps';
                'hop_rate_khz';
                'spreading_factor';
                'jamming_bandwidth_mhz';
                'jamming_power_normalized';
                'sir_db_normalized'
            };
        end
        
        function result = create_error_result(obj, waveform_id, jamming_id, error_msg)
            % 创建错误结果
            result = struct();
            result.waveform_id = waveform_id;
            result.jamming_id = jamming_id;
            result.ber = 1.0;
            result.sir_db = obj.target_sir_db;
            result.error = true;
            result.error_message = error_msg;
            result.timestamp = datetime('now');
        end
        
        function print_progress(obj, current, total, waveform_id, jamming_id)
            % 打印进度
            if mod(current, 10) == 0 || current == total
                elapsed = toc(obj.start_time);
                estimated_total = elapsed / current * total;
                remaining = estimated_total - elapsed;
                
                fprintf('[%d/%d] 波形%d vs 干扰%d - 进度:%.1f%%, 已用时:%.1fs, 预计剩余:%.1fs\n', ...
                        current, total, waveform_id, jamming_id, ...
                        current/total*100, elapsed, remaining);
            end
        end
    end
end
