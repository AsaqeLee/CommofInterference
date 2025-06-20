classdef SingleToneJamming < JammingBase
    % SingleToneJamming - 瞄准式单音干扰
    % 实现单一频率连续波(CW)干扰信号
    %
    % 作者: Asaqe Lee
    % 日期: 2025-06-20
    
    properties (Constant)
        JAMMING_ID = 1                    % 干扰信号ID
        JAMMING_NAME = '瞄准式单音干扰'    % 干扰信号名称
        JAMMING_TYPE = 'CW'               % 干扰类型
        CATEGORY = 'targeted'             % 干扰类别
    end
    
    properties (Access = private)
        tone_frequency        % 单音频率 (Hz)
        phase_offset         % 相位偏移 (rad)
        amplitude            % 幅度
        
        % 内部状态
        current_sample       % 当前采样点
        phase_accumulator    % 相位累加器
    end
    
    methods
        function obj = SingleToneJamming(config)
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
            % 生成单音干扰信号
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
            
            % 生成单音信号
            signal = obj.amplitude * exp(1j * (2*pi*obj.tone_frequency*t + obj.phase_offset));
            
            % 确保输出为行向量
            signal = signal(:).';
            
            % 更新内部状态
            obj.current_sample = obj.current_sample + signal_length;
            obj.phase_accumulator = mod(obj.phase_accumulator + 2*pi*obj.tone_frequency*signal_length/obj.sample_rate, 2*pi);
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
            
            % 计算信号功率
            target_power = mean(abs(target_signal).^2);
            jammed_power = mean(abs(jammed_signal).^2);
            
            % 计算功率增加比例
            if target_power > 0
                power_ratio = jammed_power / target_power;
                effectiveness = min((power_ratio - 1), 1);  % 限制在0-1之间
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
                obj.tone_frequency = config.center_frequency;  % 单音频率等于中心频率
            end
            
            if isfield(config, 'tone_frequency')
                obj.tone_frequency = config.tone_frequency;
            end
            
            if isfield(config, 'power_dbm')
                obj.power_dbm = config.power_dbm;
                obj.amplitude = sqrt(obj.power_watts);
            end
            
            if isfield(config, 'sample_rate')
                obj.sample_rate = config.sample_rate;
            end
            
            if isfield(config, 'duration')
                obj.duration = config.duration;
            end
            
            if isfield(config, 'phase_offset')
                obj.phase_offset = config.phase_offset;
            end
            
            % 验证参数
            obj.validate_parameters();
            
            fprintf('单音干扰配置完成: 频率=%.2fMHz, 功率=%.1fdBm\n', ...
                    obj.tone_frequency/1e6, obj.power_dbm);
        end
        
        function obj = set_tone_frequency(obj, frequency)
            % 设置单音频率
            % 输入: frequency - 频率 (Hz)
            
            assert(frequency > 0, 'SingleToneJamming:InvalidFreq', '频率必须大于0');
            assert(frequency <= obj.sample_rate/2, 'SingleToneJamming:Nyquist', ...
                   '频率不能超过奈奎斯特频率');
            
            obj.tone_frequency = frequency;
            obj.center_frequency = frequency;  % 更新中心频率
            
            fprintf('单音频率设置为: %.2f MHz\n', frequency/1e6);
        end
        
        function obj = set_phase_offset(obj, phase_rad)
            % 设置相位偏移
            % 输入: phase_rad - 相位偏移 (弧度)
            
            obj.phase_offset = mod(phase_rad, 2*pi);
            
            fprintf('相位偏移设置为: %.2f rad (%.1f°)\n', ...
                    obj.phase_offset, obj.phase_offset*180/pi);
        end
        
        function obj = adjust_frequency_to_target(obj, target_frequency, offset_hz)
            % 调整频率以瞄准目标
            % 输入: target_frequency - 目标频率 (Hz)
            %      offset_hz - 频率偏移 (Hz, 可选)
            
            if nargin < 3
                offset_hz = 0;
            end
            
            new_frequency = target_frequency + offset_hz;
            obj.set_tone_frequency(new_frequency);
            
            fprintf('单音频率调整为目标频率: %.2f MHz (偏移: %.1f kHz)\n', ...
                    new_frequency/1e6, offset_hz/1e3);
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
            spectrum.peak_frequency = obj.tone_frequency;
            spectrum.peak_power_db = max(spectrum.power_db);
        end
        
        function plot_spectrum(obj, signal_length)
            % 绘制频谱
            % 输入: signal_length - 信号长度
            
            spectrum = obj.analyze_spectrum(signal_length);
            
            figure('Name', '单音干扰频谱', 'NumberTitle', 'off');
            
            subplot(2,1,1);
            plot(spectrum.frequencies/1e6, spectrum.power_db, 'b-', 'LineWidth', 1.5);
            xlabel('频率 (MHz)');
            ylabel('功率 (dB)');
            title(sprintf('单音干扰频谱 - 频率: %.2f MHz', obj.tone_frequency/1e6));
            grid on;
            
            % 标记峰值
            hold on;
            plot(obj.tone_frequency/1e6, spectrum.peak_power_db, 'ro', 'MarkerSize', 8, 'LineWidth', 2);
            legend('频谱', '峰值', 'Location', 'best');
            
            subplot(2,1,2);
            plot(spectrum.frequencies/1e6, spectrum.phase, 'r-', 'LineWidth', 1.5);
            xlabel('频率 (MHz)');
            ylabel('相位 (rad)');
            title('相位谱');
            grid on;
        end
        
        function obj = reset(obj)
            % 重置干扰信号状态
            obj.current_sample = 0;
            obj.phase_accumulator = 0;
            
            fprintf('单音干扰状态已重置\n');
        end
        
        function print_status(obj)
            % 打印状态信息
            fprintf('=== %s 状态 ===\n', obj.JAMMING_NAME);
            fprintf('ID: %d\n', obj.JAMMING_ID);
            fprintf('类型: %s\n', obj.JAMMING_TYPE);
            fprintf('类别: %s\n', obj.CATEGORY);
            fprintf('单音频率: %.2f MHz\n', obj.tone_frequency / 1e6);
            fprintf('功率: %.1f dBm (%.2e W)\n', obj.power_dbm, obj.power_watts);
            fprintf('相位偏移: %.2f rad (%.1f°)\n', obj.phase_offset, obj.phase_offset*180/pi);
            fprintf('采样率: %.2f MHz\n', obj.sample_rate / 1e6);
            fprintf('持续时间: %.3f s\n', obj.duration);
            fprintf('状态: %s\n', obj.is_active ? '激活' : '停用');
            fprintf('当前采样点: %d\n', obj.current_sample);
            fprintf('相位累加器: %.3f rad\n', obj.phase_accumulator);
            fprintf('========================\n');
        end
    end
    
    methods (Access = protected)
        function initialize_default_parameters(obj)
            % 初始化默认参数
            obj.initialize_default_parameters@JammingBase();
            
            obj.tone_frequency = obj.center_frequency;  % 默认等于中心频率
            obj.phase_offset = 0;                       % 零相位偏移
            obj.amplitude = sqrt(obj.power_watts);      % 根据功率计算幅度
            
            obj.current_sample = 0;
            obj.phase_accumulator = 0;
        end
        
        function validate_parameters(obj)
            % 验证参数有效性
            obj.validate_parameters@JammingBase();
            
            assert(obj.tone_frequency > 0, 'SingleToneJamming:InvalidToneFreq', ...
                   '单音频率必须大于0');
            assert(obj.tone_frequency <= obj.sample_rate/2, 'SingleToneJamming:Nyquist', ...
                   '单音频率不能超过奈奎斯特频率');
            assert(obj.amplitude >= 0, 'SingleToneJamming:InvalidAmp', ...
                   '幅度必须非负');
        end
    end
end
