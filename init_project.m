% 项目初始化脚本
% 设置MATLAB环境以使用通信干扰对抗仿真系统
%
% 作者: Asaqe Lee
% 日期: 2025-06-20

function init_project()
    % 添加项目路径
    project_root = fileparts(mfilename('fullpath'));
    addpath(genpath(fullfile(project_root, 'src')));
    
    % 创建输出目录
    output_dir = fullfile(project_root, 'data', 'output');
    if ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end
    
    % 显示欢迎信息
    fprintf('=== 通信干扰对抗仿真系统 ===\n');
    fprintf('项目已初始化完成！\n');
    fprintf('运行 help JammingConfigManager 查看帮助\n');
    fprintf('============================\n');
end
