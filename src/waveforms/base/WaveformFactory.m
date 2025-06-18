classdef WaveformFactory < handle
    % WaveformFactory - 波形工厂类
    % 负责创建和管理各种通信波形实例
    %
    % 作者: 通信干扰仿真平台开发团队
    % 日期: 2025-06-18
    
    properties (Constant)
        % 支持的波形列表
        SUPPORTED_WAVEFORMS = {'BPSK', 'QPSK', 'PSK8', 'QAM16', 'QAM64', 'QAM256', ...
                              'FSK', 'GFSK', 'MSK', 'GMSK', ...
                              'DSSS', 'FHSS', 'DSSS_FHSS', ...
                              'OFDM_BPSK', 'OFDM_QPSK', 'OFDM_16QAM', 'OFDM_64QAM', ...
                              'FM', 'AM', 'PM'};
    end
    
    properties (Access = private)
        waveform_registry    % 波形注册表
        config_templates     % 配置模板
        created_instances    % 已创建的实例
    end
    
    methods (Static)
        function factory = getInstance()
            % 获取工厂单例实例
            % 输出: factory - 工厂实例
            
            persistent instance;
            if isempty(instance)
                instance = WaveformFactory();
            end
            factory = instance;
        end
        
        function waveform_list = get_supported_waveforms()
            % 获取支持的波形列表
            % 输出: waveform_list - 波形列表
            
            waveform_list = WaveformFactory.SUPPORTED_WAVEFORMS;
        end
        
        function category_list = get_waveform_categories()
            % 获取波形类别列表
            % 输出: category_list - 类别列表

            category_list = {'digital', 'analog', 'spread_spectrum', 'ofdm'};
        end

        function waveforms = get_waveforms_by_category(category)
            % 根据类别获取波形列表
            % 输入: category - 波形类别
            % 输出: waveforms - 波形列表

            all_waveforms = WaveformFactory.SUPPORTED_WAVEFORMS;
            waveforms = {};

            switch category
                case 'digital'
                    % 数字调制波形
                    digital_types = {'BPSK', 'QPSK', 'PSK8', 'QAM16', 'QAM64', 'QAM256', 'FSK', 'GFSK', 'MSK', 'GMSK'};
                    waveforms = intersect(all_waveforms, digital_types, 'stable');
                case 'analog'
                    % 模拟调制波形
                    analog_types = {'FM', 'AM', 'PM'};
                    waveforms = intersect(all_waveforms, analog_types, 'stable');
                case 'spread_spectrum'
                    % 扩频波形
                    spread_types = {'DSSS', 'FHSS', 'DSSS_FHSS'};
                    waveforms = intersect(all_waveforms, spread_types, 'stable');
                case 'ofdm'
                    % OFDM波形
                    ofdm_types = {'OFDM_BPSK', 'OFDM_QPSK', 'OFDM_16QAM', 'OFDM_64QAM'};
                    waveforms = intersect(all_waveforms, ofdm_types, 'stable');
                otherwise
                    error('WaveformFactory:InvalidCategory', '不支持的波形类别: %s', category);
            end
        end
        
        function is_supported = is_waveform_supported(waveform_type)
            % 检查是否支持指定波形
            % 输入: waveform_type - 波形类型
            % 输出: is_supported - 是否支持
            
            is_supported = ismember(waveform_type, WaveformFactory.SUPPORTED_WAVEFORMS);
        end
    end
    
    methods
        function obj = WaveformFactory()
            % 构造函数（私有，用于单例模式）
            
            obj.waveform_registry = containers.Map();
            obj.config_templates = containers.Map();
            obj.created_instances = containers.Map();
            
            % 初始化波形注册表
            obj.initialize_registry();
            
            % 初始化配置模板
            obj.initialize_config_templates();
        end
        
        function waveform = create_waveform(obj, waveform_type, varargin)
            % 创建波形实例
            % 输入: waveform_type - 波形类型
            %      varargin - 可选配置参数
            % 输出: waveform - 波形实例
            
            % 检查波形类型是否支持
            if ~obj.is_waveform_supported(waveform_type)
                error('WaveformFactory:UnsupportedWaveform', '不支持的波形类型: %s', waveform_type);
            end
            
            % 获取波形类名
            class_name = obj.get_waveform_class(waveform_type);
            
            try
                % 创建波形实例
                waveform = feval(class_name);
                
                % 应用配置模板
                if isKey(obj.config_templates, waveform_type)
                    template_config = obj.config_templates(waveform_type);
                    waveform.configure(template_config.get_config());
                end
                
                % 应用用户提供的配置
                if nargin > 2
                    if isstruct(varargin{1})
                        waveform.configure(varargin{1});
                    else
                        % 参数名值对
                        config = struct();
                        for i = 1:2:length(varargin)
                            if i+1 <= length(varargin)
                                config.(varargin{i}) = varargin{i+1};
                            end
                        end
                        waveform.configure(config);
                    end
                end
                
                % 生成实例ID并保存
                instance_id = obj.generate_instance_id(waveform_type);
                obj.created_instances(instance_id) = waveform;
                
                fprintf('成功创建波形实例: %s (ID: %s)\n', waveform_type, instance_id);
                
            catch ME
                error('WaveformFactory:CreationFailed', '创建波形失败: %s', ME.message);
            end
        end
        
        function waveform = create_waveform_by_id(obj, waveform_id, varargin)
            % 根据波形ID创建波形实例
            % 输入: waveform_id - 波形ID (1-100)
            %      varargin - 可选配置参数
            % 输出: waveform - 波形实例
            
            % 根据ID查找波形类型
            waveform_type = obj.get_waveform_type_by_id(waveform_id);
            
            if isempty(waveform_type)
                error('WaveformFactory:InvalidID', '无效的波形ID: %d', waveform_id);
            end
            
            % 创建波形实例
            waveform = obj.create_waveform(waveform_type, varargin{:});
        end
        
        function config = get_default_config(obj, waveform_type)
            % 获取默认配置
            % 输入: waveform_type - 波形类型
            % 输出: config - 默认配置
            
            if isKey(obj.config_templates, waveform_type)
                template = obj.config_templates(waveform_type);
                config = template.get_config();
            else
                error('WaveformFactory:NoTemplate', '没有找到波形 %s 的配置模板', waveform_type);
            end
        end
        
        function set_default_config(obj, waveform_type, config)
            % 设置默认配置
            % 输入: waveform_type - 波形类型
            %      config - 配置结构体或WaveformConfig对象
            
            if isa(config, 'WaveformConfig')
                obj.config_templates(waveform_type) = config;
            elseif isstruct(config)
                template = WaveformConfig(config);
                obj.config_templates(waveform_type) = template;
            else
                error('WaveformFactory:InvalidConfig', '配置必须是结构体或WaveformConfig对象');
            end
            
            fprintf('已设置波形 %s 的默认配置\n', waveform_type);
        end
        
        function instances = get_created_instances(obj)
            % 获取已创建的实例列表
            % 输出: instances - 实例映射表
            
            instances = obj.created_instances;
        end
        
        function clear_instances(obj)
            % 清除所有已创建的实例
            
            obj.created_instances = containers.Map();
            fprintf('已清除所有波形实例\n');
        end
        
        function info = get_waveform_info(obj, waveform_type)
            % 获取波形信息
            % 输入: waveform_type - 波形类型
            % 输出: info - 波形信息结构体
            
            if ~obj.is_waveform_supported(waveform_type)
                error('WaveformFactory:UnsupportedWaveform', '不支持的波形类型: %s', waveform_type);
            end
            
            info = struct();
            info.waveform_type = waveform_type;
            info.class_name = obj.get_waveform_class(waveform_type);
            info.category = obj.get_waveform_category(waveform_type);
            info.is_supported = true;
            
            % 获取默认配置信息
            if isKey(obj.config_templates, waveform_type)
                template = obj.config_templates(waveform_type);
                info.default_config = template.get_config();
            else
                info.default_config = struct();
            end
        end
        
        function print_supported_waveforms(obj)
            % 打印支持的波形列表
            
            fprintf('=== 支持的通信波形 ===\n');
            
            categories = obj.get_waveform_categories();
            for i = 1:length(categories)
                category = categories{i};
                fprintf('\n%s 波形:\n', category);
                
                waveforms = obj.get_waveforms_by_category(category);
                for j = 1:length(waveforms)
                    waveform_type = waveforms{j};
                    class_name = obj.get_waveform_class(waveform_type);
                    fprintf('  %2d. %s (%s)\n', j, waveform_type, class_name);
                end
            end
            
            fprintf('\n总计: %d 种波形\n', length(obj.SUPPORTED_WAVEFORMS));
            fprintf('====================\n');
        end
        
        function validate_all_waveforms(obj)
            % 验证所有波形的可用性
            
            fprintf('验证波形可用性...\n');
            
            valid_count = 0;
            invalid_waveforms = {};
            
            for i = 1:length(obj.SUPPORTED_WAVEFORMS)
                waveform_type = obj.SUPPORTED_WAVEFORMS{i};
                class_name = obj.get_waveform_class(waveform_type);
                
                try
                    % 尝试创建实例
                    if exist(class_name, 'class') == 8
                        fprintf('  ✓ %s\n', waveform_type);
                        valid_count = valid_count + 1;
                    else
                        fprintf('  ✗ %s (类文件不存在)\n', waveform_type);
                        invalid_waveforms{end+1} = waveform_type;
                    end
                catch ME
                    fprintf('  ✗ %s (错误: %s)\n', waveform_type, ME.message);
                    invalid_waveforms{end+1} = waveform_type;
                end
            end
            
            fprintf('\n验证结果:\n');
            fprintf('  有效波形: %d/%d\n', valid_count, length(obj.SUPPORTED_WAVEFORMS));
            fprintf('  无效波形: %d\n', length(invalid_waveforms));
            
            if ~isempty(invalid_waveforms)
                fprintf('  无效波形列表: %s\n', strjoin(invalid_waveforms, ', '));
            end
        end
    end
    
    methods (Access = private)
        function initialize_registry(obj)
            % 初始化波形注册表
            
            % 数字调制波形
            obj.waveform_registry('BPSK') = 'BPSK';
            obj.waveform_registry('QPSK') = 'QPSK';
            obj.waveform_registry('PSK8') = 'PSK8';
            obj.waveform_registry('QAM16') = 'QAM16';
            obj.waveform_registry('QAM64') = 'QAM64';
            obj.waveform_registry('QAM256') = 'QAM256';
            
            % 频移键控波形
            obj.waveform_registry('FSK') = 'FSK';
            obj.waveform_registry('GFSK') = 'GFSK';
            obj.waveform_registry('MSK') = 'MSK';
            obj.waveform_registry('GMSK') = 'GMSK';
            
            % 扩频波形
            obj.waveform_registry('DSSS') = 'DSSS';
            obj.waveform_registry('FHSS') = 'FHSS';
            obj.waveform_registry('DSSS_FHSS') = 'DSSS_FHSS';
            
            % OFDM波形
            obj.waveform_registry('OFDM_BPSK') = 'OFDM_BPSK';
            obj.waveform_registry('OFDM_QPSK') = 'OFDM_QPSK';
            obj.waveform_registry('OFDM_16QAM') = 'OFDM_16QAM';
            obj.waveform_registry('OFDM_64QAM') = 'OFDM_64QAM';
            
            % 模拟调制波形
            obj.waveform_registry('FM') = 'FM';
            obj.waveform_registry('AM') = 'AM';
            obj.waveform_registry('PM') = 'PM';
        end
        
        function initialize_config_templates(obj)
            % 初始化配置模板
            
            % 为每种波形创建默认配置模板
            waveform_types = keys(obj.waveform_registry);
            
            for i = 1:length(waveform_types)
                waveform_type = waveform_types{i};
                
                % 创建基础配置
                config = WaveformConfig();
                config.set_param('waveform_name', waveform_type);
                config.set_param('modulation_type', obj.get_modulation_type(waveform_type));
                config.set_param('category', obj.get_waveform_category(waveform_type));
                
                % 设置特定参数
                obj.set_specific_config(config, waveform_type);
                
                obj.config_templates(waveform_type) = config;
            end
        end
        
        function class_name = get_waveform_class(obj, waveform_type)
            % 获取波形类名
            % 输入: waveform_type - 波形类型
            % 输出: class_name - 类名
            
            if isKey(obj.waveform_registry, waveform_type)
                class_name = obj.waveform_registry(waveform_type);
            else
                error('WaveformFactory:UnknownWaveform', '未知的波形类型: %s', waveform_type);
            end
        end
        
        function category = get_waveform_category(obj, waveform_type)
            % 获取波形类别
            % 输入: waveform_type - 波形类型
            % 输出: category - 波形类别
            
            if contains(waveform_type, 'OFDM')
                category = 'ofdm';
            elseif ismember(waveform_type, {'DSSS', 'FHSS', 'DSSS_FHSS'})
                category = 'spread_spectrum';
            elseif ismember(waveform_type, {'FM', 'AM', 'PM'})
                category = 'analog';
            else
                category = 'digital';
            end
        end
        
        function mod_type = get_modulation_type(obj, waveform_type)
            % 获取调制类型
            % 输入: waveform_type - 波形类型
            % 输出: mod_type - 调制类型
            
            if contains(waveform_type, 'PSK')
                mod_type = 'PSK';
            elseif contains(waveform_type, 'QAM')
                mod_type = 'QAM';
            elseif contains(waveform_type, 'FSK') || contains(waveform_type, 'MSK')
                mod_type = 'FSK';
            elseif contains(waveform_type, 'OFDM')
                mod_type = 'OFDM';
            elseif contains(waveform_type, 'DSSS')
                mod_type = 'DSSS';
            elseif contains(waveform_type, 'FHSS')
                mod_type = 'FHSS';
            else
                mod_type = waveform_type;
            end
        end
        
        function set_specific_config(obj, config, waveform_type)
            % 设置特定波形的配置参数
            % 输入: config - 配置对象
            %      waveform_type - 波形类型
            
            switch waveform_type
                case 'BPSK'
                    config.set_param('modulation_order', 2);
                case 'QPSK'
                    config.set_param('modulation_order', 4);
                case 'PSK8'
                    config.set_param('modulation_order', 8);
                case 'QAM16'
                    config.set_param('modulation_order', 16);
                case 'QAM64'
                    config.set_param('modulation_order', 64);
                case 'QAM256'
                    config.set_param('modulation_order', 256);
                otherwise
                    % 使用默认配置
            end
        end
        
        function waveform_type = get_waveform_type_by_id(obj, waveform_id)
            % 根据ID获取波形类型
            % 输入: waveform_id - 波形ID
            % 输出: waveform_type - 波形类型
            
            waveform_type = '';
            
            % 简单的ID映射（实际应该从配置文件或数据库读取）
            if waveform_id >= 1 && waveform_id <= length(obj.SUPPORTED_WAVEFORMS)
                waveform_type = obj.SUPPORTED_WAVEFORMS{waveform_id};
            end
        end
        
        function instance_id = generate_instance_id(obj, waveform_type)
            % 生成实例ID
            % 输入: waveform_type - 波形类型
            % 输出: instance_id - 实例ID
            
            timestamp = datestr(now, 'yyyymmdd_HHMMSS_FFF');
            instance_id = sprintf('%s_%s', waveform_type, timestamp);
        end
    end
end
