classdef JammingFactory < handle
    % JammingFactory - 干扰信号工厂类
    % 负责创建和管理各种干扰信号实例
    %
    % 作者: Asaqe Lee
    % 日期: 2025-06-20
    
    properties (Constant)
        % 支持的干扰信号列表
        SUPPORTED_JAMMINGS = {'NoiseJamming', 'SweepJamming', 'FollowJamming', ...
                             'ContinuousWave', 'MultiTone', 'NarrowBand', ...
                             'WideBand', 'PulseJamming'};
        
        % 干扰信号类别
        JAMMING_CATEGORIES = {'targeted', 'barrage', 'follower'};
    end
    
    properties (Access = private)
        jamming_registry     % 干扰信号注册表
        config_templates     % 配置模板
        created_instances    % 已创建的实例
    end
    
    methods (Static)
        function instance = get_instance()
            % 获取单例实例
            persistent factory_instance;
            if isempty(factory_instance)
                factory_instance = JammingFactory();
            end
            instance = factory_instance;
        end
    end
    
    methods (Access = private)
        function obj = JammingFactory()
            % 私有构造函数（单例模式）
            obj.initialize_registry();
            obj.initialize_templates();
            obj.created_instances = containers.Map();
        end
    end
    
    methods
        function jamming_obj = create_jamming(obj, jamming_type, config)
            % 创建干扰信号实例
            % 输入: jamming_type - 干扰信号类型
            %      config - 配置参数
            % 输出: jamming_obj - 干扰信号对象
            
            % 验证干扰信号类型
            if ~obj.is_supported_jamming(jamming_type)
                error('JammingFactory:UnsupportedType', ...
                      '不支持的干扰信号类型: %s', jamming_type);
            end
            
            % 获取类名
            class_name = obj.jamming_registry(jamming_type);
            
            try
                % 创建实例
                jamming_obj = feval(class_name);
                
                % 配置参数
                if nargin > 2 && ~isempty(config)
                    jamming_obj = jamming_obj.configure_parameters(config);
                end
                
                % 记录创建的实例
                instance_id = sprintf('%s_%d', jamming_type, length(obj.created_instances) + 1);
                obj.created_instances(instance_id) = jamming_obj;
                
                fprintf('成功创建干扰信号: %s (ID: %s)\n', jamming_type, instance_id);
                
            catch ME
                error('JammingFactory:CreationFailed', ...
                      '创建干扰信号失败: %s\n错误信息: %s', jamming_type, ME.message);
            end
        end
        
        function jammings = get_jammings_by_category(obj, category)
            % 根据类别获取干扰信号列表
            % 输入: category - 干扰信号类别
            % 输出: jammings - 干扰信号列表
            
            all_jammings = obj.SUPPORTED_JAMMINGS;
            
            switch category
                case 'targeted'
                    % 瞄准式干扰
                    targeted_types = {'ContinuousWave', 'MultiTone', 'NarrowBand', 'NoiseJamming'};
                    jammings = intersect(all_jammings, targeted_types, 'stable');
                case 'barrage'
                    % 阻塞式干扰
                    barrage_types = {'WideBand', 'SweepJamming', 'PulseJamming'};
                    jammings = intersect(all_jammings, barrage_types, 'stable');
                case 'follower'
                    % 跟踪式干扰
                    follower_types = {'FollowJamming'};
                    jammings = intersect(all_jammings, follower_types, 'stable');
                otherwise
                    error('JammingFactory:InvalidCategory', '不支持的干扰信号类别: %s', category);
            end
        end
        
        function is_supported = is_supported_jamming(obj, jamming_type)
            % 检查是否支持指定的干扰信号类型
            is_supported = ismember(jamming_type, obj.SUPPORTED_JAMMINGS);
        end
        
        function template = get_config_template(obj, jamming_type)
            % 获取配置模板
            if obj.config_templates.isKey(jamming_type)
                template = obj.config_templates(jamming_type);
            else
                error('JammingFactory:NoTemplate', '没有找到配置模板: %s', jamming_type);
            end
        end
        
        function instances = get_all_instances(obj)
            % 获取所有创建的实例
            instances = obj.created_instances;
        end
        
        function obj = clear_instances(obj)
            % 清除所有实例
            obj.created_instances = containers.Map();
        end
        
        function print_supported_jammings(obj)
            % 打印支持的干扰信号列表
            fprintf('支持的干扰信号类型:\n');
            fprintf('==========================================\n');
            
            % 按类别分组显示
            categories = obj.JAMMING_CATEGORIES;
            for i = 1:length(categories)
                category = categories{i};
                jammings = obj.get_jammings_by_category(category);
                
                fprintf('\n%s:\n', obj.get_category_name(category));
                for j = 1:length(jammings)
                    fprintf('  %d. %s\n', j, jammings{j});
                end
            end
            fprintf('==========================================\n');
        end
        
        function print_instances_status(obj)
            % 打印所有实例状态
            instances = obj.created_instances;
            instance_ids = instances.keys;
            
            if isempty(instance_ids)
                fprintf('没有创建的干扰信号实例\n');
                return;
            end
            
            fprintf('干扰信号实例状态:\n');
            fprintf('==========================================\n');
            for i = 1:length(instance_ids)
                instance_id = instance_ids{i};
                jamming_obj = instances(instance_id);
                fprintf('\n实例ID: %s\n', instance_id);
                jamming_obj.print_status();
            end
        end
    end
    
    methods (Access = private)
        function initialize_registry(obj)
            % 初始化干扰信号注册表
            obj.jamming_registry = containers.Map();
            
            % 瞄准式干扰
            obj.jamming_registry('ContinuousWave') = 'ContinuousWave';
            obj.jamming_registry('MultiTone') = 'MultiTone';
            obj.jamming_registry('NarrowBand') = 'NarrowBand';
            obj.jamming_registry('NoiseJamming') = 'NoiseJamming';
            
            % 阻塞式干扰
            obj.jamming_registry('WideBand') = 'WideBand';
            obj.jamming_registry('SweepJamming') = 'SweepJamming';
            obj.jamming_registry('PulseJamming') = 'PulseJamming';
            
            % 跟踪式干扰
            obj.jamming_registry('FollowJamming') = 'FollowJamming';
        end
        
        function initialize_templates(obj)
            % 初始化配置模板
            obj.config_templates = containers.Map();
            
            % 基础模板
            base_template = struct();
            base_template.center_frequency = 100e6;  % 100 MHz
            base_template.bandwidth = 10e6;           % 10 MHz
            base_template.power_dbm = 0;              % 0 dBm
            base_template.sample_rate = 100e6;        % 100 MHz
            base_template.duration = 1.0;             % 1 second
            
            % 为每种干扰信号创建模板
            jammings = obj.SUPPORTED_JAMMINGS;
            for i = 1:length(jammings)
                obj.config_templates(jammings{i}) = base_template;
            end
            
            % 特殊配置
            % 宽带干扰需要更大的带宽
            wideband_template = base_template;
            wideband_template.bandwidth = 50e6;  % 50 MHz
            obj.config_templates('WideBand') = wideband_template;
            
            % 窄带干扰需要更小的带宽
            narrowband_template = base_template;
            narrowband_template.bandwidth = 1e6;  % 1 MHz
            obj.config_templates('NarrowBand') = narrowband_template;
        end
        
        function name = get_category_name(obj, category)
            % 获取类别中文名称
            switch category
                case 'targeted'
                    name = '瞄准式干扰';
                case 'barrage'
                    name = '阻塞式干扰';
                case 'follower'
                    name = '跟踪式干扰';
                otherwise
                    name = category;
            end
        end
    end
end
