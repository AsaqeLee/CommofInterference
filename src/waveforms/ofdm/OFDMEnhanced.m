classdef OFDMEnhanced < OFDM
    % OFDMEnhanced - 增强型OFDM类
    % 支持跳频、编码和多址功能
    %
    % 作者: Asaqe Lee
    % 日期: 2025-06-20
    
    properties (Access = protected)
        % 跳频参数
        frequency_points        % 频点集合
        current_frequency_index % 当前频点索引
        hop_sequence           % 跳频序列
        hop_timing             % 跳频时序
        
        % 编码参数
        ldpc_encoder           % LDPC编码器
        ldpc_decoder           % LDPC解码器
        
        % 多址参数
        access_method          % 多址方式
        time_slot_duration     % 时隙持续时间
        current_time_slot      % 当前时隙
        
        % 配置参数
        waveform_config        % 波形配置
    end
    
    methods
        function obj = OFDMEnhanced(waveform_id)
            % 构造函数
            % 输入: waveform_id - 波形ID (57-100)
            
            obj@OFDM();
            
            if nargin > 0
                obj.load_config(waveform_id);
            end
        end
        
        function load_config(obj, waveform_id)
            % 加载指定ID的波形配置
            % 输入: waveform_id - 波形ID
            
            try
                obj.waveform_config = OFDMWaveformConfig.get_config(waveform_id);
                obj.apply_config();
            catch ME
                error('OFDMEnhanced:ConfigError', '加载配置失败: %s', ME.message);
            end
        end
        
        function apply_config(obj)
            % 应用配置到OFDM对象
            
            config = obj.waveform_config;
            
            % 基础OFDM配置
            ofdm_config = struct();
            ofdm_config.num_subcarriers = config.num_subcarriers;
            ofdm_config.constellation_type = config.constellation_type;
            ofdm_config.cyclic_prefix_length = config.cyclic_prefix_length;
            ofdm_config.subcarrier_spacing = config.subcarrier_spacing;
            ofdm_config.center_frequency = config.center_frequency;
            ofdm_config.bandwidth = config.bandwidth;
            ofdm_config.sample_rate = config.sample_rate;
            ofdm_config.data_rate = config.data_rate;
            
            % 调用父类配置
            obj.configure(ofdm_config);
            
            % 跳频配置
            if config.hopping_enabled
                obj.setup_frequency_hopping(config);
            end
            
            % 编码配置
            obj.setup_coding(config);
            
            % 多址配置
            obj.setup_multiple_access(config);
        end
        
        function setup_frequency_hopping(obj, config)
            % 设置跳频参数
            
            obj.frequency_points = config.frequency_set;
            obj.hopping_rate = config.hopping_rate;
            obj.hopping_enabled = true;
            obj.current_frequency_index = 1;
            
            % 生成跳频序列
            obj.generate_hop_sequence();
        end
        
        function setup_coding(obj, config)
            % 设置编码参数
            
            obj.coding_scheme = config.coding_scheme;
            obj.coding_rate = config.coding_rate;
            
            if strcmp(config.coding_scheme, 'LDPC_1_2')
                % 简化的LDPC编码器设置
                obj.ldpc_encoder = @(data) obj.ldpc_encode(data);
                obj.ldpc_decoder = @(data) obj.ldpc_decode(data);
            end
        end
        
        function setup_multiple_access(obj, config)
            % 设置多址参数
            
            obj.access_method = config.access_method;
            
            switch config.access_method
                case 'TDMA'
                    obj.time_slot_duration = 1 / config.hopping_rate; % 时隙等于跳频周期
                case 'CS_TDMA'
                    obj.time_slot_duration = 0.5 / config.hopping_rate; % 载波感知TDMA
                otherwise
                    obj.time_slot_duration = 0;
            end
            
            obj.current_time_slot = 1;
        end
        
        function signal = generate_signal(obj, data, params)
            % 生成增强型OFDM信号
            % 输入: data - 输入数据
            %      params - 参数
            % 输出: signal - 调制信号
            
            if nargin < 3
                params = struct();
            end
            
            % 步骤1: 编码
            encoded_data = obj.apply_channel_coding(data);
            
            % 步骤2: 基础OFDM调制
            ofdm_signal = generate_signal@OFDM(obj, encoded_data, params);
            
            % 步骤3: 应用跳频
            if obj.hopping_enabled
                signal = obj.apply_frequency_hopping(ofdm_signal);
            else
                signal = ofdm_signal;
            end
            
            % 步骤4: 应用多址处理
            signal = obj.apply_multiple_access(signal);
        end
        
        function data = recover_data(obj, signal, params)
            % 恢复增强型OFDM数据
            % 输入: signal - 接收信号
            %      params - 参数
            % 输出: data - 恢复数据
            
            if nargin < 3
                params = struct();
            end
            
            % 步骤1: 逆多址处理
            processed_signal = obj.reverse_multiple_access(signal);
            
            % 步骤2: 逆跳频处理
            if obj.hopping_enabled
                ofdm_signal = obj.reverse_frequency_hopping(processed_signal);
            else
                ofdm_signal = processed_signal;
            end
            
            % 步骤3: 基础OFDM解调
            decoded_data = recover_data@OFDM(obj, ofdm_signal, params);
            
            % 步骤4: 信道解码
            data = obj.apply_channel_decoding(decoded_data);
        end
        
        function info = get_waveform_info(obj)
            % 获取波形信息
            
            % 获取基类信息
            info = get_waveform_info@OFDM(obj);
            
            % 添加增强功能信息
            if ~isempty(obj.waveform_config)
                info.waveform_id = obj.waveform_config.waveform_id;
                info.waveform_name = obj.waveform_config.waveform_name;
                info.hopping_rate = obj.waveform_config.hopping_rate;
                info.num_frequency_points = obj.waveform_config.num_frequency_points;
                info.coding_scheme = obj.waveform_config.coding_scheme;
                info.access_method = obj.waveform_config.access_method;
                info.spectral_efficiency = obj.waveform_config.spectral_efficiency;
            end
        end
        
        function plot_frequency_hopping(obj, duration)
            % 绘制跳频图
            % 输入: duration - 显示时长 (秒)
            
            if nargin < 2
                duration = 0.1; % 默认100ms
            end
            
            if ~obj.hopping_enabled
                warning('OFDMEnhanced:NoHopping', '跳频未启用');
                return;
            end
            
            % 生成时间轴
            hop_period = 1 / obj.hopping_rate;
            num_hops = ceil(duration / hop_period);
            time_axis = 0:hop_period:duration;
            
            % 生成频率序列
            freq_sequence = zeros(size(time_axis));
            for i = 1:length(time_axis)
                hop_index = mod(i-1, length(obj.hop_sequence)) + 1;
                freq_sequence(i) = obj.frequency_points(obj.hop_sequence(hop_index));
            end
            
            % 绘图
            figure('Name', '跳频序列', 'Position', [100, 100, 800, 400]);
            stairs(time_axis*1000, freq_sequence/1e6, 'LineWidth', 2);
            xlabel('时间 (ms)');
            ylabel('频率 (MHz)');
            title(sprintf('OFDM跳频序列 (跳频率: %d hops/s)', obj.hopping_rate));
            grid on;
            
            % 添加频点标记
            unique_freqs = unique(obj.frequency_points);
            for i = 1:length(unique_freqs)
                yline(unique_freqs(i)/1e6, '--', sprintf('%.1f MHz', unique_freqs(i)/1e6));
            end
        end
    end
    
    methods (Access = protected)
        function generate_hop_sequence(obj)
            % 生成跳频序列
            
            if isempty(obj.frequency_points)
                return;
            end
            
            % 生成伪随机跳频序列
            num_points = length(obj.frequency_points);
            sequence_length = max(100, num_points * 2); % 至少100个跳频点
            
            % 使用线性同余生成器产生伪随机序列
            seed = 12345; % 固定种子确保可重复性
            obj.hop_sequence = zeros(1, sequence_length);
            
            for i = 1:sequence_length
                seed = mod(1103515245 * seed + 12345, 2^31);
                obj.hop_sequence(i) = mod(seed, num_points) + 1;
            end
        end
        
        function encoded_data = apply_channel_coding(obj, data)
            % 应用信道编码
            
            if strcmp(obj.coding_scheme, 'LDPC_1_2') && ~isempty(obj.ldpc_encoder)
                encoded_data = obj.ldpc_encoder(data);
            else
                encoded_data = data; % 无编码
            end
        end
        
        function decoded_data = apply_channel_decoding(obj, data)
            % 应用信道解码
            
            if strcmp(obj.coding_scheme, 'LDPC_1_2') && ~isempty(obj.ldpc_decoder)
                decoded_data = obj.ldpc_decoder(data);
            else
                decoded_data = data; % 无解码
            end
        end
        
        function encoded_data = ldpc_encode(obj, data)
            % 简化的LDPC编码 (1/2码率)
            % 实际应用中应使用专业的LDPC编码器
            
            % 简单的重复编码模拟1/2码率
            encoded_data = reshape([data(:)'; data(:)'], [], 1);
        end
        
        function decoded_data = ldpc_decode(obj, data)
            % 简化的LDPC解码
            % 实际应用中应使用专业的LDPC解码器
            
            % 简单的多数判决解码
            data_matrix = reshape(data, 2, []);
            decoded_data = (data_matrix(1,:) + data_matrix(2,:) > 1)';
        end
        
        function signal = apply_multiple_access(obj, signal)
            % 应用多址处理
            
            switch obj.access_method
                case 'TDMA'
                    % TDMA: 在指定时隙发送
                    signal = obj.apply_tdma(signal);
                case 'CS_TDMA'
                    % 载波感知TDMA
                    signal = obj.apply_cs_tdma(signal);
                otherwise
                    % 无多址处理
            end
        end
        
        function signal = reverse_multiple_access(obj, signal)
            % 逆多址处理
            
            switch obj.access_method
                case 'TDMA'
                    signal = obj.reverse_tdma(signal);
                case 'CS_TDMA'
                    signal = obj.reverse_cs_tdma(signal);
                otherwise
                    % 无处理
            end
        end
        
        function signal = apply_tdma(obj, signal)
            % 应用TDMA
            % 简化实现：在信号前后添加保护间隔
            
            guard_samples = round(0.1 * length(signal)); % 10%保护间隔
            signal = [zeros(guard_samples, 1); signal; zeros(guard_samples, 1)];
        end
        
        function signal = reverse_tdma(obj, signal)
            % 逆TDMA处理
            % 移除保护间隔
            
            guard_samples = round(0.1 * length(signal) / 1.2); % 估算保护间隔
            if length(signal) > 2 * guard_samples
                signal = signal(guard_samples+1:end-guard_samples);
            end
        end
        
        function signal = apply_cs_tdma(obj, signal)
            % 载波感知TDMA (简化实现)
            signal = obj.apply_tdma(signal); % 暂时与TDMA相同
        end
        
        function signal = reverse_cs_tdma(obj, signal)
            % 逆载波感知TDMA
            signal = obj.reverse_tdma(signal);
        end
    end
end
