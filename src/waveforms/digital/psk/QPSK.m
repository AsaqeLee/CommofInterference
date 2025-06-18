classdef QPSK < WaveformBase
    % QPSK - 四进制相移键控调制波形
    % 实现QPSK调制和解调功能
    %
    % 作者: Asaqe Lee
    % 日期: 2025-06-18
    
    properties (Constant)
        WAVEFORM_ID = 2;
        WAVEFORM_NAME = 'QPSK';
        MODULATION_TYPE = 'PSK';
        CATEGORY = 'digital';
    end
    
    properties (Access = private)
        constellation_points  % 星座点
        phase_offset         % 相位偏移
        amplitude           % 幅度
        gray_coding         % 是否使用格雷编码
    end
    
    methods
        function obj = QPSK()
            % 构造函数
            obj@WaveformBase();
            
            % 初始化QPSK特定参数
            obj.modulation_order = 4;
            obj.phase_offset = 0;
            obj.amplitude = 1;
            obj.gray_coding = true;
            
            % QPSK星座点 (格雷编码)
            obj.constellation_points = [1+1j, -1+1j, -1-1j, 1-1j] / sqrt(2);
        end
        
        function signal = modulate(obj, data, params)
            % QPSK调制
            % 输入: data - 二进制数据
            %      params - 调制参数
            % 输出: signal - 调制后的复信号
            
            % 参数检查
            if nargin < 3
                params = struct();
            end
            
            % 解析参数
            add_noise = obj.get_param_value(params, 'add_noise', true);
            normalize = obj.get_param_value(params, 'normalize', true);
            phase_offset = obj.get_param_value(params, 'phase_offset', obj.phase_offset);
            amplitude = obj.get_param_value(params, 'amplitude', obj.amplitude);
            
            % 数据预处理
            data = obj.preprocess_data(data);
            
            % 符号映射
            symbols = obj.map_bits_to_symbols(data);
            
            % 上采样到采样率
            samples_per_symbol = round(obj.sample_rate / obj.symbol_rate);
            upsampled_symbols = obj.upsample_symbols(symbols, samples_per_symbol);
            
            % 生成载波
            t = (0:length(upsampled_symbols)-1) / obj.sample_rate;
            carrier = exp(1j * (2*pi*obj.center_frequency*t + phase_offset));
            
            % 调制
            signal = amplitude * upsampled_symbols .* carrier;
            
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
            % QPSK解调
            % 输入: signal - 接收到的复信号
            %      params - 解调参数
            % 输出: data - 解调后的二进制数据
            
            % 参数检查
            if nargin < 3
                params = struct();
            end
            
            % 解析参数
            timing_recovery = obj.get_param_value(params, 'timing_recovery', true);
            carrier_recovery = obj.get_param_value(params, 'carrier_recovery', true);
            
            % 载波恢复
            if carrier_recovery
                signal = obj.recover_carrier(signal);
            end
            
            % 下变频
            t = (0:length(signal)-1) / obj.sample_rate;
            carrier = exp(-1j * 2*pi*obj.center_frequency*t);
            baseband_signal = signal .* carrier;
            
            % 低通滤波
            baseband_signal = obj.apply_lowpass_filter(baseband_signal);
            
            % 符号同步和采样
            samples_per_symbol = round(obj.sample_rate / obj.symbol_rate);
            if timing_recovery
                symbols = obj.symbol_timing_recovery(baseband_signal, samples_per_symbol);
            else
                % 简单采样
                symbol_indices = 1:samples_per_symbol:length(baseband_signal);
                symbols = baseband_signal(symbol_indices);
            end
            
            % 符号判决
            data = obj.symbol_decision(symbols);
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
            info.constellation_points = obj.constellation_points;
            info.bits_per_symbol = log2(obj.modulation_order);
            info.gray_coding = obj.gray_coding;
            info.theoretical_ber = @(snr_db) obj.theoretical_ber_qpsk(snr_db);
            info.description = '四进制相移键控调制，每个符号携带2比特信息';
        end
        
        function plot_constellation(obj, symbols)
            % 绘制星座图
            % 输入: symbols - 符号序列（可选）
            
            figure;
            
            % 绘制理论星座点
            scatter(real(obj.constellation_points), imag(obj.constellation_points), ...
                100, 'r', 'filled', 'DisplayName', '理论星座点');
            hold on;
            
            % 如果提供了符号，绘制接收符号
            if nargin > 1 && ~isempty(symbols)
                scatter(real(symbols), imag(symbols), 20, 'b', 'o', ...
                    'DisplayName', '接收符号');
            end
            
            % 添加标签
            for i = 1:length(obj.constellation_points)
                text(real(obj.constellation_points(i)) + 0.1, ...
                     imag(obj.constellation_points(i)) + 0.1, ...
                     sprintf('%d', i-1), 'FontSize', 12);
            end
            
            xlabel('同相分量 (I)');
            ylabel('正交分量 (Q)');
            title('QPSK星座图');
            grid on;
            axis equal;
            legend;
        end
    end
    
    methods (Access = protected)
        function configure_specific(obj, config_struct)
            % QPSK特定配置
            % 输入: config_struct - 配置结构体
            
            if isfield(config_struct, 'phase_offset')
                obj.phase_offset = config_struct.phase_offset;
            end
            
            if isfield(config_struct, 'amplitude')
                obj.amplitude = config_struct.amplitude;
            end
            
            if isfield(config_struct, 'gray_coding')
                obj.gray_coding = config_struct.gray_coding;
                obj.update_constellation();
            end
            
            % 确保调制阶数为4
            obj.modulation_order = 4;
        end
        
        function update_constellation(obj)
            % 更新星座点
            
            if obj.gray_coding
                % 格雷编码星座点
                obj.constellation_points = [1+1j, -1+1j, -1-1j, 1-1j] / sqrt(2);
            else
                % 自然编码星座点
                obj.constellation_points = [1+1j, 1-1j, -1+1j, -1-1j] / sqrt(2);
            end
        end
        
        function data = preprocess_data(obj, data)
            % 数据预处理
            % 输入: data - 原始数据
            % 输出: data - 预处理后的数据
            
            % 转换为列向量
            data = data(:);
            
            % 确保数据为0和1
            data = double(data > 0);
            
            % 如果需要，添加填充位使数据长度为符号数的整数倍
            bits_per_symbol = log2(obj.modulation_order);
            remainder = mod(length(data), bits_per_symbol);
            if remainder ~= 0
                padding = bits_per_symbol - remainder;
                data = [data; zeros(padding, 1)];
            end
        end
        
        function symbols = map_bits_to_symbols(obj, data)
            % 比特到符号映射
            % 输入: data - 二进制数据
            % 输出: symbols - 复符号
            
            % 将比特分组为2比特符号
            bits_per_symbol = log2(obj.modulation_order);
            num_symbols = length(data) / bits_per_symbol;
            
            % 重塑数据为符号矩阵
            bit_matrix = reshape(data, bits_per_symbol, num_symbols);
            
            % 转换为符号索引
            symbol_indices = bit_matrix(1,:) * 2 + bit_matrix(2,:) + 1;
            
            % 映射到星座点
            symbols = obj.constellation_points(symbol_indices);
            symbols = symbols(:);  % 转换为列向量
        end
        
        function upsampled = upsample_symbols(obj, symbols, samples_per_symbol)
            % 符号上采样
            % 输入: symbols - 符号序列
            %      samples_per_symbol - 每符号采样数
            % 输出: upsampled - 上采样后的信号
            
            % 简单的零阶保持上采样
            upsampled = repelem(symbols, samples_per_symbol);
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
        
        function recovered_signal = recover_carrier(obj, signal)
            % 载波恢复（简化实现）
            % 输入: signal - 接收信号
            % 输出: recovered_signal - 载波恢复后的信号
            
            % 简化实现：假设载波相位已知
            recovered_signal = signal;
        end
        
        function filtered_signal = apply_lowpass_filter(obj, signal)
            % 应用低通滤波器
            % 输入: signal - 输入信号
            % 输出: filtered_signal - 滤波后的信号
            
            % 简化实现：使用简单的移动平均滤波器
            filter_length = 5;
            h = ones(1, filter_length) / filter_length;
            filtered_signal = filter(h, 1, signal);
        end
        
        function symbols = symbol_timing_recovery(obj, signal, samples_per_symbol)
            % 符号定时恢复
            % 输入: signal - 基带信号
            %      samples_per_symbol - 每符号采样数
            % 输出: symbols - 恢复的符号
            
            % 简化实现：使用固定采样点
            symbol_indices = round(samples_per_symbol/2):samples_per_symbol:length(signal);
            symbol_indices = symbol_indices(symbol_indices <= length(signal));
            symbols = signal(symbol_indices);
        end
        
        function data = symbol_decision(obj, symbols)
            % 符号判决
            % 输入: symbols - 接收符号
            % 输出: data - 判决后的数据
            
            % 最小距离判决
            num_symbols = length(symbols);
            data = zeros(num_symbols * 2, 1);  % 每个符号2比特
            
            for i = 1:num_symbols
                % 计算到各星座点的距离
                distances = abs(symbols(i) - obj.constellation_points);
                [~, min_idx] = min(distances);
                
                % 转换索引为比特
                symbol_value = min_idx - 1;  % 0-3
                bit1 = bitget(symbol_value, 2);  % 高位
                bit2 = bitget(symbol_value, 1);  % 低位
                
                data(2*i-1) = bit1;
                data(2*i) = bit2;
            end
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
        
        function ber = theoretical_ber_qpsk(obj, snr_db)
            % QPSK理论误码率
            % 输入: snr_db - 信噪比(dB)
            % 输出: ber - 理论误码率
            
            snr_linear = 10.^(snr_db/10);
            ber = 0.5 * erfc(sqrt(snr_linear));
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
