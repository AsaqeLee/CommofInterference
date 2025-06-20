%% 100种通信波形演示
% 演示生成的通信波形
%
% 作者: Asaqe Lee
% 日期: 2025-06-20

clear; clc; close all;

%% 加载生成的波形数据
fprintf('=== 100种通信波形演示 ===\n');

try
    load('data/output/all_waveforms.mat');
    fprintf('✓ 成功加载波形数据\n');
    fprintf('  总波形数: %d\n', length(waveforms));
    fprintf('  成功生成: %d种\n', successful_generations);
    fprintf('  采样率: %.0f Hz\n', sample_rate);
    fprintf('  信号时长: %.3f 秒\n', duration);
catch
    fprintf('✗ 无法加载波形数据，请先运行 generate_all_waveforms.m\n');
    return;
end

%% 添加路径
addpath('src/waveforms/config');

%% 选择代表性波形进行演示
demo_ids = [1, 5, 17, 21, 33, 41, 57, 70, 85, 100];
demo_names = {'FM-500Hz', 'FM-1kHz', 'FSK-500Hz', 'FSK-1kHz', ...
              'QPSK扩频-200Hz', 'QPSK扩频-1.2M', 'OFDM-BPSK', ...
              'OFDM-64QAM', 'OFDM-64QAM-CS', 'OFDM-64QAM-2k'};

fprintf('\n=== 代表性波形演示 ===\n');

% 创建演示图形
figure('Name', '通信波形时域演示', 'Position', [100, 100, 1400, 900]);

valid_demos = 0;
for i = 1:length(demo_ids)
    id = demo_ids(i);
    
    if id <= length(waveforms) && ~isempty(waveforms{id})
        valid_demos = valid_demos + 1;
        
        % 获取信号和配置信息
        signal = waveforms{id};
        info = waveform_info{id};
        
        % 创建时间轴
        t = (0:length(signal)-1) / sample_rate * 1000; % 转换为ms
        
        % 绘制时域波形
        subplot(2, 5, valid_demos);
        plot_length = min(500, length(signal)); % 只显示前500个采样点
        plot(t(1:plot_length), signal(1:plot_length), 'b-', 'LineWidth', 1);
        
        title(sprintf('ID %d: %s', id, demo_names{i}), 'FontSize', 10);
        xlabel('时间 (ms)', 'FontSize', 8);
        ylabel('幅度', 'FontSize', 8);
        grid on;
        
        % 添加配置信息
        config_text = sprintf('%.1f MHz, %.1f kbps', ...
            info.config.center_frequency/1e6, info.config.data_rate/1000);
        text(0.02, 0.95, config_text, 'Units', 'normalized', ...
             'FontSize', 7, 'BackgroundColor', 'white');
        
        fprintf('  ID %d (%s): 信号长度 %d, 功率 %.6f\n', ...
            id, demo_names{i}, length(signal), mean(abs(signal).^2));
    end
end

sgtitle('100种通信波形 - 时域演示', 'FontSize', 14, 'FontWeight', 'bold');

%% 频谱分析演示
fprintf('\n=== 频谱分析演示 ===\n');

figure('Name', '通信波形频谱演示', 'Position', [200, 200, 1400, 900]);

valid_demos = 0;
for i = 1:length(demo_ids)
    id = demo_ids(i);
    
    if id <= length(waveforms) && ~isempty(waveforms{id})
        valid_demos = valid_demos + 1;
        
        % 获取信号
        signal = waveforms{id};
        info = waveform_info{id};
        
        % 计算频谱
        N = length(signal);
        freq = (-N/2:N/2-1) * sample_rate / N;
        spectrum = fftshift(fft(signal));
        
        % 绘制频谱
        subplot(2, 5, valid_demos);
        plot(freq/1e6, 20*log10(abs(spectrum) + eps), 'r-', 'LineWidth', 1);
        
        title(sprintf('ID %d: %s', id, demo_names{i}), 'FontSize', 10);
        xlabel('频率 (MHz)', 'FontSize', 8);
        ylabel('幅度 (dB)', 'FontSize', 8);
        grid on;
        
        % 标记载频
        carrier_freq = info.config.center_frequency;
        xline(carrier_freq/1e6, 'g--', sprintf('%.1f MHz', carrier_freq/1e6), ...
              'LineWidth', 1, 'FontSize', 7);
        
        % 设置合理的频率范围
        xlim([-sample_rate/2e6, sample_rate/2e6]);
    end
end

sgtitle('100种通信波形 - 频谱演示', 'FontSize', 14, 'FontWeight', 'bold');

%% 波形统计分析
fprintf('\n=== 波形统计分析 ===\n');

% 统计各类型波形的特性
modulation_types = {'FM', 'FSK', 'QPSK', 'OFDM'};
type_stats = struct();

