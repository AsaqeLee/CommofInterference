% debug_bpsk - 调试BPSK映射问题

clc;
clear;

fprintf('=== BPSK调试 ===\n');

% 添加路径
addpath(genpath('src'));

% 创建BPSK实例
bpsk = BPSK();

% 配置参数
config = struct();
config.center_frequency = 1e6;       % 1 MHz载波
config.sample_rate = 4e6;            % 4 MHz采样率
config.symbol_rate = 1e6;            % 1 Msps
config.snr_db = inf;                 % 无噪声

bpsk.configure(config);

% 测试数据
test_data = [0; 1];

fprintf('测试数据: [%d, %d]\n', test_data(1), test_data(2));

% 调制（无噪声）
modulated_signal = bpsk.generate_signal(test_data, 'add_noise', false, 'normalize', false);

fprintf('调制信号长度: %d\n', length(modulated_signal));
fprintf('调制信号实部: [');
for i = 1:length(modulated_signal)
    fprintf('%.2f ', real(modulated_signal(i)));
end
fprintf(']\n');

% 手动解调过程
fprintf('\n手动解调过程:\n');

% 1. 下变频（基带，所以载波为1）
t = (0:length(modulated_signal)-1) / config.sample_rate;
carrier = exp(-1j * 2*pi*config.center_frequency*t);
baseband_signal = modulated_signal .* carrier;

fprintf('下变频后信号实部: [');
for i = 1:length(baseband_signal)
    fprintf('%.2f ', real(baseband_signal(i)));
end
fprintf(']\n');

% 2. 低通滤波（简化，跳过）
filtered_signal = baseband_signal;

% 3. 符号采样
samples_per_symbol = round(config.sample_rate / config.symbol_rate);
fprintf('每符号采样数: %d\n', samples_per_symbol);

symbol_indices = round(samples_per_symbol/2):samples_per_symbol:length(filtered_signal);
symbols = filtered_signal(symbol_indices);

fprintf('采样符号实部: [');
for i = 1:length(symbols)
    fprintf('%.2f ', real(symbols(i)));
end
fprintf(']\n');

% 4. 符号判决
decisions = double(real(symbols) < 0);

fprintf('判决结果: [');
for i = 1:length(decisions)
    fprintf('%d ', decisions(i));
end
fprintf(']\n');

% 比较
fprintf('\n比较结果:\n');
fprintf('原始: [%d, %d]\n', test_data(1), test_data(2));
fprintf('恢复: [%d, %d]\n', decisions(1), decisions(2));

% 检查映射逻辑
fprintf('\n映射逻辑检查:\n');
fprintf('根据代码: 0 -> +1, 1 -> -1\n');
fprintf('实际映射: 0 -> %.2f, 1 -> %.2f\n', real(symbols(1)), real(symbols(2)));

if real(symbols(1)) > 0 && real(symbols(2)) < 0
    fprintf('✓ 映射正确\n');
else
    fprintf('✗ 映射错误\n');
end

fprintf('\n=== 调试完成 ===\n');
