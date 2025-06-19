# 临时测试文件存档

本文件夹包含项目开发过程中的临时测试文件和调试脚本。

## 📁 文件分类

### 🔧 调试和修复文件
- `debug_bpsk.m` - BPSK调试脚本
- `diagnose_bpsk.m` - BPSK诊断脚本
- `test_bpsk_fix.m` - BPSK修复测试
- `test_bpsk_simple.m` - BPSK简化测试
- `test_bpsk_simple_fix.m` - BPSK简化修复测试
- `test_bpsk_fsk_fixes.m` - BPSK和FSK修复测试

### 📡 载波同步测试
- `test_carrier_sync.m` - 载波同步功能测试

### 🔄 差分编码测试
- `test_dbpsk.m` - DBPSK完整测试
- `test_dbpsk_simple.m` - DBPSK简化测试

### 📻 模拟调制测试
- `test_fm.m` - FM调制完整测试
- `test_fm_simple.m` - FM调制简化测试
- `test_fm_optimized.m` - FM调制优化测试
- `test_fm_simple_optimized.m` - FM调制简化优化测试
- `test_fm_final.m` - FM调制最终测试
- `test_fm_integration.m` - FM调制集成测试
- `test_am.m` - AM调制完整测试
- `test_am_integration.m` - AM调制集成测试
- `test_pm.m` - PM调制完整测试

### 🌐 跳频功能测试
- `test_frequency_hopping.m` - 跳频功能完整测试
- `test_frequency_hopping_simple.m` - 跳频功能简化测试

### 🔄 综合测试
- `test_analog_modulation_suite.m` - 模拟调制综合测试套件

## 📝 说明

这些文件是项目开发过程中的临时测试和调试脚本，主要用于：

1. **功能验证** - 验证新实现的调制解调算法
2. **问题诊断** - 诊断和修复发现的问题
3. **性能测试** - 测试和优化算法性能
4. **集成测试** - 验证模块间的集成效果

## ⚠️ 注意事项

- 这些文件仅用于开发和调试目的
- 正式的测试脚本位于 `tests/` 目录下
- 这些文件可能包含过时的代码或临时修改
- 不建议在生产环境中使用这些脚本

## 🗂️ 项目结构

正式的项目结构请参考：
- `tests/` - 正式测试套件
- `examples/` - 使用示例
- `src/` - 源代码
- `docs/` - 项目文档

---

**作者**: Asaqe Lee  
**创建时间**: 2025-06-18  
**用途**: 开发过程临时文件存档
