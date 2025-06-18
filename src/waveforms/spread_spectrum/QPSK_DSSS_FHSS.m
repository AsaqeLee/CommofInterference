classdef QPSK_DSSS_FHSS < FrequencyHoppingWaveform
    % QPSK_DSSS_FHSS - QPSK直接序列扩频+跳频扩频组合
    % 实现QPSK调制与DSSS和FHSS的组合
    %
    % 作者: Asaqe Lee
    % 日期: 2025-06-18
    
    properties (Constant)
        WAVEFORM_ID = 101       % 波形ID
        WAVEFORM_NAME = 'QPSK-DSSS-FHSS'  % 波形名称
        MODULATION_TYPE = 'QPSK+DSSS+FHSS'  % 调制类型
        CATEGORY = 'spread_spectrum'  % 波形类别
    end
    
    properties (Access = private)
        % DSSS参数
        spreading_code        % 扩频码
        spreading_factor      % 扩频因子
        chip_rate            % 码片速率
        
        % 扩频码生成参数
        code_type            % 码型 ('gold', 'walsh', 'pn')
        code_length          % 码长
        code_seed            % 码种子
        
        % 性能参数
        processing_gain      % 处理增益
        jamming_margin       % 抗干扰容限
        
        % 内部状态
        current_code_phase   % 当前码相位
        code_sync_status     % 码同步状态
    end
    
    methods
        function obj = QPSK_DSSS_FHSS()
            % 构造函数
            obj@FrequencyHoppingWaveform('QPSK');
            obj.initialize_dsss_params();
        end
        
        function configure(obj, config)
            % 配置QPSK+DSSS+FHSS参数
            % 输入: config - 配置结构体
            
            % 配置DSSS参数
            if isfield(config, 'spreading_factor')
                obj.spreading_factor = config.spreading_factor;
            end
            
            if isfield(config, 'chip_rate')
                obj.chip_rate = config.chip_rate;
            end
            
            if isfield(config, 'code_type')
                obj.code_type = config.code_type;
            end
            
            if isfield(config, 'code_length')
                obj.code_length = config.code_length;
            end
            
            if isfield(config, 'code_seed')
                obj.code_seed = config.code_seed;
            end
            
            % 生成扩频码
            obj.generate_spreading_code();
            
            % 计算性能参数
            obj.calculate_performance_params();
            
            % 调用父类配置
            configure@FrequencyHoppingWaveform(obj, config);
        end
        
        function signal = generate_signal(obj, data, params)
            % 生成QPSK+DSSS+FHSS信号
            % 输入: data - 输入数据比特
            %      params - 参数
            % 输出: signal - 扩频跳频调制信号
            
            % 验证输入
            if isempty(data)
                error('QPSK_DSSS_FHSS:EmptyData', '输入数据不能为空');
            end
            
            % 确保数据为列向量
            if isrow(data)
                data = data(:);
            end
            
            % 步骤1: QPSK符号映射
            qpsk_symbols = obj.map_to_qpsk_symbols(data);
            
            % 步骤2: 直接序列扩频
            spread_symbols = obj.apply_dsss(qpsk_symbols);
            
            % 步骤3: 跳频调制
            if obj.hopping_enabled
                signal = obj.apply_frequency_hopping(spread_symbols, params);
            else
                % 如果未启用跳频，直接调制
                signal = obj.base_waveform.generate_signal(spread_symbols, params);
            end
        end
        
        function data = recover_data(obj, signal, params)
            % 恢复QPSK+DSSS+FHSS数据
            % 输入: signal - 接收信号
            %      params - 参数
            % 输出: data - 恢复的数据比特
            
            % 步骤1: 跳频解调
            if obj.hopping_enabled
                spread_symbols = obj.recover_from_frequency_hopping(signal, params);
            else
                spread_symbols = obj.base_waveform.recover_data(signal, params);
            end
            
            % 步骤2: 直接序列解扩
            qpsk_symbols = obj.remove_dsss(spread_symbols);
            
            % 步骤3: QPSK符号解映射
            data = obj.demap_from_qpsk_symbols(qpsk_symbols);
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
        
        function info = get_waveform_info(obj)
            % 获取波形信息
            % 输出: info - 波形信息结构体
            
            info = struct();
            info.waveform_id = obj.WAVEFORM_ID;
            info.waveform_name = obj.WAVEFORM_NAME;
            info.modulation_type = obj.MODULATION_TYPE;
            info.category = obj.CATEGORY;
            
            % DSSS信息
            info.spreading_factor = obj.spreading_factor;
            info.chip_rate = obj.chip_rate;
            info.code_type = obj.code_type;
            info.code_length = obj.code_length;
            info.processing_gain = obj.processing_gain;
            info.jamming_margin = obj.jamming_margin;
            
            % 跳频信息
            if obj.hopping_enabled
                hop_info = obj.frequency_hopper.get_hop_info();
                info.hop_info = hop_info;
            end
        end
        
        function plot_spreading_code(obj)
            % 绘制扩频码
            
            figure('Name', '扩频码图案', 'Position', [100, 100, 800, 400]);
            
            % 显示前100个码片
            code_to_plot = obj.spreading_code(1:min(100, length(obj.spreading_code)));
            
            subplot(2,1,1);
            stem(1:length(code_to_plot), code_to_plot, 'b-', 'LineWidth', 1.5);
            xlabel('码片索引');
            ylabel('码值');
            title(sprintf('%s扩频码 (前%d码片)', obj.code_type, length(code_to_plot)));
            grid on;
            
            % 自相关函数
            subplot(2,1,2);
            autocorr_result = xcorr(obj.spreading_code, obj.spreading_code);
            lags = -(length(obj.spreading_code)-1):(length(obj.spreading_code)-1);
            plot(lags, autocorr_result, 'r-', 'LineWidth', 1);
            xlabel('延迟');
            ylabel('自相关');
            title('扩频码自相关函数');
            grid on;
        end
    end
    
    methods (Access = private)
        function initialize_dsss_params(obj)
            % 初始化DSSS参数
            obj.spreading_factor = 31;          % 31倍扩频
            obj.chip_rate = 1.023e6;            % 1.023 Mcps
            obj.code_type = 'gold';             % Gold码
            obj.code_length = 1023;             % 码长
            obj.code_seed = 1;                  % 码种子
            obj.current_code_phase = 0;
            obj.code_sync_status = false;
            
            % 生成默认扩频码
            obj.generate_spreading_code();
            obj.calculate_performance_params();
        end
        
        function generate_spreading_code(obj)
            % 生成扩频码
            
            switch lower(obj.code_type)
                case 'gold'
                    obj.spreading_code = obj.generate_gold_code();
                case 'walsh'
                    obj.spreading_code = obj.generate_walsh_code();
                case 'pn'
                    obj.spreading_code = obj.generate_pn_code();
                otherwise
                    error('QPSK_DSSS_FHSS:InvalidCodeType', '不支持的码型: %s', obj.code_type);
            end
            
            % 转换为双极性码 (-1, +1)
            obj.spreading_code = 2 * obj.spreading_code - 1;
        end
        
        function code = generate_gold_code(obj)
            % 生成Gold码
            % 输出: code - Gold码序列
            
            % 简化的Gold码生成（使用两个m序列的异或）
            % 生成器多项式: x^10 + x^3 + 1 和 x^10 + x^8 + x^5 + x^2 + 1
            
            % 第一个m序列
            reg1 = ones(1, 10); % 10位寄存器
            seq1 = zeros(1, obj.code_length);
            
            for i = 1:obj.code_length
                seq1(i) = reg1(10);
                feedback1 = xor(reg1(10), reg1(3));
                reg1 = [feedback1, reg1(1:9)];
            end
            
            % 第二个m序列
            reg2 = ones(1, 10); % 10位寄存器
            reg2(obj.code_seed) = 0; % 使用种子改变初始状态
            seq2 = zeros(1, obj.code_length);
            
            for i = 1:obj.code_length
                seq2(i) = reg2(10);
                feedback2 = xor(xor(xor(reg2(10), reg2(8)), reg2(5)), reg2(2));
                reg2 = [feedback2, reg2(1:9)];
            end
            
            % Gold码 = 两个m序列的异或
            code = xor(seq1, seq2);
        end
        
        function code = generate_walsh_code(obj)
            % 生成Walsh码
            % 输出: code - Walsh码序列
            
            % 生成Walsh矩阵
            n = ceil(log2(obj.code_length));
            N = 2^n;
            
            % 递归生成Walsh矩阵
            W = 1;
            for i = 1:n
                W = [W, W; W, -W];
            end
            
            % 选择第code_seed行作为Walsh码
            row_index = mod(obj.code_seed - 1, N) + 1;
            walsh_row = W(row_index, :);
            
            % 转换为0/1码并截取到所需长度
            code = (walsh_row + 1) / 2;
            code = code(1:obj.code_length);
        end
        
        function code = generate_pn_code(obj)
            % 生成PN码
            % 输出: code - PN码序列
            
            % 使用线性反馈移位寄存器生成PN序列
            rng(obj.code_seed);
            
            % 10位LFSR，生成器多项式: x^10 + x^3 + 1
            register = ones(1, 10);
            code = zeros(1, obj.code_length);
            
            for i = 1:obj.code_length
                code(i) = register(10);
                feedback = xor(register(10), register(3));
                register = [feedback, register(1:9)];
            end
        end
        
        function calculate_performance_params(obj)
            % 计算性能参数
            
            % 处理增益 = 扩频因子
            obj.processing_gain = 10 * log10(obj.spreading_factor);
            
            % 抗干扰容限 = 处理增益 - 系统损耗
            system_loss = 3; % dB
            obj.jamming_margin = obj.processing_gain - system_loss;
        end
        
        function symbols = map_to_qpsk_symbols(obj, data)
            % 将比特映射为QPSK符号
            % 输入: data - 输入比特
            % 输出: symbols - QPSK符号
            
            % 确保数据长度为偶数
            if mod(length(data), 2) ~= 0
                data = [data; 0]; % 补零
            end
            
            % 重新排列为2比特一组
            data_pairs = reshape(data, 2, [])';
            
            % QPSK Gray码映射
            symbols = zeros(size(data_pairs, 1), 1);
            for i = 1:size(data_pairs, 1)
                bits = data_pairs(i, :);
                if isequal(bits, [0, 0])
                    symbols(i) = 1 + 1j;      % 00 -> +1+j
                elseif isequal(bits, [0, 1])
                    symbols(i) = -1 + 1j;     % 01 -> -1+j
                elseif isequal(bits, [1, 1])
                    symbols(i) = -1 - 1j;     % 11 -> -1-j
                else % [1, 0]
                    symbols(i) = 1 - 1j;      % 10 -> +1-j
                end
            end
            
            % 归一化
            symbols = symbols / sqrt(2);
        end
        
        function data = demap_from_qpsk_symbols(obj, symbols)
            % 从QPSK符号解映射为比特
            % 输入: symbols - QPSK符号
            % 输出: data - 输出比特
            
            data = zeros(length(symbols) * 2, 1);
            
            for i = 1:length(symbols)
                symbol = symbols(i) * sqrt(2); % 反归一化
                
                % 硬判决
                if real(symbol) >= 0 && imag(symbol) >= 0
                    bits = [0, 0]; % +1+j -> 00
                elseif real(symbol) < 0 && imag(symbol) >= 0
                    bits = [0, 1]; % -1+j -> 01
                elseif real(symbol) < 0 && imag(symbol) < 0
                    bits = [1, 1]; % -1-j -> 11
                else
                    bits = [1, 0]; % +1-j -> 10
                end
                
                data(2*i-1:2*i) = bits';
            end
        end
        
        function spread_symbols = apply_dsss(obj, symbols)
            % 应用直接序列扩频
            % 输入: symbols - QPSK符号
            % 输出: spread_symbols - 扩频后的符号
            
            % 重复扩频码以匹配符号数量
            num_symbols = length(symbols);
            code_repetitions = ceil(num_symbols / length(obj.spreading_code));
            extended_code = repmat(obj.spreading_code, 1, code_repetitions);
            extended_code = extended_code(1:num_symbols);
            
            % 扩频：符号与扩频码相乘
            spread_symbols = symbols .* extended_code';
        end
        
        function symbols = remove_dsss(obj, spread_symbols)
            % 移除直接序列扩频
            % 输入: spread_symbols - 扩频符号
            % 输出: symbols - 解扩后的符号
            
            % 重复扩频码以匹配符号数量
            num_symbols = length(spread_symbols);
            code_repetitions = ceil(num_symbols / length(obj.spreading_code));
            extended_code = repmat(obj.spreading_code, 1, code_repetitions);
            extended_code = extended_code(1:num_symbols);
            
            % 解扩：与本地扩频码相乘
            symbols = spread_symbols .* extended_code';
        end
        
        function signal = apply_frequency_hopping(obj, symbols, params)
            % 应用跳频
            % 输入: symbols - 扩频符号
            %      params - 参数
            % 输出: signal - 跳频信号
            
            signal = generate_signal@FrequencyHoppingWaveform(obj, symbols, params);
        end
        
        function symbols = recover_from_frequency_hopping(obj, signal, params)
            % 从跳频信号恢复符号
            % 输入: signal - 跳频信号
            %      params - 参数
            % 输出: symbols - 恢复的符号
            
            symbols = recover_data@FrequencyHoppingWaveform(obj, signal, params);
        end
    end
end
