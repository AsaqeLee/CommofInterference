classdef MultiToneJamming < JammingBase
    % MultiToneJamming - 瞄准式多音干扰
    % 实现多个频率组合的连续波(CW)干扰信号
    %
    % 作者: Asaqe Lee
    % 日期: 2025-06-20
    
    properties (Constant)
        JAMMING_ID = 2                    % 干扰信号ID
        JAMMING_NAME = '瞄准式多音干扰'    % 干扰信号名称
        JAMMING_TYPE = 'CW'               % 干扰类型
        CATEGORY = 'targeted'             % 干扰类别
    end
    
    properties (Access = private)
        tone_frequencies     % 多音频率数组 (Hz)
        tone_powers         % 各音功率数组 (dBm)
        tone_phases         % 各音相位数组 (rad)
        tone_amplitudes     % 各音幅度数组
        
        % 内部状态
        current_sample      % 当前采样点
        phase_accumulators  % 各音相位累加器
        num_tones          % 音调数量
    end
    
    methods
        function obj = MultiToneJamming(config)
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
            % 生成多音干扰信号
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
            
            % 初始化信号
            signal = zeros(1, signal_length);
            
            % 生成各个音调并叠加
            for i = 1:obj.num_tones
                tone_signal = obj.tone_amplitudes(i) * ...
                             exp(1j * (2*pi*obj.tone_frequencies(i)*t + obj.tone_phases(i)));
                signal = signal + tone_signal;
            end
            
            % 确保输出为行向量
            signal = signal(:).';
            
            % 更新内部状态
            obj.current_sample = obj.current_sample + signal_length;
            for i = 1:obj.num_tones
                obj.phase_accumulators(i) = mod(obj.phase_accumulators(i) + ...
                    2*pi*obj.tone_frequencies(i)*signal_length/obj.sample_rate, 2*pi);
            end
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
            end
            
            if isfield(config, 'tone_frequencies')
                obj.tone_frequencies = config.tone_frequencies;
                obj.num_tones = length(obj.tone_frequencies);
            end
            
            if isfield(config, 'tone_powers')
                obj.tone_powers = config.tone_powers;
                % 确保功率数组长度与频率数组一致
                if length(obj.tone_powers) ~= obj.num_tones
                    obj.tone_powers = repmat(obj.tone_powers(1), 1, obj.num_tones);
                end
            end
            
            if isfield(config, 'power_dbm')
                obj.power_dbm = config.power_dbm;
                % 如果没有单独设置各音功率，则平均分配
                if isempty(obj.tone_powers)
                    obj.tone_powers = repmat(config.power_dbm, 1, obj.num_tones);
                end
            end
            
            if isfield(config, 'sample_rate')
                obj.sample_rate = config.sample_rate;
            end
            
            if isfield(config, 'duration')
                obj.duration = config.duration;
            end
            
            % 计算各音幅度和相位
            obj.calculate_tone_parameters();
            
            % 验证参数
            obj.validate_parameters();
            
            fprintf('多音干扰配置完成: %d个音调, 频率范围=%.2f-%.2fMHz\n', ...
                    obj.num_tones, min(obj.tone_frequencies)/1e6, max(obj.tone_frequencies)/1e6);
        end
        
        function obj = set_tone_frequencies(obj, frequencies)
            % 设置多音频率
            % 输入: frequencies - 频率数组 (Hz)
            
            assert(all(frequencies > 0), 'MultiToneJamming:InvalidFreq', '所有频率必须大于0');
            assert(all(frequencies <= obj.sample_rate/2), 'MultiToneJamming:Nyquist', ...
                   '所有频率不能超过奈奎斯特频率');
            
            obj.tone_frequencies = frequencies(:).';  % 确保为行向量
            obj.num_tones = length(obj.tone_frequencies);
            
            % 重新计算参数
            obj.calculate_tone_parameters();
            
            fprintf('多音频率设置完成: %d个音调\n', obj.num_tones);
            for i = 1:obj.num_tones
                fprintf('  音调%d: %.2f MHz\n', i, obj.tone_frequencies(i)/1e6);
            end
        end
        
        function obj = set_tone_powers(obj, powers_dbm)
            % 设置各音功率
            % 输入: powers_dbm - 功率数组 (dBm)
            
            if length(powers_dbm) == 1
                % 如果只给出一个功率值，则所有音调使用相同功率
                obj.tone_powers = repmat(powers_dbm, 1, obj.num_tones);
            else
                assert(length(powers_dbm) == obj.num_tones, 'MultiToneJamming:PowerMismatch', ...
                       '功率数组长度必须与音调数量一致');
                obj.tone_powers = powers_dbm(:).';  % 确保为行向量
            end
            
            % 重新计算幅度
            obj.calculate_tone_parameters();
            
            fprintf('多音功率设置完成:\n');
            for i = 1:obj.num_tones
                fprintf('  音调%d: %.1f dBm\n', i, obj.tone_powers(i));
            end
        end
        
        function obj = add_tone(obj, frequency, power_dbm, phase_rad)
            % 添加音调
            % 输入: frequency - 频率 (Hz)
            %      power_dbm - 功率 (dBm)
            %      phase_rad - 相位 (rad, 可选)
            
            if nargin < 4
                phase_rad = 0;
            end
            
            % 验证输入
            assert(frequency > 0, 'MultiToneJamming:InvalidFreq', '频率必须大于0');
            assert(frequency <= obj.sample_rate/2, 'MultiToneJamming:Nyquist', ...
                   '频率不能超过奈奎斯特频率');
            
            % 添加到数组
            obj.tone_frequencies(end+1) = frequency;
            obj.tone_powers(end+1) = power_dbm;
            obj.tone_phases(end+1) = phase_rad;
            obj.num_tones = obj.num_tones + 1;
            
            % 重新计算参数
            obj.calculate_tone_parameters();
            
            fprintf('添加音调: 频率=%.2fMHz, 功率=%.1fdBm, 相位=%.2frad\n', ...
                    frequency/1e6, power_dbm, phase_rad);
        end
        
        function obj = remove_tone(obj, index)
            % 移除音调
            % 输入: index - 音调索引
            
            assert(index >= 1 && index <= obj.num_tones, 'MultiToneJamming:InvalidIndex', ...
                   '音调索引超出范围');
            
            % 从数组中移除
            obj.tone_frequencies(index) = [];
            obj.tone_powers(index) = [];
            obj.tone_phases(index) = [];
            obj.num_tones = obj.num_tones - 1;
            
            % 重新计算参数
            obj.calculate_tone_parameters();
            
            fprintf('移除音调%d\n', index);
        end
        
        function obj = adjust_frequencies_to_target(obj, target_frequency, spacing_hz)
            % 调整频率以瞄准目标
            % 输入: target_frequency - 目标频率 (Hz)
            %      spacing_hz - 音调间隔 (Hz)
            
            if nargin < 3
                spacing_hz = 1e6;  % 默认1MHz间隔
            end
            
            % 生成对称分布的频率
            if obj.num_tones == 1
                new_frequencies = target_frequency;
            else
                half_span = (obj.num_tones - 1) * spacing_hz / 2;
                new_frequencies = target_frequency + (-half_span:spacing_hz:half_span);
            end
            
            obj.set_tone_frequencies(new_frequencies);
            
            fprintf('多音频率调整为目标频率: %.2f MHz (间隔: %.1f kHz)\n', ...
                    target_frequency/1e6, spacing_hz/1e3);
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
            spectrum.tone_frequencies = obj.tone_frequencies;
            spectrum.num_tones = obj.num_tones;
        end
        
        function plot_spectrum(obj, signal_length)
            % 绘制频谱
            % 输入: signal_length - 信号长度
            
            spectrum = obj.analyze_spectrum(signal_length);
            
            figure('Name', '多音干扰频谱', 'NumberTitle', 'off');
            
            subplot(2,1,1);
            plot(spectrum.frequencies/1e6, spectrum.power_db, 'b-', 'LineWidth', 1.5);
            xlabel('频率 (MHz)');
            ylabel('功率 (dB)');
            title(sprintf('多音干扰频谱 - %d个音调', obj.num_tones));
            grid on;
            
            % 标记各个音调
            hold on;
            for i = 1:obj.num_tones
                [~, idx] = min(abs(spectrum.frequencies - obj.tone_frequencies(i)));
                plot(obj.tone_frequencies(i)/1e6, spectrum.power_db(idx), 'ro', ...
                     'MarkerSize', 8, 'LineWidth', 2);
            end
            legend('频谱', '音调峰值', 'Location', 'best');
            
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
            obj.phase_accumulators = zeros(1, obj.num_tones);
            
            fprintf('多音干扰状态已重置\n');
        end
        
        function print_status(obj)
            % 打印状态信息
            fprintf('=== %s 状态 ===\n', obj.JAMMING_NAME);
            fprintf('ID: %d\n', obj.JAMMING_ID);
            fprintf('类型: %s\n', obj.JAMMING_TYPE);
            fprintf('类别: %s\n', obj.CATEGORY);
            fprintf('音调数量: %d\n', obj.num_tones);
            
            for i = 1:obj.num_tones
                fprintf('  音调%d: %.2f MHz, %.1f dBm, %.2f rad\n', ...
                        i, obj.tone_frequencies(i)/1e6, obj.tone_powers(i), obj.tone_phases(i));
            end
            
            fprintf('采样率: %.2f MHz\n', obj.sample_rate / 1e6);
            fprintf('持续时间: %.3f s\n', obj.duration);
            fprintf('状态: %s\n', obj.is_active ? '激活' : '停用');
            fprintf('当前采样点: %d\n', obj.current_sample);
            fprintf('========================\n');
        end
    end
    
    methods (Access = protected)
        function initialize_default_parameters(obj)
            % 初始化默认参数
            obj.initialize_default_parameters@JammingBase();
            
            % 默认3个音调，间隔1MHz
            obj.tone_frequencies = [99e6, 100e6, 101e6];
            obj.tone_powers = [0, 0, 0];  % 0 dBm
            obj.tone_phases = [0, 0, 0];  % 零相位
            obj.num_tones = 3;
            
            obj.current_sample = 0;
            obj.phase_accumulators = zeros(1, obj.num_tones);
            
            obj.calculate_tone_parameters();
        end
        
        function calculate_tone_parameters(obj)
            % 计算各音调参数
            if isempty(obj.tone_frequencies)
                return;
            end
            
            % 确保数组长度一致
            if length(obj.tone_powers) ~= obj.num_tones
                obj.tone_powers = repmat(obj.power_dbm, 1, obj.num_tones);
            end
            
            if length(obj.tone_phases) ~= obj.num_tones
                obj.tone_phases = zeros(1, obj.num_tones);
            end
            
            % 计算各音幅度
            obj.tone_amplitudes = zeros(1, obj.num_tones);
            for i = 1:obj.num_tones
                power_watts = 10^((obj.tone_powers(i) - 30) / 10);
                obj.tone_amplitudes(i) = sqrt(power_watts);
            end
            
            % 初始化相位累加器
            if length(obj.phase_accumulators) ~= obj.num_tones
                obj.phase_accumulators = zeros(1, obj.num_tones);
            end
        end
        
        function validate_parameters(obj)
            % 验证参数有效性
            obj.validate_parameters@JammingBase();
            
            assert(obj.num_tones > 0, 'MultiToneJamming:NoTones', '必须至少有一个音调');
            assert(all(obj.tone_frequencies > 0), 'MultiToneJamming:InvalidToneFreq', ...
                   '所有音调频率必须大于0');
            assert(all(obj.tone_frequencies <= obj.sample_rate/2), 'MultiToneJamming:Nyquist', ...
                   '所有音调频率不能超过奈奎斯特频率');
            assert(all(obj.tone_amplitudes >= 0), 'MultiToneJamming:InvalidAmp', ...
                   '所有音调幅度必须非负');
        end
    end
end
