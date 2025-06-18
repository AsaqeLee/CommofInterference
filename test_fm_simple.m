%% 简单FM调制测试
% 验证FM调制和解调的基本原理
%
% 作者: Asaqe Lee
% 日期: 2025-06-18

clear; clc; close all;

fprintf('=== 简单FM调制测试 ===\n');

%% 参数设置
fc = 1000;          % 载波频率 1kHz
fs = 10000;         % 采样频率 10kHz
fd = 100;           % 频偏 100Hz
fm = 10;            % 调制频率 10Hz
t_duration = 1;     % 持续时间 1秒

t = (0:1/fs:t_duration-1/fs)';
N = length(t);

fprintf('参数设置:\n');
fprintf('  载波频率: %d Hz\n', fc);
fprintf('  采样频率: %d Hz\n', fs);
fprintf('  频偏: %d Hz\n', fd);
fprintf('  调制频率: %d Hz\n', fm);
fprintf('  采样点数: %d\n', N);

%% 生成调制信号
modulating_signal = cos(2*pi*fm*t);
fprintf('✓ 调制信号生成完成\n');

%% FM调制
% 计算瞬时频率
instantaneous_freq = fc + fd * modulating_signal;

% 计算瞬时相位（频率的积分）
dt = 1/fs;
instantaneous_phase = 2*pi * cumsum(instantaneous_freq) * dt;

% 生成FM信号
fm_signal = cos(instantaneous_phase);

fprintf('✓ FM调制完成\n');

%% FM解调 - 方法1: 相位差分鉴频器
% 计算相邻样本的相位差
signal_delayed = [fm_signal(2:end); fm_signal(end)];
phase_diff = angle(fm_signal .* conj(signal_delayed));

% 转换为频率
demod_freq = phase_diff * fs / (2*pi);

% 去除直流分量
demod_signal_1 = demod_freq - mean(demod_freq);

% 归一化
demod_signal_1 = demod_signal_1 / fd;

fprintf('✓ 相位差分解调完成\n');

%% FM解调 - 方法2: 希尔伯特变换
% 计算解析信号
analytic_signal = hilbert(fm_signal);
instantaneous_phase_demod = unwrap(angle(analytic_signal));

% 计算瞬时频率
instantaneous_freq_demod = diff(instantaneous_phase_demod) * fs / (2*pi);
instantaneous_freq_demod = [instantaneous_freq_demod; instantaneous_freq_demod(end)];

% 去除载波频率
demod_signal_2 = instantaneous_freq_demod - fc;

% 归一化
demod_signal_2 = demod_signal_2 / fd;

fprintf('✓ 希尔伯特变换解调完成\n');

%% 性能分析
% 计算MSE
mse_1 = mean((modulating_signal - demod_signal_1).^2);
mse_2 = mean((modulating_signal - demod_signal_2).^2);

% 计算相关系数
corr_1 = corrcoef(modulating_signal, demod_signal_1);
corr_2 = corrcoef(modulating_signal, demod_signal_2);

fprintf('\n性能分析:\n');
fprintf('  相位差分解调 MSE: %.6f\n', mse_1);
fprintf('  希尔伯特解调 MSE: %.6f\n', mse_2);
fprintf('  相位差分解调相关系数: %.4f\n', corr_1(1,2));
fprintf('  希尔伯特解调相关系数: %.4f\n', corr_2(1,2));

%% 绘制结果
figure('Name', '简单FM调制解调测试', 'Position', [100, 100, 1200, 800]);

% 时域信号
subplot(2,3,1);
plot(t(1:1000), modulating_signal(1:1000), 'b-', 'LineWidth', 2);
xlabel('时间 (s)');
ylabel('幅度');
title('原始调制信号');
grid on;

subplot(2,3,2);
plot(t(1:1000), fm_signal(1:1000), 'g-', 'LineWidth', 1);
xlabel('时间 (s)');
ylabel('幅度');
title('FM调制信号');
grid on;

subplot(2,3,3);
plot(t(1:1000), modulating_signal(1:1000), 'b-', 'LineWidth', 2);
hold on;
plot(t(1:1000), demod_signal_1(1:1000), 'r--', 'LineWidth', 1.5);
plot(t(1:1000), demod_signal_2(1:1000), 'm:', 'LineWidth', 1.5);
xlabel('时间 (s)');
ylabel('幅度');
title('解调结果对比');
legend('原始', '相位差分', '希尔伯特', 'Location', 'best');
grid on;

% 频谱分析
subplot(2,3,4);
[P_orig, f_orig] = pwelch(modulating_signal, [], [], [], fs);
semilogx(f_orig, 10*log10(P_orig), 'b-', 'LineWidth', 2);
xlabel('频率 (Hz)');
ylabel('功率谱密度 (dB/Hz)');
title('原始信号频谱');
grid on;

subplot(2,3,5);
[P_fm, f_fm] = pwelch(fm_signal, [], [], [], fs);
plot(f_fm, 10*log10(P_fm), 'g-', 'LineWidth', 1);
xlabel('频率 (Hz)');
ylabel('功率谱密度 (dB/Hz)');
title('FM信号频谱');
grid on;
xlim([0, 2000]);

subplot(2,3,6);
error_1 = modulating_signal - demod_signal_1;
error_2 = modulating_signal - demod_signal_2;
plot(t(1:1000), error_1(1:1000), 'r-', 'LineWidth', 1);
hold on;
plot(t(1:1000), error_2(1:1000), 'm--', 'LineWidth', 1);
xlabel('时间 (s)');
ylabel('误差');
title('解调误差');
legend('相位差分', '希尔伯特', 'Location', 'best');
grid on;

%% 测试结果
fprintf('\n=== 测试结果 ===\n');
if mse_1 < 0.1 || mse_2 < 0.1
    fprintf('✓ FM调制解调测试通过\n');
    if mse_1 < mse_2
        fprintf('  相位差分解调性能更好\n');
    else
        fprintf('  希尔伯特变换解调性能更好\n');
    end
else
    fprintf('✗ FM调制解调测试需要改进\n');
end

fprintf('=== 简单FM调制测试结束 ===\n');
