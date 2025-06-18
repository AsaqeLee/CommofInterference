classdef FM_FH < FrequencyHoppingWaveform
    % FM_FH - FM跳频调制
    % 为FM调制添加跳频功能
    %
    % 作者: Asaqe Lee
    % 日期: 2025-06-18
    
    properties (Constant)
        WAVEFORM_ID = 61        % 波形ID
        WAVEFORM_NAME = 'FM-FH' % 波形名称
        MODULATION_TYPE = 'FM+FH'  % 调制类型
        CATEGORY = 'frequency_hopping'  % 波形类别
    end
    
    methods
        function obj = FM_FH()
            % 构造函数
            obj@FrequencyHoppingWaveform('FM');
            
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
            % 计算误码率（对于模拟调制，计算均方误差）
            % 输入: original_data - 原始数据
            %      received_data - 接收数据
            % 输出: ber - 误码率（这里用MSE表示）
            
            % 对于模拟调制，使用均方误差作为性能指标
            if length(original_data) ~= length(received_data)
                % 长度不匹配时，截取较短的长度
                min_len = min(length(original_data), length(received_data));
                original_data = original_data(1:min_len);
                received_data = received_data(1:min_len);
            end
            
            % 归一化数据
            if max(abs(original_data)) > 0
                original_data = original_data / max(abs(original_data));
            end
            if max(abs(received_data)) > 0
                received_data = received_data / max(abs(received_data));
            end
            
            % 计算均方误差
            mse = mean((original_data - received_data).^2);
            
            % 转换为类似BER的指标（0-1之间）
            ber = min(mse, 1);
        end
    end
    
    methods (Access = private)
        function configure_default_hopping(obj)
            % 配置默认跳频参数
            
            % FM跳频的典型参数
            hop_config = struct();
            hop_config.hop_frequencies = (88:0.2:108) * 1e6;  % FM广播频段
            hop_config.hop_rate = 100;                         % 100跳/秒
            hop_config.seed_value = 54321;
            hop_config.sequence_length = 63;
            
            obj.frequency_hopper.configure(hop_config);
        end
    end
end
