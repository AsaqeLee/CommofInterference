%% 项目结构整理脚本
% 整理项目文件结构，准备推送到GitHub
%
% 作者: Asaqe Lee
% 日期: 2025-06-20

clear; clc;

fprintf('=== 项目结构整理 ===\n');
fprintf('开始时间: %s\n', datestr(now));
fprintf('===================\n\n');

%% 1. 创建目录结构
fprintf('1. 创建标准目录结构...\n');

directories = {
    'src/jamming/base';
    'src/jamming/targeted';
    'src/jamming/barrage';
    'src/jamming/follower';
    'src/simulation';
    'src/analysis';
    'src/waveforms';
    'docs/api';
    'docs/examples';
    'docs/images';
    'tests/unit';
    'tests/integration';
    'tests/system';
    'data/input';
    'data/output';
    'examples/basic';
    'examples/advanced';
    'tools';
    'scripts'
};

for i = 1:length(directories)
    dir_path = directories{i};
    if ~exist(dir_path, 'dir')
        mkdir(dir_path);
        fprintf('  创建目录: %s\n', dir_path);
    else
        fprintf('  目录已存在: %s\n', dir_path);
    end
end

fprintf('✓ 目录结构创建完成\n\n');

%% 2. 移动测试文件到tests目录
fprintf('2. 整理测试文件...\n');

test_files = {
    'test_interference_simulation.m', 'tests/system/';
    'test_all_jamming_signals.m', 'tests/integration/';
    'run_complete_simulation.m', 'examples/advanced/'
};

for i = 1:size(test_files, 1)
    source_file = test_files{i, 1};
    target_dir = test_files{i, 2};
    
    if exist(source_file, 'file')
        if ~exist(target_dir, 'dir')
            mkdir(target_dir);
        end
        
        target_file = fullfile(target_dir, source_file);
        if ~exist(target_file, 'file')
            copyfile(source_file, target_file);
            fprintf('  复制: %s -> %s\n', source_file, target_file);
        else
            fprintf('  文件已存在: %s\n', target_file);
        end
    else
        fprintf('  源文件不存在: %s\n', source_file);
    end
end

fprintf('✓ 测试文件整理完成\n\n');

%% 3. 创建README文件
fprintf('3. 创建各目录README文件...\n');

readme_contents = containers.Map();

% 主要目录的README内容
readme_contents('src') = sprintf(['# 源代码目录\n\n'...
    '本目录包含通信干扰对抗仿真系统的所有源代码。\n\n'...
    '## 目录结构\n\n'...
    '- `jamming/` - 干扰信号模块\n'...
    '- `simulation/` - 仿真控制模块\n'...
    '- `analysis/` - 分析工具模块\n'...
    '- `waveforms/` - 通信波形模块\n\n'...
    '## 使用方法\n\n'...
    '```matlab\n'...
    'addpath(genpath(''src''));\n'...
    '```\n']);

readme_contents('src/jamming') = sprintf(['# 干扰信号模块\n\n'...
    '实现8种干扰信号的完整模块。\n\n'...
    '## 子模块\n\n'...
    '- `base/` - 基础类和工厂\n'...
    '- `targeted/` - 瞄准式干扰 (4种)\n'...
    '- `barrage/` - 阻塞式干扰 (3种)\n'...
    '- `follower/` - 跟踪式干扰 (1种)\n\n'...
    '## 使用示例\n\n'...
    '```matlab\n'...
    'config = JammingConfigManager.get_config(1);\n'...
    'jamming = SingleToneJamming(config);\n'...
    'signal = jamming.generate_jamming_signal([], struct());\n'...
    '```\n']);

readme_contents('tests') = sprintf(['# 测试目录\n\n'...
    '包含所有测试脚本和测试数据。\n\n'...
    '## 测试类型\n\n'...
    '- `unit/` - 单元测试\n'...
    '- `integration/` - 集成测试\n'...
    '- `system/` - 系统测试\n\n'...
    '## 运行测试\n\n'...
    '```matlab\n'...
    'run(''tests/system/test_interference_simulation.m'');\n'...
    'run(''tests/integration/test_all_jamming_signals.m'');\n'...
    '```\n']);

readme_contents('data') = sprintf(['# 数据目录\n\n'...
    '存储输入数据和输出结果。\n\n'...
    '## 目录结构\n\n'...
    '- `input/` - 输入数据文件\n'...
    '- `output/` - 仿真输出结果\n\n'...
    '## 注意事项\n\n'...
    '- 大型数据文件已在.gitignore中排除\n'...
    '- 保留示例文件用于参考\n']);

