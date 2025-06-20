%% 波形生成测试
% 测试波形生成器的基本功能
%
% 作者: Asaqe Lee
% 日期: 2025-06-20

clear; clc; close all;

%% 添加路径
addpath('src/waveforms');
addpath('src/waveforms/config');

%% 初始化
fprintf('=== 波形生成测试 ===\n');

try
    % 创建生成器
    generator = WaveformGenerator(1e6, 0.001); % 1MHz, 1ms
    fprintf('✓ 波形生成器初始化成功\n');
    
    % 测试不同类型的波形
    test_ids = [1, 17, 33, 57]; % FM, FSK, QPSK扩频, OFDM
    test_names = {'FM', 'FSK', 'QPSK扩频', 'OFDM'};
    
    for i = 1:length(test_ids)
        id = test_ids(i);
        name = test_names{i};
        
        fprintf('\n测试波形ID %d (%s):\n', id, name);
        
        try
            % 生成波形
            [signal, info] = generator.generate_waveform(id);
            
            fprintf('  ✓ 生成成功\n');
            fprintf('  信号长度: %d采样点\n', length(signal));
            fprintf('  信号功率: %.6f\n', mean(abs(signal).^2));
            fprintf('  调制类型: %s\n', info.modulation_type);
            
        catch ME
            fprintf('  ✗ 生成失败: %s\n', ME.message);
            if ~isempty(ME.stack)
                fprintf('  错误位置: %s (第%d行)\n', ME.stack(1).name, ME.stack(1).line);
            end
        end
    end
    
    fprintf('\n=== 测试完成 ===\n');
    
catch ME
    fprintf('✗ 初始化失败: %s\n', ME.message);
    if ~isempty(ME.stack)
        fprintf('错误位置: %s (第%d行)\n', ME.stack(1).name, ME.stack(1).line);
    end
end
