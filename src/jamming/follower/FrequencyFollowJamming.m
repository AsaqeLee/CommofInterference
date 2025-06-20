classdef FrequencyFollowJamming < JammingBase
    % FrequencyFollowJamming - 跟踪式跳频干扰
    % 实现模仿通信跳频图案的CW干扰信号
    %
    % 作者: Asaqe Lee
    % 日期: 2025-06-20
    
    properties (Constant)
        JAMMING_ID = 8                    % 干扰信号ID
        JAMMING_NAME = '跟踪式跳频干扰'    % 干扰信号名称
        JAMMING_TYPE = 'CW'               % 干扰类型
        CATEGORY = 'follower'             % 干扰类别
    end
    
    properties (Access = private)
        hop_frequencies     % 跳频频率表 (Hz)
        hop_rate           % 跳频速率 (hops/s)
        hop_period         % 跳频周期 (s)
        follow_delay       % 跟踪延迟 (s)
        
        % 跳频模式
        hop_pattern        % 跳频图案 ('sequential', 'random', 'custom')
        hop_sequence       % 跳频序列
        sequence_length    % 序列长度
        
        % 内部状态
        current_hop_index  % 当前跳频索引
        current_hop_freq   % 当前跳频频率
        hop_start_time     % 当前跳频开始时间
        total_hops         % 总跳频次数
        
        % 跟踪参数
        detection_mode     % 检测模式 ('energy', 'correlation')
        tracking_accuracy  % 跟踪精度
        lock_status        % 锁定状态
    end
    
    methods
        function obj = FrequencyFollowJamming(config)
            % 构造函数
            % 输入: config - 配置参数
            
            obj@JammingBase();
            
            if nargin > 0
                obj = obj.configure_parameters(config);
            else
                obj.initialize_default_parameters();
            end
        end
        
        function signal = generate_jamming_signal(obj, target_signal, params)
            % 生成跟踪式跳频干扰信号
            % 输入: target_signal - 目标通信信号
            %      params - 参数
            % 输出: signal - 干扰信号
            
            % 参数解析
            if nargin < 3
                params = struct();
            end
            
            % 获取信号长度
            if ~isempty(target_signal)
                signal_length = length(target_signal);
            else
                signal_length = round(obj.duration * obj.sample_rate);
            end
            
            % 如果有目标信号，尝试检测跳频
            if ~isempty(target_signal)
                obj.detect_target_hopping(target_signal);
            end
            
            % 生成跳频干扰信号
            signal = obj.generate_hopping_signal(signal_length);
            
            % 功率调整
            signal_power = mean(abs(signal).^2);
            target_power = obj.power_watts;
            if signal_power > 0
                signal = signal * sqrt(target_power / signal_power);
            end
            
            % 确保输出为行向量
            signal = signal(:).';
        end
        
        function signal = generate_hopping_signal(obj, signal_length)
            % 生成跳频信号
            % 输入: signal_length - 信号长度
            % 输出: signal - 跳频信号
            
            signal = zeros(1, signal_length);
            t = (0:signal_length-1) / obj.sample_rate;
            
            % 计算每个采样点的跳频频率
            for i = 1:signal_length
                current_time = t(i);
                
                % 计算当前应该使用的跳频频率
                hop_freq = obj.get_current_hop_frequency(current_time);
                
                % 生成CW信号
                signal(i) = exp(1j * 2*pi*hop_freq*current_time);
            end
        end
        
        function hop_freq = get_current_hop_frequency(obj, current_time)
            % 获取当前跳频频率
            % 输入: current_time - 当前时间
            % 输出: hop_freq - 跳频频率
            
            % 考虑跟踪延迟
            delayed_time = max(0, current_time - obj.follow_delay);
            
            % 计算跳频索引
            hop_index = floor(delayed_time / obj.hop_period) + 1;
            
            % 处理序列循环
            if hop_index > obj.sequence_length
                hop_index = mod(hop_index - 1, obj.sequence_length) + 1;
            end
            
            % 获取对应的跳频频率
            if hop_index >= 1 && hop_index <= length(obj.hop_sequence)
                freq_index = obj.hop_sequence(hop_index);
                if freq_index >= 1 && freq_index <= length(obj.hop_frequencies)
                    hop_freq = obj.hop_frequencies(freq_index);
                else
                    hop_freq = obj.center_frequency;
                end
            else
                hop_freq = obj.center_frequency;
            end
            
            % 更新内部状态
            obj.current_hop_index = hop_index;
            obj.current_hop_freq = hop_freq;
        end
        
        function detect_target_hopping(obj, target_signal)
            % 检测目标信号的跳频模式
            % 输入: target_signal - 目标信号
            
            try
                switch obj.detection_mode
                    case 'energy'
                        obj.detect_by_energy(target_signal);
                    case 'correlation'
                        obj.detect_by_correlation(target_signal);
                    otherwise
                        % 默认使用能量检测
                        obj.detect_by_energy(target_signal);
                end
            catch ME
                fprintf('跳频检测失败: %s\n', ME.message);
                obj.lock_status = false;
            end
        end
        
        function detect_by_energy(obj, target_signal)
            % 基于能量的跳频检测
            % 输入: target_signal - 目标信号
            
            % 计算短时能量
            window_length = round(obj.hop_period * obj.sample_rate / 4);
            hop_length = round(obj.hop_period * obj.sample_rate);
            
            num_hops = floor(length(target_signal) / hop_length);
            detected_freqs = zeros(1, num_hops);
            
            for i = 1:num_hops
                start_idx = (i-1) * hop_length + 1;
                end_idx = min(start_idx + hop_length - 1, length(target_signal));
                
                hop_segment = target_signal(start_idx:end_idx);
                
                % FFT分析找到主频率
                N = length(hop_segment);
                f = (0:N-1) * obj.sample_rate / N;
                S = abs(fft(hop_segment));
                
                [~, max_idx] = max(S(1:floor(N/2)));
                detected_freqs(i) = f(max_idx);
            end
            
            % 更新跳频序列
            obj.update_hop_sequence_from_detection(detected_freqs);
        end
        
        function detect_by_correlation(obj, target_signal)
            % 基于相关的跳频检测
            % 输入: target_signal - 目标信号
            
            % 简化的相关检测
            % 这里可以实现更复杂的相关算法
            obj.detect_by_energy(target_signal);
        end
        
        function update_hop_sequence_from_detection(obj, detected_freqs)
            % 根据检测结果更新跳频序列
            % 输入: detected_freqs - 检测到的频率
            
            if isempty(detected_freqs)
                return;
            end
            
            % 将检测到的频率映射到跳频频率表
            new_sequence = zeros(1, length(detected_freqs));
            
            for i = 1:length(detected_freqs)
                [~, closest_idx] = min(abs(obj.hop_frequencies - detected_freqs(i)));
                new_sequence(i) = closest_idx;
            end
            
            % 更新跳频序列
            obj.hop_sequence = new_sequence;
            obj.sequence_length = length(new_sequence);
            obj.lock_status = true;
            
            fprintf('检测到跳频模式，序列长度: %d\n', obj.sequence_length);
        end
        
        function effectiveness = calculate_effectiveness(obj, target_signal, jammed_signal)
            % 计算干扰效果
            % 输入: target_signal - 目标信号
            %      jammed_signal - 被干扰信号
            % 输出: effectiveness - 干扰效果 (0-1)
            
            if isempty(target_signal) || isempty(jammed_signal)
                effectiveness = 0;
                return;
            end
            
            % 计算跟踪精度
            if obj.lock_status
                % 如果锁定成功，效果较好
                base_effectiveness = 0.8;
            else
                % 如果未锁定，效果一般
                base_effectiveness = 0.3;
            end
            
            % 根据功率比调整效果
            target_power = mean(abs(target_signal).^2);
            jammed_power = mean(abs(jammed_signal).^2);
            
            if target_power > 0
                power_ratio = jammed_power / target_power;
                power_factor = min(log10(power_ratio + 1) / 2, 1);
                effectiveness = base_effectiveness * power_factor;
            else
                effectiveness = 0;
            end
            
            % 更新干扰效果
            obj.jamming_effectiveness = effectiveness;
        end
        
        function obj = configure_parameters(obj, config)
            % 配置参数
            % 输入: config - 配置结构体
            
            % 基础参数配置
            if isfield(config, 'center_frequency')
                obj.center_frequency = config.center_frequency;
            end
            
            if isfield(config, 'power_dbm')
                obj.power_dbm = config.power_dbm;
            end
            
            if isfield(config, 'sample_rate')
                obj.sample_rate = config.sample_rate;
            end
            
            if isfield(config, 'duration')
                obj.duration = config.duration;
            end
            
            if isfield(config, 'hop_frequencies')
                obj.hop_frequencies = config.hop_frequencies;
            end
            
            if isfield(config, 'hop_rate')
                obj.hop_rate = config.hop_rate;
                obj.hop_period = 1 / obj.hop_rate;
            end
            
            if isfield(config, 'follow_delay')
                obj.follow_delay = config.follow_delay;
            end
            
            if isfield(config, 'hop_pattern')
                obj.hop_pattern = config.hop_pattern;
            end
            
            % 生成跳频序列
            obj.generate_hop_sequence();
            
            % 验证参数
            obj.validate_parameters();
            
            fprintf('跟踪式跳频干扰配置完成: %d个频点, 跳频率=%.0fhops/s, 延迟=%.1fμs\n', ...
                    length(obj.hop_frequencies), obj.hop_rate, obj.follow_delay*1e6);
        end
        
        function obj = set_hop_frequencies(obj, frequencies)
            % 设置跳频频率表
            % 输入: frequencies - 频率数组 (Hz)
            
            assert(all(frequencies > 0), 'FrequencyFollowJamming:InvalidFreq', '所有频率必须大于0');
            
            obj.hop_frequencies = frequencies(:).';  % 确保为行向量
            
            % 重新生成跳频序列
            obj.generate_hop_sequence();
            
            fprintf('跳频频率表设置完成: %d个频点\n', length(frequencies));
            for i = 1:min(length(frequencies), 10)  % 最多显示10个
                fprintf('  频点%d: %.2f MHz\n', i, frequencies(i)/1e6);
            end
            if length(frequencies) > 10
                fprintf('  ... (共%d个频点)\n', length(frequencies));
            end
        end
        
        function obj = set_hop_rate(obj, hop_rate)
            % 设置跳频速率
            % 输入: hop_rate - 跳频速率 (hops/s)
            
            assert(hop_rate > 0, 'FrequencyFollowJamming:InvalidHopRate', '跳频速率必须大于0');
            assert(hop_rate <= 10000, 'FrequencyFollowJamming:HopRateTooHigh', '跳频速率不能超过10000 hops/s');
            
            obj.hop_rate = hop_rate;
            obj.hop_period = 1 / hop_rate;
            
            fprintf('跳频速率设置为: %.0f hops/s (周期: %.2f ms)\n', ...
                    hop_rate, obj.hop_period*1e3);
        end
        
        function generate_hop_sequence(obj)
            % 生成跳频序列
            
            if isempty(obj.hop_frequencies)
                return;
            end
            
            num_freqs = length(obj.hop_frequencies);
            
            switch obj.hop_pattern
                case 'sequential'
                    % 顺序跳频
                    obj.hop_sequence = 1:num_freqs;
                    
                case 'random'
                    % 随机跳频
                    obj.sequence_length = min(100, num_freqs * 4);  % 限制序列长度
                    obj.hop_sequence = randi(num_freqs, 1, obj.sequence_length);
                    
                case 'custom'
                    % 自定义序列（如果已设置）
                    if isempty(obj.hop_sequence)
                        obj.hop_sequence = 1:num_freqs;  % 默认顺序
                    end
                    
                otherwise
                    % 默认顺序跳频
                    obj.hop_sequence = 1:num_freqs;
            end
            
            obj.sequence_length = length(obj.hop_sequence);
        end
        
        function obj = reset(obj)
            % 重置干扰信号状态
            obj.current_hop_index = 1;
            obj.current_hop_freq = obj.hop_frequencies(1);
            obj.hop_start_time = 0;
            obj.total_hops = 0;
            obj.lock_status = false;
            
            fprintf('跟踪式跳频干扰状态已重置\n');
        end
        
        function print_status(obj)
            % 打印状态信息
            fprintf('=== %s 状态 ===\n', obj.JAMMING_NAME);
            fprintf('ID: %d\n', obj.JAMMING_ID);
            fprintf('类型: %s\n', obj.JAMMING_TYPE);
            fprintf('类别: %s\n', obj.CATEGORY);
            fprintf('中心频率: %.2f MHz\n', obj.center_frequency / 1e6);
            fprintf('跳频频点数: %d\n', length(obj.hop_frequencies));
            fprintf('跳频速率: %.0f hops/s\n', obj.hop_rate);
            fprintf('跳频周期: %.2f ms\n', obj.hop_period * 1e3);
            fprintf('跟踪延迟: %.1f μs\n', obj.follow_delay * 1e6);
            fprintf('跳频模式: %s\n', obj.hop_pattern);
            fprintf('序列长度: %d\n', obj.sequence_length);
            fprintf('当前跳频索引: %d\n', obj.current_hop_index);
            fprintf('当前跳频频率: %.2f MHz\n', obj.current_hop_freq / 1e6);
            fprintf('检测模式: %s\n', obj.detection_mode);
            fprintf('锁定状态: %s\n', obj.lock_status ? '已锁定' : '未锁定');
            fprintf('总跳频次数: %d\n', obj.total_hops);
            fprintf('功率: %.1f dBm (%.2e W)\n', obj.power_dbm, obj.power_watts);
            fprintf('采样率: %.2f MHz\n', obj.sample_rate / 1e6);
            fprintf('持续时间: %.3f s\n', obj.duration);
            fprintf('状态: %s\n', obj.is_active ? '激活' : '停用');
            fprintf('========================\n');
        end
    end
    
    methods (Access = protected)
        function initialize_default_parameters(obj)
            % 初始化默认参数
            obj.initialize_default_parameters@JammingBase();
            
            % 默认跳频频率表（以中心频率为基准）
            obj.hop_frequencies = obj.center_frequency + (-5:5) * 1e6;  % ±5MHz, 1MHz间隔
            obj.hop_rate = 1000;             % 1000 hops/s
            obj.hop_period = 1e-3;           % 1 ms
            obj.follow_delay = 1e-6;         % 1 μs跟踪延迟
            
            obj.hop_pattern = 'sequential';  % 顺序跳频
            obj.detection_mode = 'energy';   % 能量检测
            obj.tracking_accuracy = 0.9;     % 90%跟踪精度
            
            obj.current_hop_index = 1;
            obj.current_hop_freq = obj.hop_frequencies(1);
            obj.hop_start_time = 0;
            obj.total_hops = 0;
            obj.lock_status = false;
            
            % 生成默认跳频序列
            obj.generate_hop_sequence();
        end
        
        function validate_parameters(obj)
            % 验证参数有效性
            obj.validate_parameters@JammingBase();
            
            assert(~isempty(obj.hop_frequencies), 'FrequencyFollowJamming:NoHopFreqs', ...
                   '跳频频率表不能为空');
            assert(all(obj.hop_frequencies > 0), 'FrequencyFollowJamming:InvalidHopFreqs', ...
                   '所有跳频频率必须大于0');
            assert(obj.hop_rate > 0, 'FrequencyFollowJamming:InvalidHopRate', ...
                   '跳频速率必须大于0');
            assert(obj.follow_delay >= 0, 'FrequencyFollowJamming:InvalidDelay', ...
                   '跟踪延迟不能为负');
            assert(~isempty(obj.hop_sequence), 'FrequencyFollowJamming:NoHopSequence', ...
                   '跳频序列不能为空');
        end
    end
end
