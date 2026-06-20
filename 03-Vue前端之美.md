# 🎨 Vue 前端之美 — 天气卡片是怎么渲染出来的？

> **阅读对象**：了解一点点 HTML/CSS/JS  
> **目标**：读懂 App.vue 的代码，理解 Vue 的响应式原理和天气界面是如何拼装的

---

## 1. 前端骨架：一份文件，三种语言

`src/App.vue` 是**单文件组件（SFC）**，一个文件里包含三种语言：

```vue
<script setup lang="ts">
// 👈 TypeScript：逻辑代码（数据获取、计算、事件处理）
</script>

<template>
  <!-- 👈 HTML：页面结构（按钮、卡片、下拉框） -->
</template>

<style scoped>
/* 👈 CSS：样式（颜色、布局、动画） */
</style>
```

`scoped` 关键字表示这些样式**只对这个文件有效**，不会影响其他地方。

---

## 2. 数据在哪？

### 2.1 响应式状态

```typescript
import { ref, computed, watch } from "vue";

const token = ref(import.meta.env.VITE_WEATHER_TOKEN || "");  // API 密钥
const selectedProvince = ref("北京");                           // 选中的省份
const selectedCity = ref("北京");                               // 选中的城市
const loading = ref(false);                                     // 是否在加载中
const weatherData = ref<WeatherData | null>(null);              // 天气数据
const error = ref("");                                          // 错误信息
```

**`ref()`** 是 Vue 的"响应式数据"包装器。简单说：

> 被 `ref` 包裹的变量变了，界面自动更新。

比如 `loading` 从 `false` 变成 `true`，查询按钮会自动显示"查询中..."并禁用。你**不需要手动操作 DOM**，Vue 帮你做了。

### 2.2 省-市联动（computed + watch）

```typescript
const cities = computed(() => {
  return PROVINCE_CITY_MAP[selectedProvince.value] || [];
});
```

**`computed`** = 计算属性。当 `selectedProvince` 变化时，`cities` 自动重新计算，城市下拉框自动切换选项。

```typescript
watch(selectedProvince, (newProv) => {
  const list = PROVINCE_CITY_MAP[newProv];
  if (list && !list.includes(selectedCity.value)) {
    selectedCity.value = list[0];
  }
});
```

**`watch`** = 监听器。当省份变了，如果当前城市不在新省份的城市列表里，就自动切到该省第一个城市。

---

## 3. 天气数据长什么样？

```typescript
interface WeatherData {
  city: string;          // 城市名
  temp: number;          // 当前温度
  min_temp: number;      // 最低温
  max_temp: number;      // 最高温
  weather: string;       // 天气描述（"晴"）
  weather_code: string;  // 天气代码（"qing"）
  humidity: string;      // 湿度
  wind_speed: string;    // 风速
  // ...还有很多
  aqi: AqiData;          // 空气质量
  index: LifeIndex[];    // 生活指数列表
  hour: HourData[];      // 逐小时预报列表
}
```

这是用 **TypeScript 接口（interface）** 定义的"数据结构说明书"。相当于告诉编辑器：天气数据包含哪些字段，每个字段是什么类型。这样你写代码时编辑器能自动补全，也能避免拼写错误。

---

## 4. 核心动作：点击查询

```typescript
async function queryWeather() {
  loading.value = true;                    // 显示加载状态
  error.value = "";                        // 清除旧错误
  weatherData.value = null;                // 清除旧数据
  try {
    const res = await invoke<string>(       // 👈 调用 Rust 后端
      "get_weather", {                      // 命令名
        token: token.value,
        city: selectedCity.value,
        province: selectedProvince.value,
      }
    );
    const parsed = JSON.parse(res);        // 解析 JSON
    if (parsed.success && parsed.data) {
      weatherData.value = parsed.data;      // 保存到响应式变量 → 自动渲染
    } else {
      error.value = parsed.message || "查询失败";
    }
  } catch (e) {
    error.value = `请求出错: ${e}`;
  } finally {
    loading.value = false;                  // 隐藏加载状态
  }
}
```

**`invoke`** 是前端调用 Rust 后端的"电话"。你告诉它：
1. 打给谁 → `"get_weather"`
2. 带什么话 → `{token, city, province}`
3. 等什么回复 → 返回的字符串

---

## 5. 模板部分：HTML 结构

