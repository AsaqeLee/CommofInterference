classdef WaveformGenerator < handle
    % WaveformGenerator - 100种通信波形生成器
    % 统一生成所有100种通信波形
    %
    % 作者: Asaqe Lee
    % 日期: 2025-06-20
    
    properties (Access = private)
        config_manager  % 配置管理器
        sample_rate     % 采样率
        duration        % 信号持续时间
        conv_coder      % 卷积编码器
        ldpc_coder      % LDPC编码器
    end
    
    methods
        function obj = WaveformGenerator(sample_rate, duration)
            % 构造函数
            % 输入: sample_rate - 采样率 (Hz)
            %      duration - 信号持续时间 (秒)
            
            if nargin < 1
                sample_rate = 1e6; % 默认1MHz采样率
            end
            if nargin < 2
                duration = 0.001; % 默认1ms持续时间
            end
            
            obj.sample_rate = sample_rate;
            obj.duration = duration;
            
            % 添加配置管理器路径
            addpath('src/waveforms/config');
            addpath('src/waveforms/coding');
            obj.config_manager = WaveformConfigManager();

            % 初始化信道编码器
            obj.conv_coder = ConvolutionalCoder(2/3, 7); % 2/3码率，约束长度7
            obj.ldpc_coder = LDPCCoder(1/2, 1024);      % 1/2码率，块长1024
        end
        
        function [signal, info] = generate_waveform(obj, waveform_id, data)
            % 生成指定ID的波形
            % 输入: waveform_id - 波形ID (1-100)
            %      data - 输入数据 (可选)
            % 输出: signal - 生成的信号
            %      info - 波形信息
            
            if nargin < 3
                % 生成随机数据
                config = obj.config_manager.get_config(waveform_id);
                num_bits = ceil(config.data_rate * obj.duration);
                data = randi([0, 1], num_bits, 1);
            end
            
            % 获取配置
            config = obj.config_manager.get_config(waveform_id);
            
            % 根据调制类型生成波形
            switch config.modulation_type
                case 'FM'
                    [signal, info] = obj.generate_fm_waveform(config, data);
                case 'FSK'
                    [signal, info] = obj.generate_fsk_waveform(config, data);
                case 'QPSK'
                    [signal, info] = obj.generate_qpsk_waveform(config, data);
                case 'OFDM'
                    [signal, info] = obj.generate_ofdm_waveform(config, data);
                otherwise
                    error('WaveformGenerator:UnsupportedModulation', ...
                        '不支持的调制类型: %s', config.modulation_type);
            end
            
            % 添加跳频处理
            if config.hopping_enabled
                signal = obj.apply_frequency_hopping(signal, config);
            end
            
            % 添加波形信息
            info.waveform_id = waveform_id;
            info.config = config;
            info.sample_rate = obj.sample_rate;
            info.duration = obj.duration;
            info.num_samples = length(signal);
        end
        
        function [signal, info] = generate_fm_waveform(obj, config, data)
            % 生成FM调制波形
            
            % 将数字数据转换为模拟信号
            t = (0:1/obj.sample_rate:obj.duration-1/obj.sample_rate)';
            
            % 数据上采样
            samples_per_bit = round(obj.sample_rate / config.data_rate);
            analog_data = repelem(data*2-1, samples_per_bit); % 转换为±1
            analog_data = analog_data(1:length(t)); % 截断到正确长度
            
            % FM调制参数
            freq_dev = config.bandwidth / 4; % 频偏
            
            % FM调制
            phase = 2*pi*config.center_frequency*t + ...
                   2*pi*freq_dev*cumsum(analog_data)/obj.sample_rate;
            signal = cos(phase);
            
            % 波形信息
            info.modulation_type = 'FM';
            info.frequency_deviation = freq_dev;
            info.carrier_frequency = config.center_frequency;
        end
        
        function [signal, info] = generate_fsk_waveform(obj, config, data)
            % 生成FSK调制波形
            
            t = (0:1/obj.sample_rate:obj.duration-1/obj.sample_rate)';
            
            % FSK参数
            freq_sep = config.bandwidth / 4; % 频率间隔
            f0 = config.center_frequency - freq_sep/2; % 0对应的频率
            f1 = config.center_frequency + freq_sep/2; % 1对应的频率
            
            % 数据上采样
            samples_per_bit = round(obj.sample_rate / config.data_rate);
            upsampled_data = repelem(data, samples_per_bit);
            upsampled_data = upsampled_data(1:length(t));
            
            % FSK调制
            signal = zeros(size(t));
            for i = 1:length(t)
                if upsampled_data(i) == 0
                    signal(i) = cos(2*pi*f0*t(i));
                else
                    signal(i) = cos(2*pi*f1*t(i));
                end
            end
            
            % 应用信道编码
            if strcmp(config.channel_coding, '2/3卷积')
                signal = obj.apply_convolutional_coding(signal);
            end
            
            % 波形信息
            info.modulation_type = 'FSK';
            info.f0 = f0;
            info.f1 = f1;
            info.frequency_separation = freq_sep;
        end
        
        function [signal, info] = generate_qpsk_waveform(obj, config, data)
            % 生成QPSK调制波形
            
            t = (0:1/obj.sample_rate:obj.duration-1/obj.sample_rate)';
            
            % 确保数据长度为偶数
            if mod(length(data), 2) ~= 0
                data = [data; 0];
            end
            
            % 将比特分组为符号
            symbols = reshape(data, 2, [])';
            symbol_values = symbols(:,1)*2 + symbols(:,2); % 0,1,2,3
            
            % QPSK星座映射
            constellation = [1+1j, -1+1j, -1-1j, 1-1j] / sqrt(2);
            qpsk_symbols = constellation(symbol_values + 1);
            
            % 符号上采样
            samples_per_symbol = round(obj.sample_rate / (config.data_rate/2));
            upsampled_symbols = repelem(qpsk_symbols, samples_per_symbol);
            upsampled_symbols = upsampled_symbols(1:length(t));
            
            % 应用扩频
            if isfield(config, 'spread_spectrum_enabled') && config.spread_spectrum_enabled
                upsampled_symbols = obj.apply_spreading(upsampled_symbols, config);
            end
            
            % 载波调制 - 修复长度匹配问题
            target_length = length(upsampled_symbols);
            if target_length > length(t)
                % 如果扩频后信号太长，截断到时间长度
                upsampled_symbols = upsampled_symbols(1:length(t));
                target_length = length(t);
            end

            carrier = exp(1j*2*pi*config.center_frequency*t(1:target_length));
            signal = real(upsampled_symbols .* carrier);
            
            % 应用信道编码
            if strcmp(config.channel_coding, '2/3卷积')
                signal = obj.apply_convolutional_coding(signal);
            end
            
            % 波形信息
            info.modulation_type = 'QPSK';
            info.constellation = constellation;
            info.symbol_rate = config.data_rate / 2;
            if isfield(config, 'spreading_factor')
                info.spreading_factor = config.spreading_factor;
            end
        end
        
        function [signal, info] = generate_ofdm_waveform(obj, config, data)
            % 生成OFDM调制波形
            
            % OFDM参数
            num_subcarriers = 64; % 子载波数量
            cp_length = 16;       % 循环前缀长度
            
            % 确保数据长度适合子载波调制
            bits_per_symbol = obj.get_bits_per_symbol(config.constellation_type);
            total_bits = num_subcarriers * bits_per_symbol;
            
            if length(data) < total_bits
                data = [data; zeros(total_bits - length(data), 1)];
            else
                data = data(1:total_bits);
            end
            
            % 子载波调制
            modulated_data = obj.modulate_subcarriers(data, config.constellation_type);
            
            % IFFT
            ofdm_symbol = ifft(modulated_data, num_subcarriers);
            
            % 添加循环前缀
            ofdm_with_cp = [ofdm_symbol(end-cp_length+1:end); ofdm_symbol];
            
            % 上采样到指定采样率
            upsample_factor = round(obj.sample_rate / config.sample_rate);
            if upsample_factor > 1
                signal = repelem(ofdm_with_cp, upsample_factor);
            else
                signal = ofdm_with_cp;
            end
            
            % 截断到指定长度
            target_length = round(obj.duration * obj.sample_rate);
            if length(signal) > target_length
                signal = signal(1:target_length);
            else
                signal = [signal; zeros(target_length - length(signal), 1)];
            end
            
            % 载波调制
            t = (0:length(signal)-1)' / obj.sample_rate;
            carrier = exp(1j*2*pi*config.center_frequency*t);
            signal = real(signal .* carrier);
            
            % 应用LDPC编码
            if strcmp(config.channel_coding, 'LDPC_1_2')
                signal = obj.apply_ldpc_coding(signal);
            end
            
            % 波形信息
            info.modulation_type = 'OFDM';
            info.num_subcarriers = num_subcarriers;
            info.cp_length = cp_length;
            info.constellation_type = config.constellation_type;
        end
        
        function signal = apply_frequency_hopping(obj, signal, config)
            % 应用跳频处理
            
            if ~config.hopping_enabled
                return;
            end
            
            % 计算跳频参数
            hop_duration = 1 / config.hopping_rate; % 每跳持续时间
            samples_per_hop = round(hop_duration * obj.sample_rate);
            num_hops = ceil(length(signal) / samples_per_hop);
            
            % 生成跳频序列
            freq_sequence = obj.generate_hop_sequence(config.frequency_set, num_hops);
            
            % 应用跳频
            hopped_signal = zeros(size(signal));
            t = (0:length(signal)-1)' / obj.sample_rate;
            
            for hop = 1:num_hops
                start_idx = (hop-1) * samples_per_hop + 1;
                end_idx = min(hop * samples_per_hop, length(signal));
                
                if start_idx <= length(signal)
                    % 当前跳的频率
                    hop_freq = freq_sequence(hop);
                    
                    % 频率偏移
                    freq_offset = hop_freq - config.center_frequency;
                    phase_shift = exp(1j*2*pi*freq_offset*t(start_idx:end_idx));
                    
                    % 应用频率偏移
                    hopped_signal(start_idx:end_idx) = ...
                        real(signal(start_idx:end_idx) .* phase_shift);
                end
            end
            
            signal = hopped_signal;
        end
        
        function freq_sequence = generate_hop_sequence(obj, frequency_set, num_hops)
            % 生成伪随机跳频序列
            
            % 使用线性同余生成器
            seed = 12345;
            freq_sequence = zeros(num_hops, 1);
            
            for i = 1:num_hops
                seed = mod(1103515245 * seed + 12345, 2^31);
                freq_idx = mod(seed, length(frequency_set)) + 1;
                freq_sequence(i) = frequency_set(freq_idx);
            end
        end
        
        function signal = apply_spreading(obj, signal, config)
            % 应用扩频处理

            if ~isfield(config, 'spreading_factor')
                return;
            end

            % 生成扩频码
            spreading_code = obj.generate_spreading_code(config.spreading_factor);

            % 应用扩频 - 修复索引问题
            spread_signal = zeros(length(signal) * config.spreading_factor, 1);
            for i = 1:length(signal)
                start_idx = (i-1) * config.spreading_factor + 1;
                end_idx = i * config.spreading_factor;
                spread_signal(start_idx:end_idx) = signal(i) * spreading_code;
            end

            signal = spread_signal;
        end
        
        function code = generate_spreading_code(obj, spreading_factor)
            % 生成扩频码
            
            % 简单的伪随机序列
            code = 2*randi([0,1], spreading_factor, 1) - 1; % ±1序列
        end
        
        function signal = apply_convolutional_coding(obj, signal)
            % 应用真正的2/3卷积编码

            % 将模拟信号转换为比特
            % 简化方法：对信号进行量化
            quantized_bits = double(signal > 0);

            % 卷积编码
            coded_bits = obj.conv_coder.encode(quantized_bits);

            % 将编码比特转换回模拟信号
            signal = 2 * coded_bits - 1; % 转换为±1
        end
        
        function signal = apply_ldpc_coding(obj, signal)
            % 应用真正的LDPC 1/2编码

            % 将模拟信号转换为比特
            quantized_bits = double(signal > 0);

            % LDPC编码
            coded_bits = obj.ldpc_coder.encode(quantized_bits);

            % 将编码比特转换回模拟信号
            signal = 2 * coded_bits - 1; % 转换为±1
        end
        
        function bits_per_symbol = get_bits_per_symbol(obj, constellation_type)
            % 获取每符号比特数
            
            switch constellation_type
                case 'BPSK'
                    bits_per_symbol = 1;
                case 'QPSK'
                    bits_per_symbol = 2;
                case '16QAM'
                    bits_per_symbol = 4;
                case '64QAM'
                    bits_per_symbol = 6;
                otherwise
                    bits_per_symbol = 2; % 默认
            end
        end
        
        function modulated_data = modulate_subcarriers(obj, data, constellation_type)
            % 子载波调制
            
            bits_per_symbol = obj.get_bits_per_symbol(constellation_type);
            num_symbols = length(data) / bits_per_symbol;
            
            % 重新整形数据
            data_matrix = reshape(data, bits_per_symbol, num_symbols)';
            
            % 根据调制类型进行调制
            switch constellation_type
                case 'BPSK'
                    modulated_data = 2*data_matrix - 1; % ±1
                case 'QPSK'
                    constellation = [1+1j, -1+1j, -1-1j, 1-1j] / sqrt(2);
                    symbol_values = data_matrix(:,1)*2 + data_matrix(:,2);
                    modulated_data = constellation(symbol_values + 1)';
                case '16QAM'
                    % 简化的16QAM星座
                    I = 2*(data_matrix(:,1)*2 + data_matrix(:,2)) - 3; % -3,-1,1,3
                    Q = 2*(data_matrix(:,3)*2 + data_matrix(:,4)) - 3;
                    modulated_data = (I + 1j*Q) / sqrt(10);
                case '64QAM'
                    % 简化的64QAM星座
                    I = 2*(data_matrix(:,1)*4 + data_matrix(:,2)*2 + data_matrix(:,3)) - 7;
                    Q = 2*(data_matrix(:,4)*4 + data_matrix(:,5)*2 + data_matrix(:,6)) - 7;
                    modulated_data = (I + 1j*Q) / sqrt(42);
                otherwise
                    modulated_data = 2*data_matrix(:,1) - 1; % 默认BPSK
            end
        end
    end
end
