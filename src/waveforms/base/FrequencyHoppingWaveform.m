classdef FrequencyHoppingWaveform < WaveformBase
    % FrequencyHoppingWaveform - 跳频波形基类
    % 为现有调制添加跳频功能的基类
    %
    % 作者: Asaqe Lee
    % 日期: 2025-06-18
    
    properties (Access = protected)
        % 跳频控制器
        frequency_hopper
        
        % 跳频参数
        hopping_enabled      % 是否启用跳频
        base_waveform       % 基础波形对象
        hop_sync_enabled    % 是否启用跳频同步
        
        % 内部状态
        current_segment     % 当前段索引
        segment_boundaries  % 段边界时间点
    end
    
    methods
        function obj = FrequencyHoppingWaveform(base_waveform_class)
            % 构造函数
            % 输入: base_waveform_class - 基础波形类名
            
            obj@WaveformBase();
            
            % 创建跳频控制器
            obj.frequency_hopper = FrequencyHopping();
            
            % 创建基础波形实例
            if nargin > 0
                obj.base_waveform = feval(base_waveform_class);
            end
            
            % 初始化参数
            obj.hopping_enabled = false;
            obj.hop_sync_enabled = true;
            obj.current_segment = 1;
        end
        
        function configure(obj, config)
            % 配置跳频波形参数
            % 输入: config - 配置结构体
            
            % 配置基础波形
            if ~isempty(obj.base_waveform)
                obj.base_waveform.configure(config);
            end
            
            % 配置跳频参数
            if isfield(config, 'hopping_enabled')
                obj.hopping_enabled = config.hopping_enabled;
            end
            
            if isfield(config, 'hop_sync_enabled')
                obj.hop_sync_enabled = config.hop_sync_enabled;
            end
            
            % 配置跳频控制器
            hop_config = struct();
            if isfield(config, 'hop_frequencies')
                hop_config.hop_frequencies = config.hop_frequencies;
            end
            if isfield(config, 'hop_rate')
                hop_config.hop_rate = config.hop_rate;
            end
            if isfield(config, 'hop_duration')
                hop_config.hop_duration = config.hop_duration;
            end
            if isfield(config, 'hop_seed')
                hop_config.seed_value = config.hop_seed;
            end
            if isfield(config, 'hop_sequence_length')
                hop_config.sequence_length = config.hop_sequence_length;
            end
            
            if ~isempty(fieldnames(hop_config))
                obj.frequency_hopper.configure(hop_config);
            end
            
            % 调用基类配置
            configure@WaveformBase(obj, config);
        end
        
        function signal = generate_signal(obj, data, params)
            % 生成跳频调制信号
            % 输入: data - 调制数据
            %      params - 参数
            % 输出: signal - 跳频调制信号
            
            if ~obj.hopping_enabled
                % 如果未启用跳频，使用基础波形
                signal = obj.base_waveform.generate_signal(data, params);
                return;
            end
            
            % 计算信号参数
            signal_duration = length(data) / obj.sample_rate;
            hop_info = obj.frequency_hopper.get_hop_info();
            
            % 计算段边界
            obj.calculate_segment_boundaries(signal_duration);
            
            % 生成跳频信号
            signal = obj.generate_hopping_signal(data, params, signal_duration);
        end
        
        function data = recover_data(obj, signal, params)
            % 恢复跳频调制数据
            % 输入: signal - 跳频调制信号
            %      params - 参数
            % 输出: data - 恢复的数据
            
            if ~obj.hopping_enabled
                % 如果未启用跳频，使用基础波形
                data = obj.base_waveform.recover_data(signal, params);
                return;
            end
            
            % 跳频解调
            data = obj.recover_hopping_data(signal, params);
        end
        
        function spectrum = get_spectrum(obj, signal, params)
            % 获取跳频信号频谱
            % 输入: signal - 信号
            %      params - 参数
            % 输出: spectrum - 频谱结构体
            
            if nargin < 3
                params = struct();
            end
            
            % 计算FFT
            N = length(signal);
            Y = fft(signal, N);
            
            % 频率轴
            frequencies = (-N/2:N/2-1) * (obj.sample_rate/N);
            
            % 功率谱密度
            power_density = abs(fftshift(Y)).^2 / (obj.sample_rate * N);
            
            % 构造输出结构体
            spectrum = struct();
            spectrum.frequencies = frequencies;
            spectrum.power_density = power_density;
            
            if obj.hopping_enabled
                hop_info = obj.frequency_hopper.get_hop_info();
                spectrum.hop_bandwidth = hop_info.frequency_range(2) - hop_info.frequency_range(1);
                spectrum.instantaneous_bandwidth = obj.calculate_instantaneous_bandwidth();
            else
                spectrum.hop_bandwidth = 0;
                spectrum.instantaneous_bandwidth = obj.calculate_instantaneous_bandwidth();
            end
        end
        
        function info = get_waveform_info(obj)
            % 获取跳频波形信息
            % 输出: info - 波形信息结构体
            
            % 获取基础波形信息
            if ~isempty(obj.base_waveform)
                info = obj.base_waveform.get_waveform_info();
            else
                info = struct();
            end
            
            % 添加跳频信息
            info.hopping_enabled = obj.hopping_enabled;
            
            if obj.hopping_enabled
                hop_info = obj.frequency_hopper.get_hop_info();
                info.hop_info = hop_info;
                info.waveform_name = [info.waveform_name, '-FH'];
                info.modulation_type = [info.modulation_type, '+FH'];
            end
        end
        
        function plot_hopping_pattern(obj, duration)
            % 绘制跳频图案
            % 输入: duration - 显示持续时间
            
            if obj.hopping_enabled
                obj.frequency_hopper.plot_hop_pattern(duration);
            else
                fprintf('跳频未启用\n');
            end
        end
    end
    
    methods (Access = protected)
        function calculate_segment_boundaries(obj, signal_duration)
            % 计算段边界
            % 输入: signal_duration - 信号持续时间
            
            hop_info = obj.frequency_hopper.get_hop_info();
            hop_duration = hop_info.hop_duration;
            
            % 计算段数
            num_segments = ceil(signal_duration / hop_duration);
            
            % 计算边界时间点
            obj.segment_boundaries = (0:num_segments) * hop_duration;
            obj.segment_boundaries(end) = signal_duration; % 确保最后一段正确
        end
        
        function signal = generate_hopping_signal(obj, data, params, signal_duration)
            % 生成跳频信号
            % 输入: data - 调制数据
            %      params - 参数
            %      signal_duration - 信号持续时间
            % 输出: signal - 跳频信号
            
            % 初始化输出信号
            total_samples = length(data);
            signal = zeros(total_samples, 1);
            
            % 计算每段的样本数
            samples_per_segment = round(obj.segment_boundaries(2) * obj.sample_rate);
            
            % 逐段生成信号
            for i = 1:length(obj.segment_boundaries)-1
                % 计算当前段的样本范围
                start_sample = (i-1) * samples_per_segment + 1;
                end_sample = min(i * samples_per_segment, total_samples);
                
                if start_sample > total_samples
                    break;
                end
                
                % 获取当前段的数据
                segment_data = data(start_sample:end_sample);
                
                % 获取当前跳频频率
                segment_time = obj.segment_boundaries(i);
                hop_frequency = obj.frequency_hopper.get_current_frequency(segment_time);
                
                % 更新基础波形的载波频率
                segment_config = struct();
                segment_config.center_frequency = hop_frequency;
                obj.base_waveform.configure(segment_config);
                
                % 生成当前段的信号
                segment_signal = obj.base_waveform.generate_signal(segment_data, params);
                
                % 将段信号添加到总信号中
                signal(start_sample:end_sample) = segment_signal;
            end
        end
        
        function data = recover_hopping_data(obj, signal, params)
            % 恢复跳频数据
            % 输入: signal - 跳频信号
            %      params - 参数
            % 输出: data - 恢复的数据
            
            % 计算信号参数
            signal_duration = length(signal) / obj.sample_rate;
            obj.calculate_segment_boundaries(signal_duration);
            
            % 初始化输出数据
            total_samples = length(signal);
            data = [];
            
            % 计算每段的样本数
            samples_per_segment = round(obj.segment_boundaries(2) * obj.sample_rate);
            
            % 逐段恢复数据
            for i = 1:length(obj.segment_boundaries)-1
                % 计算当前段的样本范围
                start_sample = (i-1) * samples_per_segment + 1;
                end_sample = min(i * samples_per_segment, total_samples);
                
                if start_sample > total_samples
                    break;
                end
                
                % 获取当前段的信号
                segment_signal = signal(start_sample:end_sample);
                
                % 获取当前跳频频率
                segment_time = obj.segment_boundaries(i);
                hop_frequency = obj.frequency_hopper.get_current_frequency(segment_time);
                
                % 更新基础波形的载波频率
                segment_config = struct();
                segment_config.center_frequency = hop_frequency;
                obj.base_waveform.configure(segment_config);
                
                % 恢复当前段的数据
                segment_data = obj.base_waveform.recover_data(segment_signal, params);
                
                % 将段数据添加到总数据中
                data = [data; segment_data];
            end
        end
        
        function bandwidth = calculate_instantaneous_bandwidth(obj)
            % 计算瞬时带宽
            % 输出: bandwidth - 瞬时带宽
            
            if ~isempty(obj.base_waveform)
                % 获取基础波形的带宽
                base_info = obj.base_waveform.get_waveform_info();
                if isfield(base_info, 'bandwidth')
                    bandwidth = base_info.bandwidth;
                elseif isfield(base_info, 'fm_bandwidth')
                    bandwidth = base_info.fm_bandwidth;
                elseif isfield(base_info, 'am_bandwidth')
                    bandwidth = base_info.am_bandwidth;
                elseif isfield(base_info, 'pm_bandwidth')
                    bandwidth = base_info.pm_bandwidth;
                else
                    bandwidth = 2 * obj.sample_rate / 10; % 默认估计
                end
            else
                bandwidth = 2 * obj.sample_rate / 10; % 默认估计
            end
        end
    end
end
