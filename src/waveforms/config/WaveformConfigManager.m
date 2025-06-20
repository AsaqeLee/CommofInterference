classdef WaveformConfigManager < handle
    % WaveformConfigManager - 完整的波形配置管理器
    % 管理所有100种通信波形配置 (ID 1-100)
    %
    % 作者: Asaqe Lee
    % 日期: 2025-06-20
    
    properties (Constant)
        % 所有波形配置
        ALL_WAVEFORM_CONFIGS = WaveformConfigManager.initialize_all_configs();
    end
    
    methods (Static)
        function configs = initialize_all_configs()
            % 初始化所有100种波形配置
            
            configs = containers.Map('KeyType', 'int32', 'ValueType', 'any');
            
            % ID 1-16: FM调制 (跳频500, 1000, 2000)
            configs = WaveformConfigManager.add_fm_configs(configs);
            
            % ID 17-32: FSK调制 (跳频500, 1000, 2000)
            configs = WaveformConfigManager.add_fsk_configs(configs);
            
            % ID 33-56: QPSK扩频组合 (跳频200, 400)
            configs = WaveformConfigManager.add_qpsk_spread_configs(configs);
            
            % ID 57-100: OFDM系列 (已在OFDMWaveformConfig中定义)
            configs = WaveformConfigManager.add_ofdm_configs(configs);
        end
        
        function configs = add_fm_configs(configs)
            % 添加FM调制配置 (ID 1-16)
            
            data_rates = [2.4, 4.8, 9.6, 16]; % kbps
            hop_rates = [500, 1000, 2000]; % hops/s
            
            id = 1;
            for hop_idx = 1:length(hop_rates)
                hop_rate = hop_rates(hop_idx);
                for rate_idx = 1:length(data_rates)
                    data_rate = data_rates(rate_idx);
                    
                    config = struct();
                    config.waveform_id = id;
                    config.waveform_name = 'FM';
                    config.modulation_type = 'FM';
                    config.category = 'analog';
                    
                    % 基础参数
                    config.center_frequency = 30e6; % 30MHz载频
                    config.data_rate = data_rate * 1000; % 转换为bps
                    config.bandwidth = 25e3; % 25kHz带宽
                    config.sample_rate = 100e3; % 100kHz采样率
                    
                    % 跳频参数
                    config.hopping_enabled = (hop_rate > 0);
                    config.hopping_rate = hop_rate;
                    config.num_frequency_points = 256; % 全频段256个频点
                    config.frequency_set = WaveformConfigManager.generate_frequency_set(30e6, 256);
                    
                    % 编码和多址
                    config.channel_coding = 'none';
                    config.coding_rate = 1.0;
                    config.access_method = '分信道';
                    
                    configs(id) = config;
                    id = id + 1;
                end
            end
            
            % 补充ID 13-16 (2000Hops/s的额外配置)
            for rate_idx = 1:4
                if id <= 16
                    config = configs(rate_idx + 8); % 复制1000Hops/s的配置
                    config.waveform_id = id;
                    config.hopping_rate = 2000;
                    configs(id) = config;
                    id = id + 1;
                end
            end
        end
        
        function configs = add_fsk_configs(configs)
            % 添加FSK调制配置 (ID 17-32)
            
            data_rates = [2.4, 4.8, 9.6, 16]; % kbps
            hop_rates = [500, 1000, 2000]; % hops/s
            
            id = 17;
            for hop_idx = 1:length(hop_rates)
                hop_rate = hop_rates(hop_idx);
                for rate_idx = 1:length(data_rates)
                    data_rate = data_rates(rate_idx);
                    
                    config = struct();
                    config.waveform_id = id;
                    config.waveform_name = 'FSK';
                    config.modulation_type = 'FSK';
                    config.category = 'digital';
                    
                    % 基础参数
                    config.center_frequency = 30e6; % 30MHz载频
                    config.data_rate = data_rate * 1000; % 转换为bps
                    config.bandwidth = 25e3; % 25kHz带宽
                    config.sample_rate = 100e3; % 100kHz采样率
                    
                    % 跳频参数
                    config.hopping_enabled = (hop_rate > 0);
                    config.hopping_rate = hop_rate;
                    config.num_frequency_points = 256; % 全频段256个频点
                    config.frequency_set = WaveformConfigManager.generate_frequency_set(30e6, 256);
                    
                    % 编码和多址
                    config.channel_coding = '2/3卷积';
                    config.coding_rate = 2/3;
                    config.access_method = 'TDMA';
                    
                    configs(id) = config;
                    id = id + 1;
                end
            end
            
            % 补充ID 29-32 (2000Hops/s的额外配置)
            for rate_idx = 1:4
                if id <= 32
                    config = configs(rate_idx + 24); % 复制1000Hops/s的配置
                    config.waveform_id = id;
                    config.hopping_rate = 2000;
                    configs(id) = config;
                    id = id + 1;
                end
            end
        end
        
        function configs = add_qpsk_spread_configs(configs)
            % 添加QPSK扩频组合配置 (ID 33-56)
            
            % 扩频参数配置
            spread_configs = [
                % [data_rate_kbps, chip_rate, spread_factor, hop_rate]
                300, 8, 8, 200;      % ID 33
                150, 16, 16, 200;    % ID 34
                75, 32, 32, 200;     % ID 35
                18.75, 128, 128, 200; % ID 36
                600, 8, 8, 200;      % ID 37
                300, 16, 16, 200;    % ID 38
                150, 32, 32, 200;    % ID 39
                37.5, 128, 128, 200; % ID 40
                1250, 8, 8, 200;     % ID 41
                625, 16, 16, 200;    % ID 42
                312.5, 32, 32, 200;  % ID 43
                62.5, 256, 256, 200; % ID 44
                31.25, 512, 512, 200; % ID 45
                15.625, 1024, 1024, 200; % ID 46
                300, 8, 8, 400;      % ID 47
                150, 16, 16, 400;    % ID 48
                75, 32, 32, 400;     % ID 49
                600, 8, 8, 400;      % ID 50
                300, 16, 16, 400;    % ID 51
                150, 32, 32, 400;    % ID 52
                37.5, 128, 128, 400; % ID 53
                1250, 8, 8, 400;     % ID 54
                625, 16, 16, 400;    % ID 55
                312.5, 32, 32, 400;  % ID 56
            ];
            
            for i = 1:size(spread_configs, 1)
                id = 32 + i;
                data_rate = spread_configs(i, 1) * 1000; % 转换为bps
                chip_rate = spread_configs(i, 2);
                spread_factor = spread_configs(i, 3);
                hop_rate = spread_configs(i, 4);
                
                config = struct();
                config.waveform_id = id;
                config.waveform_name = 'QPSK扩频组合';
                config.modulation_type = 'QPSK';
                config.category = 'spread_spectrum';
                
                % 基础参数
                config.center_frequency = WaveformConfigManager.get_qpsk_carrier_freq(i);
                config.data_rate = data_rate;
                config.bandwidth = WaveformConfigManager.get_qpsk_bandwidth(i);
                config.sample_rate = config.bandwidth * 4; % 4倍过采样
                
                % 扩频参数
                config.spread_spectrum_enabled = true;
                config.spreading_factor = spread_factor;
                config.chip_rate = chip_rate * 1e6; % 转换为chips/s
                
                % 跳频参数
                config.hopping_enabled = true;
                config.hopping_rate = hop_rate;
                config.num_frequency_points = 32; % 频段内32个频点
                config.frequency_set = WaveformConfigManager.generate_frequency_set(config.center_frequency, 32);
                
                % 编码和多址
                config.channel_coding = '2/3卷积';
                config.coding_rate = 2/3;
                config.access_method = 'TDMA';
                
                configs(id) = config;
            end
        end
        
        function configs = add_ofdm_configs(configs)
            % 添加OFDM配置 (ID 57-100)
            % 使用已有的OFDMWaveformConfig
            
            addpath('src/waveforms/ofdm');
            ofdm_configs = OFDMWaveformConfig.WAVEFORM_CONFIGS;
            ofdm_ids = cell2mat(ofdm_configs.keys);
            
            for i = 1:length(ofdm_ids)
                id = ofdm_ids(i);
                configs(id) = ofdm_configs(id);
            end
        end
        
        function freq_set = generate_frequency_set(center_freq, num_points)
            % 生成频点集
            
            if num_points == 256
                % 全频段256个频点 (30MHz ± 12.5MHz)
                bandwidth = 25e6;
                start_freq = center_freq - bandwidth/2;
                freq_spacing = bandwidth / (num_points - 1);
            else
                % 频段内32个频点 (中心频率 ± 40%)
                bandwidth = center_freq * 0.8;
                start_freq = center_freq - bandwidth/2;
                freq_spacing = bandwidth / (num_points - 1);
            end
            
            freq_set = start_freq : freq_spacing : (start_freq + bandwidth);
            freq_set = freq_set(1:num_points);
        end
        
        function carrier_freq = get_qpsk_carrier_freq(config_index)
            % 获取QPSK配置的载频
            
            % 根据表格中的配置确定载频
            if config_index <= 14
                carrier_freq = 30.88e6; % 30-88M
            elseif config_index <= 22
                carrier_freq = 400e6;   % 400M
            else
                carrier_freq = 1350e6;  % 1350-1850M
            end
        end
        
        function bandwidth = get_qpsk_bandwidth(config_index)
            % 获取QPSK配置的带宽
            
            % 根据表格中的配置确定带宽
            if config_index <= 6
                bandwidth = 2.4e6;  % 2.4M
            elseif config_index <= 14
                bandwidth = 4.8e6;  % 4.8M
            else
                bandwidth = 19.2e6; % 19.2M
            end
        end
        
        function config = get_config(waveform_id)
            % 获取指定ID的波形配置
            
            configs = WaveformConfigManager.ALL_WAVEFORM_CONFIGS;
            if configs.isKey(waveform_id)
                config = configs(waveform_id);
            else
                error('WaveformConfigManager:InvalidID', '无效的波形ID: %d', waveform_id);
            end
        end
        
        function ids = get_all_ids()
            % 获取所有可用的波形ID
            
            configs = WaveformConfigManager.ALL_WAVEFORM_CONFIGS;
            ids = cell2mat(configs.keys);
            ids = sort(ids);
        end
        
        function configs_by_type = get_configs_by_type(modulation_type)
            % 按调制类型获取配置
            
            configs = WaveformConfigManager.ALL_WAVEFORM_CONFIGS;
            all_ids = cell2mat(configs.keys);
            configs_by_type = {};
            
            for i = 1:length(all_ids)
                config = configs(all_ids(i));
                if strcmp(config.modulation_type, modulation_type)
                    configs_by_type{end+1} = config;
                end
            end
        end
        
        function print_summary()
            % 打印波形配置总览

            configs = WaveformConfigManager.ALL_WAVEFORM_CONFIGS;
            all_ids = sort(cell2mat(configs.keys));

            fprintf('通信波形配置系统总览\n');
            fprintf('==================================================\n');
            fprintf('总计: %d种波形配置\n\n', length(all_ids));

            % 按类型统计
            type_count = containers.Map();
            for i = 1:length(all_ids)
                config = configs(all_ids(i));
                mod_type = config.modulation_type;
                if type_count.isKey(mod_type)
                    type_count(mod_type) = type_count(mod_type) + 1;
                else
                    type_count(mod_type) = 1;
                end
            end

            fprintf('按调制类型分布:\n');
            type_keys = type_count.keys;
            for i = 1:length(type_keys)
                fprintf('  %s: %d种\n', type_keys{i}, type_count(type_keys{i}));
            end

            fprintf('\nID范围分布:\n');
            fprintf('  ID 1-16:   FM调制\n');
            fprintf('  ID 17-32:  FSK调制\n');
            fprintf('  ID 33-56:  QPSK扩频组合\n');
            fprintf('  ID 57-100: OFDM系列\n');
            fprintf('==================================================\n');
        end

        function print_detailed_table()
            % 打印详细的波形配置表

            configs = WaveformConfigManager.ALL_WAVEFORM_CONFIGS;
            all_ids = sort(cell2mat(configs.keys));

            fprintf('完整通信波形配置表\n');
            fprintf('================================================================================\n');
            fprintf('ID\t调制\t\t载频(MHz)\t数据率\t\t跳频率\t\t编码\t\t多址\n');
            fprintf('================================================================================\n');

            for i = 1:length(all_ids)
                id = all_ids(i);
                config = configs(id);

                % 格式化数据率显示
                if config.data_rate >= 1e6
                    data_rate_str = sprintf('%.1fMbps', config.data_rate/1e6);
                else
                    data_rate_str = sprintf('%.1fkbps', config.data_rate/1000);
                end

                % 格式化跳频率显示
                if isfield(config, 'hopping_enabled') && config.hopping_enabled
                    hop_rate_str = sprintf('%dhops/s', config.hopping_rate);
                else
                    hop_rate_str = '无跳频';
                end

                % 格式化编码显示
                if isfield(config, 'channel_coding')
                    coding_str = config.channel_coding;
                else
                    coding_str = '无';
                end

                % 格式化多址显示
                if isfield(config, 'access_method')
                    access_str = config.access_method;
                else
                    access_str = '无';
                end

                fprintf('%d\t%s\t\t%.1f\t\t%s\t\t%s\t\t%s\t\t%s\n', ...
                    id, ...
                    config.modulation_type, ...
                    config.center_frequency/1e6, ...
                    data_rate_str, ...
                    hop_rate_str, ...
                    coding_str, ...
                    access_str);
            end

            fprintf('================================================================================\n');
        end
    end
end
