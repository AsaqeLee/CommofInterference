classdef (Abstract) WaveformBase < handle
    % WaveformBase - 通信波形基类
    % 定义所有通信波形的统一接口和基础功能
    %
    % 作者: Asaqe Lee
    % 日期: 2025-06-18
    
    properties (Abstract, Constant)
        WAVEFORM_ID         % 波形ID (1-100)
        WAVEFORM_NAME       % 波形名称
        MODULATION_TYPE     % 调制类型 ('PSK', 'QAM', 'FSK', 'OFDM', 'FM', 'DSSS', 'FHSS')
        CATEGORY           % 波形类别 ('digital', 'analog', 'spread_spectrum', 'ofdm')
    end
    
    properties (Access = protected)
        % 基础参数
        center_frequency    % 中心频率 (Hz)
        bandwidth          % 带宽 (Hz)
        data_rate          % 数据速率 (bps)
        sample_rate        % 采样率 (Hz)
        symbol_rate        % 符号速率 (symbols/s)
        
        % 调制参数
        modulation_order   % 调制阶数
        coding_scheme      % 编码方案
        coding_rate        % 编码率
        
        % 跳频参数
        hopping_enabled    % 是否启用跳频
        hopping_rate       % 跳频速率 (hops/s)
        frequency_set      % 频点集
        hop_sequence       % 跳频序列
        
        % 信道参数
        channel_type       % 信道类型 ('AWGN', 'Rayleigh', 'Rician')
        snr_db            % 信噪比 (dB)
        
        % 滤波器参数
        pulse_shaping      % 脉冲成形类型
        filter_rolloff     % 滤波器滚降因子
        
        % 仿真参数
        simulation_time    % 仿真时长 (s)
        num_symbols       % 符号数量
        
        % 内部状态
        is_configured     % 是否已配置
        last_generated_signal  % 最后生成的信号
        performance_metrics    % 性能指标
    end
    
    methods (Abstract)
        % 核心抽象方法 - 子类必须实现
        signal = modulate(obj, data, params)
        data = demodulate(obj, signal, params)
        ber = calculate_ber(obj, original_data, received_data)
        spectrum = get_spectrum(obj, signal, params)
        info = get_waveform_info(obj)
    end
    
    methods
        function obj = WaveformBase()
            % 构造函数
            obj.initialize_default_params();
            obj.is_configured = false;
        end
        
        function configure(obj, config_struct)
            % 配置波形参数
            % 输入: config_struct - 配置结构体
            
            try
                % 验证配置参数
                obj.validate_config(config_struct);
                
                % 设置基础参数
                if isfield(config_struct, 'center_frequency')
                    obj.center_frequency = config_struct.center_frequency;
                end
                if isfield(config_struct, 'bandwidth')
                    obj.bandwidth = config_struct.bandwidth;
                end
                if isfield(config_struct, 'data_rate')
                    obj.data_rate = config_struct.data_rate;
                end
                if isfield(config_struct, 'sample_rate')
                    obj.sample_rate = config_struct.sample_rate;
                end
                if isfield(config_struct, 'symbol_rate')
                    obj.symbol_rate = config_struct.symbol_rate;
                end
                
                % 设置调制参数
                if isfield(config_struct, 'modulation_order')
                    obj.modulation_order = config_struct.modulation_order;
                end
                if isfield(config_struct, 'coding_scheme')
                    obj.coding_scheme = config_struct.coding_scheme;
                end
                if isfield(config_struct, 'coding_rate')
                    obj.coding_rate = config_struct.coding_rate;
                end
                
                % 设置跳频参数
                if isfield(config_struct, 'hopping_enabled')
                    obj.hopping_enabled = config_struct.hopping_enabled;
                end
                if isfield(config_struct, 'hopping_rate')
                    obj.hopping_rate = config_struct.hopping_rate;
                end
                if isfield(config_struct, 'frequency_set')
                    obj.frequency_set = config_struct.frequency_set;
                end
                
                % 设置信道参数
                if isfield(config_struct, 'channel_type')
                    obj.channel_type = config_struct.channel_type;
                end
                if isfield(config_struct, 'snr_db')
                    obj.snr_db = config_struct.snr_db;
                end
                
                % 设置滤波器参数
                if isfield(config_struct, 'pulse_shaping')
                    obj.pulse_shaping = config_struct.pulse_shaping;
                end
                if isfield(config_struct, 'filter_rolloff')
                    obj.filter_rolloff = config_struct.filter_rolloff;
                end
                
                % 设置仿真参数
                if isfield(config_struct, 'simulation_time')
                    obj.simulation_time = config_struct.simulation_time;
                end
                if isfield(config_struct, 'num_symbols')
                    obj.num_symbols = config_struct.num_symbols;
                end
                
                % 更新配置状态
                obj.is_configured = true;
                
                % 执行子类特定的配置
                obj.configure_specific(config_struct);
                
            catch ME
                error('WaveformBase:ConfigError', '配置失败: %s', ME.message);
            end
        end
        
        function signal = generate_signal(obj, data, varargin)
            % 生成调制信号
            % 输入: data - 输入数据
            %      varargin - 可选参数
            % 输出: signal - 调制后的信号
            
            if ~obj.is_configured
                error('WaveformBase:NotConfigured', '波形未配置，请先调用configure方法');
            end
            
            % 解析可选参数
            params = obj.parse_generation_params(varargin{:});
            
            % 调用子类的调制方法
            signal = obj.modulate(data, params);
            
            % 应用脉冲成形滤波
            if ~isempty(obj.pulse_shaping)
                signal = obj.apply_pulse_shaping(signal);
            end
            
            % 应用跳频
            if obj.hopping_enabled
                signal = obj.apply_frequency_hopping(signal);
            end
            
            % 保存生成的信号
            obj.last_generated_signal = signal;
        end
        
        function data = recover_data(obj, received_signal, varargin)
            % 从接收信号中恢复数据
            % 输入: received_signal - 接收到的信号
            %      varargin - 可选参数
            % 输出: data - 恢复的数据
            
            if ~obj.is_configured
                error('WaveformBase:NotConfigured', '波形未配置，请先调用configure方法');
            end
            
            % 解析可选参数
            params = obj.parse_recovery_params(varargin{:});
            
            % 逆跳频处理
            if obj.hopping_enabled
                received_signal = obj.reverse_frequency_hopping(received_signal);
            end
            
            % 匹配滤波
            if ~isempty(obj.pulse_shaping)
                received_signal = obj.apply_matched_filter(received_signal);
            end
            
            % 调用子类的解调方法
            data = obj.demodulate(received_signal, params);
        end
        
        function metrics = analyze_performance(obj, original_data, received_data)
            % 分析性能指标
            % 输入: original_data - 原始数据
            %      received_data - 接收数据
            % 输出: metrics - 性能指标结构体
            
            metrics = struct();
            
            % 计算误码率
            metrics.ber = obj.calculate_ber(original_data, received_data);
            
            % 计算符号错误率
            metrics.ser = obj.calculate_ser(original_data, received_data);
            
            % 计算频谱效率
            metrics.spectral_efficiency = obj.data_rate / obj.bandwidth;
            
            % 计算功率效率
            if ~isempty(obj.last_generated_signal)
                metrics.power_efficiency = obj.calculate_power_efficiency();
            end
            
            % 保存性能指标
            obj.performance_metrics = metrics;
        end
        
        function plot_spectrum(obj, signal, varargin)
            % 绘制信号频谱
            % 输入: signal - 信号
            %      varargin - 可选参数
            
            if nargin < 2
                if isempty(obj.last_generated_signal)
                    error('WaveformBase:NoSignal', '没有可用的信号进行频谱分析');
                end
                signal = obj.last_generated_signal;
            end
            
            % 获取频谱
            spectrum = obj.get_spectrum(signal, varargin{:});
            
            % 绘制频谱图
            figure;
            plot(spectrum.frequencies, 10*log10(spectrum.power_density));
            xlabel('频率 (Hz)');
            ylabel('功率谱密度 (dB/Hz)');
            title(sprintf('%s 功率谱密度', obj.WAVEFORM_NAME));
            grid on;
        end
        
        function config = get_config(obj)
            % 获取当前配置
            % 输出: config - 配置结构体
            
            config = struct();
            config.waveform_id = obj.WAVEFORM_ID;
            config.waveform_name = obj.WAVEFORM_NAME;
            config.modulation_type = obj.MODULATION_TYPE;
            config.category = obj.CATEGORY;
            config.center_frequency = obj.center_frequency;
            config.bandwidth = obj.bandwidth;
            config.data_rate = obj.data_rate;
            config.sample_rate = obj.sample_rate;
            config.symbol_rate = obj.symbol_rate;
            config.modulation_order = obj.modulation_order;
            config.coding_scheme = obj.coding_scheme;
            config.coding_rate = obj.coding_rate;
            config.hopping_enabled = obj.hopping_enabled;
            config.hopping_rate = obj.hopping_rate;
            config.frequency_set = obj.frequency_set;
            config.channel_type = obj.channel_type;
            config.snr_db = obj.snr_db;
            config.pulse_shaping = obj.pulse_shaping;
            config.filter_rolloff = obj.filter_rolloff;
            config.simulation_time = obj.simulation_time;
            config.num_symbols = obj.num_symbols;
            config.is_configured = obj.is_configured;
        end
    end
    
    methods (Access = protected)
        function initialize_default_params(obj)
            % 初始化默认参数
            obj.center_frequency = 1e9;      % 1 GHz
            obj.bandwidth = 1e6;             % 1 MHz
            obj.data_rate = 1e6;             % 1 Mbps
            obj.sample_rate = 10e6;          % 10 MHz
            obj.symbol_rate = 1e6;           % 1 Msps
            obj.modulation_order = 2;        % 二进制
            obj.coding_scheme = 'none';      % 无编码
            obj.coding_rate = 1;             % 编码率1
            obj.hopping_enabled = false;     % 不启用跳频
            obj.hopping_rate = 0;            % 跳频速率0
            obj.frequency_set = [];          % 空频点集
            obj.hop_sequence = [];           % 空跳频序列
            obj.channel_type = 'AWGN';       % AWGN信道
            obj.snr_db = 10;                 % 10dB信噪比
            obj.pulse_shaping = 'none';      % 无脉冲成形
            obj.filter_rolloff = 0.35;       % 滚降因子0.35
            obj.simulation_time = 1e-3;      % 1ms仿真时长
            obj.num_symbols = 1000;          % 1000个符号
            obj.performance_metrics = struct();
        end
        
        function validate_config(obj, config_struct)
            % 验证配置参数的有效性
            % 输入: config_struct - 配置结构体
            
            % 验证频率参数
            if isfield(config_struct, 'center_frequency')
                if config_struct.center_frequency <= 0
                    error('WaveformBase:InvalidParam', '中心频率必须大于0');
                end
            end
            
            if isfield(config_struct, 'bandwidth')
                if config_struct.bandwidth <= 0
                    error('WaveformBase:InvalidParam', '带宽必须大于0');
                end
            end
            
            if isfield(config_struct, 'sample_rate')
                if config_struct.sample_rate <= 0
                    error('WaveformBase:InvalidParam', '采样率必须大于0');
                end
                if isfield(config_struct, 'bandwidth')
                    if config_struct.sample_rate < 2 * config_struct.bandwidth
                        warning('WaveformBase:SamplingRate', '采样率可能不满足奈奎斯特定理');
                    end
                end
            end
            
            % 验证调制参数
            if isfield(config_struct, 'modulation_order')
                if config_struct.modulation_order < 2 || ...
                   mod(log2(config_struct.modulation_order), 1) ~= 0
                    error('WaveformBase:InvalidParam', '调制阶数必须是2的幂次');
                end
            end
            
            % 验证跳频参数
            if isfield(config_struct, 'hopping_rate')
                if config_struct.hopping_rate < 0
                    error('WaveformBase:InvalidParam', '跳频速率不能为负数');
                end
            end
            
            % 验证信噪比
            if isfield(config_struct, 'snr_db')
                if config_struct.snr_db < -50 || config_struct.snr_db > 50
                    warning('WaveformBase:SNR', '信噪比超出常见范围(-50dB到50dB)');
                end
            end
        end
        
        function configure_specific(obj, config_struct)
            % 子类特定的配置方法（可选重写）
            % 输入: config_struct - 配置结构体
            
            % 默认实现为空，子类可以重写此方法
        end
        
        function params = parse_generation_params(obj, varargin)
            % 解析信号生成参数
            % 输入: varargin - 可变参数
            % 输出: params - 参数结构体
            
            p = inputParser;
            addParameter(p, 'add_noise', true, @islogical);
            addParameter(p, 'normalize', true, @islogical);
            addParameter(p, 'phase_offset', 0, @isnumeric);
            addParameter(p, 'amplitude', 1, @isnumeric);
            
            parse(p, varargin{:});
            params = p.Results;
        end
        
        function params = parse_recovery_params(obj, varargin)
            % 解析数据恢复参数
            % 输入: varargin - 可变参数
            % 输出: params - 参数结构体
            
            p = inputParser;
            addParameter(p, 'timing_recovery', true, @islogical);
            addParameter(p, 'carrier_recovery', true, @islogical);
            addParameter(p, 'equalization', false, @islogical);
            
            parse(p, varargin{:});
            params = p.Results;
        end
        
        function ser = calculate_ser(obj, original_data, received_data)
            % 计算符号错误率
            % 输入: original_data - 原始数据
            %      received_data - 接收数据
            % 输出: ser - 符号错误率
            
            if length(original_data) ~= length(received_data)
                error('WaveformBase:DataLengthMismatch', '数据长度不匹配');
            end
            
            symbol_errors = sum(original_data ~= received_data);
            ser = symbol_errors / length(original_data);
        end
        
        function efficiency = calculate_power_efficiency(obj)
            % 计算功率效率
            % 输出: efficiency - 功率效率
            
            if isempty(obj.last_generated_signal)
                efficiency = 0;
                return;
            end
            
            signal_power = mean(abs(obj.last_generated_signal).^2);
            peak_power = max(abs(obj.last_generated_signal).^2);
            efficiency = signal_power / peak_power;  % PAPR的倒数
        end
        
        function filtered_signal = apply_pulse_shaping(obj, signal)
            % 应用脉冲成形滤波
            % 输入: signal - 输入信号
            % 输出: filtered_signal - 滤波后的信号
            
            switch obj.pulse_shaping
                case 'rrc'
                    % 根升余弦滤波器
                    filtered_signal = obj.apply_rrc_filter(signal);
                case 'gaussian'
                    % 高斯滤波器
                    filtered_signal = obj.apply_gaussian_filter(signal);
                case 'rectangular'
                    % 矩形滤波器
                    filtered_signal = obj.apply_rectangular_filter(signal);
                otherwise
                    filtered_signal = signal;
            end
        end
        
        function filtered_signal = apply_matched_filter(obj, signal)
            % 应用匹配滤波器
            % 输入: signal - 输入信号
            % 输出: filtered_signal - 滤波后的信号
            
            % 匹配滤波器是发送滤波器的时间反转共轭
            filtered_signal = obj.apply_pulse_shaping(signal);
        end
        
        function hopped_signal = apply_frequency_hopping(obj, signal)
            % 应用跳频
            % 输入: signal - 输入信号
            % 输出: hopped_signal - 跳频后的信号
            
            if isempty(obj.hop_sequence)
                obj.generate_hop_sequence();
            end
            
            hopped_signal = signal;  % 默认实现，子类可重写
        end
        
        function signal = reverse_frequency_hopping(obj, hopped_signal)
            % 逆跳频处理
            % 输入: hopped_signal - 跳频信号
            % 输出: signal - 逆跳频后的信号
            
            signal = hopped_signal;  % 默认实现，子类可重写
        end
        
        function generate_hop_sequence(obj)
            % 生成跳频序列
            
            if isempty(obj.frequency_set)
                error('WaveformBase:NoFrequencySet', '未设置频点集');
            end
            
            % 简单的伪随机跳频序列
            num_hops = ceil(obj.simulation_time * obj.hopping_rate);
            obj.hop_sequence = obj.frequency_set(randi(length(obj.frequency_set), 1, num_hops));
        end
        
        function filtered_signal = apply_rrc_filter(obj, signal)
            % 应用根升余弦滤波器
            filtered_signal = signal;  % 简化实现，实际需要设计RRC滤波器
        end
        
        function filtered_signal = apply_gaussian_filter(obj, signal)
            % 应用高斯滤波器
            filtered_signal = signal;  % 简化实现，实际需要设计高斯滤波器
        end
        
        function filtered_signal = apply_rectangular_filter(obj, signal)
            % 应用矩形滤波器
            filtered_signal = signal;  % 简化实现
        end
    end
end