readme_contents('examples') = sprintf(['# 示例代码\n\n'...
    '提供各种使用示例和教程。\n\n'...
    '## 目录结构\n\n'...
    '- `basic/` - 基础使用示例\n'...
    '- `advanced/` - 高级功能示例\n\n'...
    '## 快速开始\n\n'...
    '从basic目录的示例开始学习系统使用。\n']);

readme_contents('docs') = sprintf(['# 文档目录\n\n'...
    '包含项目的所有文档。\n\n'...
    '## 文档类型\n\n'...
    '- `api/` - API参考文档\n'...
    '- `examples/` - 示例文档\n'...
    '- `images/` - 文档图片\n\n'...
    '## 主要文档\n\n'...
    '- 项目进展: `project_progress.md`\n'...
    '- 完成总结: `project_completion_final.md`\n']);

% 写入README文件
readme_dirs = {'src', 'src/jamming', 'tests', 'data', 'examples', 'docs'};

for i = 1:length(readme_dirs)
    dir_name = readme_dirs{i};
    readme_file = fullfile(dir_name, 'README.md');
    
    if readme_contents.isKey(dir_name)
        content = readme_contents(dir_name);
        
        % 写入文件
        fid = fopen(readme_file, 'w', 'n', 'UTF-8');
        if fid ~= -1
            fprintf(fid, '%s', content);
            fclose(fid);
            fprintf('  创建: %s\n', readme_file);
        else
            fprintf('  创建失败: %s\n', readme_file);
        end
    end
end

fprintf('✓ README文件创建完成\n\n');

%% 4. 创建示例文件
fprintf('4. 创建示例文件...\n');

% 基础示例
basic_example = sprintf(['%% 基础使用示例\n'...
    '%% 演示如何使用单个干扰信号\n'...
    '%%\n'...
    '%% 作者: Asaqe Lee\n'...
    '%% 日期: 2025-06-20\n\n'...
    'clear; clc; close all;\n\n'...
    '%% 添加路径\n'...
    'addpath(genpath(''../../src''));\n\n'...
    '%% 创建单音干扰\n'...
    'config = JammingConfigManager.get_config(1);\n'...
    'jamming = SingleToneJamming(config);\n\n'...
    '%% 生成干扰信号\n'...
    'signal = jamming.generate_jamming_signal([], struct());\n\n'...
    '%% 显示结果\n'...
    'jamming.print_status();\n'...
    'fprintf(''信号长度: %%d\\n'', length(signal));\n'...
    'fprintf(''信号功率: %%.2e W\\n'', mean(abs(signal).^2));\n']);

% 写入基础示例
basic_file = 'examples/basic/basic_jamming_example.m';
fid = fopen(basic_file, 'w', 'n', 'UTF-8');
if fid ~= -1
    fprintf(fid, '%s', basic_example);
    fclose(fid);
    fprintf('  创建: %s\n', basic_file);
end

% 高级示例 - 移动现有文件
if exist('run_complete_simulation.m', 'file')
    advanced_file = 'examples/advanced/complete_simulation_example.m';
    if ~exist(advanced_file, 'file')
        copyfile('run_complete_simulation.m', advanced_file);
        fprintf('  复制: run_complete_simulation.m -> %s\n', advanced_file);
    end
end

fprintf('✓ 示例文件创建完成\n\n');

%% 5. 创建工具脚本
fprintf('5. 创建工具脚本...\n');

% 项目初始化脚本
init_script = sprintf(['%% 项目初始化脚本\n'...
    '%% 设置MATLAB环境以使用通信干扰对抗仿真系统\n'...
    '%%\n'...
    '%% 作者: Asaqe Lee\n'...
    '%% 日期: 2025-06-20\n\n'...
    'function init_project()\n'...
    '    %% 添加项目路径\n'...
    '    project_root = fileparts(mfilename(''fullpath''));\n'...
    '    addpath(genpath(fullfile(project_root, ''src'')));\n'...
    '    \n'...
    '    %% 创建输出目录\n'...
    '    output_dir = fullfile(project_root, ''data'', ''output'');\n'...
    '    if ~exist(output_dir, ''dir'')\n'...
    '        mkdir(output_dir);\n'...
    '    end\n'...
    '    \n'...
    '    %% 显示欢迎信息\n'...
    '    fprintf(''=== 通信干扰对抗仿真系统 ===\\n'');\n'...
    '    fprintf(''项目已初始化完成！\\n'');\n'...
    '    fprintf(''运行 help JammingConfigManager 查看帮助\\n'');\n'...
    '    fprintf(''============================\\n'');\n'...
    'end\n']);

init_file = 'init_project.m';
fid = fopen(init_file, 'w', 'n', 'UTF-8');
if fid ~= -1
    fprintf(fid, '%s', init_script);
    fclose(fid);
    fprintf('  创建: %s\n', init_file);
end

fprintf('✓ 工具脚本创建完成\n\n');

