classdef OFDMWaveformConfig < handle
    % OFDMWaveformConfig - OFDM波形配置管理器
    % 管理表格中定义的所有OFDM波形配置
    %
    % 作者: Asaqe Lee
    % 日期: 2025-06-20
    
    properties (Constant)
        % OFDM波形配置表
        WAVEFORM_CONFIGS = OFDMWaveformConfig.initialize_configs();
    end
    
    methods (Static)
        function configs = initialize_configs()
            % 初始化所有OFDM波形配置
            % 基于用户提供的配置表
            
            configs = containers.Map('KeyType', 'int32', 'ValueType', 'any');
            
            % ID 57-61: OFDM-BPSK (跳频500, LDPC 1/2, TDMA)
            configs(57) = OFDMWaveformConfig.create_config(57, 'OFDM-BPSK', 'BPSK', 2.5e6, 0.5e6, 500, 'LDPC_1_2', 'TDMA');
            configs(58) = OFDMWaveformConfig.create_config(58, 'OFDM-BPSK', 'BPSK', 5e6, 1e6, 500, 'LDPC_1_2', 'TDMA');
            configs(59) = OFDMWaveformConfig.create_config(59, 'OFDM-BPSK', 'BPSK', 10e6, 2e6, 500, 'LDPC_1_2', 'TDMA');
            configs(60) = OFDMWaveformConfig.create_config(60, 'OFDM-BPSK', 'BPSK', 20e6, 4e6, 500, 'LDPC_1_2', 'TDMA');

            % ID 61-65: OFDM-QPSK (跳频500, LDPC 1/2, TDMA)
            configs(61) = OFDMWaveformConfig.create_config(61, 'OFDM-QPSK', 'QPSK', 2.5e6, 1e6, 500, 'LDPC_1_2', 'TDMA');
            configs(62) = OFDMWaveformConfig.create_config(62, 'OFDM-QPSK', 'QPSK', 5e6, 2e6, 500, 'LDPC_1_2', 'TDMA');
            configs(63) = OFDMWaveformConfig.create_config(63, 'OFDM-QPSK', 'QPSK', 10e6, 4e6, 500, 'LDPC_1_2', 'TDMA');
            configs(64) = OFDMWaveformConfig.create_config(64, 'OFDM-QPSK', 'QPSK', 20e6, 8e6, 500, 'LDPC_1_2', 'TDMA');
            configs(65) = OFDMWaveformConfig.create_config(65, 'OFDM-QPSK', 'QPSK', 2.5e6, 2e6, 500, 'LDPC_1_2', 'TDMA');

            % ID 66-68: OFDM-16QAM (跳频500, LDPC 1/2, TDMA)
            configs(66) = OFDMWaveformConfig.create_config(66, 'OFDM-16QAM', '16QAM', 5e6, 4e6, 500, 'LDPC_1_2', 'TDMA');
            configs(67) = OFDMWaveformConfig.create_config(67, 'OFDM-16QAM', '16QAM', 10e6, 8e6, 500, 'LDPC_1_2', 'TDMA');
            configs(68) = OFDMWaveformConfig.create_config(68, 'OFDM-16QAM', '16QAM', 20e6, 16e6, 500, 'LDPC_1_2', 'TDMA');

            % ID 69-72: OFDM-64QAM (跳频500, LDPC 1/2, TDMA)
            configs(69) = OFDMWaveformConfig.create_config(69, 'OFDM-64QAM', '64QAM', 2.5e6, 3e6, 500, 'LDPC_1_2', 'TDMA');
            configs(70) = OFDMWaveformConfig.create_config(70, 'OFDM-64QAM', '64QAM', 5e6, 6e6, 500, 'LDPC_1_2', 'TDMA');
            configs(71) = OFDMWaveformConfig.create_config(71, 'OFDM-64QAM', '64QAM', 10e6, 12e6, 500, 'LDPC_1_2', 'TDMA');
            configs(72) = OFDMWaveformConfig.create_config(72, 'OFDM-64QAM', '64QAM', 20e6, 24e6, 500, 'LDPC_1_2', 'TDMA');

            % ID 73-76: OFDM-BPSK (跳频500, LDPC 1/2, CS-TDMA)
            configs(73) = OFDMWaveformConfig.create_config(73, 'OFDM-BPSK', 'BPSK', 2.5e6, 0.5e6, 500, 'LDPC_1_2', 'CS_TDMA');
            configs(74) = OFDMWaveformConfig.create_config(74, 'OFDM-BPSK', 'BPSK', 5e6, 1e6, 500, 'LDPC_1_2', 'CS_TDMA');
            configs(75) = OFDMWaveformConfig.create_config(75, 'OFDM-BPSK', 'BPSK', 10e6, 2e6, 500, 'LDPC_1_2', 'CS_TDMA');
            configs(76) = OFDMWaveformConfig.create_config(76, 'OFDM-BPSK', 'BPSK', 20e6, 4e6, 500, 'LDPC_1_2', 'CS_TDMA');

            % ID 77-81: OFDM-QPSK (跳频500, LDPC 1/2, CS-TDMA)
            configs(77) = OFDMWaveformConfig.create_config(77, 'OFDM-QPSK', 'QPSK', 2.5e6, 1e6, 500, 'LDPC_1_2', 'CS_TDMA');
            configs(78) = OFDMWaveformConfig.create_config(78, 'OFDM-QPSK', 'QPSK', 5e6, 2e6, 500, 'LDPC_1_2', 'CS_TDMA');
            configs(79) = OFDMWaveformConfig.create_config(79, 'OFDM-QPSK', 'QPSK', 10e6, 4e6, 500, 'LDPC_1_2', 'CS_TDMA');
            configs(80) = OFDMWaveformConfig.create_config(80, 'OFDM-QPSK', 'QPSK', 20e6, 8e6, 500, 'LDPC_1_2', 'CS_TDMA');
            configs(81) = OFDMWaveformConfig.create_config(81, 'OFDM-QPSK', 'QPSK', 2.5e6, 2e6, 500, 'LDPC_1_2', 'CS_TDMA');

            % ID 82-84: OFDM-16QAM (跳频500, LDPC 1/2, CS-TDMA)
            configs(82) = OFDMWaveformConfig.create_config(82, 'OFDM-16QAM', '16QAM', 5e6, 4e6, 500, 'LDPC_1_2', 'CS_TDMA');
            configs(83) = OFDMWaveformConfig.create_config(83, 'OFDM-16QAM', '16QAM', 10e6, 8e6, 500, 'LDPC_1_2', 'CS_TDMA');
            configs(84) = OFDMWaveformConfig.create_config(84, 'OFDM-16QAM', '16QAM', 20e6, 16e6, 500, 'LDPC_1_2', 'CS_TDMA');

            % ID 85-88: OFDM-64QAM (跳频500, LDPC 1/2, CS-TDMA)
            configs(85) = OFDMWaveformConfig.create_config(85, 'OFDM-64QAM', '64QAM', 2.5e6, 3e6, 500, 'LDPC_1_2', 'CS_TDMA');
            configs(86) = OFDMWaveformConfig.create_config(86, 'OFDM-64QAM', '64QAM', 5e6, 6e6, 500, 'LDPC_1_2', 'CS_TDMA');
            configs(87) = OFDMWaveformConfig.create_config(87, 'OFDM-64QAM', '64QAM', 10e6, 12e6, 500, 'LDPC_1_2', 'CS_TDMA');
            configs(88) = OFDMWaveformConfig.create_config(88, 'OFDM-64QAM', '64QAM', 20e6, 24e6, 500, 'LDPC_1_2', 'CS_TDMA');

            % ID 89-96: 跳频1000 (LDPC 1/2, TDMA)
            configs(89) = OFDMWaveformConfig.create_config(89, 'OFDM-BPSK', 'BPSK', 10e6, 1.5e6, 1000, 'LDPC_1_2', 'TDMA');
            configs(90) = OFDMWaveformConfig.create_config(90, 'OFDM-BPSK', 'BPSK', 20e6, 3e6, 1000, 'LDPC_1_2', 'TDMA');
            configs(91) = OFDMWaveformConfig.create_config(91, 'OFDM-QPSK', 'QPSK', 10e6, 3e6, 1000, 'LDPC_1_2', 'TDMA');
            configs(92) = OFDMWaveformConfig.create_config(92, 'OFDM-QPSK', 'QPSK', 20e6, 6e6, 1000, 'LDPC_1_2', 'TDMA');
            configs(93) = OFDMWaveformConfig.create_config(93, 'OFDM-16QAM', '16QAM', 10e6, 6e6, 1000, 'LDPC_1_2', 'TDMA');
            configs(94) = OFDMWaveformConfig.create_config(94, 'OFDM-16QAM', '16QAM', 20e6, 12e6, 1000, 'LDPC_1_2', 'TDMA');
            configs(95) = OFDMWaveformConfig.create_config(95, 'OFDM-64QAM', '64QAM', 10e6, 10e6, 1000, 'LDPC_1_2', 'TDMA');
            configs(96) = OFDMWaveformConfig.create_config(96, 'OFDM-64QAM', '64QAM', 20e6, 20e6, 1000, 'LDPC_1_2', 'TDMA');

            % ID 97-100: 跳频2000 (LDPC 1/2, TDMA)
            configs(97) = OFDMWaveformConfig.create_config(97, 'OFDM-BPSK', 'BPSK', 20e6, 2.5e6, 2000, 'LDPC_1_2', 'TDMA');
            configs(98) = OFDMWaveformConfig.create_config(98, 'OFDM-QPSK', 'QPSK', 20e6, 5e6, 2000, 'LDPC_1_2', 'TDMA');
            configs(99) = OFDMWaveformConfig.create_config(99, 'OFDM-16QAM', '16QAM', 20e6, 10e6, 2000, 'LDPC_1_2', 'TDMA');
            configs(100) = OFDMWaveformConfig.create_config(100, 'OFDM-64QAM', '64QAM', 20e6, 15e6, 2000, 'LDPC_1_2', 'TDMA');
        end
        
        function config = create_config(id, name, modulation, carrier_freq, data_rate, hop_rate, ~, access_method)
            % 创建单个波形配置
            % 输入参数:
            %   id - 波形ID
            %   name - 波形名称
            %   modulation - 调制方式
            %   carrier_freq - 载频 (Hz)
            %   data_rate - 数据速率 (bps)
            %   hop_rate - 跳频速率 (hops/s)
            %   ~ - 编码方式 (忽略，所有OFDM都使用LDPC 1/2)
            %   access_method - 多址方式
            
            config = struct();
            config.waveform_id = id;
            config.waveform_name = name;
            config.modulation_type = 'OFDM';
            config.constellation_type = modulation;
            config.category = 'ofdm';
            
            % 基础参数
            config.center_frequency = carrier_freq;
            config.data_rate = data_rate;
            config.bandwidth = carrier_freq; % 带宽等于载频
            config.sample_rate = carrier_freq * 4; % 4倍过采样
            
            % OFDM参数
            config.num_subcarriers = 64; % 固定64个子载波
            config.cyclic_prefix_length = 16;
            config.cyclic_prefix_ratio = 0.25;
            config.subcarrier_spacing = carrier_freq / config.num_subcarriers;
            
            % 跳频参数
            config.hopping_enabled = true;
            config.hopping_rate = hop_rate;
            config.num_frequency_points = 32; % 频段内32个频点
            config.frequency_set = OFDMWaveformConfig.generate_frequency_set(carrier_freq, 32);
            
            % 信道编码参数 (所有OFDM波形都使用LDPC 1/2)
            config.channel_coding = 'LDPC_1_2';
            config.coding_rate = 0.5;  % LDPC编码率1/2
            config.coding_type = 'LDPC';
            
            % 多址参数
            config.access_method = access_method;
            
            % 性能参数
            config.spectral_efficiency = OFDMWaveformConfig.calculate_spectral_efficiency(modulation, config.coding_rate);
        end
        
        function freq_set = generate_frequency_set(center_freq, num_points)
            % 生成频点集
            % 在中心频率周围生成32个频点
            
            bandwidth = center_freq * 0.8; % 80%带宽用于跳频
            freq_spacing = bandwidth / (num_points - 1);
            start_freq = center_freq - bandwidth/2;
            
            freq_set = start_freq : freq_spacing : (start_freq + bandwidth);
            freq_set = freq_set(1:num_points); % 确保正好32个频点
        end
        
        function efficiency = calculate_spectral_efficiency(modulation, coding_rate)
            % 计算频谱效率
            
            switch upper(modulation)
                case 'BPSK'
                    bits_per_symbol = 1;
                case 'QPSK'
                    bits_per_symbol = 2;
                case '16QAM'
                    bits_per_symbol = 4;
                case '64QAM'
                    bits_per_symbol = 6;
                otherwise
                    bits_per_symbol = 2; % 默认QPSK
            end
            
            efficiency = bits_per_symbol * coding_rate;
        end
        
        function config = get_config(waveform_id)
            % 获取指定ID的波形配置
            % 输入: waveform_id - 波形ID (57-100)
            % 输出: config - 配置结构体
            
            configs = OFDMWaveformConfig.WAVEFORM_CONFIGS;
            if configs.isKey(waveform_id)
                config = configs(waveform_id);
            else
                error('OFDMWaveformConfig:InvalidID', '无效的波形ID: %d', waveform_id);
            end
        end
        
        function ids = get_all_ids()
            % 获取所有可用的波形ID
            % 输出: ids - ID数组
            
            configs = OFDMWaveformConfig.WAVEFORM_CONFIGS;
            ids = cell2mat(configs.keys);
            ids = sort(ids);
        end
        
        function configs_by_type = get_configs_by_modulation(modulation_type)
            % 按调制方式获取配置
            % 输入: modulation_type - 调制方式 ('BPSK', 'QPSK', '16QAM', '64QAM')
            % 输出: configs_by_type - 配置数组
            
            configs = OFDMWaveformConfig.WAVEFORM_CONFIGS;
            all_ids = cell2mat(configs.keys);
            configs_by_type = {};
            
            for i = 1:length(all_ids)
                config = configs(all_ids(i));
                if strcmp(config.constellation_type, modulation_type)
                    configs_by_type{end+1} = config;
                end
            end
        end
        
        function print_config_table()
            % 打印配置表
            
            configs = OFDMWaveformConfig.WAVEFORM_CONFIGS;
            all_ids = sort(cell2mat(configs.keys));
            
            fprintf('OFDM波形配置表\n');
            fprintf('================================================================================\n');
            fprintf('ID\t波形名称\t\t调制\t载频(MHz)\t数据率(Mbps)\t跳频率\t信道编码\t多址\n');
            fprintf('================================================================================\n');

            for i = 1:length(all_ids)
                config = configs(all_ids(i));
                fprintf('%d\t%s\t%s\t%.1f\t\t%.1f\t\t%d\t%s\t%s\n', ...
                    config.waveform_id, ...
                    config.waveform_name, ...
                    config.constellation_type, ...
                    config.center_frequency/1e6, ...
                    config.data_rate/1e6, ...
                    config.hopping_rate, ...
                    config.channel_coding, ...
                    config.access_method);
            end
            fprintf('================================================================================\n');
        end
    end
end
