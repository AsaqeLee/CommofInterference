classdef BPSK < WaveformBase
    % BPSK - 二进制相移键控调制波形
    % 实现BPSK调制和解调功能
    %
    % 作者: Asaqe Lee
    % 日期: 2025-06-18
    
    properties (Constant)
        WAVEFORM_ID = 1;
        WAVEFORM_NAME = 'BPSK';
        MODULATION_TYPE = 'PSK';
        CATEGORY = 'digital';
    end
    
    properties (Access = private)
        constellation_points  % 星座点
        phase_offset         % 相位偏移
        amplitude           % 幅度
        use_differential_encoding = true;  % 是否使用差分编码
        last_transmitted_symbol = 1;      % 上一个发送的符号（用于差分编码）
    end
    
    methods
        function obj = BPSK()
            % 构造函数
            obj@WaveformBase();

            % 初始化BPSK特定参数
            obj.modulation_order = 2;
            obj.constellation_points = [1, -1];  % BPSK星座点
            obj.phase_offset = 0;
            obj.amplitude = 1;
            obj.use_differential_encoding = true;  % 默认启用差分编码
            obj.last_transmitted_symbol = 1;      % 初始参考符号
        end
        
        function signal = modulate(obj, data, params)
            % BPSK调制
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
            % BPSK解调
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
            info.use_differential_encoding = obj.use_differential_encoding;
            info.theoretical_ber = @(snr_db) obj.theoretical_ber_bpsk(snr_db);

            if obj.use_differential_encoding
                info.description = '差分二进制相移键控调制(DBPSK)，通过相邻符号的相位差传输信息，解决相位模糊问题';
            else
                info.description = '二进制相移键控调制(BPSK)，使用0和π相位表示数据位0和1';
            end
        end
    end
    
    methods (Access = protected)
        function configure_specific(obj, config_struct)
            % BPSK特定配置
            % 输入: config_struct - 配置结构体

            if isfield(config_struct, 'phase_offset')
                obj.phase_offset = config_struct.phase_offset;
            end

            if isfield(config_struct, 'amplitude')
                obj.amplitude = config_struct.amplitude;
            end

            if isfield(config_struct, 'use_differential_encoding')
                obj.use_differential_encoding = config_struct.use_differential_encoding;
            end

            % 确保调制阶数为2
            obj.modulation_order = 2;
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
            % 比特到符号映射（支持差分编码）
            % 输入: data - 二进制数据
            % 输出: symbols - 复符号

            if obj.use_differential_encoding
                % 差分编码：需要在数据前添加参考符号
                % 数据位0 -> 无相位变化 (乘以+1)
                % 数据位1 -> 180度相位变化 (乘以-1)

                % 创建包含参考符号的符号序列
                symbols = zeros(length(data) + 1, 1);
                symbols(1) = obj.last_transmitted_symbol;  % 参考符号

                current_symbol = obj.last_transmitted_symbol;

                for i = 1:length(data)
                    if data(i) == 0
                        % 无相位变化
                        current_symbol = current_symbol * 1;
                    else
                        % 180度相位变化
                        current_symbol = current_symbol * (-1);
                    end
                    symbols(i + 1) = current_symbol;
                end

                % 更新最后发送的符号
                obj.last_transmitted_symbol = current_symbol;
            else
                % 传统BPSK映射: 0 -> +1, 1 -> -1
                symbols = 1 - 2*data;  % 0->+1, 1->-1
            end

            symbols = complex(symbols, 0);  % 转换为复数
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
            % 载波恢复
            % 输入: signal - 接收信号
            % 输出: recovered_signal - 载波恢复后的信号

            try
                % 使用载波同步工具进行载波恢复
                [recovered_signal, freq_offset, phase_offset] = ...
                    CarrierSync.recover_carrier_bpsk(signal, obj.sample_rate, ...
                    'algorithm', 'squaring', 'loop_bandwidth', 0.01);

                % 记录载波偏移信息（用于调试）
                if abs(freq_offset) > 1000  % 频率偏移大于1kHz时显示警告
                    fprintf('BPSK载波恢复: 频率偏移 = %.1f Hz, 相位偏移 = %.2f rad\n', ...
                        freq_offset, phase_offset);
                end

            catch ME
                % 如果载波恢复失败，使用简化方法
                fprintf('载波恢复失败，使用简化方法: %s\n', ME.message);
                recovered_signal = signal;
            end
        end
        
        function filtered_signal = apply_lowpass_filter(obj, signal)
            % 应用低通滤波器
            % 输入: signal - 输入信号
            % 输出: filtered_signal - 滤波后的信号

            % 简化实现：暂时跳过滤波，避免引入延迟
            % 在实际应用中应该使用零相位滤波器
            filtered_signal = signal;
        end
        
        function symbols = symbol_timing_recovery(obj, signal, samples_per_symbol)
            % 符号定时恢复
            % 输入: signal - 基带信号
            %      samples_per_symbol - 每符号采样数
            % 输出: symbols - 恢复的符号

            try
                % 使用载波同步工具进行符号定时恢复
                [timing_offset, corrected_symbols] = ...
                    CarrierSync.symbol_timing_recovery(signal, samples_per_symbol, ...
                    'method', 'early_late', 'loop_bandwidth', 0.01);

                symbols = corrected_symbols;

                % 记录定时偏移信息（用于调试）
                if abs(timing_offset) > samples_per_symbol * 0.1
                    fprintf('BPSK符号定时恢复: 定时偏移 = %.2f 采样点\n', timing_offset);
                end

            catch ME
                % 如果定时恢复失败，使用简化方法
                fprintf('符号定时恢复失败，使用简化方法: %s\n', ME.message);

                % 简化实现：寻找最佳采样点
                best_offset = 1;
                max_energy = 0;

                for offset = 1:samples_per_symbol
                    test_indices = offset:samples_per_symbol:length(signal);
                    test_indices = test_indices(test_indices <= length(signal));
                    if ~isempty(test_indices)
                        test_symbols = signal(test_indices);
                        energy = mean(abs(test_symbols).^2);
                        if energy > max_energy
                            max_energy = energy;
                            best_offset = offset;
                        end
                    end
                end

                % 使用最佳偏移采样
                symbol_indices = best_offset:samples_per_symbol:length(signal);
                symbol_indices = symbol_indices(symbol_indices <= length(signal));
                symbols = signal(symbol_indices);
            end
        end
        
        function data = symbol_decision(obj, symbols)
            % 符号判决（支持差分解码）
            % 输入: symbols - 接收符号
            % 输出: data - 判决后的数据

            if obj.use_differential_encoding
                % 差分解码：比较相邻符号的相位差
                data = obj.differential_decode(symbols);
            else
                % 传统BPSK判决：映射 0 -> +1, 1 -> -1
                % 所以判决时：+1 -> 0, -1 -> 1
                real_parts = real(symbols);

                % 基本判决
                data_normal = double(real_parts < 0);
                data_inverted = double(real_parts > 0);

                % 简单的相位模糊检测：比较星座点的均值
                if length(symbols) >= 4
                    % 计算两种判决下的星座点均值
                    mean_0_normal = mean(real_parts(data_normal == 0));
                    mean_1_normal = mean(real_parts(data_normal == 1));

                    mean_0_inverted = mean(real_parts(data_inverted == 0));
                    mean_1_inverted = mean(real_parts(data_inverted == 1));

                    % 计算分离度（均值差的绝对值）
                    separation_normal = abs(mean_0_normal - mean_1_normal);
                    separation_inverted = abs(mean_0_inverted - mean_1_inverted);

                    % 选择分离度更大的判决
                    if separation_inverted > separation_normal
                        data = data_inverted;
                    else
                        data = data_normal;
                    end
                else
                    % 符号数量太少，直接使用正常判决
                    data = data_normal;
                end
            end
        end

        function data = differential_decode(obj, symbols)
            % 差分解码
            % 输入: symbols - 接收符号序列
            % 输出: data - 解码后的数据

            if length(symbols) < 2
                % 符号数量不足，无法进行差分解码
                data = [];
                return;
            end

            % 初始化 - 注意：差分解码的输出长度等于输入长度
            % 第一个符号作为参考，不包含数据信息
            data = zeros(length(symbols), 1);

            % 差分解码：比较相邻符号的相位
            for i = 2:length(symbols)
                % 计算相邻符号的相位差
                phase_diff = angle(symbols(i) * conj(symbols(i-1)));

                % 判决：相位差接近0为数据位0，接近π为数据位1
                if abs(phase_diff) < pi/2
                    data(i) = 0;  % 无相位变化
                else
                    data(i) = 1;  % 180度相位变化
                end
            end

            % 移除第一个参考符号，返回实际数据
            data = data(2:end);
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
        
        function ber = theoretical_ber_bpsk(obj, snr_db)
            % BPSK理论误码率
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