%% 6. 检查文件完整性
fprintf('6. 检查文件完整性...\n');

critical_files = {
    'src/jamming/base/JammingBase.m';
    'src/jamming/base/JammingFactory.m';
    'src/jamming/base/JammingConfigManager.m';
    'src/jamming/targeted/SingleToneJamming.m';
    'src/jamming/targeted/MultiToneJamming.m';
    'src/jamming/targeted/NarrowBandJamming.m';
    'src/jamming/targeted/NoiseFMJamming.m';
    'src/jamming/barrage/WideBandJamming.m';
    'src/jamming/barrage/CombSpectrumJamming.m';
    'src/jamming/barrage/SweepJamming.m';
    'src/jamming/follower/FrequencyFollowJamming.m';
    'src/simulation/SIRController.m';
    'src/analysis/BERCalculator.m';
    'src/simulation/InterferenceSimulationEngine.m'
};

missing_files = {};
for i = 1:length(critical_files)
    if ~exist(critical_files{i}, 'file')
        missing_files{end+1} = critical_files{i};
        fprintf('  ✗ 缺失: %s\n', critical_files{i});
    else
        fprintf('  ✓ 存在: %s\n', critical_files{i});
    end
end

if isempty(missing_files)
    fprintf('✓ 所有关键文件完整\n\n');
else
    fprintf('⚠️  发现%d个缺失文件\n\n', length(missing_files));
end

%% 7. 生成项目统计
fprintf('7. 生成项目统计...\n');

% 统计代码文件
m_files = dir('**/*.m');
total_lines = 0;
total_files = length(m_files);

for i = 1:length(m_files)
    file_path = fullfile(m_files(i).folder, m_files(i).name);
    try
        content = fileread(file_path);
        lines = length(strsplit(content, '\n'));
        total_lines = total_lines + lines;
    catch
        % 忽略读取失败的文件
    end
end

fprintf('项目统计:\n');
fprintf('  MATLAB文件数: %d\n', total_files);
fprintf('  总代码行数: %d\n', total_lines);
fprintf('  平均每文件行数: %.1f\n', total_lines/total_files);

% 统计干扰信号实现
jamming_files = dir('src/jamming/**/*Jamming.m');
fprintf('  干扰信号实现: %d种\n', length(jamming_files));

fprintf('✓ 项目统计完成\n\n');

%% 8. 生成Git提交建议
fprintf('8. 生成Git提交建议...\n');

git_commands = {
    '# 初始化Git仓库（如果尚未初始化）';
    'git init';
    '';
    '# 添加所有文件';
    'git add .';
    '';
    '# 提交初始版本';
    'git commit -m "feat: 完整实现8种干扰信号的通信干扰对抗仿真系统"';
    '';
    '# 添加远程仓库（替换为您的GitHub仓库URL）';
    'git remote add origin https://github.com/asaqe/CommOfInterference.git';
    '';
    '# 推送到GitHub';
    'git branch -M main';
    'git push -u origin main';
    '';
    '# 创建发布标签';
    'git tag -a v1.0.0 -m "Release version 1.0.0: 完整的8种干扰信号实现"';
    'git push origin v1.0.0'
};

% 写入Git命令文件
git_file = 'git_commands.txt';
fid = fopen(git_file, 'w', 'n', 'UTF-8');
if fid ~= -1
    for i = 1:length(git_commands)
        fprintf(fid, '%s\n', git_commands{i});
    end
    fclose(fid);
    fprintf('  创建Git命令文件: %s\n', git_file);
end

fprintf('✓ Git提交建议生成完成\n\n');

%% 9. 最终检查和总结
fprintf('=== 项目整理总结 ===\n');
fprintf('完成时间: %s\n', datestr(now));

if isempty(missing_files)
    fprintf('✅ 项目结构完整，可以推送到GitHub\n');
    fprintf('\n推荐的下一步操作:\n');
    fprintf('1. 检查 git_commands.txt 中的Git命令\n');
    fprintf('2. 替换GitHub仓库URL为您的实际仓库\n');
    fprintf('3. 执行Git命令推送到GitHub\n');
    fprintf('4. 在GitHub上创建Release\n');
else
    fprintf('⚠️  项目存在缺失文件，请先完善后再推送\n');
    fprintf('缺失文件列表:\n');
    for i = 1:length(missing_files)
        fprintf('  - %s\n', missing_files{i});
    end
end

fprintf('\n项目亮点:\n');
fprintf('🎯 8种干扰信号完整实现\n');
fprintf('🏗️ 工业级系统架构\n');
fprintf('🧪 完整测试框架\n');
fprintf('📚 详细文档系统\n');
fprintf('🚀 即用型示例代码\n');

fprintf('===================\n');

fprintf('\n项目整理完成！🎉\n');
