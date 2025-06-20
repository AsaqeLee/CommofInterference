# 干扰信号模块

实现8种干扰信号的完整模块。

## 子模块

- `base/` - 基础类和工厂
- `targeted/` - 瞄准式干扰 (4种)
- `barrage/` - 阻塞式干扰 (3种)
- `follower/` - 跟踪式干扰 (1种)

## 使用示例

```matlab
config = JammingConfigManager.get_config(1);
jamming = SingleToneJamming(config);
signal = jamming.generate_jamming_signal([], struct());
```
