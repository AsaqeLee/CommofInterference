classdef OFDMA < OFDM
    % OFDMA - 正交频分多址
    % 实现多用户OFDM访问功能
    %
    % 作者: Asaqe Lee
    % 日期: 2025-06-18
    

    
    properties (Access = private)
        % 多用户参数
        num_users           % 用户数量
        user_allocations    % 用户子载波分配
        user_power_levels   % 用户功率分配
        
        % 调度参数
        scheduling_type     % 调度类型 ('round_robin', 'proportional_fair', 'max_rate')
        resource_blocks     % 资源块定义
        num_resource_blocks % 资源块数量
        
        % 用户配置
        user_modulations    % 每个用户的调制方式
        user_coding_rates   % 每个用户的编码率
        
        % 性能参数
        system_capacity     % 系统容量
        fairness_index      % 公平性指数
        
        % 内部状态
        current_allocation  % 当前分配状态
        user_data_queues    % 用户数据队列
    end
    
    methods
        function obj = OFDMA()
            % 构造函数
            obj@OFDM();
            obj.initialize_ofdma_params();
        end
        
        function configure(obj, config)
            % 配置OFDMA参数
            % 输入: config - 配置结构体

            % 先调用父类配置，确保OFDM参数已设置
            configure@OFDM(obj, config);

            % 多用户参数
            if isfield(config, 'num_users')
                obj.num_users = config.num_users;
            end

            if isfield(config, 'scheduling_type')
                obj.scheduling_type = config.scheduling_type;
            end

            if isfield(config, 'num_resource_blocks')
                obj.num_resource_blocks = config.num_resource_blocks;
            end

            % 重新配置用户分配（现在OFDM参数已设置）
            obj.configure_user_allocations();

            % 计算性能参数
            obj.calculate_ofdma_performance();
        end
        
        function signal = generate_signal(obj, user_data, params)
            % 生成OFDMA多用户信号
            % 输入: user_data - 用户数据 (cell array)
            %      params - 参数
            % 输出: signal - OFDMA调制信号
            
            % 验证输入
            if ~iscell(user_data)
                error('OFDMA:InvalidInput', '用户数据必须是cell array');
            end
            
            if length(user_data) ~= obj.num_users
                error('OFDMA:UserMismatch', '用户数据数量与配置的用户数不匹配');
            end
            
            % 步骤1: 资源调度
            allocation = obj.schedule_resources(user_data);
            
            % 步骤2: 多用户数据调制
            user_symbols = obj.modulate_multi_user_data(user_data, allocation);
            
            % 步骤3: 子载波映射
            ofdm_symbols = obj.map_multi_user_subcarriers(user_symbols, allocation);
            
            % 步骤4: OFDM调制 (IFFT + CP)
            time_domain_symbols = obj.apply_ifft(ofdm_symbols);
            cp_symbols = obj.add_cyclic_prefix(time_domain_symbols);
            signal = obj.parallel_to_serial(cp_symbols);
            
            % 步骤5: 添加噪声（如果需要）
            if nargin > 2 && isfield(params, 'add_noise') && params.add_noise
                signal = obj.add_awgn_noise(signal, params);
            end
        end
        
        function user_data = recover_data(obj, signal, params)
            % 恢复OFDMA多用户数据
            % 输入: signal - OFDMA调制信号
            %      params - 参数
            % 输出: user_data - 恢复的用户数据 (cell array)
            
            % 步骤1: OFDM解调
            received_symbols = obj.serial_to_parallel_recovery(signal);
            no_cp_symbols = obj.remove_cyclic_prefix(received_symbols);
            freq_domain_symbols = obj.apply_fft(no_cp_symbols);
            
            % 步骤2: 多用户子载波解映射
            user_symbols = obj.demap_multi_user_subcarriers(freq_domain_symbols);
            
            % 步骤3: 多用户数据解调
            user_data = obj.demodulate_multi_user_data(user_symbols);
        end
        
        function ber = calculate_ber(obj, original_user_data, received_user_data)
            % 计算多用户误码率
            % 输入: original_user_data - 原始用户数据
            %      received_user_data - 接收用户数据
            % 输出: ber - 误码率 (每个用户)
            
            ber = zeros(obj.num_users, 1);
            
            for user = 1:obj.num_users
                if length(original_user_data) >= user && length(received_user_data) >= user
                    orig_data = original_user_data{user};
                    recv_data = received_user_data{user};
                    
                    % 确保数据长度一致
                    min_len = min(length(orig_data), length(recv_data));
                    if min_len > 0
                        orig_data = orig_data(1:min_len);
                        recv_data = recv_data(1:min_len);
                        
                        % 计算误码数
                        errors = sum(orig_data ~= recv_data);
                        ber(user) = errors / min_len;
                    else
                        ber(user) = 1; % 无数据时设为最大误码率
                    end
                else
                    ber(user) = 1; % 用户数据缺失时设为最大误码率
                end
            end
        end
        
        function info = get_waveform_info(obj)
            % 获取OFDMA波形信息
            % 输出: info - 波形信息结构体

            % 获取基类信息
            info = get_waveform_info@OFDM(obj);

            % 更新OFDMA特有信息
            info.waveform_id = 72;
            info.waveform_name = 'OFDMA';
            info.modulation_type = 'OFDMA';
            info.category = 'ofdm';

            % OFDMA参数
            info.num_users = obj.num_users;
            info.scheduling_type = obj.scheduling_type;
            info.num_resource_blocks = obj.num_resource_blocks;
            info.system_capacity = obj.system_capacity;
            info.fairness_index = obj.fairness_index;
        end
        
        function plot_resource_allocation(obj)
            % 绘制资源分配图
            
            figure('Name', 'OFDMA资源分配', 'Position', [100, 100, 800, 600]);
            
            % 创建分配矩阵
            allocation_matrix = zeros(obj.num_subcarriers, 1);
            
            for user = 1:obj.num_users
                user_subcarriers = obj.user_allocations{user};
                allocation_matrix(user_subcarriers) = user;
            end
            
            % 绘制分配图
            subplot(2,1,1);
            bar(1:obj.num_subcarriers, allocation_matrix, 'hist');
            xlabel('子载波索引');
            ylabel('用户ID');
            title('OFDMA子载波分配');
            colormap(lines(obj.num_users + 1));
            grid on;
            
            % 绘制功率分配
            subplot(2,1,2);
            power_matrix = zeros(obj.num_subcarriers, 1);
            for user = 1:obj.num_users
                user_subcarriers = obj.user_allocations{user};
                power_matrix(user_subcarriers) = obj.user_power_levels(user);
            end
            
            bar(1:obj.num_subcarriers, power_matrix, 'hist');
            xlabel('子载波索引');
            ylabel('功率分配');
            title('OFDMA功率分配');
            grid on;
        end
        
        function plot_user_performance(obj, ber_results)
            % 绘制用户性能图
            % 输入: ber_results - 用户误码率结果
            
            figure('Name', 'OFDMA用户性能', 'Position', [100, 100, 800, 400]);
            
            subplot(1,2,1);
            bar(1:obj.num_users, ber_results);
            xlabel('用户ID');
            ylabel('误码率');
            title('各用户误码率');
            grid on;
            
            subplot(1,2,2);
            % 计算用户吞吐量
            user_throughput = zeros(obj.num_users, 1);
            for user = 1:obj.num_users
                num_subcarriers = length(obj.user_allocations{user});
                bits_per_symbol = log2(length(obj.constellation_map));
                user_throughput(user) = num_subcarriers * bits_per_symbol * (1 - ber_results(user));
            end
            
            bar(1:obj.num_users, user_throughput);
            xlabel('用户ID');
            ylabel('有效吞吐量 (bits/symbol)');
            title('各用户有效吞吐量');
            grid on;
        end
    end
    
    methods (Access = private)
        function initialize_ofdma_params(obj)
            % 初始化OFDMA参数

            obj.num_users = 4;                  % 默认4个用户
            obj.scheduling_type = 'round_robin'; % 轮询调度
            obj.num_resource_blocks = 8;        % 8个资源块

            % 初始化空的分配，等待configure时再设置
            obj.user_allocations = cell(obj.num_users, 1);
            obj.user_power_levels = ones(obj.num_users, 1);
            obj.user_modulations = cell(obj.num_users, 1);
            obj.user_coding_rates = ones(obj.num_users, 1);
            obj.system_capacity = 0;
            obj.fairness_index = 0;
        end
        
        function configure_user_allocations(obj)
            % 配置用户子载波分配
            
            % 简单的轮询分配
            obj.user_allocations = cell(obj.num_users, 1);
            obj.user_power_levels = ones(obj.num_users, 1); % 等功率分配
            obj.user_modulations = cell(obj.num_users, 1);
            obj.user_coding_rates = ones(obj.num_users, 1);
            
            % 分配数据子载波给用户
            subcarriers_per_user = floor(obj.num_data_subcarriers / obj.num_users);
            
            for user = 1:obj.num_users
                start_idx = (user - 1) * subcarriers_per_user + 1;
                end_idx = min(user * subcarriers_per_user, obj.num_data_subcarriers);
                
                if start_idx <= length(obj.data_subcarrier_indices)
                    obj.user_allocations{user} = obj.data_subcarrier_indices(start_idx:min(end_idx, length(obj.data_subcarrier_indices)));
                else
                    obj.user_allocations{user} = [];
                end
                
                obj.user_modulations{user} = obj.constellation_type;
            end
        end
        
        function allocation = schedule_resources(obj, user_data)
            % 资源调度
            % 输入: user_data - 用户数据
            % 输出: allocation - 分配结果

            % 初始化分配
            allocation = obj.user_allocations;

            % 根据调度类型调整分配
            switch obj.scheduling_type
                case 'round_robin'
                    % 轮询调度，保持默认分配
                    % 已在configure_user_allocations中实现

                case 'proportional_fair'
                    % 比例公平调度 (简化实现)
                    % 根据用户数据量调整分配
                    allocation = obj.proportional_fair_scheduling(user_data);

                case 'max_rate'
                    % 最大速率调度
                    % 将所有资源分配给信道条件最好的用户
                    allocation = obj.max_rate_scheduling(user_data);

                otherwise
                    % 默认使用轮询调度
                    warning('OFDMA:UnknownScheduling', '未知调度类型，使用轮询调度');
            end
        end

        function allocation = proportional_fair_scheduling(obj, user_data)
            % 比例公平调度算法
            % 输入: user_data - 用户数据
            % 输出: allocation - 分配结果

            allocation = cell(obj.num_users, 1);

            % 计算用户数据量
            user_data_lengths = zeros(obj.num_users, 1);
            for user = 1:obj.num_users
                if ~isempty(user_data{user})
                    user_data_lengths(user) = length(user_data{user});
                end
            end

            % 总数据量
            total_data = sum(user_data_lengths);

            if total_data > 0
                % 按比例分配子载波
                for user = 1:obj.num_users
                    proportion = user_data_lengths(user) / total_data;
                    num_subcarriers = round(proportion * obj.num_data_subcarriers);

                    % 确保至少分配一个子载波（如果有数据）
                    if user_data_lengths(user) > 0 && num_subcarriers == 0
                        num_subcarriers = 1;
                    end

                    % 分配子载波
                    start_idx = sum(cellfun(@length, allocation(1:user-1))) + 1;
                    end_idx = min(start_idx + num_subcarriers - 1, obj.num_data_subcarriers);

                    if start_idx <= length(obj.data_subcarrier_indices) && end_idx >= start_idx
                        allocation{user} = obj.data_subcarrier_indices(start_idx:min(end_idx, length(obj.data_subcarrier_indices)));
                    else
                        allocation{user} = [];
                    end
                end
            else
                % 无数据时使用默认分配
                allocation = obj.user_allocations;
            end
        end

        function allocation = max_rate_scheduling(obj, user_data)
            % 最大速率调度算法
            % 输入: user_data - 用户数据
            % 输出: allocation - 分配结果

            allocation = cell(obj.num_users, 1);

            % 找到数据量最大的用户
            user_data_lengths = zeros(obj.num_users, 1);
            for user = 1:obj.num_users
                if ~isempty(user_data{user})
                    user_data_lengths(user) = length(user_data{user});
                end
            end

            [~, max_user] = max(user_data_lengths);

            % 将所有数据子载波分配给数据量最大的用户
            if user_data_lengths(max_user) > 0
                allocation{max_user} = obj.data_subcarrier_indices;
            else
                % 如果没有用户有数据，使用默认分配
                allocation = obj.user_allocations;
            end
        end
        
        function user_symbols = modulate_multi_user_data(obj, user_data, allocation)
            % 多用户数据调制
            % 输入: user_data - 用户数据
            %      allocation - 分配方案
            % 输出: user_symbols - 用户符号
            
            user_symbols = cell(obj.num_users, 1);
            
            for user = 1:obj.num_users
                if ~isempty(user_data{user}) && ~isempty(allocation{user})
                    % 调制用户数据
                    user_symbols{user} = obj.modulate_data(user_data{user});
                else
                    user_symbols{user} = [];
                end
            end
        end
        
        function user_data = demodulate_multi_user_data(obj, user_symbols)
            % 多用户数据解调
            % 输入: user_symbols - 用户符号
            % 输出: user_data - 用户数据
            
            user_data = cell(obj.num_users, 1);
            
            for user = 1:obj.num_users
                if ~isempty(user_symbols{user})
                    user_data{user} = obj.demodulate_data(user_symbols{user});
                else
                    user_data{user} = [];
                end
            end
        end
        
        function ofdm_symbols = map_multi_user_subcarriers(obj, user_symbols, allocation)
            % 多用户子载波映射
            % 输入: user_symbols - 用户符号
            %      allocation - 分配方案
            % 输出: ofdm_symbols - OFDM符号矩阵
            
            % 计算最大OFDM符号数
            max_symbols = 0;
            for user = 1:obj.num_users
                if ~isempty(user_symbols{user}) && ~isempty(allocation{user})
                    user_ofdm_symbols = ceil(length(user_symbols{user}) / length(allocation{user}));
                    max_symbols = max(max_symbols, user_ofdm_symbols);
                end
            end
            
            if max_symbols == 0
                max_symbols = 1; % 至少一个符号
            end
            
            % 初始化OFDM符号矩阵
            ofdm_symbols = zeros(obj.num_subcarriers, max_symbols);
            
            % 映射导频
            for i = 1:max_symbols
                ofdm_symbols(obj.pilot_subcarrier_indices, i) = obj.pilot_symbols;
            end
            
            % 映射用户数据
            for user = 1:obj.num_users
                if ~isempty(user_symbols{user}) && ~isempty(allocation{user})
                    user_subcarriers = allocation{user};
                    symbols = user_symbols{user};
                    
                    % 将用户符号映射到分配的子载波
                    symbols_per_ofdm = length(user_subcarriers);
                    num_user_symbols = ceil(length(symbols) / symbols_per_ofdm);
                    
                    for i = 1:min(num_user_symbols, max_symbols)
                        start_idx = (i-1) * symbols_per_ofdm + 1;
                        end_idx = min(i * symbols_per_ofdm, length(symbols));
                        
                        if start_idx <= length(symbols)
                            user_data_symbols = symbols(start_idx:end_idx);
                            % 填充到完整长度
                            if length(user_data_symbols) < symbols_per_ofdm
                                user_data_symbols = [user_data_symbols; zeros(symbols_per_ofdm - length(user_data_symbols), 1)];
                            end
                            ofdm_symbols(user_subcarriers, i) = user_data_symbols;
                        end
                    end
                end
            end
        end
        
        function user_symbols = demap_multi_user_subcarriers(obj, ofdm_symbols)
            % 多用户子载波解映射
            % 输入: ofdm_symbols - OFDM符号矩阵
            % 输出: user_symbols - 用户符号
            
            num_ofdm_symbols = size(ofdm_symbols, 2);
            user_symbols = cell(obj.num_users, 1);
            
            for user = 1:obj.num_users
                if ~isempty(obj.user_allocations{user})
                    user_subcarriers = obj.user_allocations{user};
                    symbols = [];
                    
                    for i = 1:num_ofdm_symbols
                        user_data = ofdm_symbols(user_subcarriers, i);
                        symbols = [symbols; user_data];
                    end
                    
                    user_symbols{user} = symbols;
                else
                    user_symbols{user} = [];
                end
            end
        end
        
        function calculate_ofdma_performance(obj)
            % 计算OFDMA性能参数
            
            % 系统容量
            total_bits_per_symbol = 0;
            for user = 1:obj.num_users
                if ~isempty(obj.user_allocations{user})
                    user_subcarriers = length(obj.user_allocations{user});
                    bits_per_symbol = log2(length(obj.constellation_map));
                    total_bits_per_symbol = total_bits_per_symbol + user_subcarriers * bits_per_symbol;
                end
            end
            obj.system_capacity = total_bits_per_symbol;
            
            % 公平性指数 (简化计算)
            user_rates = zeros(obj.num_users, 1);
            for user = 1:obj.num_users
                if ~isempty(obj.user_allocations{user})
                    user_rates(user) = length(obj.user_allocations{user});
                end
            end
            
            if sum(user_rates) > 0
                obj.fairness_index = (sum(user_rates))^2 / (obj.num_users * sum(user_rates.^2));
            else
                obj.fairness_index = 0;
            end
        end
    end
end
