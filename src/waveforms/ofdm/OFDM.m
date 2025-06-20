classdef OFDM < WaveformBase
    % OFDM - 正交频分复用调制
    % 实现基础OFDM调制解调功能
    %
    % 作者: Asaqe Lee
    % 日期: 2025-06-18
    
    properties (Constant)
        WAVEFORM_ID = 71        % 波形ID
        WAVEFORM_NAME = 'OFDM'  % 波形名称
        MODULATION_TYPE = 'OFDM'  % 调制类型
        CATEGORY = 'ofdm'       % 波形类别
    end
    
    properties (Access = protected)
        % OFDM参数
        num_subcarriers      % 子载波数量
        num_data_subcarriers % 数据子载波数量
        num_pilot_subcarriers % 导频子载波数量
        num_null_subcarriers % 空子载波数量
        
        % 循环前缀参数
        cyclic_prefix_length % 循环前缀长度
        cyclic_prefix_ratio  % 循环前缀比例
        
        % 子载波配置
        subcarrier_spacing   % 子载波间隔
        data_subcarrier_indices    % 数据子载波索引
        pilot_subcarrier_indices   % 导频子载波索引
        null_subcarrier_indices    % 空子载波索引
        
        % 调制参数
        constellation_type   % 星座图类型 ('QPSK', '16QAM', '64QAM')
        constellation_map    % 星座图映射
        
        % 导频参数
        pilot_symbols       % 导频符号
        pilot_power         % 导频功率
        
        % 内部状态
        ofdm_symbol_length  % OFDM符号长度
        total_symbol_length % 包含CP的总符号长度
        
        % 性能参数
        peak_to_average_ratio % 峰均比
        spectral_efficiency   % 频谱效率
    end
    
    methods
        function obj = OFDM()
            % 构造函数
            obj@WaveformBase();
            obj.initialize_default_params();
        end
        
        function configure(obj, config)
            % 配置OFDM参数
            % 输入: config - 配置结构体
            
            % OFDM基本参数
            if isfield(config, 'num_subcarriers')
                obj.num_subcarriers = config.num_subcarriers;
            end
            
            if isfield(config, 'cyclic_prefix_ratio')
                obj.cyclic_prefix_ratio = config.cyclic_prefix_ratio;
                obj.cyclic_prefix_length = round(obj.num_subcarriers * obj.cyclic_prefix_ratio);
            end
            
            if isfield(config, 'cyclic_prefix_length')
                obj.cyclic_prefix_length = config.cyclic_prefix_length;
                obj.cyclic_prefix_ratio = obj.cyclic_prefix_length / obj.num_subcarriers;
            end
            
            if isfield(config, 'constellation_type')
                obj.constellation_type = config.constellation_type;
            end
            
            if isfield(config, 'subcarrier_spacing')
                obj.subcarrier_spacing = config.subcarrier_spacing;
            end
            
            % 重新计算子载波配置
            obj.configure_subcarriers();
            
            % 生成星座图
            obj.generate_constellation();
            
            % 生成导频
            obj.generate_pilot_symbols();
            
            % 计算性能参数
            obj.calculate_performance_params();
            
            % 调用基类配置
            configure@WaveformBase(obj, config);
        end
        
        function signal = generate_signal(obj, data, params)
            % 生成OFDM调制信号
            % 输入: data - 输入数据比特
            %      params - 参数
            % 输出: signal - OFDM调制信号
            
            % 验证输入
            if isempty(data)
                error('OFDM:EmptyData', '输入数据不能为空');
            end
            
            % 确保数据为列向量
            if isrow(data)
                data = data(:);
            end
            
            % 步骤1: 数据调制 (比特到符号映射)
            modulated_symbols = obj.modulate_data(data);
            
            % 步骤2: 串并转换和子载波映射
            ofdm_symbols = obj.serial_to_parallel_mapping(modulated_symbols);
            
            % 步骤3: IFFT变换
            time_domain_symbols = obj.apply_ifft(ofdm_symbols);
            
            % 步骤4: 添加循环前缀
            cp_symbols = obj.add_cyclic_prefix(time_domain_symbols);
            
            % 步骤5: 并串转换
            signal = obj.parallel_to_serial(cp_symbols);
            
            % 步骤6: 添加噪声（如果需要）
            if nargin > 2 && isfield(params, 'add_noise') && params.add_noise
                signal = obj.add_awgn_noise(signal, params);
            end
        end
        
        function data = recover_data(obj, signal, params)
            % 恢复OFDM调制数据
            % 输入: signal - OFDM调制信号
            %      params - 参数
            % 输出: data - 恢复的数据比特
            
            % 步骤1: 串并转换
            received_symbols = obj.serial_to_parallel_recovery(signal);
            
            % 步骤2: 移除循环前缀
            no_cp_symbols = obj.remove_cyclic_prefix(received_symbols);
            
            % 步骤3: FFT变换
            freq_domain_symbols = obj.apply_fft(no_cp_symbols);
            
            % 步骤4: 子载波解映射和并串转换
            demodulated_symbols = obj.parallel_to_serial_demapping(freq_domain_symbols);
            
            % 步骤5: 数据解调 (符号到比特映射)
            data = obj.demodulate_data(demodulated_symbols);
        end
        
        function signal = modulate(obj, data, params)
            % 实现WaveformBase的抽象方法
            % 输入: data - 输入数据
            %      params - 参数
            % 输出: signal - 调制信号

            if nargin < 3
                params = struct();
            end
            signal = obj.generate_signal(data, params);
        end

        function data = demodulate(obj, signal, params)
            % 实现WaveformBase的抽象方法
            % 输入: signal - 接收信号
            %      params - 参数
            % 输出: data - 解调数据

            if nargin < 3
                params = struct();
            end
            data = obj.recover_data(signal, params);
        end

        function ber = calculate_ber(obj, original_data, received_data)
            % 计算误码率
            % 输入: original_data - 原始数据
            %      received_data - 接收数据
            % 输出: ber - 误码率

            % 确保数据长度一致
            min_len = min(length(original_data), length(received_data));
            original_data = original_data(1:min_len);
            received_data = received_data(1:min_len);

            % 计算误码数
            errors = sum(original_data ~= received_data);
            ber = errors / min_len;
        end
        
        function spectrum = get_spectrum(obj, signal, params)
            % 获取OFDM信号频谱
            % 输入: signal - 信号
            %      params - 参数
            % 输出: spectrum - 频谱结构体
            
            if nargin < 3
                params = struct();
            end
            
            % 计算FFT
            N = length(signal);
            Y = fft(signal, N);
            
            % 频率轴
            frequencies = (-N/2:N/2-1) * (obj.sample_rate/N);
            
            % 功率谱密度
            power_density = abs(fftshift(Y)).^2 / (obj.sample_rate * N);
            
            % 构造输出结构体
            spectrum = struct();
            spectrum.frequencies = frequencies;
            spectrum.power_density = power_density;
            spectrum.subcarrier_spacing = obj.subcarrier_spacing;
            spectrum.bandwidth = obj.num_subcarriers * obj.subcarrier_spacing;
        end
        
        function info = get_waveform_info(obj)
            % 获取OFDM波形信息
            % 输出: info - 波形信息结构体
            
            info = struct();
            info.waveform_id = obj.WAVEFORM_ID;
            info.waveform_name = obj.WAVEFORM_NAME;
            info.modulation_type = obj.MODULATION_TYPE;
            info.category = obj.CATEGORY;
            
            % OFDM参数
            info.num_subcarriers = obj.num_subcarriers;
            info.num_data_subcarriers = obj.num_data_subcarriers;
            info.num_pilot_subcarriers = obj.num_pilot_subcarriers;
            info.cyclic_prefix_length = obj.cyclic_prefix_length;
            info.cyclic_prefix_ratio = obj.cyclic_prefix_ratio;
            info.constellation_type = obj.constellation_type;
            info.subcarrier_spacing = obj.subcarrier_spacing;
            
            % 性能参数
            info.peak_to_average_ratio = obj.peak_to_average_ratio;
            info.spectral_efficiency = obj.spectral_efficiency;
            info.bandwidth = obj.num_subcarriers * obj.subcarrier_spacing;
            info.symbol_duration = obj.total_symbol_length / obj.sample_rate;
        end
        
        function plot_constellation(obj, symbols)
            % 绘制星座图
            % 输入: symbols - 符号数据
            
            if nargin < 2
                % 使用默认星座图
                symbols = obj.constellation_map;
            end
            
            figure('Name', 'OFDM星座图', 'Position', [100, 100, 600, 500]);
            scatter(real(symbols), imag(symbols), 50, 'filled');
            xlabel('同相分量 (I)');
            ylabel('正交分量 (Q)');
            title(sprintf('OFDM %s 星座图', obj.constellation_type));
            grid on;
            axis equal;
            
            % 添加理想星座点
            hold on;
            scatter(real(obj.constellation_map), imag(obj.constellation_map), ...
                    100, 'r', 'x', 'LineWidth', 2);
            legend('接收符号', '理想星座点', 'Location', 'best');
        end
        
        function plot_subcarrier_allocation(obj)
            % 绘制子载波分配图
            
            figure('Name', 'OFDM子载波分配', 'Position', [100, 100, 800, 400]);
            
            % 创建子载波类型数组
            subcarrier_types = zeros(1, obj.num_subcarriers);
            subcarrier_types(obj.data_subcarrier_indices) = 1;      % 数据子载波
            subcarrier_types(obj.pilot_subcarrier_indices) = 2;     % 导频子载波
            subcarrier_types(obj.null_subcarrier_indices) = 0;      % 空子载波
            
            % 绘制条形图
            bar(1:obj.num_subcarriers, subcarrier_types, 'hist');
            xlabel('子载波索引');
            ylabel('子载波类型');
            title('OFDM子载波分配');
            
            % 设置颜色和图例
            colormap([0.8 0.8 0.8; 0.2 0.6 1.0; 1.0 0.2 0.2]); % 灰色、蓝色、红色
            colorbar('Ticks', [0, 1, 2], 'TickLabels', {'空载波', '数据载波', '导频载波'});
            grid on;
        end
    end
    
    methods (Access = protected)
        function initialize_default_params(obj)
            % 初始化默认参数
            
            % 默认OFDM参数
            obj.num_subcarriers = 64;           % 64个子载波
            obj.cyclic_prefix_ratio = 0.25;     % 1/4循环前缀
            obj.cyclic_prefix_length = 16;      % 16个样本的CP
            obj.constellation_type = 'QPSK';    % QPSK调制
            obj.subcarrier_spacing = 15e3;      % 15kHz子载波间隔
            
            % 配置子载波
            obj.configure_subcarriers();
            
            % 生成星座图
            obj.generate_constellation();
            
            % 生成导频
            obj.generate_pilot_symbols();
            
            % 计算性能参数
            obj.calculate_performance_params();
        end
        
        function configure_subcarriers(obj)
            % 配置子载波分配
            
            % 计算各类子载波数量
            obj.num_pilot_subcarriers = max(4, round(obj.num_subcarriers * 0.1)); % 10%导频
            obj.num_null_subcarriers = max(2, round(obj.num_subcarriers * 0.05));  % 5%空载波
            obj.num_data_subcarriers = obj.num_subcarriers - obj.num_pilot_subcarriers - obj.num_null_subcarriers;
            
            % 分配子载波索引
            % 空子载波在两端
            null_per_side = floor(obj.num_null_subcarriers / 2);
            obj.null_subcarrier_indices = [1:null_per_side, ...
                                          (obj.num_subcarriers-null_per_side+1):obj.num_subcarriers];
            
            % 导频子载波均匀分布
            pilot_spacing = floor(obj.num_subcarriers / obj.num_pilot_subcarriers);
            obj.pilot_subcarrier_indices = null_per_side + 1 : pilot_spacing : obj.num_subcarriers - null_per_side;
            obj.pilot_subcarrier_indices = obj.pilot_subcarrier_indices(1:obj.num_pilot_subcarriers);
            
            % 剩余的为数据子载波
            all_indices = 1:obj.num_subcarriers;
            used_indices = [obj.null_subcarrier_indices, obj.pilot_subcarrier_indices];
            obj.data_subcarrier_indices = setdiff(all_indices, used_indices);
            obj.data_subcarrier_indices = obj.data_subcarrier_indices(1:obj.num_data_subcarriers);
            
            % 计算符号长度
            obj.ofdm_symbol_length = obj.num_subcarriers;
            obj.total_symbol_length = obj.ofdm_symbol_length + obj.cyclic_prefix_length;
        end
        
        function generate_constellation(obj)
            % 生成星座图映射

            switch upper(obj.constellation_type)
                case 'BPSK'
                    obj.constellation_map = [1, -1];
                case 'QPSK'
                    obj.constellation_map = [1+1j, -1+1j, -1-1j, 1-1j] / sqrt(2);
                case '16QAM'
                    % 16QAM星座图
                    I = [-3, -1, 1, 3];
                    Q = [-3, -1, 1, 3];
                    [I_grid, Q_grid] = meshgrid(I, Q);
                    obj.constellation_map = (I_grid(:) + 1j*Q_grid(:)) / sqrt(10);
                case '64QAM'
                    % 64QAM星座图
                    I = [-7, -5, -3, -1, 1, 3, 5, 7];
                    Q = [-7, -5, -3, -1, 1, 3, 5, 7];
                    [I_grid, Q_grid] = meshgrid(I, Q);
                    obj.constellation_map = (I_grid(:) + 1j*Q_grid(:)) / sqrt(42);
                otherwise
                    error('OFDM:UnsupportedConstellation', '不支持的星座图类型: %s', obj.constellation_type);
            end
        end
        
        function generate_pilot_symbols(obj)
            % 生成导频符号
            
            % 使用BPSK导频符号
            obj.pilot_symbols = ones(1, obj.num_pilot_subcarriers);
            obj.pilot_power = 1; % 归一化功率
        end
        
        function calculate_performance_params(obj)
            % 计算性能参数
            
            % 频谱效率 (bits/s/Hz)
            bits_per_symbol = log2(length(obj.constellation_map));
            obj.spectral_efficiency = bits_per_symbol * obj.num_data_subcarriers / obj.num_subcarriers;
            
            % 峰均比 (初始估计)
            obj.peak_to_average_ratio = 10 * log10(obj.num_subcarriers); % dB
        end

        function modulated_symbols = modulate_data(obj, data)
            % 数据调制 (比特到符号映射)
            % 输入: data - 输入比特
            % 输出: modulated_symbols - 调制符号

            bits_per_symbol = log2(length(obj.constellation_map));

            % 确保数据长度是符号长度的整数倍
            num_bits = length(data);
            num_symbols = ceil(num_bits / bits_per_symbol);
            padded_bits = [data; zeros(num_symbols * bits_per_symbol - num_bits, 1)];

            % 重新排列为符号组
            bit_matrix = reshape(padded_bits, bits_per_symbol, num_symbols)';

            % 映射到星座图
            modulated_symbols = zeros(num_symbols, 1);
            for i = 1:num_symbols
                % 将比特转换为十进制索引
                symbol_index = bi2de(bit_matrix(i, :), 'left-msb') + 1;
                modulated_symbols(i) = obj.constellation_map(symbol_index);
            end
        end

        function data = demodulate_data(obj, symbols)
            % 数据解调 (符号到比特映射)
            % 输入: symbols - 接收符号
            % 输出: data - 解调比特

            bits_per_symbol = log2(length(obj.constellation_map));
            num_symbols = length(symbols);

            % 硬判决解调
            data = zeros(num_symbols * bits_per_symbol, 1);

            for i = 1:num_symbols
                % 找到最近的星座点
                distances = abs(symbols(i) - obj.constellation_map);
                [~, min_index] = min(distances);

                % 转换为比特
                symbol_bits = de2bi(min_index - 1, bits_per_symbol, 'left-msb');
                data((i-1)*bits_per_symbol + 1 : i*bits_per_symbol) = symbol_bits';
            end
        end

        function ofdm_symbols = serial_to_parallel_mapping(obj, symbols)
            % 串并转换和子载波映射
            % 输入: symbols - 串行符号
            % 输出: ofdm_symbols - OFDM符号矩阵

            % 计算需要的OFDM符号数
            num_ofdm_symbols = ceil(length(symbols) / obj.num_data_subcarriers);

            % 填充符号到完整的OFDM符号
            padded_symbols = [symbols; zeros(num_ofdm_symbols * obj.num_data_subcarriers - length(symbols), 1)];

            % 初始化OFDM符号矩阵
            ofdm_symbols = zeros(obj.num_subcarriers, num_ofdm_symbols);

            % 映射数据和导频到子载波
            for i = 1:num_ofdm_symbols
                % 获取当前OFDM符号的数据
                start_idx = (i-1) * obj.num_data_subcarriers + 1;
                end_idx = i * obj.num_data_subcarriers;
                data_symbols = padded_symbols(start_idx:end_idx);

                % 映射到子载波
                ofdm_symbols(obj.data_subcarrier_indices, i) = data_symbols;
                ofdm_symbols(obj.pilot_subcarrier_indices, i) = obj.pilot_symbols;
                % 空子载波保持为0
            end
        end

        function symbols = parallel_to_serial_demapping(obj, ofdm_symbols)
            % 子载波解映射和并串转换
            % 输入: ofdm_symbols - OFDM符号矩阵
            % 输出: symbols - 串行符号

            num_ofdm_symbols = size(ofdm_symbols, 2);
            symbols = zeros(num_ofdm_symbols * obj.num_data_subcarriers, 1);

            for i = 1:num_ofdm_symbols
                % 提取数据子载波
                data_symbols = ofdm_symbols(obj.data_subcarrier_indices, i);

                % 存储到输出
                start_idx = (i-1) * obj.num_data_subcarriers + 1;
                end_idx = i * obj.num_data_subcarriers;
                symbols(start_idx:end_idx) = data_symbols;
            end
        end

        function time_symbols = apply_ifft(obj, freq_symbols)
            % 应用IFFT变换
            % 输入: freq_symbols - 频域符号
            % 输出: time_symbols - 时域符号

            time_symbols = ifft(freq_symbols, obj.num_subcarriers, 1);
        end

        function freq_symbols = apply_fft(obj, time_symbols)
            % 应用FFT变换
            % 输入: time_symbols - 时域符号
            % 输出: freq_symbols - 频域符号

            freq_symbols = fft(time_symbols, obj.num_subcarriers, 1);
        end

        function cp_symbols = add_cyclic_prefix(obj, symbols)
            % 添加循环前缀
            % 输入: symbols - 时域符号
            % 输出: cp_symbols - 带循环前缀的符号

            num_symbols = size(symbols, 2);
            cp_symbols = zeros(obj.total_symbol_length, num_symbols);

            for i = 1:num_symbols
                % 复制符号的最后CP_length个样本到前面
                cp_part = symbols(end-obj.cyclic_prefix_length+1:end, i);
                cp_symbols(:, i) = [cp_part; symbols(:, i)];
            end
        end

        function symbols = remove_cyclic_prefix(obj, cp_symbols)
            % 移除循环前缀
            % 输入: cp_symbols - 带循环前缀的符号
            % 输出: symbols - 移除CP后的符号

            symbols = cp_symbols(obj.cyclic_prefix_length+1:end, :);
        end

        function signal = parallel_to_serial(obj, symbols)
            % 并串转换
            % 输入: symbols - 并行符号矩阵
            % 输出: signal - 串行信号

            signal = symbols(:);
        end

        function symbols = serial_to_parallel_recovery(obj, signal)
            % 串并转换 (接收端)
            % 输入: signal - 串行信号
            % 输出: symbols - 并行符号矩阵

            % 计算OFDM符号数
            num_ofdm_symbols = floor(length(signal) / obj.total_symbol_length);

            % 重新排列为矩阵
            signal_matrix = reshape(signal(1:num_ofdm_symbols * obj.total_symbol_length), ...
                                   obj.total_symbol_length, num_ofdm_symbols);
            symbols = signal_matrix;
        end
    end
end
