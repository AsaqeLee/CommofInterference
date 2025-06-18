classdef PM < WaveformBase
    % PM - 相位调制 (Phase Modulation)
    % 实现模拟相位调制的调制和解调功能
    %
    % 作者: Asaqe Lee
    % 日期: 2025-06-18
    
    properties (Constant)
        WAVEFORM_ID = 53        % 波形ID
        WAVEFORM_NAME = 'PM'    % 波形名称
        MODULATION_TYPE = 'PM'  % 调制类型
        CATEGORY = 'analog'     % 波形类别
    end
    
    properties (Access = private)
        % PM特有参数
        phase_deviation        % 相位偏移 (弧度)
        modulation_index      % 调制指数
        baseband_bandwidth    % 基带带宽 (Hz)
        carrier_amplitude     % 载波幅度
        
        % 滤波器参数
        differentiator_filter % 微分器滤波器
        integrator_filter     % 积分器滤波器
        
        % 内部状态
        last_phase           % 上一个相位值
        phase_accumulator    % 相位累加器
    end
    
    methods
        function obj = PM()
            % 构造函数
            obj@WaveformBase();
            obj.initialize_pm_params();
        end
        
        function signal = modulate(obj, data, params)
            % PM调制
            % 输入: data - 调制信号 (基带信号)
            %      params - 调制参数
            % 输出: signal - PM调制信号
            
            % 验证输入
            if isempty(data)
                error('PM:EmptyData', '输入数据不能为空');
            end
            
            % 确保数据为列向量
            if isrow(data)
                data = data(:);
            end
            
            % 归一化调制信号
            data = data / max(abs(data));
            
            % 生成时间向量
            t = (0:length(data)-1)' / obj.sample_rate;
            
            % 计算瞬时相位
            instantaneous_phase = 2*pi*obj.center_frequency*t + obj.phase_deviation * data;
            
            % 生成PM信号
            signal = obj.carrier_amplitude * cos(instantaneous_phase);
            
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
            % PM解调
            % 输入: signal - PM调制信号
            %      params - 解调参数
            % 输出: data - 解调后的基带信号
            
            % 验证输入
            if isempty(signal)
                error('PM:EmptySignal', '输入信号不能为空');
            end
            
            % 确保信号为列向量
            if isrow(signal)
                signal = signal(:);
            end
            
            % 选择解调方法
            if isfield(params, 'demod_method')
                demod_method = params.demod_method;
            else
                demod_method = 'phase_detector';  % 默认使用相位检测器
            end
            
            switch demod_method
                case 'phase_detector'
                    % 相位检测器解调
                    data = obj.phase_detector(signal);
                    
                case 'hilbert'
                    % 希尔伯特变换解调
                    data = obj.hilbert_demodulator(signal);
                    
                case 'differential'
                    % 差分解调
                    data = obj.differential_demodulator(signal);
                    
                otherwise
                    error('PM:InvalidDemodMethod', '不支持的解调方法: %s', demod_method);
            end
            
            % 去除直流分量
            data = data - mean(data);
            
            % 归一化
            if max(abs(data)) > 0
                data = data / max(abs(data));
            end
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
            spectrum.bandwidth = obj.calculate_pm_bandwidth();
        end
        
        function info = get_waveform_info(obj)
            % 获取波形信息
            % 输出: info - 波形信息结构体
            
            info = struct();
            info.waveform_id = obj.WAVEFORM_ID;
            info.waveform_name = obj.WAVEFORM_NAME;
            info.modulation_type = obj.MODULATION_TYPE;
            info.category = obj.CATEGORY;
            info.phase_deviation = obj.phase_deviation;
            info.modulation_index = obj.modulation_index;
            info.carrier_amplitude = obj.carrier_amplitude;
            info.baseband_bandwidth = obj.baseband_bandwidth;
            info.pm_bandwidth = obj.calculate_pm_bandwidth();
        end
    end
    
    methods (Access = private)
        function initialize_pm_params(obj)
            % 初始化PM特有参数
            obj.phase_deviation = pi/2;         % π/2弧度相位偏移
            obj.modulation_index = obj.phase_deviation;
            obj.baseband_bandwidth = 5e3;       % 5 kHz基带带宽
            obj.carrier_amplitude = 1.0;        % 载波幅度
            obj.last_phase = 0;
            obj.phase_accumulator = 0;
            
            % 初始化滤波器
            obj.initialize_filters();
        end
        
        function initialize_filters(obj)
            % 初始化微分器和积分器滤波器
            
            % 设计微分器滤波器（用于PM到FM转换）
            % 简单的差分滤波器
            obj.differentiator_filter = {[1, -1], [1]};
            
            % 设计积分器滤波器（用于FM到PM转换）
            % 简单的累积滤波器
            obj.integrator_filter = {[1], [1, -1]};
        end
        
        function data = phase_detector(obj, signal)
            % 相位检测器解调
            % 输入: signal - PM信号
            % 输出: data - 解调后的基带信号
            
            % 计算解析信号
            analytic_signal = hilbert(signal);
            
            % 提取瞬时相位
            instantaneous_phase = unwrap(angle(analytic_signal));
            
            % 去除载波相位
            t = (0:length(signal)-1)' / obj.sample_rate;
            carrier_phase = 2*pi*obj.center_frequency*t;
            
            % 提取调制相位
            modulation_phase = instantaneous_phase - carrier_phase;
            
            % 归一化到相位偏移范围
            data = modulation_phase / obj.phase_deviation;
        end
        
        function data = hilbert_demodulator(obj, signal)
            % 希尔伯特变换解调器
            % 输入: signal - PM信号
            % 输出: data - 解调后的基带信号
            
            % 计算解析信号
            analytic_signal = hilbert(signal);
            
            % 计算瞬时相位
            instantaneous_phase = unwrap(angle(analytic_signal));
            
            % 计算瞬时频率（相位的导数）
            dt = 1 / obj.sample_rate;
            instantaneous_freq = diff(instantaneous_phase) / dt;
            
            % 补齐长度
            instantaneous_freq = [instantaneous_freq; instantaneous_freq(end)];
            
            % 去除载波频率
            carrier_freq = 2*pi*obj.center_frequency;
            modulation_freq = instantaneous_freq - carrier_freq;
            
            % 积分得到相位调制信号
            data = cumsum(modulation_freq) * dt;
            
            % 归一化
            data = data / obj.phase_deviation;
        end
        
        function data = differential_demodulator(obj, signal)
            % 差分解调器
            % 输入: signal - PM信号
            % 输出: data - 解调后的基带信号
            
            % 计算相邻样本的相位差
            signal_delayed = [signal(2:end); signal(end)];
            
            % 计算瞬时相位差
            phase_diff = angle(signal .* conj(signal_delayed));
            
            % 去除载波相位差
            dt = 1 / obj.sample_rate;
            carrier_phase_diff = 2*pi*obj.center_frequency*dt;
            
            % 提取调制相位差
            modulation_phase_diff = phase_diff - carrier_phase_diff;
            
            % 积分得到相位调制信号
            data = cumsum(modulation_phase_diff);
            
            % 归一化
            data = data / obj.phase_deviation;
        end
        
        function bandwidth = calculate_pm_bandwidth(obj)
            % 计算PM信号带宽（Carson规则）
            % 输出: bandwidth - PM信号带宽
            
            % Carson规则: BW = 2 * (相位偏移 + 基带带宽)
            % 对于PM，相位偏移以频率单位表示
            max_freq_deviation = obj.phase_deviation * obj.baseband_bandwidth;
            bandwidth = 2 * (max_freq_deviation + obj.baseband_bandwidth);
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
            % PM特定的配置方法
            % 输入: config_struct - 配置结构体
            
            if isfield(config_struct, 'phase_deviation')
                obj.phase_deviation = config_struct.phase_deviation;
                obj.modulation_index = obj.phase_deviation;
            end
            
            if isfield(config_struct, 'modulation_index')
                obj.modulation_index = config_struct.modulation_index;
                obj.phase_deviation = obj.modulation_index;
            end
            
            if isfield(config_struct, 'carrier_amplitude')
                obj.carrier_amplitude = config_struct.carrier_amplitude;
            end
            
            if isfield(config_struct, 'baseband_bandwidth')
                obj.baseband_bandwidth = config_struct.baseband_bandwidth;
            end
            
            % 重新初始化滤波器
            obj.initialize_filters();
        end
        
        function params = parse_recovery_params(obj, varargin)
            % 重写基类方法，添加PM特有的解调参数
            % 输入: varargin - 可变参数
            % 输出: params - 参数结构体
            
            p = inputParser;
            addParameter(p, 'timing_recovery', true, @islogical);
            addParameter(p, 'carrier_recovery', true, @islogical);
            addParameter(p, 'equalization', false, @islogical);
            addParameter(p, 'demod_method', 'phase_detector', @ischar);  % PM特有参数
            
            parse(p, varargin{:});
            params = p.Results;
        end
    end
end
