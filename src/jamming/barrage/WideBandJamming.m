classdef WideBandJamming < JammingBase
    % WideBandJamming - 阻塞式宽带干扰
    % 实现QPSK/16QAM调制的宽带干扰信号，覆盖通信带宽
    %
    % 作者: Asaqe Lee
    % 日期: 2025-06-20
    
    properties (Constant)
        JAMMING_ID = 5                    % 干扰信号ID
        JAMMING_NAME = '阻塞式宽带干扰'    % 干扰信号名称
        JAMMING_TYPE = 'QPSK/16QAM'       % 干扰类型
        CATEGORY = 'barrage'              % 干扰类别
    end
    
    properties (Access = private)
        modulation_type      % 调制类型 ('QPSK', '16QAM')
        symbol_rate         % 符号速率 (sps)
        pulse_shaping       % 脉冲成形滤波器
        roll_off_factor     % 滚降因子
        
        % 宽带参数
        coverage_bandwidth  % 覆盖带宽 (Hz)
        num_carriers       % 载波数量
        carrier_spacing    % 载波间隔 (Hz)
        
        % 调制参数
        constellation       % 星座图
        bit_per_symbol      % 每符号比特数
        
        % 内部状态
        carrier_phases      % 各载波相位
        symbol_buffers      % 符号缓冲区
        filter_states       % 滤波器状态
    end
    
    methods
        function obj = WideBandJamming(config)
            % 构造函数
            % 输入: config - 配置参数
            
            obj@JammingBase();
            
            if nargin > 0
                obj = obj.configure_parameters(config);
            else
                obj.initialize_default_parameters();
            end
        end
        
        function signal = generate_jamming_signal(obj, target_signal, params)
            % 生成宽带干扰信号
            % 输入: target_signal - 目标通信信号
            %      params - 参数
            % 输出: signal - 干扰信号
            
            % 参数解析
            if nargin < 3
                params = struct();
            end
            
            % 获取信号长度
            if ~isempty(target_signal)
                signal_length = length(target_signal);
            else
                signal_length = round(obj.duration * obj.sample_rate);
            end
            
            % 初始化输出信号
            signal = zeros(1, signal_length);
            
            % 生成各个载波的信号并叠加
            for i = 1:obj.num_carriers
                carrier_freq = obj.center_frequency + (i - (obj.num_carriers+1)/2) * obj.carrier_spacing;
                carrier_signal = obj.generate_single_carrier_signal(carrier_freq, signal_length, i);
                signal = signal + carrier_signal;
            end
            
            % 功率归一化
            signal_power = mean(abs(signal).^2);
            target_power = obj.power_watts;
            if signal_power > 0
                signal = signal * sqrt(target_power / signal_power);
            end
            
            % 确保输出为行向量
            signal = signal(:).';
        end
        
        function carrier_signal = generate_single_carrier_signal(obj, carrier_freq, signal_length, carrier_idx)
            % 生成单个载波信号
            % 输入: carrier_freq - 载波频率
            %      signal_length - 信号长度
            %      carrier_idx - 载波索引
            % 输出: carrier_signal - 载波信号
            
            % 计算需要的符号数
            samples_per_symbol = round(obj.sample_rate / obj.symbol_rate);
            num_symbols = ceil(signal_length / samples_per_symbol);
            
            % 生成随机数据比特
            num_bits = num_symbols * obj.bit_per_symbol;
            data_bits = randi([0, 1], 1, num_bits);
            
            % 比特到符号映射
            symbols = obj.bits_to_symbols(data_bits);
            
            % 上采样
            upsampled_symbols = obj.upsample_symbols(symbols, samples_per_symbol);
            
            % 脉冲成形滤波
            filtered_signal = obj.apply_pulse_shaping(upsampled_symbols);
            
            % 载波调制
            t = (0:length(filtered_signal)-1) / obj.sample_rate;
            carrier_phase = obj.carrier_phases(carrier_idx);
            carrier = exp(1j * (2*pi*carrier_freq*t + carrier_phase));
            modulated_signal = filtered_signal .* carrier;
            
            % 截取到所需长度
            if length(modulated_signal) > signal_length
                carrier_signal = modulated_signal(1:signal_length);
            else
                carrier_signal = [modulated_signal, zeros(1, signal_length - length(modulated_signal))];
            end
            
            % 更新载波相位
            obj.carrier_phases(carrier_idx) = mod(carrier_phase + 2*pi*carrier_freq*length(carrier_signal)/obj.sample_rate, 2*pi);
        end
        
        function effectiveness = calculate_effectiveness(obj, target_signal, jammed_signal)
            % 计算干扰效果
            % 输入: target_signal - 目标信号
            %      jammed_signal - 被干扰信号
            % 输出: effectiveness - 干扰效果 (0-1)
            
            if isempty(target_signal) || isempty(jammed_signal)
                effectiveness = 0;
                return;
            end
            
            % 计算频域覆盖度
            N = length(target_signal);
            target_spectrum = abs(fft(target_signal)).^2;
            jammed_spectrum = abs(fft(jammed_signal)).^2;
            
            % 计算频谱能量比
            target_energy = sum(target_spectrum);
            jammed_energy = sum(jammed_spectrum);
            
            if target_energy > 0
                energy_ratio = jammed_energy / target_energy;
                effectiveness = min(log10(energy_ratio) / 2, 1);
            else
                effectiveness = 0;
            end
            
            % 更新干扰效果
            obj.jamming_effectiveness = effectiveness;
        end
        
        function obj = configure_parameters(obj, config)
            % 配置参数
            % 输入: config - 配置结构体
            
            % 基础参数配置
            if isfield(config, 'center_frequency')
                obj.center_frequency = config.center_frequency;
            end
            
            if isfield(config, 'bandwidth')
                obj.bandwidth = config.bandwidth;
                obj.coverage_bandwidth = config.bandwidth;
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
            
            if isfield(config, 'modulation_type')
                obj.modulation_type = config.modulation_type;
            end
            
            if isfield(config, 'symbol_rate')
                obj.symbol_rate = config.symbol_rate;
            end
            
            % 计算载波参数
            obj.calculate_carrier_parameters();
            
            % 根据调制类型设置参数
            obj.setup_modulation_parameters();
            
            % 验证参数
            obj.validate_parameters();
            
            fprintf('宽带干扰配置完成: %s调制, 覆盖带宽=%.1fMHz, %d个载波\n', ...
                    obj.modulation_type, obj.coverage_bandwidth/1e6, obj.num_carriers);
        end
        
        function obj = set_coverage_bandwidth(obj, bandwidth)
            % 设置覆盖带宽
            % 输入: bandwidth - 覆盖带宽 (Hz)
            
            assert(bandwidth > 0, 'WideBandJamming:InvalidBandwidth', '覆盖带宽必须大于0');
            assert(bandwidth <= obj.sample_rate/2, 'WideBandJamming:BandwidthTooHigh', ...
                   '覆盖带宽不能超过奈奎斯特频率');
            
            obj.coverage_bandwidth = bandwidth;
            obj.bandwidth = bandwidth;
            
            % 重新计算载波参数
            obj.calculate_carrier_parameters();
            
            fprintf('覆盖带宽设置为: %.1f MHz (%d个载波)\n', ...
                    bandwidth/1e6, obj.num_carriers);
        end
        
        function obj = set_num_carriers(obj, num_carriers)
            % 设置载波数量
            % 输入: num_carriers - 载波数量
            
            assert(num_carriers > 0, 'WideBandJamming:InvalidCarriers', '载波数量必须大于0');
            assert(num_carriers <= 64, 'WideBandJamming:TooManyCarriers', '载波数量不能超过64');
            
            obj.num_carriers = num_carriers;
            obj.carrier_spacing = obj.coverage_bandwidth / obj.num_carriers;
            
            % 重新初始化载波状态
            obj.carrier_phases = zeros(1, obj.num_carriers);
            obj.symbol_buffers = cell(1, obj.num_carriers);
            obj.filter_states = cell(1, obj.num_carriers);
            
            fprintf('载波数量设置为: %d (间隔: %.1f kHz)\n', ...
                    num_carriers, obj.carrier_spacing/1e3);
        end
        
        function calculate_carrier_parameters(obj)
            % 计算载波参数
            
            % 根据符号速率和覆盖带宽计算载波数量
            min_carrier_spacing = obj.symbol_rate * 1.2;  % 1.2倍符号速率间隔
            max_carriers = floor(obj.coverage_bandwidth / min_carrier_spacing);
            
            % 限制载波数量在合理范围内
            obj.num_carriers = min(max(max_carriers, 1), 32);
            obj.carrier_spacing = obj.coverage_bandwidth / obj.num_carriers;
            
            % 初始化载波状态
            obj.carrier_phases = zeros(1, obj.num_carriers);
            obj.symbol_buffers = cell(1, obj.num_carriers);
            obj.filter_states = cell(1, obj.num_carriers);
        end
        
        function symbols = bits_to_symbols(obj, bits)
            % 比特到符号映射
            % 输入: bits - 比特序列
            % 输出: symbols - 符号序列
            
            num_bits = length(bits);
            num_symbols = floor(num_bits / obj.bit_per_symbol);
            
            % 重新整理比特
            bits = bits(1:num_symbols * obj.bit_per_symbol);
            bit_matrix = reshape(bits, obj.bit_per_symbol, num_symbols).';
            
            switch obj.modulation_type
                case 'QPSK'
                    symbols = obj.qpsk_mapping(bit_matrix);
                case '16QAM'
                    symbols = obj.qam16_mapping(bit_matrix);
            end
        end
        
        function symbols = qpsk_mapping(obj, bit_matrix)
            % QPSK映射
            % 输入: bit_matrix - 比特矩阵 (N×2)
            % 输出: symbols - QPSK符号
            
            % Gray码映射
            I = 2*bit_matrix(:,1) - 1;  % 0->-1, 1->1
            Q = 2*bit_matrix(:,2) - 1;  % 0->-1, 1->1
            
            symbols = (I + 1j*Q) / sqrt(2);  % 归一化功率
        end
        
        function symbols = qam16_mapping(obj, bit_matrix)
            % 16QAM映射
            % 输入: bit_matrix - 比特矩阵 (N×4)
            % 输出: symbols - 16QAM符号
            
            % Gray码映射
            I_bits = bit_matrix(:,1:2);
            Q_bits = bit_matrix(:,3:4);
            
            % 转换为十进制
            I_dec = I_bits(:,1)*2 + I_bits(:,2);
            Q_dec = Q_bits(:,1)*2 + Q_bits(:,2);
            
            % 映射到星座点
            constellation_map = [-3, -1, 1, 3];
            I = constellation_map(I_dec + 1);
            Q = constellation_map(Q_dec + 1);
            
            symbols = (I + 1j*Q) / sqrt(10);  % 归一化功率
        end
        
        function upsampled = upsample_symbols(obj, symbols, samples_per_symbol)
            % 符号上采样
            % 输入: symbols - 符号序列
            %      samples_per_symbol - 每符号采样数
            % 输出: upsampled - 上采样后的信号
            
            upsampled = zeros(1, length(symbols) * samples_per_symbol);
            upsampled(1:samples_per_symbol:end) = symbols;
        end
        
        function filtered_signal = apply_pulse_shaping(obj, signal)
            % 应用脉冲成形滤波
            % 输入: signal - 输入信号
            % 输出: filtered_signal - 滤波后的信号
            
            if strcmp(obj.pulse_shaping, 'rrc')
                % 根升余弦滤波器
                filter_span = 6;  % 滤波器跨度
                samples_per_symbol = round(obj.sample_rate / obj.symbol_rate);
                
                % 设计RRC滤波器
                rrc_filter = rcosdesign(obj.roll_off_factor, filter_span, samples_per_symbol, 'sqrt');
                
                % 滤波
                filtered_signal = conv(signal, rrc_filter, 'same');
            else
                % 无滤波
                filtered_signal = signal;
            end
        end
        
        function spectrum = analyze_spectrum(obj, signal_length)
            % 分析频谱
            % 输入: signal_length - 信号长度
            % 输出: spectrum - 频谱结构体
            
            if nargin < 2
                signal_length = round(obj.duration * obj.sample_rate);
            end
            
            % 生成测试信号
            test_signal = obj.generate_jamming_signal([], struct());
            
            % FFT分析
            N = length(test_signal);
            f = (-N/2:N/2-1) * obj.sample_rate / N;
            S = fftshift(fft(test_signal));
            
            spectrum = struct();
            spectrum.frequencies = f;
            spectrum.magnitude = abs(S);
            spectrum.phase = angle(S);
            spectrum.power_db = 20*log10(abs(S) + eps);
            spectrum.center_frequency = obj.center_frequency;
            spectrum.coverage_bandwidth = obj.coverage_bandwidth;
            spectrum.num_carriers = obj.num_carriers;
            spectrum.carrier_spacing = obj.carrier_spacing;
            spectrum.modulation_type = obj.modulation_type;
        end
        
        function plot_spectrum(obj, signal_length)
            % 绘制频谱
            % 输入: signal_length - 信号长度
            
            spectrum = obj.analyze_spectrum(signal_length);
            
            figure('Name', '宽带干扰频谱', 'NumberTitle', 'off');
            
            subplot(2,1,1);
            plot(spectrum.frequencies/1e6, spectrum.power_db, 'b-', 'LineWidth', 1.5);
            xlabel('频率 (MHz)');
            ylabel('功率 (dB)');
            title(sprintf('宽带干扰频谱 - %s调制, %d载波, 覆盖%.1fMHz', ...
                         obj.modulation_type, obj.num_carriers, obj.coverage_bandwidth/1e6));
            grid on;
            
            % 标记覆盖带宽
            hold on;
            fc = obj.center_frequency;
            bw = obj.coverage_bandwidth;
            plot([fc-bw/2, fc-bw/2]/1e6, ylim, 'r--', 'LineWidth', 1);
            plot([fc+bw/2, fc+bw/2]/1e6, ylim, 'r--', 'LineWidth', 1);
            plot(fc/1e6, max(spectrum.power_db), 'ro', 'MarkerSize', 8, 'LineWidth', 2);
            
            % 标记各载波位置
            for i = 1:obj.num_carriers
                carrier_freq = fc + (i - (obj.num_carriers+1)/2) * obj.carrier_spacing;
                plot(carrier_freq/1e6, max(spectrum.power_db)-10, 'g^', 'MarkerSize', 6);
            end
            
            legend('频谱', '覆盖带宽', '', '中心频率', '载波位置', 'Location', 'best');
            
            subplot(2,1,2);
            plot(spectrum.frequencies/1e6, spectrum.phase, 'r-', 'LineWidth', 1.5);
            xlabel('频率 (MHz)');
            ylabel('相位 (rad)');
            title('相位谱');
            grid on;
        end
        
        function obj = reset(obj)
            % 重置干扰信号状态
            obj.carrier_phases = zeros(1, obj.num_carriers);
            obj.symbol_buffers = cell(1, obj.num_carriers);
            obj.filter_states = cell(1, obj.num_carriers);
            
            fprintf('宽带干扰状态已重置\n');
        end
        
        function print_status(obj)
            % 打印状态信息
            fprintf('=== %s 状态 ===\n', obj.JAMMING_NAME);
            fprintf('ID: %d\n', obj.JAMMING_ID);
            fprintf('类型: %s\n', obj.JAMMING_TYPE);
            fprintf('类别: %s\n', obj.CATEGORY);
            fprintf('调制类型: %s\n', obj.modulation_type);
            fprintf('中心频率: %.2f MHz\n', obj.center_frequency / 1e6);
            fprintf('覆盖带宽: %.1f MHz\n', obj.coverage_bandwidth / 1e6);
            fprintf('载波数量: %d\n', obj.num_carriers);
            fprintf('载波间隔: %.1f kHz\n', obj.carrier_spacing / 1e3);
            fprintf('符号速率: %.1f ksps\n', obj.symbol_rate / 1e3);
            fprintf('每符号比特数: %d\n', obj.bit_per_symbol);
            fprintf('功率: %.1f dBm (%.2e W)\n', obj.power_dbm, obj.power_watts);
            fprintf('脉冲成形: %s\n', obj.pulse_shaping);
            fprintf('滚降因子: %.2f\n', obj.roll_off_factor);
            fprintf('采样率: %.2f MHz\n', obj.sample_rate / 1e6);
            fprintf('持续时间: %.3f s\n', obj.duration);
            fprintf('状态: %s\n', obj.is_active ? '激活' : '停用');
            fprintf('========================\n');
        end
    end
    
    methods (Access = protected)
        function initialize_default_parameters(obj)
            % 初始化默认参数
            obj.initialize_default_parameters@JammingBase();
            
            obj.modulation_type = 'QPSK';     % 默认QPSK
            obj.coverage_bandwidth = 20e6;    % 20 MHz覆盖带宽
            obj.symbol_rate = 16e6;           % 16 Msps符号率
            obj.pulse_shaping = 'rrc';        % 根升余弦滤波
            obj.roll_off_factor = 0.35;       % 滚降因子
            
            % 计算载波参数
            obj.calculate_carrier_parameters();
            
            obj.setup_modulation_parameters();
        end
        
        function setup_modulation_parameters(obj)
            % 设置调制参数
            switch obj.modulation_type
                case 'QPSK'
                    obj.bit_per_symbol = 2;
                    obj.constellation = [1+1j, -1+1j, 1-1j, -1-1j] / sqrt(2);
                case '16QAM'
                    obj.bit_per_symbol = 4;
                    I_levels = [-3, -1, 1, 3];
                    Q_levels = [-3, -1, 1, 3];
                    [I_grid, Q_grid] = meshgrid(I_levels, Q_levels);
                    obj.constellation = (I_grid(:) + 1j*Q_grid(:)).' / sqrt(10);
            end
        end
        
        function validate_parameters(obj)
            % 验证参数有效性
            obj.validate_parameters@JammingBase();
            
            assert(obj.coverage_bandwidth > 0, 'WideBandJamming:InvalidCoverageBW', ...
                   '覆盖带宽必须大于0');
            assert(obj.symbol_rate > 0, 'WideBandJamming:InvalidSymbolRate', ...
                   '符号速率必须大于0');
            assert(obj.num_carriers > 0, 'WideBandJamming:InvalidCarriers', ...
                   '载波数量必须大于0');
            assert(ismember(obj.modulation_type, {'QPSK', '16QAM'}), ...
                   'WideBandJamming:InvalidModulation', '不支持的调制类型');
        end
    end
end
