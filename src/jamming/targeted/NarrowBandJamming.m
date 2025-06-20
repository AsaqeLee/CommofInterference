classdef NarrowBandJamming < JammingBase
    % NarrowBandJamming - 瞄准式窄带干扰
    % 实现QPSK/16QAM调制的窄带干扰信号，带宽10kHz
    %
    % 作者: Asaqe Lee
    % 日期: 2025-06-20
    
    properties (Constant)
        JAMMING_ID = 3                    % 干扰信号ID
        JAMMING_NAME = '瞄准式窄带干扰'    % 干扰信号名称
        JAMMING_TYPE = 'QPSK/16QAM'       % 干扰类型
        CATEGORY = 'targeted'             % 干扰类别
    end
    
    properties (Access = private)
        modulation_type      % 调制类型 ('QPSK', '16QAM')
        symbol_rate         % 符号速率 (sps)
        pulse_shaping       % 脉冲成形滤波器
        roll_off_factor     % 滚降因子
        
        % 调制参数
        constellation       % 星座图
        bit_per_symbol      % 每符号比特数
        
        % 内部状态
        current_phase       % 当前相位
        symbol_buffer       % 符号缓冲区
        filter_state        % 滤波器状态
    end
    
    methods
        function obj = NarrowBandJamming(config)
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
            % 生成窄带干扰信号
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
            carrier = exp(1j * (2*pi*obj.center_frequency*t + obj.current_phase));
            modulated_signal = filtered_signal .* carrier;
            
            % 截取到所需长度
            if length(modulated_signal) > signal_length
                signal = modulated_signal(1:signal_length);
            else
                signal = [modulated_signal, zeros(1, signal_length - length(modulated_signal))];
            end
            
            % 功率调整
            signal_power = mean(abs(signal).^2);
            target_power = obj.power_watts;
            if signal_power > 0
                signal = signal * sqrt(target_power / signal_power);
            end
            
            % 确保输出为行向量
            signal = signal(:).';
            
            % 更新内部状态
            obj.current_phase = mod(obj.current_phase + 2*pi*obj.center_frequency*length(signal)/obj.sample_rate, 2*pi);
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
            
            % 计算频域重叠度
            target_spectrum = fft(target_signal);
            jammed_spectrum = fft(jammed_signal);
            
            % 计算功率谱密度
            target_psd = abs(target_spectrum).^2;
            jammed_psd = abs(jammed_spectrum).^2;
            
            % 计算干扰效果（基于功率增加和频谱重叠）
            power_increase = mean(jammed_psd) / mean(target_psd);
            effectiveness = min(log10(power_increase) / 2, 1);  % 限制在0-1之间
            
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
            
            % 根据调制类型设置参数
            obj.setup_modulation_parameters();
            
            % 验证参数
            obj.validate_parameters();
            
            fprintf('窄带干扰配置完成: %s调制, 带宽=%.1fkHz, 符号率=%.1fksps\n', ...
                    obj.modulation_type, obj.bandwidth/1e3, obj.symbol_rate/1e3);
        end
        
        function obj = set_modulation_type(obj, mod_type)
            % 设置调制类型
            % 输入: mod_type - 调制类型 ('QPSK', '16QAM')
            
            supported_types = {'QPSK', '16QAM'};
            if ~ismember(mod_type, supported_types)
                error('NarrowBandJamming:UnsupportedModulation', ...
                      '不支持的调制类型: %s', mod_type);
            end
            
            obj.modulation_type = mod_type;
            obj.setup_modulation_parameters();
            
            fprintf('调制类型设置为: %s\n', mod_type);
        end
        
        function obj = set_symbol_rate(obj, symbol_rate)
            % 设置符号速率
            % 输入: symbol_rate - 符号速率 (sps)
            
            assert(symbol_rate > 0, 'NarrowBandJamming:InvalidSymbolRate', '符号速率必须大于0');
            assert(symbol_rate <= obj.sample_rate/4, 'NarrowBandJamming:SymbolRateTooHigh', ...
                   '符号速率不能超过采样率的1/4');
            
            obj.symbol_rate = symbol_rate;
            
            fprintf('符号速率设置为: %.1f ksps\n', symbol_rate/1e3);
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
            spectrum.bandwidth = obj.bandwidth;
            spectrum.modulation_type = obj.modulation_type;
        end
        
        function plot_spectrum(obj, signal_length)
            % 绘制频谱
            % 输入: signal_length - 信号长度
            
            spectrum = obj.analyze_spectrum(signal_length);
            
            figure('Name', '窄带干扰频谱', 'NumberTitle', 'off');
            
            subplot(2,1,1);
            plot(spectrum.frequencies/1e6, spectrum.power_db, 'b-', 'LineWidth', 1.5);
            xlabel('频率 (MHz)');
            ylabel('功率 (dB)');
            title(sprintf('窄带干扰频谱 - %s调制, 带宽%.1fkHz', ...
                         obj.modulation_type, obj.bandwidth/1e3));
            grid on;
            
            % 标记中心频率和带宽
            hold on;
            fc = obj.center_frequency;
            bw = obj.bandwidth;
            plot([fc-bw/2, fc-bw/2]/1e6, ylim, 'r--', 'LineWidth', 1);
            plot([fc+bw/2, fc+bw/2]/1e6, ylim, 'r--', 'LineWidth', 1);
            plot(fc/1e6, max(spectrum.power_db), 'ro', 'MarkerSize', 8, 'LineWidth', 2);
            legend('频谱', '带宽边界', '', '中心频率', 'Location', 'best');
            
            subplot(2,1,2);
            plot(spectrum.frequencies/1e6, spectrum.phase, 'r-', 'LineWidth', 1.5);
            xlabel('频率 (MHz)');
            ylabel('相位 (rad)');
            title('相位谱');
            grid on;
        end
        
        function plot_constellation(obj)
            % 绘制星座图
            figure('Name', '窄带干扰星座图', 'NumberTitle', 'off');
            
            % 生成测试符号
            test_bits = randi([0, 1], 1, 1000 * obj.bit_per_symbol);
            test_symbols = obj.bits_to_symbols(test_bits);
            
            scatter(real(test_symbols), imag(test_symbols), 'b.');
            xlabel('同相分量');
            ylabel('正交分量');
            title(sprintf('%s星座图', obj.modulation_type));
            grid on;
            axis equal;
            
            % 添加理想星座点
            hold on;
            ideal_constellation = obj.constellation;
            scatter(real(ideal_constellation), imag(ideal_constellation), ...
                    'ro', 'MarkerSize', 10, 'LineWidth', 2);
            legend('接收符号', '理想星座点', 'Location', 'best');
        end
        
        function obj = reset(obj)
            % 重置干扰信号状态
            obj.current_phase = 0;
            obj.symbol_buffer = [];
            obj.filter_state = [];
            
            fprintf('窄带干扰状态已重置\n');
        end
        
        function print_status(obj)
            % 打印状态信息
            fprintf('=== %s 状态 ===\n', obj.JAMMING_NAME);
            fprintf('ID: %d\n', obj.JAMMING_ID);
            fprintf('类型: %s\n', obj.JAMMING_TYPE);
            fprintf('类别: %s\n', obj.CATEGORY);
            fprintf('调制类型: %s\n', obj.modulation_type);
            fprintf('中心频率: %.2f MHz\n', obj.center_frequency / 1e6);
            fprintf('带宽: %.1f kHz\n', obj.bandwidth / 1e3);
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
            obj.bandwidth = 10e3;             % 10 kHz带宽
            obj.symbol_rate = 8e3;            % 8 ksps符号率
            obj.pulse_shaping = 'rrc';        % 根升余弦滤波
            obj.roll_off_factor = 0.35;       % 滚降因子
            
            obj.current_phase = 0;
            obj.symbol_buffer = [];
            obj.filter_state = [];
            
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
            
            assert(obj.symbol_rate > 0, 'NarrowBandJamming:InvalidSymbolRate', ...
                   '符号速率必须大于0');
            assert(obj.symbol_rate <= obj.sample_rate/4, 'NarrowBandJamming:SymbolRateTooHigh', ...
                   '符号速率不能超过采样率的1/4');
            assert(obj.bandwidth > 0, 'NarrowBandJamming:InvalidBandwidth', ...
                   '带宽必须大于0');
            assert(ismember(obj.modulation_type, {'QPSK', '16QAM'}), ...
                   'NarrowBandJamming:InvalidModulation', '不支持的调制类型');
        end
    end
end