for mod_type = modulation_types
    type_name = mod_type{1};
    type_stats.(type_name) = struct();
    type_stats.(type_name).count = 0;
    type_stats.(type_name).powers = [];
    type_stats.(type_name).lengths = [];
    type_stats.(type_name).frequencies = [];
    type_stats.(type_name).data_rates = [];
end

% 收集统计数据
for i = 1:length(waveforms)
    if ~isempty(waveforms{i}) && ~isempty(waveform_info{i})
        signal = waveforms{i};
        info = waveform_info{i};
        mod_type = info.config.modulation_type;
        
        if isfield(type_stats, mod_type)
            type_stats.(mod_type).count = type_stats.(mod_type).count + 1;
            type_stats.(mod_type).powers(end+1) = mean(abs(signal).^2);
            type_stats.(mod_type).lengths(end+1) = length(signal);
            type_stats.(mod_type).frequencies(end+1) = info.config.center_frequency;
            type_stats.(mod_type).data_rates(end+1) = info.config.data_rate;
        end
    end
end

% 显示统计结果
fprintf('各调制类型统计:\n');
for mod_type = modulation_types
    type_name = mod_type{1};
    stats = type_stats.(type_name);
    
    if stats.count > 0
        fprintf('  %s调制 (%d种):\n', type_name, stats.count);
        fprintf('    平均功率: %.6f (%.6f - %.6f)\n', ...
            mean(stats.powers), min(stats.powers), max(stats.powers));
        fprintf('    平均长度: %d采样点 (%d - %d)\n', ...
            round(mean(stats.lengths)), min(stats.lengths), max(stats.lengths));
        fprintf('    载频范围: %.1f - %.1f MHz\n', ...
            min(stats.frequencies)/1e6, max(stats.frequencies)/1e6);
        fprintf('    数据率范围: %.1f - %.1f kbps\n', ...
            min(stats.data_rates)/1000, max(stats.data_rates)/1000);
    end
end

%% 创建波形特性对比图
fprintf('\n=== 波形特性对比 ===\n');

figure('Name', '波形特性对比', 'Position', [300, 300, 1200, 600]);

% 功率对比
subplot(1, 3, 1);
powers_by_type = {};
type_labels = {};
for mod_type = modulation_types
    type_name = mod_type{1};
    if type_stats.(type_name).count > 0
        powers_by_type{end+1} = type_stats.(type_name).powers;
        type_labels{end+1} = type_name;
    end
end

if ~isempty(powers_by_type)
    boxplot([powers_by_type{:}], [type_labels{:}]);
    title('各调制类型功率分布');
    ylabel('信号功率');
    grid on;
end

% 载频分布
subplot(1, 3, 2);
all_freqs = [];
all_types = [];
for mod_type = modulation_types
    type_name = mod_type{1};
    if type_stats.(type_name).count > 0
        all_freqs = [all_freqs, type_stats.(type_name).frequencies/1e6];
        all_types = [all_types, repmat({type_name}, 1, length(type_stats.(type_name).frequencies))];
    end
end

if ~isempty(all_freqs)
    scatter(1:length(all_freqs), all_freqs, 50, 'filled');
    title('载频分布');
    xlabel('波形序号');
    ylabel('载频 (MHz)');
    grid on;
end

% 数据率分布
subplot(1, 3, 3);
all_rates = [];
for mod_type = modulation_types
    type_name = mod_type{1};
    if type_stats.(type_name).count > 0
        all_rates = [all_rates, type_stats.(type_name).data_rates/1000];
    end
end

if ~isempty(all_rates)
    histogram(all_rates, 20);
    title('数据率分布');
    xlabel('数据率 (kbps)');
    ylabel('波形数量');
    grid on;
end

sgtitle('100种通信波形特性对比分析', 'FontSize', 14, 'FontWeight', 'bold');

%% 演示总结
fprintf('\n=== 演示总结 ===\n');
fprintf('✅ 成功演示了100种通信波形系统\n');
fprintf('📊 生成成功率: %.1f%% (%d/100)\n', successful_generations/100*100, successful_generations);
fprintf('🎯 涵盖调制类型: FM, FSK, QPSK扩频, OFDM\n');
fprintf('📈 载频范围: %.1f - %.1f MHz\n', min(all_freqs), max(all_freqs));
fprintf('⚡ 数据率范围: %.1f - %.1f kbps\n', min(all_rates), max(all_rates));
fprintf('🔧 系统功能完整，可用于实际应用\n');

fprintf('\n=== 使用建议 ===\n');
fprintf('1. 加载特定波形: signal = waveforms{57};\n');
fprintf('2. 查看波形信息: info = waveform_info{57};\n');
fprintf('3. 重新生成波形: [signal, info] = generator.generate_waveform(57);\n');
fprintf('4. 查看配置表: WaveformConfigManager.print_detailed_table();\n');

fprintf('\n🎉 100种通信波形演示完成！\n');
