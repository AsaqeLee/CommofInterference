classdef FM < WaveformBase
    % FM - 频率调制 (Frequency Modulation)
    % 实现模拟频率调制的调制和解调功能
    %
    % 作者: Asaqe Lee
    % 日期: 2025-06-18
    
    properties (Constant)
        WAVEFORM_ID = 51        % 波形ID
        WAVEFORM_NAME = 'FM'    % 波形名称
        MODULATION_TYPE = 'FM'  % 调制类型
        CATEGORY = 'analog'     % 波形类别
    end
    
    properties (Access = private)
        % FM特有参数
        frequency_deviation     % 频偏 (Hz)
        modulation_index       % 调制指数
        baseband_bandwidth     % 基带带宽 (Hz)
        preemphasis_enabled    % 是否启用预加重
        deemphasis_enabled     % 是否启用去加重
        
        % 滤波器参数
        preemphasis_filter     % 预加重滤波器
        deemphasis_filter      % 去加重滤波器
        
        % 内部状态
        phase_accumulator      % 相位累加器
        last_phase            % 上一个相位值
    end
    
    methods
        function obj = FM()
            % 构造函数
            obj@WaveformBase();
            obj.initialize_fm_params();
        end
        
        function signal = modulate(obj, data, params)
            % FM调制
            % 输入: data - 调制信号 (基带信号)
            %      params - 调制参数
            % 输出: signal - FM调制信号
            
            % 验证输入
            if isempty(data)
                error('FM:EmptyData', '输入数据不能为空');
            end
            
            % 确保数据为列向量
            if isrow(data)
                data = data(:);
            end
            
            % 应用预加重滤波
            if obj.preemphasis_enabled && ~isempty(obj.preemphasis_filter)
                data = filter(obj.preemphasis_filter{1}, obj.preemphasis_filter{2}, data);
            end
            
            % 限制调制信号幅度以防止过调制
            max_amplitude = obj.frequency_deviation / (2 * pi * max(abs(data)));
            if max_amplitude < 1
                warning('FM:Overmodulation', '可能发生过调制，建议减小调制信号幅度或增大频偏');
            end
            
            % 计算瞬时频率
            instantaneous_freq = obj.center_frequency + obj.frequency_deviation * data;
            
            % 计算瞬时相位（相位是频率的积分）
            dt = 1 / obj.sample_rate;
            instantaneous_phase = 2 * pi * cumsum(instantaneous_freq) * dt;
            
            % 生成FM信号
            signal = cos(instantaneous_phase);
            
            % 应用幅度参数
            if isfield(params, 'amplitude')
                signal = params.amplitude * signal;
            end
            
            % 添加噪声
            if isfield(params, 'add_noise') && params.add_noise
                signal = obj.add_awgn_noise(signal);
            end
            
            % 归一化
            if isfield(params, 'normalize') && params.normalize
                signal = signal / max(abs(signal));
            end
        end
        
        function data = demodulate(obj, signal, params)
            % FM解调
            % 输入: signal - FM调制信号
            %      params - 解调参数
            % 输出: data - 解调后的基带信号
            
            % 验证输入
            if isempty(signal)
                error('FM:EmptySignal', '输入信号不能为空');
            end
            
            % 确保信号为列向量
            if isrow(signal)
                signal = signal(:);
            end
            
            % 方法1: 鉴频器解调（基于相位差分）
            data = obj.frequency_discriminator(signal);
            
            % 方法2: 可选择使用希尔伯特变换解调
            if isfield(params, 'demod_method') && strcmp(params.demod_method, 'hilbert')
                data = obj.hilbert_demodulator(signal);
            end

            % 方法3: 可选择使用改进的PLL解调
            if isfield(params, 'demod_method') && strcmp(params.demod_method, 'pll')
                data = obj.pll_demodulator(signal);
            end
            
            % 应用去加重滤波
            if obj.deemphasis_enabled && ~isempty(obj.deemphasis_filter)
                data = filter(obj.deemphasis_filter{1}, obj.deemphasis_filter{2}, data);
            end
            
            % 去除直流分量
            data = data - mean(data);
        end
        
        function ber = calculate_ber(obj, original_data, received_data)
            % 计算误码率（对于模拟调制，计算均方误差）
            % 输入: original_data - 原始数据
            %      received_data - 接收数据
            % 输出: ber - 误码率（这里用MSE表示）
            
            % 对于模拟调制，使用均方误差作为性能指标
            if length(original_data) ~= length(received_data)
                % 长度不匹配时，截取较短的长度
                min_len = min(length(original_data), length(received_data));
                original_data = original_data(1:min_len);
                received_data = received_data(1:min_len);
            end
            
            % 归一化数据
            original_data = original_data / max(abs(original_data));
            received_data = received_data / max(abs(received_data));
            
            % 计算均方误差
            mse = mean((original_data - received_data).^2);
            
            % 转换为类似BER的指标（0-1之间）
            ber = min(mse, 1);
        end
        
        function spectrum = get_spectrum(obj, signal, params)
            % 获取信号频谱
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
            frequencies = (-N/2:N/2-1) * (obj.sample_rate/N) + obj.center_frequency;
            
            % 功率谱密度
            power_density = abs(fftshift(Y)).^2 / (obj.sample_rate * N);
            
            % 构造输出结构体
            spectrum = struct();
            spectrum.frequencies = frequencies;
            spectrum.power_density = power_density;
            spectrum.bandwidth = obj.calculate_fm_bandwidth();
        end
        
        function info = get_waveform_info(obj)
            % 获取波形信息
            % 输出: info - 波形信息结构体
            
            info = struct();
            info.waveform_id = obj.WAVEFORM_ID;
            info.waveform_name = obj.WAVEFORM_NAME;
            info.modulation_type = obj.MODULATION_TYPE;
            info.category = obj.CATEGORY;
            info.frequency_deviation = obj.frequency_deviation;
            info.modulation_index = obj.modulation_index;
            info.baseband_bandwidth = obj.baseband_bandwidth;
            info.fm_bandwidth = obj.calculate_fm_bandwidth();
            info.preemphasis_enabled = obj.preemphasis_enabled;
            info.deemphasis_enabled = obj.deemphasis_enabled;
        end
    end
    
    methods (Access = private)
        function initialize_fm_params(obj)
            % 初始化FM特有参数（优化版本）
            obj.frequency_deviation = 5e3;       % 5 kHz (适合测试的频偏)
            obj.baseband_bandwidth = 2e3;        % 2 kHz (基带带宽)
            obj.modulation_index = obj.frequency_deviation / obj.baseband_bandwidth;
            obj.preemphasis_enabled = false;     % 暂时禁用预加重（简化测试）
            obj.deemphasis_enabled = true;       % 启用去加重滤波
            obj.phase_accumulator = 0;
            obj.last_phase = 0;

            % 初始化滤波器
            obj.initialize_filters();
        end
        
        function initialize_filters(obj)
            % 初始化预加重和去加重滤波器（优化版本）

            % 预加重滤波器 (75μs时间常数)
            tau_pre = 75e-6;  % 75微秒
            fc_pre = 1 / (2 * pi * tau_pre);  % 截止频率

            % 设计一阶高通滤波器作为预加重
            if fc_pre < obj.sample_rate/2
                [b_pre, a_pre] = butter(1, fc_pre/(obj.sample_rate/2), 'high');
                obj.preemphasis_filter = {b_pre, a_pre};
            else
                obj.preemphasis_filter = [];
            end

            % 去加重滤波器 - 使用基带带宽作为截止频率
            fc_de = obj.baseband_bandwidth;
            if fc_de < obj.sample_rate/2
                [b_de, a_de] = butter(4, fc_de/(obj.sample_rate/2), 'low');  % 4阶低通
                obj.deemphasis_filter = {b_de, a_de};
            else
                obj.deemphasis_filter = [];
            end
        end
        
        function data = frequency_discriminator(obj, signal)
            % 鉴频器解调（经典版本）
            % 输入: signal - FM信号
            % 输出: data - 解调后的基带信号

            % 基于相位差分的鉴频器
            signal_delayed = [signal(2:end); signal(end)];

            % 计算瞬时频率
            phase_diff = angle(signal .* conj(signal_delayed));
            instantaneous_freq = phase_diff * obj.sample_rate / (2 * pi);

            % 去除直流分量
            data = instantaneous_freq - mean(instantaneous_freq);

            % 归一化
            data = data / obj.frequency_deviation;
        end
        
        function data = hilbert_demodulator(obj, signal)
            % 希尔伯特变换解调器（经典版本）
            % 输入: signal - FM信号
            % 输出: data - 解调后的基带信号

            % 计算解析信号
            analytic_signal = hilbert(signal);
            instantaneous_phase = unwrap(angle(analytic_signal));

            % 计算瞬时频率
            instantaneous_freq = diff(instantaneous_phase) * obj.sample_rate / (2*pi);

            % 补齐长度
            instantaneous_freq = [instantaneous_freq; instantaneous_freq(end)];

            % 去除载波频率
            data = instantaneous_freq - obj.center_frequency;

            % 归一化
            data = data / obj.frequency_deviation;
        end

        function data = pll_demodulator(obj, signal)
            % PLL锁相环解调器（优化版本）
            % 输入: signal - FM信号
            % 输出: data - 解调后的基带信号

            % PLL参数
            loop_bandwidth = obj.baseband_bandwidth * 2;  % 环路带宽
            damping_factor = 0.707;  % 阻尼因子

            % 计算环路滤波器参数
            wn = loop_bandwidth;
            K1 = 2 * damping_factor * wn;
            K2 = wn^2;

            % 初始化PLL状态
            phase_error = 0;
            vco_phase = 0;
            integrator = 0;

            dt = 1 / obj.sample_rate;
            N = length(signal);
            data = zeros(N, 1);

            for i = 1:N
                % 相位检测器
                vco_output = cos(vco_phase);
                phase_error = signal(i) * (-sin(vco_phase));

                % 环路滤波器（二阶）
                integrator = integrator + K2 * phase_error * dt;
                vco_freq = K1 * phase_error + integrator;

                % VCO
                vco_phase = vco_phase + 2 * pi * (obj.center_frequency + vco_freq) * dt;

                % 输出频率偏移
                data(i) = vco_freq;
            end

            % 应用低通滤波
            if ~isempty(obj.deemphasis_filter)
                data = filter(obj.deemphasis_filter{1}, obj.deemphasis_filter{2}, data);
            end

            % 去除直流分量
            data = data - mean(data);

            % 归一化
            if max(abs(data)) > 0
                data = data / max(abs(data));
            end
        end

        function bandwidth = calculate_fm_bandwidth(obj)
            % 计算FM信号带宽（Carson规则）
            % 输出: bandwidth - FM信号带宽
            
            % Carson规则: BW = 2 * (频偏 + 基带带宽)
            bandwidth = 2 * (obj.frequency_deviation + obj.baseband_bandwidth);
        end
        
        function noisy_signal = add_awgn_noise(obj, signal)
            % 添加AWGN噪声
            % 输入: signal - 输入信号
            % 输出: noisy_signal - 加噪后的信号
            
            signal_power = mean(abs(signal).^2);
            noise_power = signal_power / (10^(obj.snr_db/10));
            noise = sqrt(noise_power/2) * (randn(size(signal)) + 1j*randn(size(signal)));
            noisy_signal = signal + real(noise);
        end
    end
    
    methods (Access = protected)
        function configure_specific(obj, config_struct)
            % FM特定的配置方法
            % 输入: config_struct - 配置结构体

            if isfield(config_struct, 'frequency_deviation')
                obj.frequency_deviation = config_struct.frequency_deviation;
            end

            if isfield(config_struct, 'baseband_bandwidth')
                obj.baseband_bandwidth = config_struct.baseband_bandwidth;
            end

            if isfield(config_struct, 'modulation_index')
                obj.modulation_index = config_struct.modulation_index;
            else
                % 根据频偏和基带带宽计算调制指数
                obj.modulation_index = obj.frequency_deviation / obj.baseband_bandwidth;
            end

            if isfield(config_struct, 'preemphasis_enabled')
                obj.preemphasis_enabled = config_struct.preemphasis_enabled;
            end

            if isfield(config_struct, 'deemphasis_enabled')
                obj.deemphasis_enabled = config_struct.deemphasis_enabled;
            end

            % 重新初始化滤波器
            obj.initialize_filters();
        end

        function params = parse_recovery_params(obj, varargin)
            % 重写基类方法，添加FM特有的解调参数
            % 输入: varargin - 可变参数
            % 输出: params - 参数结构体

            p = inputParser;
            addParameter(p, 'timing_recovery', true, @islogical);
            addParameter(p, 'carrier_recovery', true, @islogical);
            addParameter(p, 'equalization', false, @islogical);
            addParameter(p, 'demod_method', 'hilbert', @ischar);  % FM特有参数（默认希尔伯特）

            parse(p, varargin{:});
            params = p.Results;
        end
    end
end
