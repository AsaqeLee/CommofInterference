classdef WaveformConfig < handle
    % WaveformConfig - 波形配置管理类
    % 负责管理和验证波形配置参数
    %
    % 作者: Asaqe Lee
    % 日期: 2025-06-18
    
    properties (Constant)
        % 支持的调制类型
        SUPPORTED_MODULATIONS = {'PSK', 'QAM', 'FSK', 'OFDM', 'FM', 'DSSS', 'FHSS'};
        
        % 支持的信道类型
        SUPPORTED_CHANNELS = {'AWGN', 'Rayleigh', 'Rician', 'MultiPath'};
        
        % 支持的脉冲成形类型
        SUPPORTED_PULSE_SHAPING = {'none', 'rrc', 'gaussian', 'rectangular'};
        
        % 支持的编码方案
        SUPPORTED_CODING = {'none', 'convolutional', 'turbo', 'ldpc', 'hamming'};
        
        % 频率范围 (Hz)
        MIN_FREQUENCY = 1e6;      % 1 MHz
        MAX_FREQUENCY = 100e9;    % 100 GHz
        
        % 数据速率范围 (bps)
        MIN_DATA_RATE = 1e3;      % 1 kbps
        MAX_DATA_RATE = 1e9;      % 1 Gbps
        
        % 信噪比范围 (dB)
        MIN_SNR = -50;
        MAX_SNR = 50;
    end
    
    properties (Access = private)
        config_data    % 配置数据结构体
        is_valid      % 配置是否有效
        error_messages % 错误信息列表
    end
    
    methods
        function obj = WaveformConfig(varargin)
            % 构造函数
            % 输入: varargin - 可选的配置参数
            
            obj.config_data = struct();
            obj.is_valid = false;
            obj.error_messages = {};
            
            % 初始化默认配置
            obj.initialize_defaults();
            
            % 如果提供了配置参数，则设置配置
            if nargin > 0
                obj.set_config(varargin{:});
            end
        end
        
        function set_config(obj, varargin)
            % 设置配置参数
            % 输入: varargin - 参数名值对或配置结构体
            
            if nargin == 2 && isstruct(varargin{1})
                % 输入是结构体
                config_struct = varargin{1};
                fields = fieldnames(config_struct);
                for i = 1:length(fields)
                    obj.config_data.(fields{i}) = config_struct.(fields{i});
                end
            else
                % 输入是参数名值对
                for i = 1:2:length(varargin)
                    if i+1 <= length(varargin)
                        param_name = varargin{i};
                        param_value = varargin{i+1};
                        obj.config_data.(param_name) = param_value;
                    end
                end
            end
            
            % 验证配置
            obj.validate();
        end
        
        function config = get_config(obj)
            % 获取配置结构体
            % 输出: config - 配置结构体
            
            config = obj.config_data;
        end
        
        function value = get_param(obj, param_name)
            % 获取特定参数值
            % 输入: param_name - 参数名
            % 输出: value - 参数值
            
            if isfield(obj.config_data, param_name)
                value = obj.config_data.(param_name);
            else
                error('WaveformConfig:ParamNotFound', '参数 %s 不存在', param_name);
            end
        end
        
        function set_param(obj, param_name, param_value)
            % 设置特定参数值
            % 输入: param_name - 参数名
            %      param_value - 参数值
            
            obj.config_data.(param_name) = param_value;
            obj.validate();
        end
        
        function valid = is_config_valid(obj)
            % 检查配置是否有效
            % 输出: valid - 是否有效
            
            valid = obj.is_valid;
        end
        
        function messages = get_error_messages(obj)
            % 获取错误信息
            % 输出: messages - 错误信息列表
            
            messages = obj.error_messages;
        end
        
        function print_config(obj)
            % 打印配置信息
            
            fprintf('=== 波形配置信息 ===\n');
            fprintf('配置状态: %s\n', obj.get_status_string());
            
            if ~obj.is_valid && ~isempty(obj.error_messages)
                fprintf('错误信息:\n');
                for i = 1:length(obj.error_messages)
                    fprintf('  - %s\n', obj.error_messages{i});
                end
                fprintf('\n');
            end
            
            fprintf('基础参数:\n');
            fprintf('  波形ID: %d\n', obj.get_param_safe('waveform_id', 'N/A'));
            fprintf('  波形名称: %s\n', obj.get_param_safe('waveform_name', 'N/A'));
            fprintf('  调制类型: %s\n', obj.get_param_safe('modulation_type', 'N/A'));
            fprintf('  中心频率: %.2f MHz\n', obj.get_param_safe('center_frequency', 0) / 1e6);
            fprintf('  带宽: %.2f MHz\n', obj.get_param_safe('bandwidth', 0) / 1e6);
            fprintf('  数据速率: %.2f kbps\n', obj.get_param_safe('data_rate', 0) / 1e3);
            fprintf('  采样率: %.2f MHz\n', obj.get_param_safe('sample_rate', 0) / 1e6);
            
            fprintf('调制参数:\n');
            fprintf('  调制阶数: %d\n', obj.get_param_safe('modulation_order', 0));
            fprintf('  编码方案: %s\n', obj.get_param_safe('coding_scheme', 'N/A'));
            fprintf('  编码率: %.2f\n', obj.get_param_safe('coding_rate', 0));
            
            fprintf('跳频参数:\n');
            fprintf('  跳频使能: %s\n', obj.get_bool_string('hopping_enabled'));
            fprintf('  跳频速率: %.0f Hop/s\n', obj.get_param_safe('hopping_rate', 0));
            
            fprintf('信道参数:\n');
            fprintf('  信道类型: %s\n', obj.get_param_safe('channel_type', 'N/A'));
            fprintf('  信噪比: %.1f dB\n', obj.get_param_safe('snr_db', 0));
            
            fprintf('滤波器参数:\n');
            fprintf('  脉冲成形: %s\n', obj.get_param_safe('pulse_shaping', 'N/A'));
            fprintf('  滚降因子: %.2f\n', obj.get_param_safe('filter_rolloff', 0));
            
            fprintf('仿真参数:\n');
            fprintf('  仿真时长: %.3f ms\n', obj.get_param_safe('simulation_time', 0) * 1000);
            fprintf('  符号数量: %d\n', obj.get_param_safe('num_symbols', 0));
            
            fprintf('==================\n');
        end
        
        function save_to_file(obj, filename)
            % 保存配置到文件
            % 输入: filename - 文件名
            
            try
                config_data = obj.config_data;
                save(filename, 'config_data');
                fprintf('配置已保存到文件: %s\n', filename);
            catch ME
                error('WaveformConfig:SaveError', '保存配置失败: %s', ME.message);
            end
        end
        
        function load_from_file(obj, filename)
            % 从文件加载配置
            % 输入: filename - 文件名
            
            try
                loaded_data = load(filename);
                if isfield(loaded_data, 'config_data')
                    obj.config_data = loaded_data.config_data;
                    obj.validate();
                    fprintf('配置已从文件加载: %s\n', filename);
                else
                    error('文件中未找到config_data字段');
                end
            catch ME
                error('WaveformConfig:LoadError', '加载配置失败: %s', ME.message);
            end
        end
        
        function copy_obj = copy(obj)
            % 创建配置的副本
            % 输出: copy_obj - 配置副本
            
            copy_obj = WaveformConfig();
            copy_obj.config_data = obj.config_data;
            copy_obj.is_valid = obj.is_valid;
            copy_obj.error_messages = obj.error_messages;
        end
        
        function merge_config(obj, other_config)
            % 合并另一个配置
            % 输入: other_config - 另一个WaveformConfig对象或结构体
            
            if isa(other_config, 'WaveformConfig')
                merge_data = other_config.get_config();
            elseif isstruct(other_config)
                merge_data = other_config;
            else
                error('WaveformConfig:InvalidInput', '输入必须是WaveformConfig对象或结构体');
            end
            
            fields = fieldnames(merge_data);
            for i = 1:length(fields)
                obj.config_data.(fields{i}) = merge_data.(fields{i});
            end
            
            obj.validate();
        end
    end
    
    methods (Access = private)
        function initialize_defaults(obj)
            % 初始化默认配置
            
            obj.config_data.waveform_id = 1;
            obj.config_data.waveform_name = 'Default Waveform';
            obj.config_data.modulation_type = 'PSK';
            obj.config_data.category = 'digital';
            obj.config_data.center_frequency = 1e9;      % 1 GHz
            obj.config_data.bandwidth = 1e6;             % 1 MHz
            obj.config_data.data_rate = 1e6;             % 1 Mbps
            obj.config_data.sample_rate = 10e6;          % 10 MHz
            obj.config_data.symbol_rate = 1e6;           % 1 Msps
            obj.config_data.modulation_order = 2;        % 二进制
            obj.config_data.coding_scheme = 'none';      % 无编码
            obj.config_data.coding_rate = 1;             % 编码率1
            obj.config_data.hopping_enabled = false;     % 不启用跳频
            obj.config_data.hopping_rate = 0;            % 跳频速率0
            obj.config_data.frequency_set = [];          % 空频点集
            obj.config_data.channel_type = 'AWGN';       % AWGN信道
            obj.config_data.snr_db = 10;                 % 10dB信噪比
            obj.config_data.pulse_shaping = 'none';      % 无脉冲成形
            obj.config_data.filter_rolloff = 0.35;       % 滚降因子0.35
            obj.config_data.simulation_time = 1e-3;      % 1ms仿真时长
            obj.config_data.num_symbols = 1000;          % 1000个符号
        end
        
        function validate(obj)
            % 验证配置参数
            
            obj.error_messages = {};
            obj.is_valid = true;
            
            % 验证基础参数
            obj.validate_basic_params();
            
            % 验证调制参数
            obj.validate_modulation_params();
            
            % 验证跳频参数
            obj.validate_hopping_params();
            
            % 验证信道参数
            obj.validate_channel_params();
            
            % 验证滤波器参数
            obj.validate_filter_params();
            
            % 验证仿真参数
            obj.validate_simulation_params();
            
            % 验证参数间的一致性
            obj.validate_consistency();
            
            % 如果有错误，设置为无效
            if ~isempty(obj.error_messages)
                obj.is_valid = false;
            end
        end
        
        function validate_basic_params(obj)
            % 验证基础参数
            
            % 验证中心频率
            if isfield(obj.config_data, 'center_frequency')
                fc = obj.config_data.center_frequency;
                if fc < obj.MIN_FREQUENCY || fc > obj.MAX_FREQUENCY
                    obj.add_error(sprintf('中心频率超出范围 [%.0f, %.0f] Hz', ...
                        obj.MIN_FREQUENCY, obj.MAX_FREQUENCY));
                end
            end
            
            % 验证带宽
            if isfield(obj.config_data, 'bandwidth')
                bw = obj.config_data.bandwidth;
                if bw <= 0
                    obj.add_error('带宽必须大于0');
                end
            end
            
            % 验证数据速率
            if isfield(obj.config_data, 'data_rate')
                dr = obj.config_data.data_rate;
                if dr < obj.MIN_DATA_RATE || dr > obj.MAX_DATA_RATE
                    obj.add_error(sprintf('数据速率超出范围 [%.0f, %.0f] bps', ...
                        obj.MIN_DATA_RATE, obj.MAX_DATA_RATE));
                end
            end
            
            % 验证采样率
            if isfield(obj.config_data, 'sample_rate')
                fs = obj.config_data.sample_rate;
                if fs <= 0
                    obj.add_error('采样率必须大于0');
                end
                
                % 检查奈奎斯特定理
                if isfield(obj.config_data, 'bandwidth')
                    bw = obj.config_data.bandwidth;
                    if fs < 2 * bw
                        obj.add_error('采样率不满足奈奎斯特定理 (fs >= 2*BW)');
                    end
                end
            end
        end
        
        function validate_modulation_params(obj)
            % 验证调制参数
            
            % 验证调制类型
            if isfield(obj.config_data, 'modulation_type')
                mod_type = obj.config_data.modulation_type;
                if ~ismember(mod_type, obj.SUPPORTED_MODULATIONS)
                    obj.add_error(sprintf('不支持的调制类型: %s', mod_type));
                end
            end
            
            % 验证调制阶数
            if isfield(obj.config_data, 'modulation_order')
                M = obj.config_data.modulation_order;
                if M < 2 || mod(log2(M), 1) ~= 0
                    obj.add_error('调制阶数必须是2的幂次且大于等于2');
                end
            end
            
            % 验证编码方案
            if isfield(obj.config_data, 'coding_scheme')
                coding = obj.config_data.coding_scheme;
                if ~ismember(coding, obj.SUPPORTED_CODING)
                    obj.add_error(sprintf('不支持的编码方案: %s', coding));
                end
            end
            
            % 验证编码率
            if isfield(obj.config_data, 'coding_rate')
                rate = obj.config_data.coding_rate;
                if rate <= 0 || rate > 1
                    obj.add_error('编码率必须在(0, 1]范围内');
                end
            end
        end
        
        function validate_hopping_params(obj)
            % 验证跳频参数
            
            % 验证跳频速率
            if isfield(obj.config_data, 'hopping_rate')
                hop_rate = obj.config_data.hopping_rate;
                if hop_rate < 0
                    obj.add_error('跳频速率不能为负数');
                end
            end
            
            % 如果启用跳频，检查频点集
            if isfield(obj.config_data, 'hopping_enabled') && ...
               obj.config_data.hopping_enabled
                if isfield(obj.config_data, 'frequency_set')
                    freq_set = obj.config_data.frequency_set;
                    if isempty(freq_set)
                        obj.add_error('启用跳频时必须设置频点集');
                    elseif length(freq_set) < 2
                        obj.add_error('频点集至少需要2个频点');
                    end
                end
            end
        end
        
        function validate_channel_params(obj)
            % 验证信道参数
            
            % 验证信道类型
            if isfield(obj.config_data, 'channel_type')
                ch_type = obj.config_data.channel_type;
                if ~ismember(ch_type, obj.SUPPORTED_CHANNELS)
                    obj.add_error(sprintf('不支持的信道类型: %s', ch_type));
                end
            end
            
            % 验证信噪比
            if isfield(obj.config_data, 'snr_db')
                snr = obj.config_data.snr_db;
                if snr < obj.MIN_SNR || snr > obj.MAX_SNR
                    obj.add_error(sprintf('信噪比超出范围 [%d, %d] dB', ...
                        obj.MIN_SNR, obj.MAX_SNR));
                end
            end
        end
        
        function validate_filter_params(obj)
            % 验证滤波器参数
            
            % 验证脉冲成形类型
            if isfield(obj.config_data, 'pulse_shaping')
                ps_type = obj.config_data.pulse_shaping;
                if ~ismember(ps_type, obj.SUPPORTED_PULSE_SHAPING)
                    obj.add_error(sprintf('不支持的脉冲成形类型: %s', ps_type));
                end
            end
            
            % 验证滚降因子
            if isfield(obj.config_data, 'filter_rolloff')
                rolloff = obj.config_data.filter_rolloff;
                if rolloff < 0 || rolloff > 1
                    obj.add_error('滚降因子必须在[0, 1]范围内');
                end
            end
        end
        
        function validate_simulation_params(obj)
            % 验证仿真参数
            
            % 验证仿真时长
            if isfield(obj.config_data, 'simulation_time')
                sim_time = obj.config_data.simulation_time;
                if sim_time <= 0
                    obj.add_error('仿真时长必须大于0');
                end
            end
            
            % 验证符号数量
            if isfield(obj.config_data, 'num_symbols')
                num_sym = obj.config_data.num_symbols;
                if num_sym <= 0 || mod(num_sym, 1) ~= 0
                    obj.add_error('符号数量必须是正整数');
                end
            end
        end
        
        function validate_consistency(obj)
            % 验证参数间的一致性
            
            % 检查符号速率和数据速率的一致性
            if isfield(obj.config_data, 'symbol_rate') && ...
               isfield(obj.config_data, 'data_rate') && ...
               isfield(obj.config_data, 'modulation_order')
                
                Rs = obj.config_data.symbol_rate;
                Rb = obj.config_data.data_rate;
                M = obj.config_data.modulation_order;
                
                expected_Rb = Rs * log2(M);
                if abs(Rb - expected_Rb) / expected_Rb > 0.01  % 1%容差
                    obj.add_error(sprintf('数据速率与符号速率不一致: 期望%.0f bps, 实际%.0f bps', ...
                        expected_Rb, Rb));
                end
            end
            
            % 检查仿真时长和符号数量的一致性
            if isfield(obj.config_data, 'simulation_time') && ...
               isfield(obj.config_data, 'num_symbols') && ...
               isfield(obj.config_data, 'symbol_rate')
                
                sim_time = obj.config_data.simulation_time;
                num_sym = obj.config_data.num_symbols;
                Rs = obj.config_data.symbol_rate;
                
                expected_time = num_sym / Rs;
                if abs(sim_time - expected_time) / expected_time > 0.01  % 1%容差
                    obj.add_error(sprintf('仿真时长与符号数量不一致: 期望%.3f ms, 实际%.3f ms', ...
                        expected_time*1000, sim_time*1000));
                end
            end
        end
        
        function add_error(obj, message)
            % 添加错误信息
            % 输入: message - 错误信息
            
            obj.error_messages{end+1} = message;
        end
        
        function value = get_param_safe(obj, param_name, default_value)
            % 安全获取参数值
            % 输入: param_name - 参数名
            %      default_value - 默认值
            % 输出: value - 参数值
            
            if isfield(obj.config_data, param_name)
                value = obj.config_data.(param_name);
            else
                value = default_value;
            end
        end
        
        function str = get_bool_string(obj, param_name)
            % 获取布尔参数的字符串表示
            % 输入: param_name - 参数名
            % 输出: str - 字符串表示
            
            value = obj.get_param_safe(param_name, false);
            if value
                str = '是';
            else
                str = '否';
            end
        end
        
        function str = get_status_string(obj)
            % 获取配置状态字符串
            % 输出: str - 状态字符串
            
            if obj.is_valid
                str = '有效';
            else
                str = '无效';
            end
        end
    end
end
