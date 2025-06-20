classdef LDPCCoder < handle
    % LDPCCoder - LDPC编码器/解码器
    % 实现真正的LDPC编码，支持1/2码率
    %
    % 作者: Asaqe Lee
    % 日期: 2025-06-20
    
    properties (Access = private)
        H_matrix          % 校验矩阵
        G_matrix          % 生成矩阵
        code_rate         % 编码率
        block_length      % 码块长度
        info_length       % 信息长度
        parity_length     % 校验长度
    end
    
    methods
        function obj = LDPCCoder(code_rate, block_length)
            % 构造函数
            % 输入: code_rate - 编码率 (默认1/2)
            %      block_length - 码块长度 (默认1024)
            
            if nargin < 1
                code_rate = 1/2;
            end
            if nargin < 2
                block_length = 1024;
            end
            
            obj.code_rate = code_rate;
            obj.block_length = block_length;
            obj.info_length = round(block_length * code_rate);
            obj.parity_length = block_length - obj.info_length;
            
            % 生成LDPC矩阵
            obj.generate_ldpc_matrices();
        end
        
        function coded_bits = encode(obj, data_bits)
            % LDPC编码
            % 输入: data_bits - 输入数据比特 (列向量)
            % 输出: coded_bits - 编码后的比特
            
            % 确保输入是列向量
            if size(data_bits, 2) > size(data_bits, 1)
                data_bits = data_bits';
            end
            
            % 分块编码
            num_blocks = ceil(length(data_bits) / obj.info_length);
            coded_bits = [];
            
            for i = 1:num_blocks
                start_idx = (i-1) * obj.info_length + 1;
                end_idx = min(i * obj.info_length, length(data_bits));
                
                % 获取当前块
                current_block = data_bits(start_idx:end_idx);
                
                % 填充到标准长度
                if length(current_block) < obj.info_length
                    current_block = [current_block; zeros(obj.info_length - length(current_block), 1)];
                end
                
                % 编码当前块
                coded_block = obj.encode_block(current_block);
                coded_bits = [coded_bits; coded_block];
            end
        end
        
        function decoded_bits = decode(obj, coded_bits, max_iterations)
            % LDPC解码
            % 输入: coded_bits - 编码比特 (软信息或硬比特)
            %      max_iterations - 最大迭代次数
            % 输出: decoded_bits - 解码比特
            
            if nargin < 3
                max_iterations = 50;
            end
            
            % 分块解码
            num_blocks = ceil(length(coded_bits) / obj.block_length);
            decoded_bits = [];
            
            for i = 1:num_blocks
                start_idx = (i-1) * obj.block_length + 1;
                end_idx = min(i * obj.block_length, length(coded_bits));
                
                % 获取当前块
                current_block = coded_bits(start_idx:end_idx);
                
                % 填充到标准长度
                if length(current_block) < obj.block_length
                    current_block = [current_block; zeros(obj.block_length - length(current_block), 1)];
                end
                
                % 解码当前块
                decoded_block = obj.decode_block(current_block, max_iterations);
                decoded_bits = [decoded_bits; decoded_block];
            end
        end
        
        function generate_ldpc_matrices(obj)
            % 生成LDPC校验矩阵和生成矩阵
            
            % 使用规则LDPC码构造方法
            obj.H_matrix = obj.construct_regular_ldpc();
            
            % 从校验矩阵生成生成矩阵
            obj.G_matrix = obj.construct_generator_matrix();
        end
        
        function H = construct_regular_ldpc(obj)
            % 构造规则LDPC码校验矩阵
            
            % 参数设置
            dv = 3;  % 变量节点度数
            dc = 6;  % 校验节点度数
            
            % 确保参数一致性
            if obj.parity_length * dc ~= obj.block_length * dv
                % 调整参数以满足一致性
                dc = round(obj.block_length * dv / obj.parity_length);
            end
            
            % 初始化校验矩阵
            H = zeros(obj.parity_length, obj.block_length);
            
            % 使用循环构造方法
            for i = 1:obj.parity_length
                for j = 1:dc
                    col_idx = mod((i-1)*dc + j - 1, obj.block_length) + 1;
                    H(i, col_idx) = 1;
                end
            end
            
            % 随机置换以避免短环
            for col = 1:obj.block_length
                perm_indices = randperm(obj.parity_length);
                H(:, col) = H(perm_indices, col);
            end
            
            % 确保每列恰好有dv个1
            for col = 1:obj.block_length
                ones_count = sum(H(:, col));
                if ones_count > dv
                    % 随机移除多余的1
                    ones_positions = find(H(:, col));
                    remove_indices = ones_positions(randperm(ones_count, ones_count - dv));
                    H(remove_indices, col) = 0;
                elseif ones_count < dv
                    % 随机添加1
                    zeros_positions = find(H(:, col) == 0);
                    if ~isempty(zeros_positions)
                        add_indices = zeros_positions(randperm(length(zeros_positions), min(dv - ones_count, length(zeros_positions))));
                        H(add_indices, col) = 1;
                    end
                end
            end
            
            obj.H_matrix = H;
        end
        
        function G = construct_generator_matrix(obj)
            % 从校验矩阵构造生成矩阵
            
            H = obj.H_matrix;
            
            % 使用高斯消元法将H转换为系统形式 [P | I]
            [H_sys, perm] = obj.gaussian_elimination(H);
            
            % 提取P矩阵
            P = H_sys(:, 1:obj.info_length);
            
            % 生成矩阵 G = [I | P^T]
            G = [eye(obj.info_length), P'];
            
            % 应用置换
            G_perm = zeros(size(G));
            G_perm(:, perm) = G;
            
            obj.G_matrix = G_perm;
        end
        
        function [H_sys, perm] = gaussian_elimination(obj, H)
            % 高斯消元法将矩阵转换为系统形式
            
            [m, n] = size(H);
            H_work = H;
            perm = 1:n;
            
            for i = 1:min(m, n)
                % 寻找主元
                pivot_col = i;
                for j = i+1:n
                    if sum(H_work(:, j)) < sum(H_work(:, pivot_col))
                        pivot_col = j;
                    end
                end
                
                % 交换列
                if pivot_col ~= i
                    H_work(:, [i, pivot_col]) = H_work(:, [pivot_col, i]);
                    perm([i, pivot_col]) = perm([pivot_col, i]);
                end
                
                % 寻找行主元
                pivot_row = 0;
                for row = i:m
                    if H_work(row, i) == 1
                        pivot_row = row;
                        break;
                    end
                end
                
                if pivot_row == 0
                    continue;
                end
                
                % 交换行
                if pivot_row ~= i && i <= m
                    H_work([i, pivot_row], :) = H_work([pivot_row, i], :);
                end
                
                % 消元
                if i <= m && H_work(i, i) == 1
                    for row = 1:m
                        if row ~= i && H_work(row, i) == 1
                            H_work(row, :) = mod(H_work(row, :) + H_work(i, :), 2);
                        end
                    end
                end
            end
            
            H_sys = H_work;
        end
        
        function coded_block = encode_block(obj, info_bits)
            % 编码单个块
            
            % 使用生成矩阵编码
            coded_block = mod(info_bits' * obj.G_matrix, 2)';
        end
        
        function decoded_block = decode_block(obj, received_block, max_iterations)
            % 解码单个块 - 使用置信传播算法
            
            % 初始化
            H = obj.H_matrix;
            [m, n] = size(H);
            
            % 将硬比特转换为软信息
            if all(received_block == 0 | received_block == 1)
                % 硬比特，转换为软信息
                llr = 2 * received_block - 1; % 0->-1, 1->1
                llr = llr * 4; % 增加可靠性
            else
                llr = received_block; % 已经是软信息
            end
            
            % 初始化消息
            var_to_check = zeros(m, n); % 变量节点到校验节点的消息
            check_to_var = zeros(m, n); % 校验节点到变量节点的消息
            
            % 迭代解码
            for iter = 1:max_iterations
                % 变量节点更新
                for v = 1:n
                    connected_checks = find(H(:, v));
                    for c_idx = 1:length(connected_checks)
                        c = connected_checks(c_idx);
                        other_checks = connected_checks(connected_checks ~= c);
                        var_to_check(c, v) = llr(v) + sum(check_to_var(other_checks, v));
                    end
                end
                
                % 校验节点更新
                for c = 1:m
                    connected_vars = find(H(c, :));
                    for v_idx = 1:length(connected_vars)
                        v = connected_vars(v_idx);
                        other_vars = connected_vars(connected_vars ~= v);
                        
                        % 计算tanh乘积
                        product = 1;
                        for other_v = other_vars
                            product = product * tanh(var_to_check(c, other_v) / 2);
                        end
                        
                        % 避免数值问题
                        product = max(min(product, 0.9999), -0.9999);
                        check_to_var(c, v) = 2 * atanh(product);
                    end
                end
                
                % 计算后验概率
                posterior = llr;
                for v = 1:n
                    connected_checks = find(H(:, v));
                    posterior(v) = llr(v) + sum(check_to_var(connected_checks, v));
                end
                
                % 硬判决
                decoded = (posterior < 0);
                
                % 检查是否满足校验方程
                syndrome = mod(H * decoded, 2);
                if all(syndrome == 0)
                    break; % 解码成功
                end
            end
            
            % 提取信息比特
            decoded_block = decoded(1:obj.info_length);
        end
        
        function info = get_code_info(obj)
            % 获取编码信息
            
            info = struct();
            info.code_rate = obj.code_rate;
            info.block_length = obj.block_length;
            info.info_length = obj.info_length;
            info.parity_length = obj.parity_length;
            info.H_matrix_size = size(obj.H_matrix);
            info.G_matrix_size = size(obj.G_matrix);
        end
    end
end
