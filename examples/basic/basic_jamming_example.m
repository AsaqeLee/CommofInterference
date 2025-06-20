% 基础使用示例
% 演示如何使用单个干扰信号
%
% 作者: Asaqe Lee
% 日期: 2025-06-20

clear; clc; close all;

% 添加路径
addpath(genpath('../../src'));

% 创建单音干扰
config = JammingConfigManager.get_config(1);
jamming = SingleToneJamming(config);

% 生成干扰信号
signal = jamming.generate_jamming_signal([], struct());

% 显示结果
jamming.print_status();
fprintf('信号长度: %d\n', length(signal));
fprintf('信号功率: %.2e W\n', mean(abs(signal).^2));
