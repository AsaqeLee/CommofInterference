classdef QPSK_FH < FrequencyHoppingWaveform
    % QPSK_FH - QPSK跳频调制
    % 为QPSK调制添加跳频功能
    %
    % 作者: Asaqe Lee
    % 日期: 2025-06-18
    
    properties (Constant)
        WAVEFORM_ID = 63        % 波形ID
        WAVEFORM_NAME = 'QPSK-FH' % 波形名称
        MODULATION_TYPE = 'QPSK+FH'  % 调制类型
        CATEGORY = 'frequency_hopping'  % 波形类别
    end
    
    methods
        function obj = QPSK_FH()
            % 构造函数
            obj@FrequencyHoppingWaveform('QPSK');
            
            % 默认启用跳频
            obj.hopping_enabled = true;
            
            % 配置默认跳频参数
            obj.configure_default_hopping();
        end
        
        function info = get_waveform_info(obj)
            % 获取波形信息
            % 输出: info - 波形信息结构体
            
            info = get_waveform_info@FrequencyHoppingWaveform(obj);
            info.waveform_id = obj.WAVEFORM_ID;
            info.waveform_name = obj.WAVEFORM_NAME;
            info.modulation_type = obj.MODULATION_TYPE;
            info.category = obj.CATEGORY;
        end
        
        function ber = calculate_ber(obj, original_data, received_data)
            % 计算误码率
            % 输入: original_data - 原始数据
            %      received_data - 接收数据
            % 输出: ber - 误码率
            
            % 确保数据长度一致
            min_len = min(length(original_data), length(received_data));
            original_data = original_data(1:min_len);
            received_data = received_data(1:min_len);
            
            % 计算误码数
            errors = sum(original_data ~= received_data);
            ber = errors / min_len;
        end
    end
    
    methods (Access = private)
        function configure_default_hopping(obj)
            % 配置默认跳频参数
            
            % QPSK跳频的典型参数
            hop_config = struct();
            hop_config.hop_frequencies = (2400:1:2483) * 1e6;  % 2.4GHz ISM频段
            hop_config.hop_rate = 1600;                        % 1600跳/秒
            hop_config.seed_value = 13579;
            hop_config.sequence_length = 79;
            
            obj.frequency_hopper.configure(hop_config);
        end
    end
end
