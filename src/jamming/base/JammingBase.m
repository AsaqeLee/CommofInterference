classdef (Abstract) JammingBase < handle
    % JammingBase - 干扰信号基类
    % 定义所有干扰信号的通用接口和基础功能
    %
    % 作者: Asaqe Lee
    % 日期: 2025-06-20
    
    properties (Abstract, Constant)
        JAMMING_ID          % 干扰信号ID
        JAMMING_NAME        % 干扰信号名称
        JAMMING_TYPE        % 干扰类型
        CATEGORY            % 干扰类别
    end
    
    properties (Access = protected)
        % 基础参数
        center_frequency    % 中心频率 (Hz)
        bandwidth          % 带宽 (Hz)
        power_dbm          % 功率 (dBm)
        sample_rate        % 采样率 (Hz)
        duration           % 持续时间 (s)
        
        % 控制参数
        is_active          % 是否激活
        start_time         % 开始时间
        stop_time          % 结束时间
        
        % 性能参数
        jamming_effectiveness  % 干扰效果
        power_efficiency      % 功率效率
        
        % 内部状态
        current_phase      % 当前相位
        internal_state     % 内部状态
    end
    
    properties (Dependent)
        % 计算属性
        power_watts        % 功率 (W)
        frequency_range    % 频率范围
        time_range         % 时间范围
    end
    
    methods (Abstract)
        % 抽象方法 - 子类必须实现
        signal = generate_jamming_signal(obj, target_signal, params)
        effectiveness = calculate_effectiveness(obj, target_signal, jammed_signal)
        obj = configure_parameters(obj, config)
    end
    
    methods
        function obj = JammingBase()
            % 构造函数
            obj.initialize_default_parameters();
        end
        
        function power_w = get.power_watts(obj)
            % 获取功率(瓦特)
            power_w = 10^((obj.power_dbm - 30) / 10);
        end
        
        function freq_range = get.frequency_range(obj)
            % 获取频率范围
            freq_range = [obj.center_frequency - obj.bandwidth/2, ...
                         obj.center_frequency + obj.bandwidth/2];
        end
        
        function time_range = get.time_range(obj)
            % 获取时间范围
            time_range = [obj.start_time, obj.stop_time];
        end
        
        function obj = set_power_dbm(obj, power_dbm)
            % 设置功率(dBm)
            obj.power_dbm = power_dbm;
        end
        
        function obj = set_frequency(obj, center_freq, bandwidth)
            % 设置频率参数
            obj.center_frequency = center_freq;
            if nargin > 2
                obj.bandwidth = bandwidth;
            end
        end
        
        function obj = set_timing(obj, start_time, duration)
            % 设置时序参数
            obj.start_time = start_time;
            obj.duration = duration;
            obj.stop_time = start_time + duration;
        end
        
        function obj = activate(obj)
            % 激活干扰信号
            obj.is_active = true;
        end
        
        function obj = deactivate(obj)
            % 停用干扰信号
            obj.is_active = false;
        end
        
        function is_in_range = check_frequency_overlap(obj, target_freq, target_bw)
            % 检查频率重叠
            target_range = [target_freq - target_bw/2, target_freq + target_bw/2];
            jamming_range = obj.frequency_range;
            
            % 检查是否有重叠
            is_in_range = ~(target_range(2) < jamming_range(1) || ...
                           target_range(1) > jamming_range(2));
        end
        
        function is_active_now = check_time_active(obj, current_time)
            % 检查当前时间是否激活
            is_active_now = obj.is_active && ...
                           current_time >= obj.start_time && ...
                           current_time <= obj.stop_time;
        end
        
        function sir_db = calculate_sir(obj, signal_power, jamming_power)
            % 计算信干比
            % 输入: signal_power - 信号功率
            %      jamming_power - 干扰功率
            % 输出: sir_db - 信干比(dB)
            
            if jamming_power <= 0
                sir_db = inf;
            else
                sir_db = 10 * log10(signal_power / jamming_power);
            end
        end
        
        function adjusted_power = adjust_power_for_sir(obj, signal_power, target_sir_db)
            % 根据目标信干比调整干扰功率
            % 输入: signal_power - 信号功率
            %      target_sir_db - 目标信干比(dB)
            % 输出: adjusted_power - 调整后的干扰功率
            
            target_sir_linear = 10^(target_sir_db / 10);
            adjusted_power = signal_power / target_sir_linear;
        end
        
        function noisy_signal = add_awgn_noise(obj, signal, snr_db)
            % 添加AWGN噪声
            % 输入: signal - 原始信号
            %      snr_db - 信噪比(dB)
            % 输出: noisy_signal - 加噪后的信号
            
            signal_power = mean(abs(signal).^2);
            snr_linear = 10^(snr_db/10);
            noise_power = signal_power / snr_linear;
            
            % 生成复高斯噪声
            noise = sqrt(noise_power/2) * (randn(size(signal)) + 1j*randn(size(signal)));
            noisy_signal = signal + noise;
        end
        
        function config = get_configuration(obj)
            % 获取当前配置
            config = struct();
            config.jamming_id = obj.JAMMING_ID;
            config.jamming_name = obj.JAMMING_NAME;
            config.jamming_type = obj.JAMMING_TYPE;
            config.category = obj.CATEGORY;
            config.center_frequency = obj.center_frequency;
            config.bandwidth = obj.bandwidth;
            config.power_dbm = obj.power_dbm;
            config.sample_rate = obj.sample_rate;
            config.duration = obj.duration;
            config.is_active = obj.is_active;
        end
        
        function obj = load_configuration(obj, config)
            % 加载配置
            if isfield(config, 'center_frequency')
                obj.center_frequency = config.center_frequency;
            end
            if isfield(config, 'bandwidth')
                obj.bandwidth = config.bandwidth;
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
            if isfield(config, 'is_active')
                obj.is_active = config.is_active;
            end
        end
        
        function print_status(obj)
            % 打印干扰信号状态
            fprintf('=== %s 状态 ===\n', obj.JAMMING_NAME);
            fprintf('ID: %d\n', obj.JAMMING_ID);
            fprintf('类型: %s\n', obj.JAMMING_TYPE);
            fprintf('类别: %s\n', obj.CATEGORY);
            fprintf('中心频率: %.2f MHz\n', obj.center_frequency / 1e6);
            fprintf('带宽: %.2f MHz\n', obj.bandwidth / 1e6);
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
            obj.center_frequency = 100e6;    % 100 MHz
            obj.bandwidth = 10e6;             % 10 MHz
            obj.power_dbm = 0;                % 0 dBm
            obj.sample_rate = 100e6;          % 100 MHz
            obj.duration = 1.0;               % 1 second
            obj.is_active = false;
            obj.start_time = 0;
            obj.stop_time = obj.duration;
            obj.current_phase = 0;
            obj.internal_state = struct();
        end
        
        function value = get_param_value(obj, params, param_name, default_value)
            % 获取参数值（带默认值）
            if isfield(params, param_name)
                value = params.(param_name);
            else
                value = default_value;
            end
        end
        
        function validate_parameters(obj)
            % 验证参数有效性
            assert(obj.center_frequency > 0, 'JammingBase:InvalidFreq', '中心频率必须大于0');
            assert(obj.bandwidth > 0, 'JammingBase:InvalidBW', '带宽必须大于0');
            assert(obj.sample_rate > 0, 'JammingBase:InvalidSR', '采样率必须大于0');
            assert(obj.duration > 0, 'JammingBase:InvalidDur', '持续时间必须大于0');
            assert(obj.sample_rate >= 2 * obj.bandwidth, 'JammingBase:Nyquist', ...
                   '采样率必须满足奈奎斯特定理');
        end
    end
end
