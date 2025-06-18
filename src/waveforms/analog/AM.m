classdef AM < WaveformBase
    % AM - 幅度调制 (Amplitude Modulation)
    % 实现模拟幅度调制的调制和解调功能
    %
    % 作者: Asaqe Lee
    % 日期: 2025-06-18
    
    properties (Constant)
        WAVEFORM_ID = 52        % 波形ID
        WAVEFORM_NAME = 'AM'    % 波形名称
        MODULATION_TYPE = 'AM'  % 调制类型
        CATEGORY = 'analog'     % 波形类别
    end
    
    properties (Access = private)
        % AM特有参数
        modulation_depth       % 调制深度 (0-1)
        carrier_amplitude      % 载波幅度
        baseband_bandwidth     % 基带带宽 (Hz)
        am_type               % AM类型 ('DSB-FC', 'DSB-SC', 'SSB-USB', 'SSB-LSB')
        
        % 滤波器参数
        sideband_filter       % 边带滤波器
        
        % 内部状态
        last_envelope         % 上一个包络值
    end
    
    methods
        function obj = AM()
            % 构造函数
            obj@WaveformBase();
            obj.initialize_am_params();
        end
        
        function signal = modulate(obj, data, params)
            % AM调制
            % 输入: data - 调制信号 (基带信号)
            %      params - 调制参数
            % 输出: signal - AM调制信号
            
            % 验证输入
            if isempty(data)
                error('AM:EmptyData', '输入数据不能为空');
            end
            
            % 确保数据为列向量
            if isrow(data)
                data = data(:);
            end
            
            % 归一化调制信号
            data = data / max(abs(data));
            
            % 生成载波
            t = (0:length(data)-1)' / obj.sample_rate;
            carrier = obj.carrier_amplitude * cos(2*pi*obj.center_frequency*t);
            
            % 根据AM类型进行调制
            switch obj.am_type
                case 'DSB-FC'
                    % 双边带全载波AM
                    envelope = obj.carrier_amplitude * (1 + obj.modulation_depth * data);
                    signal = envelope .* cos(2*pi*obj.center_frequency*t);
                    
                case 'DSB-SC'
                    % 双边带抑制载波AM
                    signal = obj.carrier_amplitude * data .* cos(2*pi*obj.center_frequency*t);
                    
                case 'SSB-USB'
                    % 单边带上边带AM
                    signal = obj.generate_ssb(data, t, 'upper');
                    
                case 'SSB-LSB'
                    % 单边带下边带AM
                    signal = obj.generate_ssb(data, t, 'lower');
                    
                otherwise
                    error('AM:InvalidType', '不支持的AM类型: %s', obj.am_type);
            end
            
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
            % AM解调
            % 输入: signal - AM调制信号
            %      params - 解调参数
            % 输出: data - 解调后的基带信号
            
            % 验证输入
            if isempty(signal)
                error('AM:EmptySignal', '输入信号不能为空');
            end
            
            % 确保信号为列向量
            if isrow(signal)
                signal = signal(:);
            end
            
            % 选择解调方法
            if isfield(params, 'demod_method')
                demod_method = params.demod_method;
            else
                demod_method = 'envelope';  % 默认使用包络检波
            end
            
            switch demod_method
                case 'envelope'
                    % 包络检波解调
                    data = obj.envelope_detector(signal);
                    
                case 'coherent'
                    % 相干解调
                    data = obj.coherent_demodulator(signal);
                    
                case 'hilbert'
                    % 希尔伯特变换解调
                    data = obj.hilbert_demodulator(signal);
                    
                otherwise
                    error('AM:InvalidDemodMethod', '不支持的解调方法: %s', demod_method);
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
            spectrum.bandwidth = obj.calculate_am_bandwidth();
        end
        
        function info = get_waveform_info(obj)
            % 获取波形信息
            % 输出: info - 波形信息结构体
            
            info = struct();
            info.waveform_id = obj.WAVEFORM_ID;
            info.waveform_name = obj.WAVEFORM_NAME;
            info.modulation_type = obj.MODULATION_TYPE;
            info.category = obj.CATEGORY;
            info.modulation_depth = obj.modulation_depth;
            info.carrier_amplitude = obj.carrier_amplitude;
            info.baseband_bandwidth = obj.baseband_bandwidth;
            info.am_type = obj.am_type;
            info.am_bandwidth = obj.calculate_am_bandwidth();
        end
    end
    
    methods (Access = private)
        function initialize_am_params(obj)
            % 初始化AM特有参数
            obj.modulation_depth = 0.8;         % 80%调制深度
            obj.carrier_amplitude = 1.0;        % 载波幅度
            obj.baseband_bandwidth = 5e3;       % 5 kHz基带带宽
            obj.am_type = 'DSB-FC';             % 默认双边带全载波
            obj.last_envelope = 0;
            
            % 初始化滤波器
            obj.initialize_filters();
        end
        
        function initialize_filters(obj)
            % 初始化边带滤波器
            
            % 设计边带滤波器（用于SSB）
            fc_normalized = obj.baseband_bandwidth / (obj.sample_rate/2);
            if fc_normalized < 1
                [b, a] = butter(6, fc_normalized, 'low');
                obj.sideband_filter = {b, a};
            else
                obj.sideband_filter = [];
            end
        end
        
        function signal = generate_ssb(obj, data, t, sideband)
            % 生成单边带信号
            % 输入: data - 基带信号
            %      t - 时间向量
            %      sideband - 'upper' 或 'lower'
            
            % 生成希尔伯特变换
            data_hilbert = hilbert(data);
            
            % 生成正交载波
            carrier_i = cos(2*pi*obj.center_frequency*t);
            carrier_q = sin(2*pi*obj.center_frequency*t);
            
            if strcmp(sideband, 'upper')
                % 上边带
                signal = obj.carrier_amplitude * ...
                    (real(data_hilbert) .* carrier_i - imag(data_hilbert) .* carrier_q);
            else
                % 下边带
                signal = obj.carrier_amplitude * ...
                    (real(data_hilbert) .* carrier_i + imag(data_hilbert) .* carrier_q);
            end
        end
        
        function data = envelope_detector(obj, signal)
            % 包络检波器
            % 输入: signal - AM信号
            % 输出: data - 解调后的基带信号
            
            % 计算信号包络
            analytic_signal = hilbert(signal);
            envelope = abs(analytic_signal);
            
            % 对于DSB-FC，需要去除直流分量
            if strcmp(obj.am_type, 'DSB-FC')
                data = envelope - obj.carrier_amplitude;
                data = data / obj.modulation_depth;
            else
                data = envelope;
            end
        end
        
        function data = coherent_demodulator(obj, signal)
            % 相干解调器
            % 输入: signal - AM信号
            % 输出: data - 解调后的基带信号
            
            % 生成本地载波
            t = (0:length(signal)-1)' / obj.sample_rate;
            local_carrier = 2 * cos(2*pi*obj.center_frequency*t);
            
            % 相干解调
            demod_signal = signal .* local_carrier;
            
            % 低通滤波
            if ~isempty(obj.sideband_filter)
                data = filter(obj.sideband_filter{1}, obj.sideband_filter{2}, demod_signal);
            else
                data = demod_signal;
            end
        end
        
        function data = hilbert_demodulator(obj, signal)
            % 希尔伯特变换解调器
            % 输入: signal - AM信号
            % 输出: data - 解调后的基带信号
            
            % 计算解析信号
            analytic_signal = hilbert(signal);
            
            % 提取包络
            data = abs(analytic_signal);
            
            % 对于DSB-FC，去除载波分量
            if strcmp(obj.am_type, 'DSB-FC')
                data = data - mean(data);
            end
        end
        
        function bandwidth = calculate_am_bandwidth(obj)
            % 计算AM信号带宽
            % 输出: bandwidth - AM信号带宽
            
            switch obj.am_type
                case {'DSB-FC', 'DSB-SC'}
                    % 双边带：带宽 = 2 * 基带带宽
                    bandwidth = 2 * obj.baseband_bandwidth;
                case {'SSB-USB', 'SSB-LSB'}
                    % 单边带：带宽 = 基带带宽
                    bandwidth = obj.baseband_bandwidth;
                otherwise
                    bandwidth = 2 * obj.baseband_bandwidth;
            end
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
            % AM特定的配置方法
            % 输入: config_struct - 配置结构体
            
            if isfield(config_struct, 'modulation_depth')
                obj.modulation_depth = config_struct.modulation_depth;
            end
            
            if isfield(config_struct, 'carrier_amplitude')
                obj.carrier_amplitude = config_struct.carrier_amplitude;
            end
            
            if isfield(config_struct, 'baseband_bandwidth')
                obj.baseband_bandwidth = config_struct.baseband_bandwidth;
            end
            
            if isfield(config_struct, 'am_type')
                obj.am_type = config_struct.am_type;
            end
            
            % 重新初始化滤波器
            obj.initialize_filters();
        end
        
        function params = parse_recovery_params(obj, varargin)
            % 重写基类方法，添加AM特有的解调参数
            % 输入: varargin - 可变参数
            % 输出: params - 参数结构体
            
            p = inputParser;
            addParameter(p, 'timing_recovery', true, @islogical);
            addParameter(p, 'carrier_recovery', true, @islogical);
            addParameter(p, 'equalization', false, @islogical);
            addParameter(p, 'demod_method', 'envelope', @ischar);  % AM特有参数
            
            parse(p, varargin{:});
            params = p.Results;
        end
    end
end