```html
<template>
  <main class="app-container">
    <!-- 标题 -->
    <header class="app-header">
      <h1>🌤 天气查询</h1>
    </header>

    <!-- 查询表单：省-市下拉框 + 查询按钮 -->
    <section class="search-section">
      <div class="search-form">
        <div class="field-row">
          <div class="field">
            <label>省份</label>
            <select v-model="selectedProvince">
              <option v-for="p in PROVINCES" :key="p" :value="p">{{ p }}</option>
            </select>
          </div>
          <div class="field">
            <label>城市</label>
            <select v-model="selectedCity">
              <option v-for="c in cities" :key="c" :value="c">{{ c }}</option>
            </select>
          </div>
        </div>
        <button @click="queryWeather" :disabled="loading">
          {{ loading ? "查询中..." : "🔍 查询天气" }}
        </button>
      </div>
    </section>

    <!-- 天气卡片（只有 weatherData 有值时显示） -->
    <section v-if="weatherData">
      <div class="weather-main-card">
        <!-- 城市名 + 温度 -->
        <h2>{{ weatherData.city }}</h2>
        <span class="temp-big">{{ weatherData.temp }}°</span>
        <!-- 湿度、风速、日出日落... -->
      </div>
      <!-- 更多卡片：AQI、小时预报、生活指数 -->
    </section>
  </main>
</template>
```

几个 Vue 模板语法：

| 语法 | 含义 | 示例 |
|------|------|------|
| `{{ }}` | 插值表达式，显示变量值 | `{{ weatherData.city }}` |
| `v-model` | 双向绑定 | `v-model="selectedProvince"` |
| `v-if` | 条件渲染 | `v-if="weatherData"` |
| `v-for` | 循环渲染 | `v-for="p in PROVINCES"` |
| `@click` | 点击事件 | `@click="queryWeather"` |
| `:disabled` | 属性绑定（`:xxx`= `v-bind:xxx`） | `:disabled="loading"` |

---

## 6. 样式之美：CSS 如何让界面好看

### 6.1 主温度大字号

```css
.temp-big {
  font-size: 4em;       /* 字体大，突出温度 */
  font-weight: 300;     /* 细体，显得精致 */
}

.weather-icon-big {
  font-size: 3em;       /* 天气图标也大 */
}
```

### 6.2 网格布局

```css
.details-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);  /* 3列等宽 */
  gap: 10px;
}
```

把"湿度、风速、风力、能见度、日出、日落"排成 3 列 2 行。

手机屏幕窄时自动变成 2 列：

```css
@media (max-width: 420px) {
  .details-grid {
    grid-template-columns: repeat(2, 1fr);  /* 2列 */
  }
}
```

### 6.3 空气质量颜色

```typescript
function airColor(air: string): string {
  const n = parseInt(air);
  if (n <= 50) return "#00b300";     // 优 → 绿色
  if (n <= 100) return "#ffcc00";    // 良 → 黄色
  if (n <= 150) return "#ff6600";    // 轻度污染 → 橙色
  if (n <= 200) return "#ff3300";    // 中度污染 → 红色
  return "#990000";                   // 重度污染 → 深红
}
```

AQI 数值的颜色和背景都是根据空气质量**动态计算**的，用 `:style` 绑定：

```html
<div class="weather-main-card" :style="{ background: airBg(weatherData.air) }">
```

### 6.4 暗色模式

```css
@media (prefers-color-scheme: dark) {
  :root {
    color: #f0f0f0;
    background-color: #1a1a2e;       /* 深蓝色背景 */
  }
  .search-form,
  .card {
    background: #1e1e3a !important;  /* 卡片变暗 */
  }
}
```

系统切换暗色模式时，App 自动跟随。

---

## 7. 天气图标映射

```typescript
const WEATHER_ICONS: Record<string, string> = {
  qing:       "☀️",
  duoyun:     "⛅",
  yin:        "☁️",
  xiaoyu:     "🌦️",
  xiaoxue:    "🌨️",
  wu:         "🌫️",
  // ...
};
```

API 返回的是 `weather_code: "qing"`，前端把它翻译成 `☀️`。如果遇到不认识的天码，默认显示 `🌡️`。

---

## 8. 模板与样式分离的好处

```
     数据 (script)           界面 (template)           样式 (style)
 ┌────────────────┐     ┌──────────────────┐     ┌────────────────┐
 │ weatherData     │────→│ {{ temp }}°      │     │ font-size: 4em │
 │ loading         │────→│ :disabled        │     │ opacity: 0.6   │
 │ selectedProvince│←───→│ select v-model   │     │ border-radius  │
 │ queryWeather()  │────→│ @click           │     │ cursor:pointer │
 └────────────────┘     └──────────────────┘     └────────────────┘
```

各司其职，互不干扰。这就是 Vue 的核心设计理念。

---

## 9. 小结

- **`ref`** 让数据变得"响应式"—— 数据变了，界面自动变
- **`v-model`、`v-if`、`v-for`** 是 Vue 模板的核心指令
- **`invoke`** 是前端呼叫 Rust 后端的桥梁
- **CSS 网格 + 媒体查询** 实现了自适应手机屏幕
- **TypeScript 接口** 让数据结构一目了然

下一篇我们看看这个项目是怎么从代码变成鸿蒙手机上的 App 的 →

> 📄 [04-从代码到HAP.md](./04-从代码到HAP.md)
