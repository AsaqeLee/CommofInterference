classdef BERCalculator < handle
    % BERCalculator - 误比特率计算框架
    % 支持100种通信波形在干扰环境下的性能评估
    %
    % 作者: Asaqe Lee
    % 日期: 2025-06-20
    
    properties (Constant)
        % 默认参数
        DEFAULT_NUM_BITS = 10000;       % 默认比特数
        DEFAULT_NUM_TRIALS = 100;       % 默认试验次数
        MIN_ERROR_COUNT = 100;          % 最小错误数
        MAX_TRIALS = 1000;              % 最大试验次数
        CONFIDENCE_LEVEL = 0.95;        % 置信度
    end
    
    properties (Access = private)
        % 仿真参数
        num_bits               % 每次试验的比特数
        num_trials             % 试验次数
        sir_db                 % 信干比 (dB)
        
        % 结果存储
        ber_results            % BER结果容器
        trial_results          % 每次试验结果
        statistics             % 统计信息
        
        % 状态控制
        is_running             % 是否正在运行
        current_trial          % 当前试验次数
        total_bits_tested      % 总测试比特数
        total_errors           % 总错误数
        
        % 性能监控
        start_time             % 开始时间
        elapsed_time           % 已用时间
        estimated_time         % 预计总时间
    end
    
    methods
        function obj = BERCalculator(num_bits, num_trials)
            % 构造函数
            % 输入: num_bits - 每次试验的比特数
            %      num_trials - 试验次数
            
            if nargin < 1
                num_bits = obj.DEFAULT_NUM_BITS;
            end
            if nargin < 2
                num_trials = obj.DEFAULT_NUM_TRIALS;
            end
            
            obj.initialize_parameters(num_bits, num_trials);
        end
        
        function ber = calculate_ber(obj, waveform_obj, jamming_obj, sir_db, params)
            % 计算误比特率
            % 输入: waveform_obj - 波形对象
            %      jamming_obj - 干扰对象
            %      sir_db - 信干比 (dB)
            %      params - 参数结构体
            % 输出: ber - 误比特率
            
            % 参数解析
            if nargin < 5
                params = struct();
            end
            
            obj.sir_db = sir_db;
            obj.reset_counters();
            
            fprintf('开始BER计算: 波形=%s, 干扰=%s, SIR=%.1fdB\n', ...
                    class(waveform_obj), class(jamming_obj), sir_db);
            
            obj.start_time = tic;
            obj.is_running = true;
            
            % 创建SIR控制器
            sir_controller = SIRController(sir_db);
            
            total_errors = 0;
            total_bits = 0;
            
            for trial = 1:obj.num_trials
                obj.current_trial = trial;
                
                % 生成随机数据
                data_bits = randi([0, 1], 1, obj.num_bits);
                
                % 生成通信信号
                comm_signal = waveform_obj.generate_signal(data_bits, params);
                
                % 生成干扰信号
                jamming_signal = jamming_obj.generate_jamming_signal(comm_signal, params);
                
                % 控制信干比并合成信号
                [combined_signal, actual_sir] = sir_controller.combine_signals(...
                    comm_signal, jamming_signal, sir_db);
                
                % 解调信号
                try
                    received_bits = waveform_obj.demodulate(combined_signal, params);
                    
                    % 确保长度一致
                    min_len = min(length(data_bits), length(received_bits));
                    data_bits = data_bits(1:min_len);
                    received_bits = received_bits(1:min_len);
                    
                    % 计算错误
                    errors = sum(data_bits ~= received_bits);
                    
                catch ME
                    % 解调失败，记录为全部错误
                    fprintf('解调失败 (试验%d): %s\n', trial, ME.message);
                    errors = obj.num_bits;
                    min_len = obj.num_bits;
                end
                
                % 累计统计
                total_errors = total_errors + errors;
                total_bits = total_bits + min_len;
                
                % 记录试验结果
                obj.record_trial_result(trial, errors, min_len, actual_sir);
                
                % 更新进度
                obj.update_progress();
                
                % 检查早期停止条件
                if obj.check_early_stop(total_errors, total_bits)
                    break;
                end
            end
            
            % 计算最终BER
            if total_bits > 0
                ber = total_errors / total_bits;
            else
                ber = 1;  % 如果没有有效比特，设为最大错误率
            end
            
            % 更新统计信息
            obj.update_statistics(ber, total_errors, total_bits);
            
            obj.is_running = false;
            obj.elapsed_time = toc(obj.start_time);
            
            fprintf('BER计算完成: BER=%.6f, 错误数=%d, 总比特数=%d, 用时=%.2fs\n', ...
                    ber, total_errors, total_bits, obj.elapsed_time);
        end
        
        function ber_table = calculate_ber_for_all_waveforms(obj, waveform_configs, jamming_configs, sir_db)
            % 计算所有波形的BER
            % 输入: waveform_configs - 波形配置
            %      jamming_configs - 干扰配置
            %      sir_db - 信干比 (dB)
            % 输出: ber_table - BER结果表
            
            fprintf('开始计算所有波形的BER (SIR=%.1fdB)\n', sir_db);
            
            waveform_ids = cell2mat(waveform_configs.keys);
            jamming_ids = cell2mat(jamming_configs.keys);
            
            num_waveforms = length(waveform_ids);
            num_jammings = length(jamming_ids);
            
            % 初始化结果表
            ber_table = zeros(num_waveforms, num_jammings);
            
            total_combinations = num_waveforms * num_jammings;
            current_combination = 0;
            
            for i = 1:num_waveforms
                waveform_id = waveform_ids(i);
                waveform_config = waveform_configs(waveform_id);
                
                % 创建波形对象
                try
                    waveform_obj = obj.create_waveform_object(waveform_config);
                catch ME
                    fprintf('创建波形%d失败: %s\n', waveform_id, ME.message);
                    ber_table(i, :) = 1;  % 设为最大错误率
                    continue;
                end
                
                for j = 1:num_jammings
                    current_combination = current_combination + 1;
                    jamming_id = jamming_ids(j);
                    jamming_config = jamming_configs(jamming_id);
                    
                    fprintf('进度: %d/%d - 波形%d vs 干扰%d\n', ...
                            current_combination, total_combinations, waveform_id, jamming_id);
                    
                    % 创建干扰对象
                    try
                        jamming_obj = obj.create_jamming_object(jamming_config);
                        
                        % 计算BER
                        ber = obj.calculate_ber(waveform_obj, jamming_obj, sir_db);
                        ber_table(i, j) = ber;
                        
                    catch ME
                        fprintf('计算BER失败 (波形%d, 干扰%d): %s\n', ...
                                waveform_id, jamming_id, ME.message);
                        ber_table(i, j) = 1;  % 设为最大错误率
                    end
                end
            end
            
            fprintf('所有波形BER计算完成\n');
        end
        
        function confidence_interval = calculate_confidence_interval(obj, ber, num_bits)
            % 计算置信区间
            % 输入: ber - 误比特率
            %      num_bits - 比特数
            % 输出: confidence_interval - 置信区间 [下限, 上限]
            
            if ber <= 0 || ber >= 1
                confidence_interval = [0, 1];
                return;
            end
            
            % 使用正态近似计算置信区间
            z_alpha = norminv(1 - (1 - obj.CONFIDENCE_LEVEL) / 2);
            std_error = sqrt(ber * (1 - ber) / num_bits);
            
            lower_bound = max(0, ber - z_alpha * std_error);
            upper_bound = min(1, ber + z_alpha * std_error);
            
            confidence_interval = [lower_bound, upper_bound];
        end
        
        function obj = set_parameters(obj, num_bits, num_trials)
            % 设置参数
            % 输入: num_bits - 每次试验的比特数
            %      num_trials - 试验次数
            
            obj.num_bits = num_bits;
            obj.num_trials = num_trials;
            
            fprintf('BER计算参数设置: 比特数=%d, 试验次数=%d\n', num_bits, num_trials);
        end
        
        function results = get_results(obj)
            % 获取结果
            results = obj.ber_results;
        end
        
        function obj = reset(obj)
            % 重置计算器
            obj.reset_counters();
            obj.ber_results = containers.Map();
            obj.trial_results = [];
            obj.statistics = struct();
            
            fprintf('BER计算器已重置\n');
        end
        
        function print_statistics(obj)
            % 打印统计信息
            if isempty(obj.statistics)
                fprintf('没有统计信息可显示\n');
                return;
            end
            
            fprintf('=== BER计算统计 ===\n');
            fprintf('信干比: %.1f dB\n', obj.sir_db);
            fprintf('误比特率: %.6f\n', obj.statistics.ber);
            fprintf('总错误数: %d\n', obj.statistics.total_errors);
            fprintf('总比特数: %d\n', obj.statistics.total_bits);
            fprintf('试验次数: %d\n', obj.statistics.num_trials);
            fprintf('置信区间: [%.6f, %.6f]\n', obj.statistics.confidence_interval);
            fprintf('计算时间: %.2f s\n', obj.elapsed_time);
            fprintf('==================\n');
        end
        
        function plot_ber_curve(obj, sir_range, waveform_obj, jamming_obj)
            % 绘制BER曲线
            % 输入: sir_range - 信干比范围
            %      waveform_obj - 波形对象
            %      jamming_obj - 干扰对象
            
            ber_values = zeros(size(sir_range));
            
            for i = 1:length(sir_range)
                ber_values(i) = obj.calculate_ber(waveform_obj, jamming_obj, sir_range(i));
            end
            
            figure('Name', 'BER性能曲线', 'NumberTitle', 'off');
            semilogy(sir_range, ber_values, 'b-o', 'LineWidth', 2, 'MarkerSize', 6);
            xlabel('信干比 (dB)');
            ylabel('误比特率');
            title(sprintf('BER性能曲线 - %s vs %s', class(waveform_obj), class(jamming_obj)));
            grid on;
            
            % 标记10dB点
            target_sir = 10;
            if any(sir_range == target_sir)
                idx = find(sir_range == target_sir);
                hold on;
                semilogy(target_sir, ber_values(idx), 'ro', 'MarkerSize', 10, 'LineWidth', 3);
                legend('BER曲线', '10dB工作点', 'Location', 'best');
            end
        end
    end
    
    methods (Access = private)
        function initialize_parameters(obj, num_bits, num_trials)
            % 初始化参数
            obj.num_bits = num_bits;
            obj.num_trials = num_trials;
            obj.sir_db = 10;  % 默认10dB
            
            obj.ber_results = containers.Map();
            obj.trial_results = [];
            obj.statistics = struct();
            
            obj.reset_counters();
        end
        
        function reset_counters(obj)
            % 重置计数器
            obj.is_running = false;
            obj.current_trial = 0;
            obj.total_bits_tested = 0;
            obj.total_errors = 0;
            obj.start_time = 0;
            obj.elapsed_time = 0;
            obj.estimated_time = 0;
        end
        
        function record_trial_result(obj, trial, errors, bits, actual_sir)
            % 记录试验结果
            result = struct();
            result.trial = trial;
            result.errors = errors;
            result.bits = bits;
            result.ber = errors / bits;
            result.actual_sir = actual_sir;
            
            obj.trial_results(end+1) = result;
        end
        
        function update_progress(obj)
            % 更新进度
            if mod(obj.current_trial, 10) == 0 || obj.current_trial == obj.num_trials
                progress = obj.current_trial / obj.num_trials * 100;
                elapsed = toc(obj.start_time);
                estimated_total = elapsed / obj.current_trial * obj.num_trials;
                remaining = estimated_total - elapsed;
                
                fprintf('进度: %.1f%% (%d/%d), 已用时: %.1fs, 预计剩余: %.1fs\n', ...
                        progress, obj.current_trial, obj.num_trials, elapsed, remaining);
            end
        end
        
        function should_stop = check_early_stop(obj, total_errors, total_bits)
            % 检查早期停止条件
            should_stop = false;
            
            % 如果错误数足够多且置信度满足要求，可以早期停止
            if total_errors >= obj.MIN_ERROR_COUNT && obj.current_trial >= obj.num_trials / 2
                current_ber = total_errors / total_bits;
                ci = obj.calculate_confidence_interval(current_ber, total_bits);
                relative_error = (ci(2) - ci(1)) / (2 * current_ber);
                
                if relative_error < 0.1  % 相对误差小于10%
                    should_stop = true;
                    fprintf('满足早期停止条件 (试验%d)\n', obj.current_trial);
                end
            end
        end
        
        function update_statistics(obj, ber, total_errors, total_bits)
            % 更新统计信息
            obj.statistics.ber = ber;
            obj.statistics.total_errors = total_errors;
            obj.statistics.total_bits = total_bits;
            obj.statistics.num_trials = obj.current_trial;
            obj.statistics.confidence_interval = obj.calculate_confidence_interval(ber, total_bits);
            obj.statistics.sir_db = obj.sir_db;
        end
        
        function waveform_obj = create_waveform_object(obj, config)
            % 创建波形对象
            % 这里需要根据配置创建相应的波形对象
            % 暂时返回空，需要与波形工厂集成
            waveform_obj = [];
        end
        
        function jamming_obj = create_jamming_object(obj, config)
            % 创建干扰对象
            % 这里需要根据配置创建相应的干扰对象
            % 暂时返回空，需要与干扰工厂集成
            jamming_obj = [];
        end
    end
end
