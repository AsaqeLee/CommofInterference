classdef FSK < WaveformBase
    % FSK - 频移键控调制波形
    % 实现二进制FSK调制和解调功能
    %
    % 作者: Asaqe Lee
    % 日期: 2025-06-18
    
    properties (Constant)
        WAVEFORM_ID = 7;
        WAVEFORM_NAME = 'FSK';
        MODULATION_TYPE = 'FSK';
        CATEGORY = 'digital';
    end
    
    properties (Access = private)
        frequency_deviation  % 频偏 (Hz)
        frequency_0         % 表示'0'的频率 (Hz)
        frequency_1         % 表示'1'的频率 (Hz)
        modulation_index    % 调制指数
        phase_continuity    % 相位连续性
    end
    
    methods
        function obj = FSK()
            % 构造函数
            obj@WaveformBase();
            
            % 初始化FSK特定参数
            obj.modulation_order = 2;
            obj.frequency_deviation = 50e3;  % 50 kHz频偏
            obj.modulation_index = 1.0;      % 调制指数
            obj.phase_continuity = true;     % 相位连续
            
            % 计算频率
            obj.update_frequencies();
        end
        
        function signal = modulate(obj, data, params)
            % FSK调制
            % 输入: data - 二进制数据 (0, 1)
            %      params - 调制参数
            % 输出: signal - 调制后的复信号
            
            % 参数检查
            if nargin < 3
                params = struct();
            end
            
            % 解析参数
            add_noise = obj.get_param_value(params, 'add_noise', true);
            normalize = obj.get_param_value(params, 'normalize', true);
            amplitude = obj.get_param_value(params, 'amplitude', 1);
            
            % 数据预处理
            data = obj.preprocess_data(data);
            
            % 计算每符号采样数
            samples_per_symbol = round(obj.sample_rate / obj.symbol_rate);
            total_samples = length(data) * samples_per_symbol;
            
            % 初始化信号
            signal = zeros(1, total_samples);
            
            % 时间向量
            t_symbol = (0:samples_per_symbol-1) / obj.sample_rate;
            
            % 相位累积（用于相位连续）
            phase_accumulator = 0;
            
            for i = 1:length(data)
                % 选择频率
                if data(i) == 0
                    freq = obj.frequency_0;
                else
                    freq = obj.frequency_1;
                end
                
                % 计算当前符号的起始和结束索引
                start_idx = (i-1) * samples_per_symbol + 1;
                end_idx = i * samples_per_symbol;
                
                if obj.phase_continuity
                    % 相位连续FSK
                    phase = 2*pi*freq*t_symbol + phase_accumulator;
                    % 更新相位累积器
                    phase_accumulator = phase(end);
                else
                    % 相位不连续FSK
                    phase = 2*pi*freq*t_symbol;
                end
                
                % 生成符号信号
                symbol_signal = amplitude * exp(1j * phase);
                signal(start_idx:end_idx) = symbol_signal;
            end
            
            % 上变频到载波频率
            t = (0:length(signal)-1) / obj.sample_rate;
            carrier = exp(1j * 2*pi*obj.center_frequency*t);
            signal = signal .* carrier;
            
            % 归一化
            if normalize
                signal = signal / max(abs(signal));
            end
            
            % 添加噪声
            if add_noise && obj.snr_db < inf
                signal = obj.add_awgn_noise(signal, obj.snr_db);
            end
            
            % 确保输出为行向量
            signal = signal(:).';
        end
        
        function data = demodulate(obj, signal, params)
            % FSK解调
            % 输入: signal - 接收到的复信号
            %      params - 解调参数
            % 输出: data - 解调后的二进制数据

            % 参数检查
            if nargin < 3
                params = struct();
            end

            % 解析参数
            method = obj.get_param_value(params, 'method', 'coherent');  % 'coherent' 或 'noncoherent'

            % 下变频
            t = (0:length(signal)-1) / obj.sample_rate;
            carrier = exp(-1j * 2*pi*obj.center_frequency*t);
            baseband_signal = signal .* carrier;

            % 根据解调方法选择
            switch method
                case 'coherent'
                    data = obj.coherent_demodulation(baseband_signal);
                case 'noncoherent'
                    data = obj.noncoherent_demodulation(baseband_signal);
                otherwise
                    error('FSK:InvalidMethod', '不支持的解调方法: %s', method);
            end
        end

        function data = recover_data(obj, received_signal, varargin)
            % 从接收信号中恢复数据（统一接口）
            % 输入: received_signal - 接收到的信号
            %      varargin - 可选参数
            % 输出: data - 恢复的数据

            % 解析可选参数
            p = inputParser;
            addParameter(p, 'method', 'coherent', @(x) ismember(x, {'coherent', 'noncoherent'}));
            addParameter(p, 'timing_recovery', true, @islogical);
            addParameter(p, 'carrier_recovery', true, @islogical);

            parse(p, varargin{:});
            params = p.Results;

            % 调用解调方法
            data = obj.demodulate(received_signal, params);
        end
        
        function ber = calculate_ber(obj, original_data, received_data)
            % 计算误码率
            % 输入: original_data - 原始数据
            %      received_data - 接收数据
            % 输出: ber - 误码率
            
            % 确保数据长度一致
            min_length = min(length(original_data), length(received_data));
            original_data = original_data(1:min_length);
            received_data = received_data(1:min_length);
            
            % 计算错误比特数
            errors = sum(original_data ~= received_data);
            ber = errors / min_length;
        end
        
        function spectrum = get_spectrum(obj, signal, params)
            % 获取信号频谱
            % 输入: signal - 信号
            %      params - 频谱分析参数
            % 输出: spectrum - 频谱结构体
            
            if nargin < 3
                params = struct();
            end
            
            % 解析参数
            nfft = obj.get_param_value(params, 'nfft', 1024);
            window_type = obj.get_param_value(params, 'window', 'hamming');
            
            % 计算功率谱密度
            [psd, frequencies] = obj.compute_psd(signal, nfft, window_type);
            
            % 构造频谱结构体
            spectrum = struct();
            spectrum.frequencies = frequencies;
            spectrum.power_density = psd;
            spectrum.center_frequency = obj.center_frequency;
            spectrum.bandwidth = obj.bandwidth;
            spectrum.frequency_0 = obj.frequency_0;
            spectrum.frequency_1 = obj.frequency_1;
            spectrum.frequency_deviation = obj.frequency_deviation;
        end
        
        function info = get_waveform_info(obj)
            % 获取波形信息
            % 输出: info - 波形信息结构体
            
            info = struct();
            info.waveform_id = obj.WAVEFORM_ID;
            info.waveform_name = obj.WAVEFORM_NAME;
            info.modulation_type = obj.MODULATION_TYPE;
            info.category = obj.CATEGORY;
            info.modulation_order = obj.modulation_order;
            info.frequency_deviation = obj.frequency_deviation;
            info.frequency_0 = obj.frequency_0;
            info.frequency_1 = obj.frequency_1;
            info.modulation_index = obj.modulation_index;
            info.phase_continuity = obj.phase_continuity;
            info.bits_per_symbol = log2(obj.modulation_order);
            info.theoretical_ber_coherent = @(snr_db) obj.theoretical_ber_fsk_coherent(snr_db);
            info.theoretical_ber_noncoherent = @(snr_db) obj.theoretical_ber_fsk_noncoherent(snr_db);
            info.description = '二进制频移键控调制，使用不同频率表示数据位0和1';
        end
        
        function plot_frequency_response(obj)
            % 绘制频率响应
            
            figure;
            
            % 频率范围
            f_range = linspace(obj.center_frequency - 5*obj.frequency_deviation, ...
                              obj.center_frequency + 5*obj.frequency_deviation, 1000);
            
            % 标记关键频率
            hold on;
            plot([obj.center_frequency + obj.frequency_0, obj.center_frequency + obj.frequency_0], ...
                 [0, 1], 'r--', 'LineWidth', 2, 'DisplayName', 'Frequency 0');
            plot([obj.center_frequency + obj.frequency_1, obj.center_frequency + obj.frequency_1], ...
                 [0, 1], 'b--', 'LineWidth', 2, 'DisplayName', 'Frequency 1');
            plot([obj.center_frequency, obj.center_frequency], ...
                 [0, 1], 'k-', 'LineWidth', 1, 'DisplayName', 'Carrier');
            
            xlabel('频率 (Hz)');
            ylabel('归一化幅度');
            title('FSK频率分配');
            legend;
            grid on;
            
            % 添加文本标注
            text(obj.center_frequency + obj.frequency_0, 0.5, ...
                sprintf('f_0 = %.1f kHz', obj.frequency_0/1000), ...
                'HorizontalAlignment', 'center');
            text(obj.center_frequency + obj.frequency_1, 0.5, ...
                sprintf('f_1 = %.1f kHz', obj.frequency_1/1000), ...
                'HorizontalAlignment', 'center');
        end
    end
    
    methods (Access = protected)
        function configure_specific(obj, config_struct)
            % FSK特定配置
            % 输入: config_struct - 配置结构体
            
            if isfield(config_struct, 'frequency_deviation')
                obj.frequency_deviation = config_struct.frequency_deviation;
                obj.update_frequencies();
            end
            
            if isfield(config_struct, 'modulation_index')
                obj.modulation_index = config_struct.modulation_index;
                obj.update_frequencies();
            end
            
            if isfield(config_struct, 'phase_continuity')
                obj.phase_continuity = config_struct.phase_continuity;
            end
            
            % 确保调制阶数为2
            obj.modulation_order = 2;
        end
        
        function update_frequencies(obj)
            % 更新频率设置
            
            % 根据调制指数计算频偏
            if obj.modulation_index > 0
                obj.frequency_deviation = obj.modulation_index * obj.symbol_rate / 2;
            end
            
            % 计算两个频率
            obj.frequency_0 = -obj.frequency_deviation;
            obj.frequency_1 = +obj.frequency_deviation;
        end
        
        function data = preprocess_data(obj, data)
            % 数据预处理
            % 输入: data - 原始数据
            % 输出: data - 预处理后的数据
            
            % 转换为列向量
            data = data(:);
            
            % 确保数据为0和1
            data = double(data > 0);
        end
        
        function data = coherent_demodulation(obj, baseband_signal)
            % 相干解调
            % 输入: baseband_signal - 基带信号
            % 输出: data - 解调数据
            
            samples_per_symbol = round(obj.sample_rate / obj.symbol_rate);
            num_symbols = floor(length(baseband_signal) / samples_per_symbol);
            
            data = zeros(num_symbols, 1);
            
            % 生成本地振荡器信号
            t_symbol = (0:samples_per_symbol-1) / obj.sample_rate;
            local_osc_0 = exp(1j * 2*pi*obj.frequency_0*t_symbol);
            local_osc_1 = exp(1j * 2*pi*obj.frequency_1*t_symbol);
            
            for i = 1:num_symbols
                % 提取当前符号
                start_idx = (i-1) * samples_per_symbol + 1;
                end_idx = i * samples_per_symbol;
                symbol_signal = baseband_signal(start_idx:end_idx);
                
                % 相关检测
                corr_0 = abs(sum(symbol_signal .* conj(local_osc_0)));
                corr_1 = abs(sum(symbol_signal .* conj(local_osc_1)));
                
                % 判决
                if corr_0 > corr_1
                    data(i) = 0;
                else
                    data(i) = 1;
                end
            end
        end
        
        function data = noncoherent_demodulation(obj, baseband_signal)
            % 非相干解调（包络检测）
            % 输入: baseband_signal - 基带信号
            % 输出: data - 解调数据
            
            samples_per_symbol = round(obj.sample_rate / obj.symbol_rate);
            num_symbols = floor(length(baseband_signal) / samples_per_symbol);
            
            data = zeros(num_symbols, 1);
            
            % 设计带通滤波器
            [b0, a0] = obj.design_bandpass_filter(obj.frequency_0);
            [b1, a1] = obj.design_bandpass_filter(obj.frequency_1);
            
            % 滤波
            filtered_0 = filter(b0, a0, baseband_signal);
            filtered_1 = filter(b1, a1, baseband_signal);
            
            % 包络检测
            envelope_0 = abs(filtered_0);
            envelope_1 = abs(filtered_1);
            
            for i = 1:num_symbols
                % 提取当前符号的包络
                start_idx = (i-1) * samples_per_symbol + 1;
                end_idx = i * samples_per_symbol;
                
                energy_0 = sum(envelope_0(start_idx:end_idx).^2);
                energy_1 = sum(envelope_1(start_idx:end_idx).^2);
                
                % 判决
                if energy_0 > energy_1
                    data(i) = 0;
                else
                    data(i) = 1;
                end
            end
        end
        
        function [b, a] = design_bandpass_filter(obj, center_freq)
            % 设计带通滤波器
            % 输入: center_freq - 中心频率
            % 输出: b, a - 滤波器系数
            
            % 简化的带通滤波器设计
            normalized_freq = center_freq / (obj.sample_rate/2);
            bandwidth_norm = obj.frequency_deviation / (obj.sample_rate/2);
            
            % 使用巴特沃斯滤波器
            [b, a] = butter(4, [normalized_freq - bandwidth_norm/2, ...
                               normalized_freq + bandwidth_norm/2], 'bandpass');
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
        
        function [psd, frequencies] = compute_psd(obj, signal, nfft, window_type)
            % 计算功率谱密度
            % 输入: signal - 信号
            %      nfft - FFT点数
            %      window_type - 窗函数类型
            % 输出: psd - 功率谱密度
            %      frequencies - 频率向量
            
            % 应用窗函数
            switch window_type
                case 'hamming'
                    window = hamming(length(signal));
                case 'hanning'
                    window = hanning(length(signal));
                case 'blackman'
                    window = blackman(length(signal));
                otherwise
                    window = ones(length(signal), 1);
            end
            
            windowed_signal = signal(:) .* window;
            
            % 计算FFT
            X = fft(windowed_signal, nfft);
            
            % 计算功率谱密度
            psd = abs(X).^2 / (obj.sample_rate * sum(window.^2));
            
            % 生成频率向量
            frequencies = (-nfft/2:nfft/2-1) * obj.sample_rate / nfft;
            psd = fftshift(psd);
        end
        
        function ber = theoretical_ber_fsk_coherent(obj, snr_db)
            % FSK相干解调理论误码率
            % 输入: snr_db - 信噪比(dB)
            % 输出: ber - 理论误码率
            
            snr_linear = 10.^(snr_db/10);
            ber = 0.5 * erfc(sqrt(snr_linear/2));
        end
        
        function ber = theoretical_ber_fsk_noncoherent(obj, snr_db)
            % FSK非相干解调理论误码率
            % 输入: snr_db - 信噪比(dB)
            % 输出: ber - 理论误码率
            
            snr_linear = 10.^(snr_db/10);
            ber = 0.5 * exp(-snr_linear/2);
        end
        
        function value = get_param_value(obj, params, param_name, default_value)
            % 安全获取参数值
            % 输入: params - 参数结构体
            %      param_name - 参数名
            %      default_value - 默认值
            % 输出: value - 参数值
            
            if isfield(params, param_name)
                value = params.(param_name);
            else
                value = default_value;
            end
        end
    end
end
