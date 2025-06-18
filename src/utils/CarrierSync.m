classdef CarrierSync < handle
    % CarrierSync - 载波同步工具类
    % 实现各种载波频率和相位恢复算法
    %
    % 作者: 通信干扰仿真平台开发团队
    % 日期: 2025-06-18
    
    properties (Constant)
        % 支持的载波恢复算法
        SUPPORTED_ALGORITHMS = {'costas', 'squaring', 'decision_feedback', 'blind'};
    end
    
    methods (Static)
        function [recovered_signal, freq_offset, phase_offset] = recover_carrier_bpsk(signal, sample_rate, varargin)
            % BPSK载波恢复
            % 输入: signal - 接收信号
            %      sample_rate - 采样率
            %      varargin - 可选参数
            % 输出: recovered_signal - 载波恢复后的信号
            %      freq_offset - 估计的频率偏移
            %      phase_offset - 估计的相位偏移
            
            % 解析参数
            p = inputParser;
            addParameter(p, 'algorithm', 'squaring', @(x) ismember(x, CarrierSync.SUPPORTED_ALGORITHMS));
            addParameter(p, 'loop_bandwidth', 0.01, @isnumeric);
            addParameter(p, 'damping_factor', 0.707, @isnumeric);
            addParameter(p, 'freq_search_range', [-0.1, 0.1], @isnumeric);
            
            parse(p, varargin{:});
            algorithm = p.Results.algorithm;
            loop_bw = p.Results.loop_bandwidth;
            damping = p.Results.damping_factor;
            freq_range = p.Results.freq_search_range;
            
            switch algorithm
                case 'squaring'
                    [recovered_signal, freq_offset, phase_offset] = ...
                        CarrierSync.squaring_loop_bpsk(signal, sample_rate, loop_bw, damping);
                case 'costas'
                    [recovered_signal, freq_offset, phase_offset] = ...
                        CarrierSync.costas_loop_bpsk(signal, sample_rate, loop_bw, damping);
                case 'blind'
                    [recovered_signal, freq_offset, phase_offset] = ...
                        CarrierSync.blind_carrier_recovery(signal, sample_rate, freq_range);
                otherwise
                    % 默认使用平方环
                    [recovered_signal, freq_offset, phase_offset] = ...
                        CarrierSync.squaring_loop_bpsk(signal, sample_rate, loop_bw, damping);
            end
        end
        
        function [recovered_signal, freq_offset, phase_offset] = squaring_loop_bpsk(signal, sample_rate, loop_bw, damping)
            % BPSK平方环载波恢复
            % 输入: signal - 接收信号
            %      sample_rate - 采样率
            %      loop_bw - 环路带宽
            %      damping - 阻尼因子
            % 输出: recovered_signal - 载波恢复后的信号
            %      freq_offset - 频率偏移估计
            %      phase_offset - 相位偏移估计
            
            N = length(signal);
            
            % 初始化环路参数
            Kp = 4 * damping * loop_bw / (1 + 2*damping*loop_bw + loop_bw^2);
            Ki = 4 * loop_bw^2 / (1 + 2*damping*loop_bw + loop_bw^2);
            
            % 初始化状态变量
            phase_error = 0;
            freq_error = 0;
            phase_acc = 0;
            
            % 存储结果
            recovered_signal = zeros(size(signal));
            phase_estimates = zeros(1, N);
            
            for n = 1:N
                % 生成本地载波
                local_carrier = exp(-1j * phase_acc);
                
                % 下变频
                baseband = signal(n) * local_carrier;
                recovered_signal(n) = baseband;
                
                % 平方操作去除调制
                squared_signal = baseband^2;
                
                % 相位误差检测
                phase_error = angle(squared_signal) / 2;  % 除以2因为平方操作
                
                % 环路滤波器
                freq_error = freq_error + Ki * phase_error;
                phase_acc = phase_acc + Kp * phase_error + freq_error;
                
                % 保持相位在[-π, π]范围内
                phase_acc = mod(phase_acc + pi, 2*pi) - pi;
                
                phase_estimates(n) = phase_acc;
            end
            
            % 估计频率和相位偏移
            if N > 1
                freq_offset = mean(diff(phase_estimates)) * sample_rate / (2*pi);
            else
                freq_offset = 0;
            end
            phase_offset = mean(phase_estimates);
        end
        
        function [recovered_signal, freq_offset, phase_offset] = costas_loop_bpsk(signal, sample_rate, loop_bw, damping)
            % BPSK Costas环载波恢复
            % 输入: signal - 接收信号
            %      sample_rate - 采样率
            %      loop_bw - 环路带宽
            %      damping - 阻尼因子
            % 输出: recovered_signal - 载波恢复后的信号
            %      freq_offset - 频率偏移估计
            %      phase_offset - 相位偏移估计
            
            N = length(signal);
            
            % 初始化环路参数
            Kp = 4 * damping * loop_bw / (1 + 2*damping*loop_bw + loop_bw^2);
            Ki = 4 * loop_bw^2 / (1 + 2*damping*loop_bw + loop_bw^2);
            
            % 初始化状态变量
            phase_error = 0;
            freq_error = 0;
            phase_acc = 0;
            
            % 存储结果
            recovered_signal = zeros(size(signal));
            phase_estimates = zeros(1, N);
            
            for n = 1:N
                % 生成本地载波
                local_carrier = exp(-1j * phase_acc);
                
                % 下变频
                baseband = signal(n) * local_carrier;
                recovered_signal(n) = baseband;
                
                % Costas环相位误差检测
                I = real(baseband);
                Q = imag(baseband);
                
                % BPSK的相位误差检测器
                phase_error = sign(I) * Q;
                
                % 环路滤波器
                freq_error = freq_error + Ki * phase_error;
                phase_acc = phase_acc + Kp * phase_error + freq_error;
                
                % 保持相位在[-π, π]范围内
                phase_acc = mod(phase_acc + pi, 2*pi) - pi;
                
                phase_estimates(n) = phase_acc;
            end
            
            % 估计频率和相位偏移
            if N > 1
                freq_offset = mean(diff(phase_estimates)) * sample_rate / (2*pi);
            else
                freq_offset = 0;
            end
            phase_offset = mean(phase_estimates);
        end
        
        function [recovered_signal, freq_offset, phase_offset] = blind_carrier_recovery(signal, sample_rate, freq_range)
            % 盲载波恢复（基于频域搜索）
            % 输入: signal - 接收信号
            %      sample_rate - 采样率
            %      freq_range - 频率搜索范围（归一化频率）
            % 输出: recovered_signal - 载波恢复后的信号
            %      freq_offset - 频率偏移估计
            %      phase_offset - 相位偏移估计
            
            N = length(signal);
            
            % 频率搜索网格
            freq_search = linspace(freq_range(1), freq_range(2), 100);
            max_power = 0;
            best_freq = 0;
            
            % 搜索最佳频率偏移
            for freq_offset_norm = freq_search
                % 生成测试载波
                t = (0:N-1) / sample_rate;
                test_carrier = exp(-1j * 2*pi * freq_offset_norm * sample_rate * t);
                
                % 下变频
                test_baseband = signal .* test_carrier;
                
                % 计算基带信号的功率集中度
                % 对于正确的频率偏移，基带信号应该有最大的功率
                power = mean(abs(test_baseband).^2);
                
                if power > max_power
                    max_power = power;
                    best_freq = freq_offset_norm * sample_rate;
                end
            end
            
            % 使用最佳频率进行载波恢复
            t = (0:N-1) / sample_rate;
            optimal_carrier = exp(-1j * 2*pi * best_freq * t);
            recovered_signal = signal .* optimal_carrier;
            
            % 相位偏移估计（简化）
            phase_offset = angle(mean(recovered_signal));
            
            % 相位校正
            recovered_signal = recovered_signal * exp(-1j * phase_offset);
            
            freq_offset = best_freq;
        end
        
        function [timing_offset, corrected_signal] = symbol_timing_recovery(signal, samples_per_symbol, varargin)
            % 符号定时恢复
            % 输入: signal - 基带信号
            %      samples_per_symbol - 每符号采样数
            %      varargin - 可选参数
            % 输出: timing_offset - 定时偏移
            %      corrected_signal - 定时校正后的信号
            
            % 解析参数
            p = inputParser;
            addParameter(p, 'method', 'early_late', @ischar);
            addParameter(p, 'loop_bandwidth', 0.01, @isnumeric);
            
            parse(p, varargin{:});
            method = p.Results.method;
            loop_bw = p.Results.loop_bandwidth;
            
            switch method
                case 'early_late'
                    [timing_offset, corrected_signal] = ...
                        CarrierSync.early_late_timing_recovery(signal, samples_per_symbol, loop_bw);
                case 'gardner'
                    [timing_offset, corrected_signal] = ...
                        CarrierSync.gardner_timing_recovery(signal, samples_per_symbol, loop_bw);
                otherwise
                    % 默认使用超前滞后算法
                    [timing_offset, corrected_signal] = ...
                        CarrierSync.early_late_timing_recovery(signal, samples_per_symbol, loop_bw);
            end
        end
        
        function [timing_offset, corrected_signal] = early_late_timing_recovery(signal, samples_per_symbol, loop_bw)
            % 超前滞后定时恢复算法
            % 输入: signal - 基带信号
            %      samples_per_symbol - 每符号采样数
            %      loop_bw - 环路带宽
            % 输出: timing_offset - 定时偏移
            %      corrected_signal - 定时校正后的信号
            
            N = length(signal);
            num_symbols = floor(N / samples_per_symbol);
            
            % 初始化
            timing_error = 0;
            timing_acc = samples_per_symbol / 2;  % 初始采样位置
            
            corrected_signal = zeros(1, num_symbols);
            timing_offsets = zeros(1, num_symbols);
            
            % 环路参数
            Kp = loop_bw;
            Ki = loop_bw^2 / 4;
            
            for k = 1:num_symbols
                % 当前采样位置
                sample_idx = round(timing_acc);
                
                if sample_idx > 0 && sample_idx <= N
                    corrected_signal(k) = signal(sample_idx);
                    
                    % 超前滞后误差检测
                    if sample_idx > 1 && sample_idx < N
                        early_sample = signal(sample_idx - 1);
                        late_sample = signal(sample_idx + 1);
                        
                        % 简化的定时误差检测器
                        timing_error = real((early_sample - late_sample) * conj(signal(sample_idx)));
                    end
                    
                    % 更新定时
                    timing_acc = timing_acc + samples_per_symbol + Kp * timing_error + Ki * timing_error;
                    timing_offsets(k) = timing_acc - k * samples_per_symbol;
                else
                    corrected_signal(k) = 0;
                    timing_acc = timing_acc + samples_per_symbol;
                end
            end
            
            timing_offset = mean(timing_offsets);
        end
        
        function [timing_offset, corrected_signal] = gardner_timing_recovery(signal, samples_per_symbol, loop_bw)
            % Gardner定时恢复算法
            % 输入: signal - 基带信号
            %      samples_per_symbol - 每符号采样数
            %      loop_bw - 环路带宽
            % 输出: timing_offset - 定时偏移
            %      corrected_signal - 定时校正后的信号
            
            % 简化实现，使用超前滞后算法
            [timing_offset, corrected_signal] = ...
                CarrierSync.early_late_timing_recovery(signal, samples_per_symbol, loop_bw);
        end
        
        function snr_est = estimate_snr(signal, noise_bandwidth)
            % 估计信噪比
            % 输入: signal - 信号
            %      noise_bandwidth - 噪声带宽
            % 输出: snr_est - 信噪比估计(dB)
            
            % 简化的SNR估计
            signal_power = mean(abs(signal).^2);
            
            % 使用信号的方差估计噪声功率
            signal_magnitude = abs(signal);
            noise_power = var(signal_magnitude);
            
            if noise_power > 0
                snr_linear = signal_power / noise_power;
                snr_est = 10 * log10(snr_linear);
            else
                snr_est = inf;
            end
        end
    end
end
