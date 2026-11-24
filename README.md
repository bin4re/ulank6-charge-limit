# ulank6-charge-limit

幽兰本（YourLand CodeBook，RK3588，内核 `6.12.69-jiuqi+`）的 **Type-C 充电限制**补丁：
充电截止 **8.24V（≈80%）**、充电电流 **≤1.47A**，并修复 SC8886 在 CV 点的闩锁。

- 基线：[gedulab/ulank6](https://github.com/gedulab/ulank6) `4ff601f9 add ndb`
- 参考：[ret2void/yourland](https://gitcode.com/ret2void/yourland) 7.3.3

## 改了什么

| 文件 | 改动 |
|---|---|
| `arch/arm64/boot/dts/rockchip/rk3588-yourland.dts` | `ti,max-charge-voltage`：`8700000` → **`8240000`** |
| `drivers/power/supply/bq25700_charger.c` | CV 复位、1.472A clamp、30s 轮询、AC 插入重下发、清 `CHRG_INHIBIT`/`EN_HIZ` |

## 原理

### 硬件与寄存器

- 电池：2S 6000mAh，标称 3.8V/节，满充 4.35V/节（8.70V）；
- 充电芯片：SC8886（bq25700 兼容），I2C 地址 `0x6b`；
- Type-C：PD 15V/3A → SC8886；DC 圆口 12V 不经过它；
- 关键寄存器：

| 寄存器 | 字段 | 步进 |
|---|---|---|
| `0x02` | ChargeCurrent | 64mA |
| `0x04` | ChargeVoltage | 16mV |
| `0x0e` | InputCurrent | — |
| `0x20` | 状态（AC_STAT / IN_FCHRG） | — |
| `0x28` | ADC（IBAT 等） | — |

### 原厂行为

- CV **8.70V**（实测 8.688V，4.34V/节），CC **2.944A**（PD 事件 46×64mA）；
- 到 CV 后 SC8886 **关闭充电通路**（latch），驱动不感知；
- 电量计（CW2017）测电池端电压，此时读到的是 CV 节点 → 显示 **100%**，实际约 80%；
- 拔插/重启不会自动恢复；芯片还可能把 `ChargeCurrent` 静默清零。

### 本补丁

1. **DTS：8.24V** = 4.12V/节 ≈ 80%；
2. **CV 复位**：写 0 → 3–5ms → 目标 → 读回校验 → 恢复 `ChargeCurrent`；SC8886 在 CV 点关断后，清零再写回可重新打开充电通路；
3. **1.5A clamp**：所有写充电电流的路径（初始化、PD 事件、IRQ、轮询）统一走 `bq25700_set_ichg()`，上限 23×64mA = **1.472A**；
4. **30s 轮询**：AC 在位时重写 Ichg / IIN / VINDPM，防止芯片静默清零；
5. **AC 插入重下发**：IRQ 检测到 AC 插入时重跑 CV 复位 + 限流，拔插后自动续充；
6. **probe 清 `CHRG_INHIBIT`/`EN_HIZ`**：清掉热重启残留的禁止充电/高阻态。

### 为什么是 8.24V / 1.472A

- **4.12V/节** 是锂电的"80%/存储"电压，日历老化、产气（鼓包）显著低于 4.35V/节；
- **1.472A（0.25C）** 比 2.944A（0.49C）温和：IR 降从约 0.42V 降到约 0.2V，CV 入口从约 55% 提前到约 70%，发热更小（实测电池 27–30.5°C）；
- 代价是慢：CC 段约 2 倍时间，最后 1% 可能 1 小时。

### 电量计为什么变真实

CW2017 测的是电池端电压。原厂闩锁后充电通路断开，它读的是 CV 节点 → 100%；新逻辑下通路保持、电流自然衰减到 0，它读到的是真实电池电压 → 约 80%。

### 实测与 7.3.3 的对应

- 曲线：1472mA 恒流 → 8.24V → 832 / 448 / 192 / 0mA → 停在 **79–81%**；
- 7.3.3（懒大王）用 8.2V / 1.5A；按 SC8886 的步进取最接近值，即 **8.24V / 1.472A**。

## 打补丁

```bash
git clone https://github.com/gedulab/ulank6.git
cd ulank6
git checkout 4ff601f9
git am -3 /path/to/ulank6-charge-limit/patches/*.patch
```

或 `./scripts/bootstrap.sh`（自动 clone + 打补丁）。

补丁顺序固定：`0001`（DTS）→ `0002`（驱动）。冲突时用 `git am --continue` 或 `git am --abort`。

编译、安装和启动项配置按 ulank6 进行。

## 注意

- **只用 Type-C**：DC 圆口绕过充电芯片，8.24V 限制不生效。
- **到 80% 后很慢**：CV 收尾，最后 1% 可能很慢。

## 参考

- [gedulab/ulank6](https://github.com/gedulab/ulank6)、[ret2void/yourland](https://gitcode.com/ret2void/yourland) 7.3.3（懒大王）
