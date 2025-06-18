classdef FrequencyHopping < handle
    % FrequencyHopping - 跳频基础类
    % 提供跳频序列生成、频率切换控制等基础功能
    %
    % 作者: Asaqe Lee
    % 日期: 2025-06-18
    
    properties (Access = private)
        % 跳频参数
        hop_frequencies        % 跳频频率集合
        hop_sequence          % 跳频序列
        hop_duration          % 每跳持续时间 (秒)
        hop_rate             % 跳频速率 (跳/秒)
        current_hop_index    % 当前跳频索引
        
        % 序列生成参数
        pn_sequence          % 伪随机序列
        seed_value           % 随机种子
        sequence_length      % 序列长度
        
        % 同步参数
        sync_pattern         % 同步图案
        sync_threshold       % 同步阈值
        
        % 内部状态
        time_in_hop         % 当前跳内时间
        total_time          % 总时间
        is_synchronized     % 是否同步
    end
    
    methods
        function obj = FrequencyHopping()
            % 构造函数
            obj.initialize_default_params();
        end
        
        function configure(obj, config)
            % 配置跳频参数
            % 输入: config - 配置结构体
            
            if isfield(config, 'hop_frequencies')
                obj.hop_frequencies = config.hop_frequencies;
            end
            
            if isfield(config, 'hop_rate')
                obj.hop_rate = config.hop_rate;
                obj.hop_duration = 1 / obj.hop_rate;
            end
            
            if isfield(config, 'hop_duration')
                obj.hop_duration = config.hop_duration;
                obj.hop_rate = 1 / obj.hop_duration;
            end
            
            if isfield(config, 'seed_value')
                obj.seed_value = config.seed_value;
            end
            
            if isfield(config, 'sequence_length')
                obj.sequence_length = config.sequence_length;
            end
            
            % 生成跳频序列
            obj.generate_hop_sequence();
            
            % 重置状态
            obj.reset();
        end
        
        function freq = get_current_frequency(obj, time)
            % 获取当前时刻的跳频频率
            % 输入: time - 当前时间
            % 输出: freq - 当前频率

            % 检查跳频序列是否存在
            if isempty(obj.hop_sequence)
                obj.generate_hop_sequence();
            end

            % 计算当前跳频索引
            hop_index = floor(time / obj.hop_duration) + 1;
            hop_index = mod(hop_index - 1, length(obj.hop_sequence)) + 1;

            % 获取对应的频率
            freq_index = obj.hop_sequence(hop_index);
            freq = obj.hop_frequencies(freq_index);
        end
        
        function [freqs, times] = get_frequency_sequence(obj, total_duration, sample_rate)
            % 获取完整的频率序列
            % 输入: total_duration - 总持续时间
            %      sample_rate - 采样率
            % 输出: freqs - 频率序列
            %      times - 时间序列
            
            times = (0:1/sample_rate:total_duration-1/sample_rate)';
            freqs = zeros(size(times));
            
            for i = 1:length(times)
                freqs(i) = obj.get_current_frequency(times(i));
            end
        end
        
        function sequence = generate_pn_sequence(obj, seq_length, seed)
            % 生成伪随机序列
            % 输入: seq_length - 序列长度
            %      seed - 随机种子
            % 输出: sequence - 伪随机序列

            if nargin < 3
                seed = obj.seed_value;
            end

            % 使用线性反馈移位寄存器生成PN序列
            rng(seed);

            % 生成m序列（最大长度序列）
            % 使用简化的方法生成伪随机序列
            sequence = zeros(1, seq_length);
            register = [1, 1, 0, 1]; % 4位寄存器初始状态

            for i = 1:seq_length
                % 输出当前状态的最后一位
                sequence(i) = register(end);

                % 计算反馈位（异或运算）
                feedback = xor(register(1), register(2));

                % 移位并插入反馈位
                register = [feedback, register(1:end-1)];
            end

            % 转换为1到N的索引
            if ~isempty(obj.hop_frequencies)
                sequence = mod(sequence, length(obj.hop_frequencies)) + 1;
            else
                % 如果频率集合为空，使用默认值
                sequence = ones(size(sequence));
            end
        end
        
        function pattern = generate_sync_pattern(obj)
            % 生成同步图案
            % 输出: pattern - 同步图案
            
            % 使用特定的同步序列
            pattern = [1, 0, 1, 1, 0, 1, 0, 0, 1, 1, 1, 0, 1, 0, 1, 0];
        end
        
        function is_sync = detect_synchronization(obj, received_pattern)
            % 检测同步
            % 输入: received_pattern - 接收到的图案
            % 输出: is_sync - 是否同步
            
            sync_pattern = obj.generate_sync_pattern();
            
            % 计算相关性
            correlation = xcorr(received_pattern, sync_pattern);
            max_corr = max(abs(correlation));
            
            % 判断是否超过阈值
            is_sync = max_corr > obj.sync_threshold;
        end
        
        function reset(obj)
            % 重置跳频状态
            obj.current_hop_index = 1;
            obj.time_in_hop = 0;
            obj.total_time = 0;
            obj.is_synchronized = false;
        end
        
        function info = get_hop_info(obj)
            % 获取跳频信息
            % 输出: info - 跳频信息结构体

            % 确保跳频序列存在
            if isempty(obj.hop_sequence)
                obj.generate_hop_sequence();
            end

            info = struct();
            info.num_frequencies = length(obj.hop_frequencies);
            if ~isempty(obj.hop_frequencies)
                info.frequency_range = [min(obj.hop_frequencies), max(obj.hop_frequencies)];
            else
                info.frequency_range = [0, 0];
            end
            info.hop_rate = obj.hop_rate;
            info.hop_duration = obj.hop_duration;
            info.sequence_length = length(obj.hop_sequence);
            info.current_hop_index = obj.current_hop_index;
            info.is_synchronized = obj.is_synchronized;
        end
        
        function plot_hop_pattern(obj, duration)
            % 绘制跳频图案
            % 输入: duration - 显示持续时间
            
            if nargin < 2
                duration = 10 * obj.hop_duration; % 默认显示10跳
            end
            
            sample_rate = 1000; % 用于绘图的采样率
            [freqs, times] = obj.get_frequency_sequence(duration, sample_rate);
            
            figure('Name', '跳频图案', 'Position', [100, 100, 800, 400]);
            plot(times * 1000, freqs / 1e6, 'b-', 'LineWidth', 2);
            xlabel('时间 (ms)');
            ylabel('频率 (MHz)');
            title('跳频频率随时间变化');
            grid on;
            
            % 添加跳频边界线
            hop_times = (0:obj.hop_duration:duration) * 1000;
            for i = 1:length(hop_times)
                xline(hop_times(i), 'r--', 'Alpha', 0.5);
            end
        end
    end
    
    methods (Access = private)
        function initialize_default_params(obj)
            % 初始化默认参数
            
            % 默认跳频频率集合 (10个频率，间隔1MHz)
            obj.hop_frequencies = (2400:1:2409) * 1e6; % 2.4-2.409 GHz
            
            % 默认跳频参数
            obj.hop_rate = 1000;                    % 1000 跳/秒
            obj.hop_duration = 1 / obj.hop_rate;    % 1ms每跳
            
            % 序列参数
            obj.seed_value = 12345;
            obj.sequence_length = 127;              % 默认序列长度
            
            % 同步参数
            obj.sync_threshold = 0.8;
            
            % 生成默认序列
            obj.generate_hop_sequence();
            
            % 初始化状态
            obj.reset();
        end
        
        function generate_hop_sequence(obj)
            % 生成跳频序列
            
            if isempty(obj.hop_frequencies)
                error('FrequencyHopping:NoFrequencies', '跳频频率集合不能为空');
            end
            
            % 生成伪随机序列
            obj.pn_sequence = obj.generate_pn_sequence(obj.sequence_length, obj.seed_value);
            
            % 映射到频率索引
            num_freqs = length(obj.hop_frequencies);
            obj.hop_sequence = mod(obj.pn_sequence - 1, num_freqs) + 1;
            
            % 生成同步图案
            obj.sync_pattern = obj.generate_sync_pattern();
        end
    end
end
