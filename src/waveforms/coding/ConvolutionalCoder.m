classdef ConvolutionalCoder < handle
    % ConvolutionalCoder - 卷积编码器/解码器
    % 实现真正的卷积编码，支持多种码率
    %
    % 作者: Asaqe Lee
    % 日期: 2025-06-20
    
    properties (Access = private)
        constraint_length  % 约束长度
        code_rate         % 编码率
        generator_poly    % 生成多项式
        trellis          % 网格结构
    end
    
    methods
        function obj = ConvolutionalCoder(code_rate, constraint_length)
            % 构造函数
            % 输入: code_rate - 编码率 (如 2/3)
            %      constraint_length - 约束长度 (默认7)
            
            if nargin < 2
                constraint_length = 7;
            end
            
            obj.constraint_length = constraint_length;
            obj.code_rate = code_rate;
            
            % 根据编码率设置生成多项式
            obj.setup_generator_polynomials();
            obj.setup_trellis();
        end
        
        function coded_bits = encode(obj, data_bits)
            % 卷积编码
            % 输入: data_bits - 输入数据比特 (列向量)
            % 输出: coded_bits - 编码后的比特
            
            % 确保输入是列向量
            if size(data_bits, 2) > size(data_bits, 1)
                data_bits = data_bits';
            end
            
            % 对于2/3码率，需要将输入分组
            if abs(obj.code_rate - 2/3) < 1e-6
                coded_bits = obj.encode_2_3(data_bits);
            else
                % 默认1/2码率编码
                coded_bits = obj.encode_1_2(data_bits);
            end
        end
        
        function decoded_bits = decode(obj, coded_bits, algorithm)
            % 卷积解码
            % 输入: coded_bits - 编码比特
            %      algorithm - 解码算法 ('viterbi' 或 'sequential')
            % 输出: decoded_bits - 解码比特
            
            if nargin < 3
                algorithm = 'viterbi';
            end
            
            switch algorithm
                case 'viterbi'
                    decoded_bits = obj.viterbi_decode(coded_bits);
                case 'sequential'
                    decoded_bits = obj.sequential_decode(coded_bits);
                otherwise
                    error('ConvolutionalCoder:InvalidAlgorithm', ...
                        '不支持的解码算法: %s', algorithm);
            end
        end
        
        function setup_generator_polynomials(obj)
            % 设置生成多项式
            
            if abs(obj.code_rate - 2/3) < 1e-6
                % 2/3码率的生成多项式 (约束长度7)
                obj.generator_poly = [
                    121;  % 1111001 (二进制)
                    91;   % 1011011 (二进制)
                    117;  % 1110101 (二进制)
                ];
            else
                % 1/2码率的生成多项式 (约束长度7)
                obj.generator_poly = [
                    121;  % 1111001 (二进制)
                    91;   % 1011011 (二进制)
                ];
            end
        end
        
        function setup_trellis(obj)
            % 设置网格结构
            
            num_states = 2^(obj.constraint_length - 1);
            num_inputs = 2;
            
            if abs(obj.code_rate - 2/3) < 1e-6
                num_outputs = 3;
            else
                num_outputs = 2;
            end
            
            % 简化的网格结构
            obj.trellis = struct();
            obj.trellis.numInputSymbols = num_inputs;
            obj.trellis.numOutputSymbols = 2^num_outputs;
            obj.trellis.numStates = num_states;
        end
        
        function coded_bits = encode_1_2(obj, data_bits)
            % 1/2码率卷积编码
            
            % 添加尾比特
            tail_bits = zeros(obj.constraint_length - 1, 1);
            input_bits = [data_bits; tail_bits];
            
            % 初始化移位寄存器
            shift_reg = zeros(obj.constraint_length, 1);
            coded_bits = [];
            
            for i = 1:length(input_bits)
                % 移位并输入新比特
                shift_reg = [input_bits(i); shift_reg(1:end-1)];
                
                % 计算输出
                poly1_bits = de2bi(obj.generator_poly(1), obj.constraint_length, 'left-msb')';
                poly2_bits = de2bi(obj.generator_poly(2), obj.constraint_length, 'left-msb')';
                output1 = mod(sum(shift_reg .* poly1_bits), 2);
                output2 = mod(sum(shift_reg .* poly2_bits), 2);
                
                coded_bits = [coded_bits; output1; output2];
            end
        end
        
        function coded_bits = encode_2_3(obj, data_bits)
            % 2/3码率卷积编码
            
            % 确保输入长度是2的倍数
            if mod(length(data_bits), 2) ~= 0
                data_bits = [data_bits; 0];
            end
            
            % 将输入分为2比特一组
            input_pairs = reshape(data_bits, 2, [])';
            
            % 添加尾比特
            tail_pairs = zeros(obj.constraint_length - 1, 2);
            input_pairs = [input_pairs; tail_pairs];
            
            % 初始化移位寄存器
            shift_reg = zeros(obj.constraint_length, 1);
            coded_bits = [];
            
            for i = 1:size(input_pairs, 1)
                % 处理每对输入比特
                for j = 1:2
                    % 移位并输入新比特
                    shift_reg = [input_pairs(i, j); shift_reg(1:end-1)];
                end
                
                % 计算3个输出比特
                output1 = mod(sum(shift_reg .* de2bi(obj.generator_poly(1), obj.constraint_length, 'left-msb')'), 2);
                output2 = mod(sum(shift_reg .* de2bi(obj.generator_poly(2), obj.constraint_length, 'left-msb')'), 2);
                output3 = mod(sum(shift_reg .* de2bi(obj.generator_poly(3), obj.constraint_length, 'left-msb')'), 2);
                
                coded_bits = [coded_bits; output1; output2; output3];
            end
        end
        
        function decoded_bits = viterbi_decode(obj, coded_bits)
            % Viterbi解码算法
            
            num_states = 2^(obj.constraint_length - 1);
            
            if abs(obj.code_rate - 2/3) < 1e-6
                % 2/3码率解码
                if mod(length(coded_bits), 3) ~= 0
                    error('ConvolutionalCoder:InvalidLength', '2/3码率编码比特长度必须是3的倍数');
                end
                num_symbols = length(coded_bits) / 3;
                coded_symbols = reshape(coded_bits, 3, num_symbols)';
            else
                % 1/2码率解码
                if mod(length(coded_bits), 2) ~= 0
                    error('ConvolutionalCoder:InvalidLength', '1/2码率编码比特长度必须是2的倍数');
                end
                num_symbols = length(coded_bits) / 2;
                coded_symbols = reshape(coded_bits, 2, num_symbols)';
            end
            
            % 简化的Viterbi解码
            decoded_bits = obj.simplified_viterbi(coded_symbols);
        end
        
        function decoded_bits = simplified_viterbi(obj, coded_symbols)
            % 简化的Viterbi解码实现
            
            num_states = 2^(obj.constraint_length - 1);
            num_symbols = size(coded_symbols, 1);
            
            % 路径度量
            path_metrics = inf(num_states, num_symbols + 1);
            path_metrics(1, 1) = 0; % 初始状态
            
            % 存储路径
            paths = zeros(num_states, num_symbols);
            
            % 前向处理
            for t = 1:num_symbols
                new_metrics = inf(num_states, 1);
                
                for state = 0:num_states-1
                    if path_metrics(state+1, t) < inf
                        % 尝试两个可能的输入
                        for input = 0:1
                            [next_state, expected_output] = obj.get_next_state_output(state, input);
                            
                            % 计算汉明距离
                            distance = sum(coded_symbols(t, :) ~= expected_output);
                            new_metric = path_metrics(state+1, t) + distance;
                            
                            if new_metric < new_metrics(next_state+1)
                                new_metrics(next_state+1) = new_metric;
                                paths(next_state+1, t) = input;
                            end
                        end
                    end
                end
                
                path_metrics(:, t+1) = new_metrics;
            end
            
            % 回溯
            [~, final_state] = min(path_metrics(:, end));
            decoded_bits = zeros(num_symbols, 1);
            
            current_state = final_state - 1;
            for t = num_symbols:-1:1
                decoded_bits(t) = paths(current_state+1, t);
                % 计算前一个状态
                input = decoded_bits(t);
                current_state = obj.get_prev_state(current_state, input);
            end
            
            % 移除尾比特
            if length(decoded_bits) > obj.constraint_length - 1
                decoded_bits = decoded_bits(1:end-(obj.constraint_length-1));
            end
        end
        
        function [next_state, output] = get_next_state_output(obj, current_state, input)
            % 获取下一个状态和输出

            % 基于移位寄存器操作
            current_bits = de2bi(current_state, obj.constraint_length-1, 'left-msb');
            shift_reg = [input; current_bits'];

            % 计算输出
            if abs(obj.code_rate - 2/3) < 1e-6
                output = zeros(1, 3);
                for i = 1:3
                    poly_bits = de2bi(obj.generator_poly(i), obj.constraint_length, 'left-msb')';
                    output(i) = mod(sum(shift_reg .* poly_bits), 2);
                end
            else
                output = zeros(1, 2);
                for i = 1:2
                    poly_bits = de2bi(obj.generator_poly(i), obj.constraint_length, 'left-msb')';
                    output(i) = mod(sum(shift_reg .* poly_bits), 2);
                end
            end

            % 下一个状态
            next_state = bi2de(shift_reg(1:obj.constraint_length-1)', 'left-msb');
        end
        
        function prev_state = get_prev_state(obj, current_state, input)
            % 获取前一个状态
            
            current_bits = de2bi(current_state, obj.constraint_length-1, 'left-msb');
            prev_bits = [current_bits(2:end), 0]; % 右移一位
            prev_state = bi2de(prev_bits, 'left-msb');
        end
        
        function decoded_bits = sequential_decode(obj, coded_bits)
            % 序列解码算法 (简化实现)
            
            % 对于简化实现，使用硬判决解码
            decoded_bits = obj.viterbi_decode(coded_bits);
        end
    end
end
