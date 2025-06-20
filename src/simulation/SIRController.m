classdef SIRController < handle
    % SIRController - 信干比控制系统
    % 实现精确的信干比控制，确保在指定信干比条件下进行仿真
    %
    % 作者: Asaqe Lee
    % 日期: 2025-06-20
    
    properties (Constant)
        % 默认参数
        DEFAULT_TARGET_SIR_DB = 10;     % 默认目标信干比 10dB
        MIN_SIR_DB = -30;               % 最小信干比
        MAX_SIR_DB = 50;                % 最大信干比
        POWER_TOLERANCE = 0.1;          % 功率容差 (dB)
        MAX_ITERATIONS = 100;           % 最大迭代次数
    end
    
    properties (Access = private)
        target_sir_db          % 目标信干比 (dB)
        current_sir_db         % 当前信干比 (dB)
        signal_power           % 信号功率 (W)
        jamming_power          % 干扰功率 (W)
        total_power            % 总功率 (W)
        
        % 控制参数
        control_mode           % 控制模式 ('auto', 'manual')
        power_adjustment_step  % 功率调整步长 (dB)
        convergence_threshold  % 收敛阈值 (dB)
        
        % 监控参数
        power_history          % 功率历史记录
        sir_history           % 信干比历史记录
        iteration_count       % 迭代计数
        
        % 状态标志
        is_converged          % 是否收敛
        is_active             % 是否激活
    end
    
    properties (Dependent)
        % 计算属性
        sir_linear            % 线性信干比
        signal_power_dbm      % 信号功率 (dBm)
        jamming_power_dbm     % 干扰功率 (dBm)
        total_power_dbm       % 总功率 (dBm)
    end
    
    methods
        function obj = SIRController(target_sir_db)
            % 构造函数
            % 输入: target_sir_db - 目标信干比 (dB)
            
            if nargin < 1
                target_sir_db = obj.DEFAULT_TARGET_SIR_DB;
            end
            
            obj.initialize_parameters(target_sir_db);
        end
        
        function sir_lin = get.sir_linear(obj)
            % 获取线性信干比
            sir_lin = 10^(obj.current_sir_db / 10);
        end
        
        function power_dbm = get.signal_power_dbm(obj)
            % 获取信号功率 (dBm)
            power_dbm = 10 * log10(obj.signal_power * 1000);
        end
        
        function power_dbm = get.jamming_power_dbm(obj)
            % 获取干扰功率 (dBm)
            power_dbm = 10 * log10(obj.jamming_power * 1000);
        end
        
        function power_dbm = get.total_power_dbm(obj)
            % 获取总功率 (dBm)
            power_dbm = 10 * log10(obj.total_power * 1000);
        end
        
        function obj = set_target_sir(obj, target_sir_db)
            % 设置目标信干比
            % 输入: target_sir_db - 目标信干比 (dB)
            
            % 验证输入
            if target_sir_db < obj.MIN_SIR_DB || target_sir_db > obj.MAX_SIR_DB
                error('SIRController:InvalidSIR', ...
                      '信干比必须在 %.1f 到 %.1f dB 之间', ...
                      obj.MIN_SIR_DB, obj.MAX_SIR_DB);
            end
            
            obj.target_sir_db = target_sir_db;
            obj.is_converged = false;
            
            fprintf('目标信干比设置为: %.1f dB\n', target_sir_db);
        end
        
        function [adjusted_jamming_power, actual_sir_db] = control_sir(obj, signal, jamming_signal)
            % 控制信干比
            % 输入: signal - 通信信号
            %      jamming_signal - 干扰信号
            % 输出: adjusted_jamming_power - 调整后的干扰功率
            %      actual_sir_db - 实际信干比
            
            % 计算信号功率
            obj.signal_power = obj.calculate_signal_power(signal);
            
            % 计算初始干扰功率
            initial_jamming_power = obj.calculate_signal_power(jamming_signal);
            
            % 根据目标信干比计算所需干扰功率
            target_jamming_power = obj.calculate_required_jamming_power(obj.signal_power, obj.target_sir_db);
            
            % 计算功率调整因子
            power_adjustment_factor = sqrt(target_jamming_power / initial_jamming_power);
            
            % 调整干扰信号功率
            adjusted_jamming_signal = jamming_signal * power_adjustment_factor;
            adjusted_jamming_power = obj.calculate_signal_power(adjusted_jamming_signal);
            
            % 计算实际信干比
            actual_sir_db = obj.calculate_sir_db(obj.signal_power, adjusted_jamming_power);
            
            % 更新内部状态
            obj.jamming_power = adjusted_jamming_power;
            obj.current_sir_db = actual_sir_db;
            obj.total_power = obj.signal_power + obj.jamming_power;
            
            % 记录历史
            obj.record_measurement(obj.signal_power, adjusted_jamming_power, actual_sir_db);
            
            % 检查收敛
            obj.check_convergence();
            
            fprintf('SIR控制结果: 目标=%.1fdB, 实际=%.1fdB, 误差=%.2fdB\n', ...
                    obj.target_sir_db, actual_sir_db, abs(obj.target_sir_db - actual_sir_db));
        end
        
        function [combined_signal, sir_db] = combine_signals(obj, signal, jamming_signal, target_sir_db)
            % 合成信号并控制信干比
            % 输入: signal - 通信信号
            %      jamming_signal - 干扰信号
            %      target_sir_db - 目标信干比 (可选)
            % 输出: combined_signal - 合成信号
            %      sir_db - 实际信干比
            
            if nargin > 3
                obj.set_target_sir(target_sir_db);
            end
            
            % 控制信干比
            [adjusted_jamming_power, sir_db] = obj.control_sir(signal, jamming_signal);
            
            % 计算调整因子
            original_jamming_power = obj.calculate_signal_power(jamming_signal);
            adjustment_factor = sqrt(adjusted_jamming_power / original_jamming_power);
            
            % 调整干扰信号
            adjusted_jamming_signal = jamming_signal * adjustment_factor;
            
            % 合成信号
            combined_signal = signal + adjusted_jamming_signal;
            
            % 更新总功率
            obj.total_power = obj.calculate_signal_power(combined_signal);
        end
        
        function power = calculate_signal_power(obj, signal)
            % 计算信号功率
            % 输入: signal - 信号
            % 输出: power - 功率 (W)
            
            power = mean(abs(signal).^2);
        end
        
        function sir_db = calculate_sir_db(obj, signal_power, jamming_power)
            % 计算信干比
            % 输入: signal_power - 信号功率
            %      jamming_power - 干扰功率
            % 输出: sir_db - 信干比 (dB)
            
            if jamming_power <= 0
                sir_db = inf;
            else
                sir_db = 10 * log10(signal_power / jamming_power);
            end
        end
        
        function required_power = calculate_required_jamming_power(obj, signal_power, target_sir_db)
            % 计算所需干扰功率
            % 输入: signal_power - 信号功率
            %      target_sir_db - 目标信干比
            % 输出: required_power - 所需干扰功率
            
            target_sir_linear = 10^(target_sir_db / 10);
            required_power = signal_power / target_sir_linear;
        end
        
        function obj = activate(obj)
            % 激活控制器
            obj.is_active = true;
            fprintf('SIR控制器已激活\n');
        end
        
        function obj = deactivate(obj)
            % 停用控制器
            obj.is_active = false;
            fprintf('SIR控制器已停用\n');
        end
        
        function obj = reset(obj)
            % 重置控制器
            obj.current_sir_db = 0;
            obj.signal_power = 0;
            obj.jamming_power = 0;
            obj.total_power = 0;
            obj.power_history = [];
            obj.sir_history = [];
            obj.iteration_count = 0;
            obj.is_converged = false;
            
            fprintf('SIR控制器已重置\n');
        end
        
        function print_status(obj)
            % 打印控制器状态
            fprintf('=== SIR控制器状态 ===\n');
            fprintf('目标信干比: %.1f dB\n', obj.target_sir_db);
            fprintf('当前信干比: %.1f dB\n', obj.current_sir_db);
            fprintf('信号功率: %.2f dBm\n', obj.signal_power_dbm);
            fprintf('干扰功率: %.2f dBm\n', obj.jamming_power_dbm);
            fprintf('总功率: %.2f dBm\n', obj.total_power_dbm);
            fprintf('控制模式: %s\n', obj.control_mode);
            fprintf('收敛状态: %s\n', obj.is_converged ? '已收敛' : '未收敛');
            fprintf('激活状态: %s\n', obj.is_active ? '激活' : '停用');
            fprintf('迭代次数: %d\n', obj.iteration_count);
            fprintf('==================\n');
        end
        
        function plot_history(obj)
            % 绘制历史曲线
            if isempty(obj.sir_history)
                fprintf('没有历史数据可绘制\n');
                return;
            end
            
            figure('Name', 'SIR控制历史', 'NumberTitle', 'off');
            
            subplot(2,1,1);
            plot(obj.sir_history, 'b-', 'LineWidth', 2);
            hold on;
            plot([1, length(obj.sir_history)], [obj.target_sir_db, obj.target_sir_db], 'r--', 'LineWidth', 1);
            xlabel('迭代次数');
            ylabel('信干比 (dB)');
            title('信干比控制历史');
            legend('实际SIR', '目标SIR', 'Location', 'best');
            grid on;
            
            subplot(2,1,2);
            plot(10*log10(obj.power_history(:,1)*1000), 'g-', 'LineWidth', 2);
            hold on;
            plot(10*log10(obj.power_history(:,2)*1000), 'r-', 'LineWidth', 2);
            xlabel('迭代次数');
            ylabel('功率 (dBm)');
            title('功率控制历史');
            legend('信号功率', '干扰功率', 'Location', 'best');
            grid on;
        end
    end
    
    methods (Access = private)
        function initialize_parameters(obj, target_sir_db)
            % 初始化参数
            obj.target_sir_db = target_sir_db;
            obj.current_sir_db = 0;
            obj.signal_power = 0;
            obj.jamming_power = 0;
            obj.total_power = 0;
            
            obj.control_mode = 'auto';
            obj.power_adjustment_step = 0.1;  % 0.1 dB
            obj.convergence_threshold = 0.1;  % 0.1 dB
            
            obj.power_history = [];
            obj.sir_history = [];
            obj.iteration_count = 0;
            
            obj.is_converged = false;
            obj.is_active = true;
        end
        
        function record_measurement(obj, signal_power, jamming_power, sir_db)
            % 记录测量结果
            obj.iteration_count = obj.iteration_count + 1;
            obj.power_history(end+1, :) = [signal_power, jamming_power];
            obj.sir_history(end+1) = sir_db;
        end
        
        function check_convergence(obj)
            % 检查收敛性
            error_db = abs(obj.current_sir_db - obj.target_sir_db);
            obj.is_converged = error_db <= obj.convergence_threshold;
        end
    end
end
