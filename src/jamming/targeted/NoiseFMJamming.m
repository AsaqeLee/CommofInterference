classdef NoiseFMJamming < JammingBase
    % NoiseFMJamming - 瞄准式噪声调频干扰
    % 实现高斯白噪声调频的干扰信号
    %
    % 作者: Asaqe Lee
    % 日期: 2025-06-20
    
    properties (Constant)
        JAMMING_ID = 4                    % 干扰信号ID
        JAMMING_NAME = '瞄准式噪声调频干扰'  % 干扰信号名称
        JAMMING_TYPE = 'FM'               % 干扰类型
        CATEGORY = 'targeted'             % 干扰类别
    end
    
    properties (Access = private)
        noise_bandwidth      % 噪声带宽 (Hz)
        fm_deviation        % FM偏移 (Hz)
        modulation_index    % 调制指数
        noise_power         % 噪声功率
        
        % 滤波器参数
        noise_filter        % 噪声滤波器
        filter_order        % 滤波器阶数
        
        % 内部状态
        current_phase       % 当前相位
        phase_accumulator   % 相位累加器
        noise_state         % 噪声生成器状态
        filter_state        % 滤波器状态
    end
    
    methods
        function obj = NoiseFMJamming(config)
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
            % 生成噪声调频干扰信号
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
            
            % 生成时间向量
            t = (0:signal_length-1) / obj.sample_rate;
            
            % 生成高斯白噪声
            noise = obj.generate_filtered_noise(signal_length);
            
            % FM调制
            % 相位是噪声的积分
            phase_deviation = 2*pi*obj.fm_deviation * cumsum(noise) / obj.sample_rate;
            
            % 生成FM信号
            instantaneous_phase = 2*pi*obj.center_frequency*t + phase_deviation + obj.current_phase;
            signal = sqrt(obj.power_watts) * exp(1j * instantaneous_phase);
            
            % 确保输出为行向量
            signal = signal(:).';
            
            % 更新内部状态
            obj.current_phase = mod(obj.current_phase + 2*pi*obj.center_frequency*signal_length/obj.sample_rate, 2*pi);
            obj.phase_accumulator = mod(obj.phase_accumulator + phase_deviation(end), 2*pi);
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
            
            % 计算瞬时频率变化
            target_phase = unwrap(angle(target_signal));
            jammed_phase = unwrap(angle(jammed_signal));
            
            target_freq = diff(target_phase) * obj.sample_rate / (2*pi);
            jammed_freq = diff(jammed_phase) * obj.sample_rate / (2*pi);
            
            % 计算频率方差增加
            target_freq_var = var(target_freq);
            jammed_freq_var = var(jammed_freq);
            
            if target_freq_var > 0
                freq_var_ratio = jammed_freq_var / target_freq_var;
                effectiveness = min(log10(freq_var_ratio) / 2, 1);
            else
                effectiveness = 0.5;  % 默认值
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
            
            if isfield(config, 'power_dbm')
                obj.power_dbm = config.power_dbm;
            end
            
            if isfield(config, 'sample_rate')
                obj.sample_rate = config.sample_rate;
            end
            
            if isfield(config, 'duration')
                obj.duration = config.duration;
            end
            
            if isfield(config, 'noise_bandwidth')
                obj.noise_bandwidth = config.noise_bandwidth;
            end
            
            if isfield(config, 'fm_deviation')
                obj.fm_deviation = config.fm_deviation;
            end
            
            % 计算调制指数
            obj.modulation_index = obj.fm_deviation / obj.noise_bandwidth;
            
            % 设计噪声滤波器
            obj.design_noise_filter();
            
            % 验证参数
            obj.validate_parameters();
            
            fprintf('噪声FM干扰配置完成: 噪声带宽=%.1fkHz, FM偏移=%.1fkHz, 调制指数=%.2f\n', ...
                    obj.noise_bandwidth/1e3, obj.fm_deviation/1e3, obj.modulation_index);
        end
        
        function obj = set_noise_bandwidth(obj, bandwidth)
            % 设置噪声带宽
            % 输入: bandwidth - 噪声带宽 (Hz)
            
            assert(bandwidth > 0, 'NoiseFMJamming:InvalidBandwidth', '噪声带宽必须大于0');
            assert(bandwidth <= obj.sample_rate/4, 'NoiseFMJamming:BandwidthTooHigh', ...
                   '噪声带宽不能超过采样率的1/4');
            
            obj.noise_bandwidth = bandwidth;
            obj.modulation_index = obj.fm_deviation / obj.noise_bandwidth;
            
            % 重新设计滤波器
            obj.design_noise_filter();
            
            fprintf('噪声带宽设置为: %.1f kHz\n', bandwidth/1e3);
        end
        
        function obj = set_fm_deviation(obj, deviation)
            % 设置FM偏移
            % 输入: deviation - FM偏移 (Hz)
            
            assert(deviation > 0, 'NoiseFMJamming:InvalidDeviation', 'FM偏移必须大于0');
            
            obj.fm_deviation = deviation;
            obj.modulation_index = obj.fm_deviation / obj.noise_bandwidth;
            
            fprintf('FM偏移设置为: %.1f kHz (调制指数: %.2f)\n', ...
                    deviation/1e3, obj.modulation_index);
        end
        
        function noise = generate_filtered_noise(obj, signal_length)
            % 生成滤波后的噪声
            % 输入: signal_length - 信号长度
            % 输出: noise - 滤波后的噪声
            
            % 生成高斯白噪声
            white_noise = randn(1, signal_length);
            
            % 应用带限滤波器
            if ~isempty(obj.noise_filter)
                noise = filter(obj.noise_filter, white_noise);
            else
                noise = white_noise;
            end
            
            % 功率归一化
            noise_power = mean(noise.^2);
            if noise_power > 0
                noise = noise * sqrt(obj.noise_power / noise_power);
            end
        end
        
        function design_noise_filter(obj)
            % 设计噪声滤波器
            
            % 归一化截止频率
            nyquist_freq = obj.sample_rate / 2;
            normalized_cutoff = obj.noise_bandwidth / (2 * nyquist_freq);
            
            % 确保截止频率在有效范围内
            normalized_cutoff = min(normalized_cutoff, 0.95);
            
            try
                % 设计Butterworth低通滤波器
                obj.filter_order = 6;  % 6阶滤波器
                [b, a] = butter(obj.filter_order, normalized_cutoff, 'low');
                obj.noise_filter = {b, a};
                
            catch ME
                fprintf('滤波器设计失败: %s\n', ME.message);
                obj.noise_filter = [];
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
            spectrum.noise_bandwidth = obj.noise_bandwidth;
            spectrum.fm_deviation = obj.fm_deviation;
            spectrum.modulation_index = obj.modulation_index;
            
            % 计算有效带宽 (Carson规则)
            spectrum.carson_bandwidth = 2 * (obj.fm_deviation + obj.noise_bandwidth);
        end
        
        function plot_spectrum(obj, signal_length)
            % 绘制频谱
            % 输入: signal_length - 信号长度
            
            spectrum = obj.analyze_spectrum(signal_length);
            
            figure('Name', '噪声FM干扰频谱', 'NumberTitle', 'off');
            
            subplot(3,1,1);
            plot(spectrum.frequencies/1e6, spectrum.power_db, 'b-', 'LineWidth', 1.5);
            xlabel('频率 (MHz)');
            ylabel('功率 (dB)');
            title(sprintf('噪声FM干扰频谱 - 调制指数%.2f', obj.modulation_index));
            grid on;
            
            % 标记中心频率和Carson带宽
            hold on;
            fc = obj.center_frequency;
            carson_bw = spectrum.carson_bandwidth;
            plot([fc-carson_bw/2, fc-carson_bw/2]/1e6, ylim, 'r--', 'LineWidth', 1);
            plot([fc+carson_bw/2, fc+carson_bw/2]/1e6, ylim, 'r--', 'LineWidth', 1);
            plot(fc/1e6, max(spectrum.power_db), 'ro', 'MarkerSize', 8, 'LineWidth', 2);
            legend('频谱', 'Carson带宽', '', '中心频率', 'Location', 'best');
            
            subplot(3,1,2);
            plot(spectrum.frequencies/1e6, spectrum.phase, 'r-', 'LineWidth', 1.5);
            xlabel('频率 (MHz)');
            ylabel('相位 (rad)');
            title('相位谱');
            grid on;
            
            % 绘制瞬时频率
            subplot(3,1,3);
            t = (0:length(test_signal)-1) / obj.sample_rate;
            inst_phase = unwrap(angle(test_signal));
            inst_freq = [0, diff(inst_phase)] * obj.sample_rate / (2*pi);
            plot(t*1e3, (inst_freq - obj.center_frequency)/1e3, 'g-', 'LineWidth', 1);
            xlabel('时间 (ms)');
            ylabel('频率偏移 (kHz)');
            title('瞬时频率偏移');
            grid on;
        end
        
        function plot_time_domain(obj, signal_length)
            % 绘制时域波形
            % 输入: signal_length - 信号长度
            
            if nargin < 2
                signal_length = round(0.01 * obj.sample_rate);  % 10ms
            end
            
            % 生成测试信号
            test_signal = obj.generate_jamming_signal([], struct());
            test_signal = test_signal(1:min(signal_length, length(test_signal)));
            
            t = (0:length(test_signal)-1) / obj.sample_rate;
            
            figure('Name', '噪声FM干扰时域波形', 'NumberTitle', 'off');
            
            subplot(3,1,1);
            plot(t*1e3, real(test_signal), 'b-', 'LineWidth', 1);
            xlabel('时间 (ms)');
            ylabel('幅度');
            title('实部');
            grid on;
            
            subplot(3,1,2);
            plot(t*1e3, imag(test_signal), 'r-', 'LineWidth', 1);
            xlabel('时间 (ms)');
            ylabel('幅度');
            title('虚部');
            grid on;
            
            subplot(3,1,3);
            envelope = abs(test_signal);
            plot(t*1e3, envelope, 'g-', 'LineWidth', 1.5);
            xlabel('时间 (ms)');
            ylabel('包络');
            title('信号包络');
            grid on;
        end
        
        function obj = reset(obj)
            % 重置干扰信号状态
            obj.current_phase = 0;
            obj.phase_accumulator = 0;
            obj.noise_state = [];
            obj.filter_state = [];
            
            fprintf('噪声FM干扰状态已重置\n');
        end
        
        function print_status(obj)
            % 打印状态信息
            fprintf('=== %s 状态 ===\n', obj.JAMMING_NAME);
            fprintf('ID: %d\n', obj.JAMMING_ID);
            fprintf('类型: %s\n', obj.JAMMING_TYPE);
            fprintf('类别: %s\n', obj.CATEGORY);
            fprintf('中心频率: %.2f MHz\n', obj.center_frequency / 1e6);
            fprintf('噪声带宽: %.1f kHz\n', obj.noise_bandwidth / 1e3);
            fprintf('FM偏移: %.1f kHz\n', obj.fm_deviation / 1e3);
            fprintf('调制指数: %.2f\n', obj.modulation_index);
            fprintf('Carson带宽: %.1f kHz\n', 2*(obj.fm_deviation + obj.noise_bandwidth)/1e3);
            fprintf('功率: %.1f dBm (%.2e W)\n', obj.power_dbm, obj.power_watts);
            fprintf('滤波器阶数: %d\n', obj.filter_order);
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
            
            obj.noise_bandwidth = 50e3;      % 50 kHz噪声带宽
            obj.fm_deviation = 25e3;         % 25 kHz FM偏移
            obj.modulation_index = 0.5;      % 调制指数
            obj.noise_power = 1.0;           % 单位噪声功率
            obj.filter_order = 6;            % 6阶滤波器
            
            obj.current_phase = 0;
            obj.phase_accumulator = 0;
            obj.noise_state = [];
            obj.filter_state = [];
            
            % 设计默认滤波器
            obj.design_noise_filter();
        end
        
        function validate_parameters(obj)
            % 验证参数有效性
            obj.validate_parameters@JammingBase();
            
            assert(obj.noise_bandwidth > 0, 'NoiseFMJamming:InvalidNoiseBW', ...
                   '噪声带宽必须大于0');
            assert(obj.fm_deviation > 0, 'NoiseFMJamming:InvalidFMDev', ...
                   'FM偏移必须大于0');
            assert(obj.noise_bandwidth <= obj.sample_rate/4, 'NoiseFMJamming:NoiseBWTooHigh', ...
                   '噪声带宽不能超过采样率的1/4');
            assert(obj.modulation_index > 0, 'NoiseFMJamming:InvalidModIndex', ...
                   '调制指数必须大于0');
        end
    end
end
