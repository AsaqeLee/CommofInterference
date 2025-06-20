classdef CombSpectrumJamming < JammingBase
    % CombSpectrumJamming - 阻塞式宽带梳状谱干扰
    % 实现高斯白噪声+梳状滤波器的干扰信号，产生3个梳状谱
    %
    % 作者: Asaqe Lee
    % 日期: 2025-06-20
    
    properties (Constant)
        JAMMING_ID = 6                    % 干扰信号ID
        JAMMING_NAME = '阻塞式宽带梳状谱干扰'  % 干扰信号名称
        JAMMING_TYPE = '高斯白噪声+梳状滤波器'  % 干扰类型
        CATEGORY = 'barrage'              % 干扰类别
    end
    
    properties (Access = private)
        comb_spacing         % 梳状间隔 (Hz)
        comb_count          % 梳状数量
        comb_bandwidth      % 单个梳状带宽 (Hz)
        noise_power         % 噪声功率
        
        % 滤波器参数
        comb_filters        % 梳状滤波器组
        filter_order        % 滤波器阶数
        filter_type         % 滤波器类型
        
        % 梳状谱参数
        comb_frequencies    % 梳状频率
        comb_weights        % 梳状权重
        
        % 内部状态
        filter_states       % 滤波器状态
        noise_buffer        % 噪声缓冲区
    end
    
    methods
        function obj = CombSpectrumJamming(config)
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
            % 生成梳状谱干扰信号
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
            
            % 生成高斯白噪声
            white_noise = sqrt(obj.noise_power) * randn(1, signal_length);
            
            % 初始化输出信号
            signal = zeros(1, signal_length);
            
            % 通过各个梳状滤波器并叠加
            for i = 1:obj.comb_count
                % 设计单个梳状滤波器
                comb_filter = obj.design_single_comb_filter(i);
                
                % 滤波
                if ~isempty(comb_filter)
                    filtered_noise = filter(comb_filter.b, comb_filter.a, white_noise);
                else
                    filtered_noise = white_noise;
                end
                
                % 载波调制到对应频率
                t = (0:signal_length-1) / obj.sample_rate;
                carrier_freq = obj.comb_frequencies(i);
                carrier = exp(1j * 2*pi*carrier_freq*t);
                modulated_signal = filtered_noise .* carrier;
                
                % 加权叠加
                signal = signal + obj.comb_weights(i) * modulated_signal;
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
        
        function comb_filter = design_single_comb_filter(obj, comb_index)
            % 设计单个梳状滤波器
            % 输入: comb_index - 梳状索引
            % 输出: comb_filter - 滤波器结构体
            
            try
                % 计算归一化频率
                nyquist_freq = obj.sample_rate / 2;
                
                % 梳状滤波器的通带
                center_freq = 0;  % 基带滤波器
                bandwidth = obj.comb_bandwidth;
                
                % 归一化截止频率
                low_cutoff = max(-bandwidth/2, -nyquist_freq*0.9) / nyquist_freq;
                high_cutoff = min(bandwidth/2, nyquist_freq*0.9) / nyquist_freq;
                
                % 确保频率在有效范围内
                low_cutoff = max(low_cutoff, 0.01);
                high_cutoff = min(high_cutoff, 0.99);
                
                if high_cutoff > low_cutoff
                    % 设计带通滤波器
                    [b, a] = butter(obj.filter_order, [low_cutoff, high_cutoff], 'bandpass');
                    comb_filter.b = b;
                    comb_filter.a = a;
                else
                    % 如果频率范围无效，返回全通滤波器
                    comb_filter.b = 1;
                    comb_filter.a = 1;
                end
                
            catch ME
                fprintf('梳状滤波器%d设计失败: %s\n', comb_index, ME.message);
                % 返回全通滤波器
                comb_filter.b = 1;
                comb_filter.a = 1;
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
            
            % 计算频域梳状特征
            N = length(target_signal);
            target_spectrum = abs(fft(target_signal)).^2;
            jammed_spectrum = abs(fft(jammed_signal)).^2;
            
            % 计算梳状谱的覆盖效果
            f = (0:N-1) * obj.sample_rate / N;
            
            % 在梳状频率附近计算能量增加
            total_enhancement = 0;
            for i = 1:obj.comb_count
                % 找到最接近梳状频率的频率索引
                [~, freq_idx] = min(abs(f - obj.comb_frequencies(i)));
                
                % 计算该频率附近的能量增加
                freq_range = max(1, freq_idx-10):min(N, freq_idx+10);
                target_energy = sum(target_spectrum(freq_range));
                jammed_energy = sum(jammed_spectrum(freq_range));
                
                if target_energy > 0
                    enhancement = jammed_energy / target_energy;
                    total_enhancement = total_enhancement + enhancement;
                end
            end
            
            % 计算平均增强效果
            avg_enhancement = total_enhancement / obj.comb_count;
            effectiveness = min(log10(avg_enhancement) / 2, 1);
            
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
            
            if isfield(config, 'comb_spacing')
                obj.comb_spacing = config.comb_spacing;
            end
            
            if isfield(config, 'comb_count')
                obj.comb_count = config.comb_count;
            end
            
            % 计算梳状参数
            obj.calculate_comb_parameters();
            
            % 验证参数
            obj.validate_parameters();
            
            fprintf('梳状谱干扰配置完成: %d个梳状, 间隔=%.1fMHz, 单梳带宽=%.1fMHz\n', ...
                    obj.comb_count, obj.comb_spacing/1e6, obj.comb_bandwidth/1e6);
        end
        
        function obj = set_comb_parameters(obj, spacing, count, bandwidth)
            % 设置梳状参数
            % 输入: spacing - 梳状间隔 (Hz)
            %      count - 梳状数量
            %      bandwidth - 单个梳状带宽 (Hz)
            
            assert(spacing > 0, 'CombSpectrumJamming:InvalidSpacing', '梳状间隔必须大于0');
            assert(count > 0, 'CombSpectrumJamming:InvalidCount', '梳状数量必须大于0');
            assert(bandwidth > 0, 'CombSpectrumJamming:InvalidBandwidth', '梳状带宽必须大于0');
            
            obj.comb_spacing = spacing;
            obj.comb_count = count;
            obj.comb_bandwidth = bandwidth;
            
            % 重新计算梳状参数
            obj.calculate_comb_parameters();
            
            fprintf('梳状参数设置: %d个梳状, 间隔=%.1fMHz, 带宽=%.1fMHz\n', ...
                    count, spacing/1e6, bandwidth/1e6);
        end
        
        function calculate_comb_parameters(obj)
            % 计算梳状参数
            
            % 计算各梳状频率（相对于中心频率）
            obj.comb_frequencies = zeros(1, obj.comb_count);
            for i = 1:obj.comb_count
                obj.comb_frequencies(i) = obj.center_frequency + (i - (obj.comb_count+1)/2) * obj.comb_spacing;
            end
            
            % 设置各梳状权重（可以不同，这里设为相等）
            obj.comb_weights = ones(1, obj.comb_count) / obj.comb_count;
            
            % 初始化滤波器状态
            obj.filter_states = cell(1, obj.comb_count);
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
            spectrum.comb_frequencies = obj.comb_frequencies;
            spectrum.comb_spacing = obj.comb_spacing;
            spectrum.comb_count = obj.comb_count;
            spectrum.comb_bandwidth = obj.comb_bandwidth;
        end
        
        function plot_spectrum(obj, signal_length)
            % 绘制频谱
            % 输入: signal_length - 信号长度
            
            spectrum = obj.analyze_spectrum(signal_length);
            
            figure('Name', '梳状谱干扰频谱', 'NumberTitle', 'off');
            
            subplot(2,1,1);
            plot(spectrum.frequencies/1e6, spectrum.power_db, 'b-', 'LineWidth', 1.5);
            xlabel('频率 (MHz)');
            ylabel('功率 (dB)');
            title(sprintf('梳状谱干扰频谱 - %d个梳状, 间隔%.1fMHz', ...
                         obj.comb_count, obj.comb_spacing/1e6));
            grid on;
            
            % 标记各梳状位置
            hold on;
            for i = 1:obj.comb_count
                comb_freq = obj.comb_frequencies(i);
                plot([comb_freq, comb_freq]/1e6, ylim, 'r--', 'LineWidth', 1);
                
                % 标记梳状带宽
                bw = obj.comb_bandwidth;
                plot([comb_freq-bw/2, comb_freq-bw/2]/1e6, ylim, 'g:', 'LineWidth', 0.5);
                plot([comb_freq+bw/2, comb_freq+bw/2]/1e6, ylim, 'g:', 'LineWidth', 0.5);
            end
            
            % 标记中心频率
            plot(obj.center_frequency/1e6, max(spectrum.power_db), 'ko', 'MarkerSize', 8, 'LineWidth', 2);
            
            legend('频谱', '梳状中心', '梳状带宽', '', '系统中心频率', 'Location', 'best');
            
            subplot(2,1,2);
            plot(spectrum.frequencies/1e6, spectrum.phase, 'r-', 'LineWidth', 1.5);
            xlabel('频率 (MHz)');
            ylabel('相位 (rad)');
            title('相位谱');
            grid on;
        end
        
        function plot_comb_structure(obj)
            % 绘制梳状结构图
            figure('Name', '梳状谱结构', 'NumberTitle', 'off');
            
            % 理想梳状响应
            f = linspace(-obj.sample_rate/2, obj.sample_rate/2, 1000);
            ideal_response = zeros(size(f));
            
            for i = 1:obj.comb_count
                comb_freq = obj.comb_frequencies(i);
                bw = obj.comb_bandwidth;
                
                % 矩形窗近似
                comb_mask = abs(f - comb_freq) <= bw/2;
                ideal_response = ideal_response + obj.comb_weights(i) * comb_mask;
            end
            
            subplot(2,1,1);
            plot(f/1e6, ideal_response, 'b-', 'LineWidth', 2);
            xlabel('频率 (MHz)');
            ylabel('幅度响应');
            title('理想梳状滤波器响应');
            grid on;
            
            % 标记各梳状
            hold on;
            for i = 1:obj.comb_count
                comb_freq = obj.comb_frequencies(i);
                plot(comb_freq/1e6, obj.comb_weights(i), 'ro', 'MarkerSize', 8, 'LineWidth', 2);
                text(comb_freq/1e6, obj.comb_weights(i)+0.1, sprintf('梳状%d', i), ...
                     'HorizontalAlignment', 'center');
            end
            
            subplot(2,1,2);
            % 绘制梳状参数
            bar(1:obj.comb_count, obj.comb_frequencies/1e6);
            xlabel('梳状索引');
            ylabel('频率 (MHz)');
            title('各梳状频率分布');
            grid on;
            
            % 添加参数文本
            text(0.02, 0.98, sprintf('梳状数量: %d', obj.comb_count), ...
                 'Units', 'normalized', 'VerticalAlignment', 'top');
            text(0.02, 0.90, sprintf('梳状间隔: %.1f MHz', obj.comb_spacing/1e6), ...
                 'Units', 'normalized', 'VerticalAlignment', 'top');
            text(0.02, 0.82, sprintf('单梳带宽: %.1f MHz', obj.comb_bandwidth/1e6), ...
                 'Units', 'normalized', 'VerticalAlignment', 'top');
        end
        
        function obj = reset(obj)
            % 重置干扰信号状态
            obj.filter_states = cell(1, obj.comb_count);
            obj.noise_buffer = [];
            
            fprintf('梳状谱干扰状态已重置\n');
        end
        
        function print_status(obj)
            % 打印状态信息
            fprintf('=== %s 状态 ===\n', obj.JAMMING_NAME);
            fprintf('ID: %d\n', obj.JAMMING_ID);
            fprintf('类型: %s\n', obj.JAMMING_TYPE);
            fprintf('类别: %s\n', obj.CATEGORY);
            fprintf('中心频率: %.2f MHz\n', obj.center_frequency / 1e6);
            fprintf('梳状数量: %d\n', obj.comb_count);
            fprintf('梳状间隔: %.1f MHz\n', obj.comb_spacing / 1e6);
            fprintf('单梳带宽: %.1f MHz\n', obj.comb_bandwidth / 1e6);
            fprintf('总覆盖带宽: %.1f MHz\n', obj.bandwidth / 1e6);
            
            fprintf('梳状频率:\n');
            for i = 1:obj.comb_count
                fprintf('  梳状%d: %.2f MHz (权重: %.3f)\n', ...
                        i, obj.comb_frequencies(i)/1e6, obj.comb_weights(i));
            end
            
            fprintf('噪声功率: %.2f\n', obj.noise_power);
            fprintf('滤波器阶数: %d\n', obj.filter_order);
            fprintf('功率: %.1f dBm (%.2e W)\n', obj.power_dbm, obj.power_watts);
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
            
            obj.comb_spacing = 5e6;          % 5 MHz梳状间隔
            obj.comb_count = 3;              % 3个梳状
            obj.comb_bandwidth = 2e6;        % 2 MHz单梳带宽
            obj.noise_power = 1.0;           % 单位噪声功率
            obj.filter_order = 4;            % 4阶滤波器
            obj.filter_type = 'bandpass';    % 带通滤波器
            
            obj.filter_states = cell(1, obj.comb_count);
            obj.noise_buffer = [];
            
            % 计算梳状参数
            obj.calculate_comb_parameters();
        end
        
        function validate_parameters(obj)
            % 验证参数有效性
            obj.validate_parameters@JammingBase();
            
            assert(obj.comb_spacing > 0, 'CombSpectrumJamming:InvalidSpacing', ...
                   '梳状间隔必须大于0');
            assert(obj.comb_count > 0, 'CombSpectrumJamming:InvalidCount', ...
                   '梳状数量必须大于0');
            assert(obj.comb_bandwidth > 0, 'CombSpectrumJamming:InvalidCombBW', ...
                   '梳状带宽必须大于0');
            assert(obj.noise_power > 0, 'CombSpectrumJamming:InvalidNoisePower', ...
                   '噪声功率必须大于0');
            assert(obj.filter_order > 0, 'CombSpectrumJamming:InvalidFilterOrder', ...
                   '滤波器阶数必须大于0');
        end
    end
end
