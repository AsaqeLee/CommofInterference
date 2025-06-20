classdef SweepJamming < JammingBase
    % SweepJamming - 阻塞式扫频干扰
    % 实现线性调频(LFM)扫频干扰信号，扫频周期0.5ms
    %
    % 作者: Asaqe Lee
    % 日期: 2025-06-20
    
    properties (Constant)
        JAMMING_ID = 7                    % 干扰信号ID
        JAMMING_NAME = '阻塞式扫频干扰'    % 干扰信号名称
        JAMMING_TYPE = 'LFM'              % 干扰类型
        CATEGORY = 'barrage'              % 干扰类别
    end
    
    properties (Access = private)
        sweep_bandwidth     % 扫频带宽 (Hz)
        sweep_period       % 扫频周期 (s)
        sweep_direction    % 扫频方向 ('up', 'down', 'triangle')
        sweep_rate         % 扫频速率 (Hz/s)
        
        % LFM参数
        chirp_rate         % 线性调频率 (Hz/s)
        start_frequency    % 起始频率 (Hz)
        stop_frequency     % 结束频率 (Hz)
        
        % 内部状态
        current_time       % 当前时间
        current_frequency  % 当前瞬时频率
        phase_accumulator  % 相位累加器
        sweep_cycle_count  % 扫频周期计数
    end
    
    methods
        function obj = SweepJamming(config)
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
            % 生成扫频干扰信号
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
            
            % 生成扫频信号
            signal = obj.generate_lfm_signal(t);
            
            % 功率调整
            signal_power = mean(abs(signal).^2);
            target_power = obj.power_watts;
            if signal_power > 0
                signal = signal * sqrt(target_power / signal_power);
            end
            
            % 确保输出为行向量
            signal = signal(:).';
            
            % 更新内部状态
            obj.current_time = obj.current_time + signal_length / obj.sample_rate;
        end
        
        function signal = generate_lfm_signal(obj, t)
            % 生成LFM信号
            % 输入: t - 时间向量
            % 输出: signal - LFM信号
            
            signal = zeros(size(t));
            
            for i = 1:length(t)
                % 计算当前时间在扫频周期中的位置
                cycle_time = mod(obj.current_time + t(i), obj.sweep_period);
                
                % 根据扫频方向计算瞬时频率
                inst_freq = obj.calculate_instantaneous_frequency(cycle_time);
                
                % 计算相位（频率的积分）
                if i == 1
                    phase = obj.phase_accumulator;
                else
                    % 使用梯形积分计算相位
                    dt = t(i) - t(i-1);
                    prev_freq = obj.calculate_instantaneous_frequency(mod(obj.current_time + t(i-1), obj.sweep_period));
                    phase_increment = 2*pi * (prev_freq + inst_freq) * dt / 2;
                    phase = phase + phase_increment;
                end
                
                % 生成复指数信号
                signal(i) = exp(1j * phase);
            end
            
            % 更新相位累加器
            if ~isempty(t)
                final_cycle_time = mod(obj.current_time + t(end), obj.sweep_period);
                final_freq = obj.calculate_instantaneous_frequency(final_cycle_time);
                obj.phase_accumulator = phase;
                obj.current_frequency = final_freq;
            end
        end
        
        function inst_freq = calculate_instantaneous_frequency(obj, cycle_time)
            % 计算瞬时频率
            % 输入: cycle_time - 周期内时间
            % 输出: inst_freq - 瞬时频率
            
            switch obj.sweep_direction
                case 'up'
                    % 上扫频
                    progress = cycle_time / obj.sweep_period;
                    inst_freq = obj.start_frequency + progress * obj.sweep_bandwidth;
                    
                case 'down'
                    % 下扫频
                    progress = cycle_time / obj.sweep_period;
                    inst_freq = obj.stop_frequency - progress * obj.sweep_bandwidth;
                    
                case 'triangle'
                    % 三角波扫频
                    half_period = obj.sweep_period / 2;
                    if cycle_time <= half_period
                        % 上扫频阶段
                        progress = cycle_time / half_period;
                        inst_freq = obj.start_frequency + progress * obj.sweep_bandwidth;
                    else
                        % 下扫频阶段
                        progress = (cycle_time - half_period) / half_period;
                        inst_freq = obj.stop_frequency - progress * obj.sweep_bandwidth;
                    end
                    
                otherwise
                    inst_freq = obj.center_frequency;
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
            
            % 计算时频域覆盖效果
            % 使用短时傅里叶变换分析时频特性
            window_length = round(0.001 * obj.sample_rate);  % 1ms窗口
            overlap = round(window_length * 0.5);
            
            % 计算目标信号的时频图
            [~, ~, ~, target_spectrogram] = spectrogram(target_signal, window_length, overlap);
            [~, ~, ~, jammed_spectrogram] = spectrogram(jammed_signal, window_length, overlap);
            
            % 计算时频域能量比
            target_energy = sum(abs(target_spectrogram(:)).^2);
            jammed_energy = sum(abs(jammed_spectrogram(:)).^2);
            
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
            
            if isfield(config, 'power_dbm')
                obj.power_dbm = config.power_dbm;
            end
            
            if isfield(config, 'sample_rate')
                obj.sample_rate = config.sample_rate;
            end
            
            if isfield(config, 'duration')
                obj.duration = config.duration;
            end
            
            if isfield(config, 'sweep_bandwidth')
                obj.sweep_bandwidth = config.sweep_bandwidth;
            end
            
            if isfield(config, 'sweep_period')
                obj.sweep_period = config.sweep_period;
            end
            
            if isfield(config, 'sweep_direction')
                obj.sweep_direction = config.sweep_direction;
            end
            
            % 计算扫频参数
            obj.calculate_sweep_parameters();
            
            % 验证参数
            obj.validate_parameters();
            
            fprintf('扫频干扰配置完成: 扫频带宽=%.1fMHz, 周期=%.2fms, 方向=%s\n', ...
                    obj.sweep_bandwidth/1e6, obj.sweep_period*1e3, obj.sweep_direction);
        end
        
        function obj = set_sweep_parameters(obj, bandwidth, period, direction)
            % 设置扫频参数
            % 输入: bandwidth - 扫频带宽 (Hz)
            %      period - 扫频周期 (s)
            %      direction - 扫频方向
            
            assert(bandwidth > 0, 'SweepJamming:InvalidBandwidth', '扫频带宽必须大于0');
            assert(period > 0, 'SweepJamming:InvalidPeriod', '扫频周期必须大于0');
            
            valid_directions = {'up', 'down', 'triangle'};
            if ~ismember(direction, valid_directions)
                error('SweepJamming:InvalidDirection', '无效的扫频方向: %s', direction);
            end
            
            obj.sweep_bandwidth = bandwidth;
            obj.sweep_period = period;
            obj.sweep_direction = direction;
            
            % 重新计算扫频参数
            obj.calculate_sweep_parameters();
            
            fprintf('扫频参数设置: 带宽=%.1fMHz, 周期=%.2fms, 方向=%s, 速率=%.1fMHz/s\n', ...
                    bandwidth/1e6, period*1e3, direction, obj.sweep_rate/1e6);
        end
        
        function calculate_sweep_parameters(obj)
            % 计算扫频参数
            
            % 计算扫频速率
            if strcmp(obj.sweep_direction, 'triangle')
                % 三角波扫频，一个周期内扫两次
                obj.sweep_rate = 2 * obj.sweep_bandwidth / obj.sweep_period;
            else
                % 单向扫频
                obj.sweep_rate = obj.sweep_bandwidth / obj.sweep_period;
            end
            
            % 计算线性调频率
            obj.chirp_rate = obj.sweep_rate;
            
            % 计算起始和结束频率
            obj.start_frequency = obj.center_frequency - obj.sweep_bandwidth / 2;
            obj.stop_frequency = obj.center_frequency + obj.sweep_bandwidth / 2;
            
            % 更新带宽
            obj.bandwidth = obj.sweep_bandwidth;
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
            spectrum.sweep_bandwidth = obj.sweep_bandwidth;
            spectrum.sweep_period = obj.sweep_period;
            spectrum.sweep_rate = obj.sweep_rate;
            spectrum.sweep_direction = obj.sweep_direction;
        end
        
        function plot_spectrum(obj, signal_length)
            % 绘制频谱
            % 输入: signal_length - 信号长度
            
            spectrum = obj.analyze_spectrum(signal_length);
            
            figure('Name', '扫频干扰频谱', 'NumberTitle', 'off');
            
            subplot(2,1,1);
            plot(spectrum.frequencies/1e6, spectrum.power_db, 'b-', 'LineWidth', 1.5);
            xlabel('频率 (MHz)');
            ylabel('功率 (dB)');
            title(sprintf('扫频干扰频谱 - %s扫频, 带宽%.1fMHz, 周期%.2fms', ...
                         obj.sweep_direction, obj.sweep_bandwidth/1e6, obj.sweep_period*1e3));
            grid on;
            
            % 标记扫频范围
            hold on;
            plot([obj.start_frequency, obj.start_frequency]/1e6, ylim, 'r--', 'LineWidth', 1);
            plot([obj.stop_frequency, obj.stop_frequency]/1e6, ylim, 'r--', 'LineWidth', 1);
            plot(obj.center_frequency/1e6, max(spectrum.power_db), 'ro', 'MarkerSize', 8, 'LineWidth', 2);
            legend('频谱', '扫频起点', '扫频终点', '中心频率', 'Location', 'best');
            
            subplot(2,1,2);
            plot(spectrum.frequencies/1e6, spectrum.phase, 'r-', 'LineWidth', 1.5);
            xlabel('频率 (MHz)');
            ylabel('相位 (rad)');
            title('相位谱');
            grid on;
        end
        
        function plot_time_frequency(obj, signal_length)
            % 绘制时频图
            % 输入: signal_length - 信号长度
            
            if nargin < 2
                signal_length = round(0.01 * obj.sample_rate);  % 10ms
            end
            
            % 生成测试信号
            test_signal = obj.generate_jamming_signal([], struct());
            test_signal = test_signal(1:min(signal_length, length(test_signal)));
            
            % 计算时频图
            window_length = round(0.0005 * obj.sample_rate);  % 0.5ms窗口
            overlap = round(window_length * 0.8);
            
            [S, F, T] = spectrogram(test_signal, window_length, overlap, [], obj.sample_rate);
            
            figure('Name', '扫频干扰时频图', 'NumberTitle', 'off');
            
            subplot(2,1,1);
            imagesc(T*1e3, F/1e6, 20*log10(abs(S)));
            axis xy;
            xlabel('时间 (ms)');
            ylabel('频率 (MHz)');
            title(sprintf('扫频干扰时频图 - %s扫频', obj.sweep_direction));
            colorbar;
            colormap('jet');
            
            % 叠加理论扫频轨迹
            hold on;
            t_theory = linspace(0, max(T), 1000);
            f_theory = zeros(size(t_theory));
            
            for i = 1:length(t_theory)
                cycle_time = mod(t_theory(i), obj.sweep_period);
                f_theory(i) = obj.calculate_instantaneous_frequency(cycle_time);
            end
            
            plot(t_theory*1e3, f_theory/1e6, 'w-', 'LineWidth', 2);
            legend('时频图', '理论轨迹', 'Location', 'best');
            
            subplot(2,1,2);
            % 绘制瞬时频率
            t = (0:length(test_signal)-1) / obj.sample_rate;
            inst_phase = unwrap(angle(test_signal));
            inst_freq = [0, diff(inst_phase)] * obj.sample_rate / (2*pi);
            
            plot(t*1e3, inst_freq/1e6, 'b-', 'LineWidth', 1.5);
            xlabel('时间 (ms)');
            ylabel('瞬时频率 (MHz)');
            title('瞬时频率变化');
            grid on;
            
            % 叠加理论值
            hold on;
            plot(t_theory*1e3, f_theory/1e6, 'r--', 'LineWidth', 1);
            legend('实际瞬时频率', '理论瞬时频率', 'Location', 'best');
        end
        
        function obj = reset(obj)
            % 重置干扰信号状态
            obj.current_time = 0;
            obj.current_frequency = obj.start_frequency;
            obj.phase_accumulator = 0;
            obj.sweep_cycle_count = 0;
            
            fprintf('扫频干扰状态已重置\n');
        end
        
        function print_status(obj)
            % 打印状态信息
            fprintf('=== %s 状态 ===\n', obj.JAMMING_NAME);
            fprintf('ID: %d\n', obj.JAMMING_ID);
            fprintf('类型: %s\n', obj.JAMMING_TYPE);
            fprintf('类别: %s\n', obj.CATEGORY);
            fprintf('中心频率: %.2f MHz\n', obj.center_frequency / 1e6);
            fprintf('扫频带宽: %.1f MHz\n', obj.sweep_bandwidth / 1e6);
            fprintf('扫频周期: %.2f ms\n', obj.sweep_period * 1e3);
            fprintf('扫频方向: %s\n', obj.sweep_direction);
            fprintf('扫频速率: %.1f MHz/s\n', obj.sweep_rate / 1e6);
            fprintf('线性调频率: %.1f MHz/s\n', obj.chirp_rate / 1e6);
            fprintf('起始频率: %.2f MHz\n', obj.start_frequency / 1e6);
            fprintf('结束频率: %.2f MHz\n', obj.stop_frequency / 1e6);
            fprintf('当前频率: %.2f MHz\n', obj.current_frequency / 1e6);
            fprintf('功率: %.1f dBm (%.2e W)\n', obj.power_dbm, obj.power_watts);
            fprintf('采样率: %.2f MHz\n', obj.sample_rate / 1e6);
            fprintf('持续时间: %.3f s\n', obj.duration);
            fprintf('当前时间: %.3f s\n', obj.current_time);
            fprintf('扫频周期数: %d\n', obj.sweep_cycle_count);
            fprintf('状态: %s\n', obj.is_active ? '激活' : '停用');
            fprintf('========================\n');
        end
    end
    
    methods (Access = protected)
        function initialize_default_parameters(obj)
            % 初始化默认参数
            obj.initialize_default_parameters@JammingBase();
            
            obj.sweep_bandwidth = 20e6;      % 20 MHz扫频带宽
            obj.sweep_period = 0.5e-3;       % 0.5 ms扫频周期
            obj.sweep_direction = 'up';      % 上扫频
            
            obj.current_time = 0;
            obj.current_frequency = obj.center_frequency;
            obj.phase_accumulator = 0;
            obj.sweep_cycle_count = 0;
            
            % 计算扫频参数
            obj.calculate_sweep_parameters();
        end
        
        function validate_parameters(obj)
            % 验证参数有效性
            obj.validate_parameters@JammingBase();
            
            assert(obj.sweep_bandwidth > 0, 'SweepJamming:InvalidSweepBW', ...
                   '扫频带宽必须大于0');
            assert(obj.sweep_period > 0, 'SweepJamming:InvalidSweepPeriod', ...
                   '扫频周期必须大于0');
            assert(obj.sweep_bandwidth <= obj.sample_rate/2, 'SweepJamming:SweepBWTooHigh', ...
                   '扫频带宽不能超过奈奎斯特频率');
            
            valid_directions = {'up', 'down', 'triangle'};
            assert(ismember(obj.sweep_direction, valid_directions), ...
                   'SweepJamming:InvalidDirection', '无效的扫频方向');
        end
    end
end
