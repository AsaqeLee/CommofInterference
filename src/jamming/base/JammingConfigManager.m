classdef JammingConfigManager < handle
    % JammingConfigManager - 干扰信号配置管理器
    % 按照用户提供的干扰信号分类表管理8种干扰信号配置
    %
    % 作者: Asaqe Lee
    % 日期: 2025-06-20
    
    properties (Constant)
        % 8种干扰信号配置
        JAMMING_CONFIGS = containers.Map('KeyType', 'int32', 'ValueType', 'any');
    end
    
    properties (Access = private, Constant)
        % 干扰信号定义表
        JAMMING_DEFINITIONS = {
            % ID, 体制,     信号样式,    调制方式,           带宽,        特殊参数
            1,  '瞄准式',  '单音',      'CW',              0,           '单一频率连续波';
            2,  '瞄准式',  '多音',      'CW',              0,           '多个频率组合';
            3,  '瞄准式',  '窄带',      'QPSK/16QAM',      10e3,        '10kHz带宽数字调制';
            4,  '瞄准式',  '噪声调频',  'FM',              0,           '高斯白噪声调制';
            5,  '阻塞式',  '宽带',      'QPSK/16QAM',      0,           '通信带宽覆盖';
            6,  '阻塞式',  '宽带梳状谱','高斯白噪声+梳状滤波器', 0,      '3个梳状谱';
            7,  '阻塞式',  '扫频',      'LFM',             0,           '扫频周期0.5ms';
            8,  '跟踪式',  '跳频',      'CW',              0,           '模仿通信跳频图案'
        };
    end
    
    methods (Static)
        function configs = initialize_all_configs()
            % 初始化所有8种干扰信号配置
            
            configs = containers.Map('KeyType', 'int32', 'ValueType', 'any');
            
            % 根据定义表创建配置
            definitions = JammingConfigManager.JAMMING_DEFINITIONS;
            
            for i = 1:size(definitions, 1)
                jamming_id = definitions{i, 1};
                regime = definitions{i, 2};
                signal_type = definitions{i, 3};
                modulation = definitions{i, 4};
                bandwidth = definitions{i, 5};
                description = definitions{i, 6};
                
                config = JammingConfigManager.create_jamming_config(...
                    jamming_id, regime, signal_type, modulation, bandwidth, description);
                
                configs(jamming_id) = config;
            end
        end
        
        function config = create_jamming_config(jamming_id, regime, signal_type, modulation, bandwidth, description)
            % 创建单个干扰信号配置
            
            config = struct();
            config.jamming_id = jamming_id;
            config.regime = regime;           % 干扰体制
            config.signal_type = signal_type; % 信号样式
            config.modulation = modulation;   % 调制方式
            config.bandwidth = bandwidth;     % 带宽 (Hz)
            config.description = description; % 描述
            
            % 根据干扰类型设置默认参数
            switch jamming_id
                case 1  % 瞄准式-单音-CW
                    config.center_frequency = 100e6;  % 100 MHz
                    config.power_dbm = 0;              % 0 dBm
                    config.tone_frequency = 100e6;     % 单音频率
                    config.class_name = 'SingleToneJamming';
                    
                case 2  % 瞄准式-多音-CW
                    config.center_frequency = 100e6;  % 100 MHz
                    config.power_dbm = 0;              % 0 dBm
                    config.tone_frequencies = [99e6, 100e6, 101e6];  % 多音频率
                    config.tone_powers = [0, 0, 0];    % 各音功率 (dBm)
                    config.class_name = 'MultiToneJamming';
                    
                case 3  % 瞄准式-窄带-QPSK/16QAM
                    config.center_frequency = 100e6;  % 100 MHz
                    config.power_dbm = 0;              % 0 dBm
                    config.bandwidth = 10e3;           % 10 kHz
                    config.modulation_type = 'QPSK';   % 默认QPSK
                    config.symbol_rate = 8e3;          % 8 ksps
                    config.class_name = 'NarrowBandJamming';
                    
                case 4  % 瞄准式-噪声调频-FM
                    config.center_frequency = 100e6;  % 100 MHz
                    config.power_dbm = 0;              % 0 dBm
                    config.noise_bandwidth = 50e3;    % 噪声带宽 50 kHz
                    config.fm_deviation = 25e3;       % FM偏移 25 kHz
                    config.class_name = 'NoiseFMJamming';
                    
                case 5  % 阻塞式-宽带-QPSK/16QAM
                    config.center_frequency = 100e6;  % 100 MHz
                    config.power_dbm = 0;              % 0 dBm
                    config.bandwidth = 20e6;           % 20 MHz (通信带宽)
                    config.modulation_type = 'QPSK';   % 默认QPSK
                    config.symbol_rate = 16e6;         % 16 Msps
                    config.class_name = 'WideBandJamming';
                    
                case 6  % 阻塞式-宽带梳状谱
                    config.center_frequency = 100e6;  % 100 MHz
                    config.power_dbm = 0;              % 0 dBm
                    config.bandwidth = 20e6;           % 20 MHz
                    config.comb_spacing = 5e6;         % 梳状间隔 5 MHz
                    config.comb_count = 3;             % 3个梳状谱
                    config.class_name = 'CombSpectrumJamming';
                    
                case 7  % 阻塞式-扫频-LFM
                    config.center_frequency = 100e6;  % 100 MHz
                    config.power_dbm = 0;              % 0 dBm
                    config.sweep_bandwidth = 20e6;    % 扫频带宽 20 MHz
                    config.sweep_period = 0.5e-3;     % 扫频周期 0.5 ms
                    config.sweep_direction = 'up';    % 扫频方向
                    config.class_name = 'SweepJamming';
                    
                case 8  % 跟踪式-跳频-CW
                    config.center_frequency = 100e6;  % 100 MHz
                    config.power_dbm = 0;              % 0 dBm
                    config.hop_frequencies = [];      % 跳频频率表(动态设置)
                    config.hop_rate = 1000;           % 跳频速率 1000 hops/s
                    config.follow_delay = 1e-6;       % 跟踪延迟 1 μs
                    config.class_name = 'FrequencyFollowJamming';
            end
            
            % 通用参数
            config.sample_rate = 100e6;        % 100 MHz采样率
            config.duration = 1.0;             % 1秒持续时间
            config.is_active = false;          % 默认未激活
        end
        
        function config = get_config(jamming_id)
            % 获取指定ID的干扰信号配置
            
            configs = JammingConfigManager.initialize_all_configs();
            if configs.isKey(jamming_id)
                config = configs(jamming_id);
            else
                error('JammingConfigManager:InvalidID', '无效的干扰信号ID: %d', jamming_id);
            end
        end
        
        function ids = get_all_ids()
            % 获取所有可用的干扰信号ID
            
            configs = JammingConfigManager.initialize_all_configs();
            ids = cell2mat(configs.keys);
            ids = sort(ids);
        end
        
        function configs_by_regime = get_configs_by_regime(regime)
            % 根据干扰体制获取配置
            % 输入: regime - '瞄准式', '阻塞式', '跟踪式'
            
            all_configs = JammingConfigManager.initialize_all_configs();
            all_ids = cell2mat(all_configs.keys);
            
            configs_by_regime = containers.Map('KeyType', 'int32', 'ValueType', 'any');
            
            for i = 1:length(all_ids)
                config = all_configs(all_ids(i));
                if strcmp(config.regime, regime)
                    configs_by_regime(all_ids(i)) = config;
                end
            end
        end
        
        function print_all_configs()
            % 打印所有干扰信号配置
            
            configs = JammingConfigManager.initialize_all_configs();
            all_ids = sort(cell2mat(configs.keys));
            
            fprintf('干扰信号配置表\n');
            fprintf('================================================================================\n');
            fprintf('ID\t体制\t\t信号样式\t\t调制方式\t\t带宽\t\t描述\n');
            fprintf('================================================================================\n');
            
            for i = 1:length(all_ids)
                config = configs(all_ids(i));
                
                % 格式化带宽显示
                if config.bandwidth == 0
                    bw_str = '0';
                elseif config.bandwidth >= 1e6
                    bw_str = sprintf('%.1fMHz', config.bandwidth/1e6);
                elseif config.bandwidth >= 1e3
                    bw_str = sprintf('%.1fkHz', config.bandwidth/1e3);
                else
                    bw_str = sprintf('%.0fHz', config.bandwidth);
                end
                
                fprintf('%d\t%s\t\t%s\t\t%s\t\t%s\t\t%s\n', ...
                        config.jamming_id, config.regime, config.signal_type, ...
                        config.modulation, bw_str, config.description);
            end
            fprintf('================================================================================\n');
        end
        
        function print_regime_summary()
            % 打印干扰体制汇总
            
            fprintf('干扰体制汇总\n');
            fprintf('==================================================\n');
            
            regimes = {'瞄准式', '阻塞式', '跟踪式'};
            
            for i = 1:length(regimes)
                regime = regimes{i};
                configs = JammingConfigManager.get_configs_by_regime(regime);
                ids = sort(cell2mat(configs.keys));
                
                fprintf('\n%s (%d种):\n', regime, length(ids));
                for j = 1:length(ids)
                    config = configs(ids(j));
                    fprintf('  ID %d: %s - %s\n', config.jamming_id, ...
                            config.signal_type, config.modulation);
                end
            end
            fprintf('==================================================\n');
        end
        
        function validate_config(config)
            % 验证配置有效性
            
            required_fields = {'jamming_id', 'regime', 'signal_type', 'modulation', ...
                              'center_frequency', 'power_dbm', 'sample_rate', 'duration'};
            
            for i = 1:length(required_fields)
                field = required_fields{i};
                if ~isfield(config, field)
                    error('JammingConfigManager:MissingField', ...
                          '配置缺少必需字段: %s', field);
                end
            end
            
            % 验证数值范围
            assert(config.jamming_id >= 1 && config.jamming_id <= 8, ...
                   'JammingConfigManager:InvalidID', '干扰信号ID必须在1-8之间');
            assert(config.center_frequency > 0, ...
                   'JammingConfigManager:InvalidFreq', '中心频率必须大于0');
            assert(config.sample_rate > 0, ...
                   'JammingConfigManager:InvalidSR', '采样率必须大于0');
            assert(config.duration > 0, ...
                   'JammingConfigManager:InvalidDur', '持续时间必须大于0');
        end
    end
end
