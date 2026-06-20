<script setup lang="ts">
import { ref } from "vue";
import { invoke } from "@tauri-apps/api/core";

type WeatherCode =
  | "qing" | "duoyun" | "yin"
  | "xiaoyu" | "zhenyu" | "zhongyu" | "dayu" | "baoyu" | "tebaoyu"
  | "leizhenyubanyoubingbao" | "leizhenyu"
  | "xiaoxue" | "zhongxue" | "daxue" | "baoxue"
  | "wu" | "dongyu" | "yangsha" | "shachenbao" | "fuchen";

interface AqiData {
  air: string;
  air_level: string;
  air_tips: string;
  pm25: string;
  pm10: string;
  co: string;
  no2: string;
  so2: string;
  o3: string;
}

interface LifeIndex {
  type: string;
  level: string;
  name: string;
  content: string;
}

interface HourData {
  time: string;
  temp: number;
  wea: string;
  wea_code: string;
  wind: string;
  wind_level: string;
}

interface WeatherData {
  city: string;
  city_en: string;
  province: string;
  province_en: string;
  city_id: string;
  date: string;
  update_time: string;
  weather: string;
  weather_code: WeatherCode;
  temp: number;
  min_temp: number;
  max_temp: number;
  wind: string;
  wind_speed: string;
  wind_power: string;
  rain: string;
  rain_24h: string;
  humidity: string;
  visibility: string;
  pressure: string;
  tail_number: string;
  air: string;
  air_pm25: string;
  sunrise: string;
  sunset: string;
  aqi: AqiData;
  index: LifeIndex[];
  alarm: unknown[];
  hour: HourData[];
}

const WEATHER_ICONS: Record<string, string> = {
  qing:       "☀️",
  duoyun:     "⛅",
  yin:        "☁️",
  xiaoyu:     "🌦️",
  zhenyu:     "🌦️",
  zhongyu:    "🌧️",
  dayu:       "🌧️",
  baoyu:      "🌧️",
  tebaoyu:    "🌧️",
  leizhenyu:  "⛈️",
  leizhenyubanyoubingbao: "⛈️",
  xiaoxue:    "🌨️",
  zhongxue:   "❄️",
  daxue:      "❄️",
  baoxue:     "❄️",
  wu:         "🌫️",
  dongyu:     "🌨️",
  yangsha:    "🌪️",
  shachenbao: "🌪️",
  fuchen:     "🌫️",
};

const greetMsg = ref("");
const name = ref("");

const token = ref(import.meta.env.VITE_WEATHER_TOKEN || "");
const city = ref("北京");
const province = ref("");
const loading = ref(false);
const weatherData = ref<WeatherData | null>(null);
const error = ref("");
const showAllIndexes = ref(false);

function getWeatherIcon(code: string): string {
  return WEATHER_ICONS[code] || "🌡️";
}

function airColor(air: string): string {
  const n = parseInt(air);
  if (isNaN(n)) return "#999";
  if (n <= 50) return "#00b300";
  if (n <= 100) return "#ffcc00";
  if (n <= 150) return "#ff6600";
  if (n <= 200) return "#ff3300";
  return "#990000";
}

function airBg(air: string): string {
  const n = parseInt(air);
  if (isNaN(n)) return "#f0f0f0";
  if (n <= 50) return "#e8f5e8";
  if (n <= 100) return "#fff8e0";
  if (n <= 150) return "#fff0e0";
  if (n <= 200) return "#ffe8e0";
  return "#ffd6d6";
}

function formatHourTime(t: string): string {
  const m = t.match(/(\d{2}):\d{2}/);
  return m ? m[1] + ":00" : "";
}

function indexEmoji(type: string): string {
  const map: Record<string, string> = {
    diaoyu_index: "🎣", ganmao_index: "🤧", guoming_index: "🤧",
    xiche_index: "🚗", yundong_index: "🏃", ziwanxian_index: "🧴",
    chuanyi_index: "👕", lvyou_index: "🏕️", shushizhishu: "😌",
    kongtiao_index: "❄️"
  };
  return map[type] || "📊";
}

async function queryWeather() {
  loading.value = true;
  error.value = "";
  weatherData.value = null;
  try {
    const res = await invoke<string>("get_weather", {
      token: token.value,
      city: city.value,
      province: province.value || null,
    });
    const parsed = JSON.parse(res);
    if (parsed.success && parsed.data) {
      weatherData.value = parsed.data as WeatherData;
    } else {
      error.value = parsed.message || "查询失败";
    }
  } catch (e) {
    error.value = `请求出错: ${e}`;
  } finally {
    loading.value = false;
  }
}

async function greet() {
  greetMsg.value = await invoke("greet", { name: name.value });
}
</script>

<template>
  <main class="app-container">
    <header class="app-header">
      <h1>🌤 天气查询</h1>
    </header>

    <!-- 查询表单 -->
    <section class="search-section">
      <div class="search-form">
        <div class="field-row">
          <div class="field">
            <label>城市</label>
            <input v-model="city" placeholder="如：北京" @keyup.enter="queryWeather" />
          </div>
          <div class="field">
            <label>省份</label>
            <input v-model="province" placeholder="可选" @keyup.enter="queryWeather" />
          </div>
        </div>
        <button class="search-btn" @click="queryWeather" :disabled="loading">
          <span v-if="loading" class="spinner"></span>
          {{ loading ? "查询中..." : "🔍 查询天气" }}
        </button>
      </div>
    </section>

    <!-- 错误提示 -->
    <div v-if="error" class="error-msg">{{ error }}</div>

    <!-- 天气卡片 -->
    <section v-if="weatherData" class="weather-section">
      <!-- 主卡片 -->
      <div class="weather-main-card" :style="{ background: airBg(weatherData.air) }">
        <div class="main-top">
          <div class="city-info">
            <h2>{{ weatherData.city }}</h2>
            <span class="update-time">{{ weatherData.update_time }} 更新</span>
          </div>
          <div class="weather-main-temp">
            <span class="weather-icon-big">{{ getWeatherIcon(weatherData.weather_code) }}</span>
            <span class="temp-big">{{ weatherData.temp }}°</span>
          </div>
          <div class="weather-desc">
            <span>{{ weatherData.weather }}</span>
            <span class="temp-range">{{ weatherData.min_temp }}° / {{ weatherData.max_temp }}°</span>
          </div>
        </div>

        <!-- 详细指标 -->
        <div class="details-grid">
          <div class="detail-item">
            <span class="detail-label">💧 湿度</span>
            <span class="detail-value">{{ weatherData.humidity }}</span>
          </div>
          <div class="detail-item">
            <span class="detail-label">🌬️ 风速</span>
            <span class="detail-value">{{ weatherData.wind_speed }}</span>
          </div>
          <div class="detail-item">
            <span class="detail-label">🌀 风力</span>
            <span class="detail-value">{{ weatherData.wind_power }}</span>
          </div>
          <div class="detail-item">
            <span class="detail-label">👁️ 能见度</span>
            <span class="detail-value">{{ weatherData.visibility }}</span>
          </div>
          <div class="detail-item">
            <span class="detail-label">🌅 日出</span>
            <span class="detail-value">{{ weatherData.sunrise }}</span>
          </div>
          <div class="detail-item">
            <span class="detail-label">🌇 日落</span>
            <span class="detail-value">{{ weatherData.sunset }}</span>
          </div>
        </div>
      </div>

      <!-- 空气质量 -->
      <div class="card aqi-card">
        <h3>🌿 空气质量</h3>
        <div class="aqi-row">
          <div class="aqi-number" :style="{ color: airColor(weatherData.air) }">
            {{ weatherData.aqi.air }}
          </div>
          <div class="aqi-info">
            <span class="aqi-level">{{ weatherData.aqi.air_level }}</span>
            <span class="aqi-tips">{{ weatherData.aqi.air_tips }}</span>
          </div>
        </div>
        <div class="aqi-details">
          <div class="aqi-item"><label>PM2.5</label><span>{{ weatherData.aqi.pm25 }}</span></div>
          <div class="aqi-item"><label>PM10</label><span>{{ weatherData.aqi.pm10 }}</span></div>
          <div class="aqi-item"><label>CO</label><span>{{ weatherData.aqi.co }}</span></div>
          <div class="aqi-item"><label>NO₂</label><span>{{ weatherData.aqi.no2 }}</span></div>
          <div class="aqi-item"><label>SO₂</label><span>{{ weatherData.aqi.so2 }}</span></div>
          <div class="aqi-item"><label>O₃</label><span>{{ weatherData.aqi.o3 }}</span></div>
        </div>
      </div>

      <!-- 逐小时预报 -->
      <div class="card hourly-card">
        <h3>⏰ 逐小时预报</h3>
        <div class="hourly-scroll">
          <div v-for="h in weatherData.hour" :key="h.time" class="hour-item">
            <span class="hour-time">{{ formatHourTime(h.time) }}</span>
            <span class="hour-icon">{{ getWeatherIcon(h.wea_code) }}</span>
            <span class="hour-temp">{{ h.temp }}°</span>
            <span class="hour-wind">{{ h.wind_level }}</span>
          </div>
        </div>
      </div>

      <!-- 生活指数 -->
      <div class="card index-card">
        <h3>📋 生活指数</h3>
        <div class="index-list">
          <div v-for="item in (showAllIndexes ? weatherData.index : weatherData.index.slice(0, 4))" :key="item.type" class="index-item">
            <div class="index-icon">{{ indexEmoji(item.type) }}</div>
            <div class="index-body">
              <div class="index-header">
                <span class="index-name">{{ item.name }}</span>
                <span class="index-level">{{ item.level }}</span>
              </div>
              <p class="index-content">{{ item.content }}</p>
            </div>
          </div>
        </div>
        <button v-if="weatherData.index.length > 4" class="toggle-btn" @click="showAllIndexes = !showAllIndexes">
          {{ showAllIndexes ? "收起" : `展开全部 (${weatherData.index.length}项)` }}
        </button>
      </div>
    </section>

    <!-- 底部分隔 -->
    <hr class="section-divider" />

    <!-- 原有 demo 保留 -->
    <section class="demo-section">
      <h1>Welcome to Tauri + Vue</h1>
      <div class="row">
        <a href="https://vite.dev" target="_blank"><img src="/vite.svg" class="logo vite" alt="Vite" /></a>
        <a href="https://tauri.app" target="_blank"><img src="/tauri.svg" class="logo tauri" alt="Tauri" /></a>
        <a href="https://vuejs.org/" target="_blank"><img src="./assets/vue.svg" class="logo vue" alt="Vue" /></a>
      </div>
      <form class="row" @submit.prevent="greet">
        <input v-model="name" placeholder="Enter a name..." />
        <button type="submit">Greet</button>
      </form>
      <p>{{ greetMsg }}</p>
    </section>
  </main>
</template>

<style scoped>
/* ========== 全局 ========== */
.app-container {
  max-width: 600px;
  margin: 0 auto;
  padding: 20px 16px 40px;
}

.app-header h1 {
  font-size: 1.6em;
  margin-bottom: 16px;
  text-align: center;
}

/* ========== 搜索表单 ========== */
.search-section {
  margin-bottom: 20px;
}

.search-form {
  background: #fff;
  border-radius: 16px;
  padding: 20px;
  box-shadow: 0 2px 12px rgba(0, 0, 0, 0.08);
}

.field-row {
  display: flex;
  gap: 10px;
  margin-bottom: 12px;
}

/* 小屏幕时表单字段竖排 */
@media (max-width: 400px) {
  .field-row {
    flex-direction: column;
    gap: 8px;
  }
}

.field {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.field label {
  font-size: 0.8em;
  font-weight: 600;
  color: #888;
  padding-left: 2px;
}

.field input {
  padding: 10px 12px;
  border: 1.5px solid #e0e0e0;
  border-radius: 10px;
  font-size: 0.95em;
  transition: border-color 0.2s;
}

.field input:focus {
  border-color: #396cd8;
  outline: none;
}

.search-btn {
  width: 100%;
  padding: 12px;
  border: none;
  border-radius: 10px;
  background: linear-gradient(135deg, #396cd8 0%, #2a5ab5 100%);
  color: #fff;
  font-size: 1em;
  font-weight: 600;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  transition: opacity 0.2s;
}

.search-btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.spinner {
  width: 18px;
  height: 18px;
  border: 2px solid rgba(255, 255, 255, 0.3);
  border-top-color: #fff;
  border-radius: 50%;
  animation: spin 0.6s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

/* ========== 错误 ========== */
.error-msg {
  background: #fff0f0;
  color: #d32f2f;
  border-radius: 12px;
  padding: 14px 18px;
  margin-bottom: 16px;
  font-size: 0.9em;
  text-align: center;
}

/* ========== 主天气卡片 ========== */
.weather-main-card {
  border-radius: 20px;
  padding: 24px;
  margin-bottom: 16px;
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.08);
  transition: background 0.3s;
}

.main-top {
  text-align: center;
}

.city-info h2 {
  font-size: 1.4em;
  margin: 0;
}

.update-time {
  font-size: 0.75em;
  color: #999;
}

.weather-main-temp {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  margin: 8px 0 4px;
}

.weather-icon-big {
  font-size: 3em;
  line-height: 1;
}

.temp-big {
  font-size: 4em;
  font-weight: 300;
  line-height: 1;
}

.weather-desc {
  display: flex;
  justify-content: center;
  gap: 12px;
  font-size: 1em;
  color: #666;
}

.temp-range {
  color: #999;
}

.details-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 10px;
  margin-top: 20px;
  padding-top: 16px;
  border-top: 1px solid rgba(0, 0, 0, 0.06);
}

/* 小屏幕详情改为 2 列 */
@media (max-width: 420px) {
  .details-grid {
    grid-template-columns: repeat(2, 1fr);
  }
}

.detail-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 2px;
}

.detail-label {
  font-size: 0.75em;
  color: #999;
}

.detail-value {
  font-size: 0.9em;
  font-weight: 600;
}

/* ========== 通用卡片 ========== */
.card {
  background: #fff;
  border-radius: 16px;
  padding: 20px;
  margin-bottom: 16px;
  box-shadow: 0 2px 12px rgba(0, 0, 0, 0.08);
}

.card h3 {
  font-size: 1em;
  margin: 0 0 14px;
  color: #444;
}

/* ========== AQI ========== */
.aqi-row {
  display: flex;
  align-items: center;
  gap: 16px;
  margin-bottom: 14px;
}

.aqi-number {
  font-size: 2.8em;
  font-weight: 700;
  line-height: 1;
  min-width: 70px;
  text-align: center;
}

.aqi-info {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.aqi-level {
  font-weight: 700;
  font-size: 1.05em;
  color: #333;
}

.aqi-tips {
  font-size: 0.82em;
  color: #888;
  line-height: 1.4;
}

.aqi-details {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 8px;
}

@media (max-width: 420px) {
  .aqi-details {
    grid-template-columns: repeat(2, 1fr);
  }
}

.aqi-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 8px;
  background: #f8f8f8;
  border-radius: 10px;
}

.aqi-item label {
  font-size: 0.75em;
  color: #999;
}

.aqi-item span {
  font-size: 0.95em;
  font-weight: 600;
}

/* ========== 小时预报 ========== */
.hourly-scroll {
  display: flex;
  overflow-x: auto;
  gap: 10px;
  padding-bottom: 4px;
  scrollbar-width: thin;
}

.hour-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
  padding: 10px 12px;
  background: #f8f8f8;
  border-radius: 12px;
  min-width: 60px;
  flex-shrink: 0;
}

.hour-time {
  font-size: 0.75em;
  color: #999;
}

.hour-icon {
  font-size: 1.3em;
}

.hour-temp {
  font-size: 1em;
  font-weight: 700;
}

.hour-wind {
  font-size: 0.7em;
  color: #aaa;
}

/* ========== 生活指数 ========== */
.index-list {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.index-item {
  display: flex;
  gap: 12px;
  align-items: flex-start;
}

.index-icon {
  font-size: 1.6em;
  flex-shrink: 0;
  width: 40px;
  text-align: center;
}

.index-body {
  flex: 1;
}

.index-header {
  display: flex;
  align-items: baseline;
  gap: 8px;
  margin-bottom: 2px;
}

.index-name {
  font-weight: 600;
  font-size: 0.93em;
}

.index-level {
  font-size: 0.78em;
  padding: 1px 10px;
  border-radius: 20px;
  background: #e8f0ff;
  color: #396cd8;
}

.index-content {
  margin: 0;
  font-size: 0.82em;
  color: #888;
  line-height: 1.5;
}

.toggle-btn {
  margin-top: 12px;
  width: 100%;
  padding: 8px;
  border: 1.5px solid #ddd;
  border-radius: 10px;
  background: transparent;
  color: #666;
  font-size: 0.85em;
  cursor: pointer;
  transition: border-color 0.2s;
}

.toggle-btn:hover {
  border-color: #396cd8;
  color: #396cd8;
}

/* ========== 移动端适配 ========== */
@media (max-width: 440px) {
  .app-container {
    padding: 12px 10px 30px;
  }

  .weather-main-card {
    padding: 16px;
    border-radius: 16px;
  }

  .weather-icon-big {
    font-size: 2.4em;
  }

  .temp-big {
    font-size: 3.2em;
  }

  .aqi-number {
    font-size: 2.2em;
    min-width: 56px;
  }

  .hour-item {
    min-width: 52px;
    padding: 8px 10px;
  }

  .hour-icon {
    font-size: 1.1em;
  }

  .index-icon {
    font-size: 1.3em;
    width: 32px;
  }

  .search-form {
    padding: 14px;
  }

  .card {
    padding: 14px;
  }
}

/* ========== 分隔 & Demo ========== */
.section-divider {
  margin: 32px 0;
  border: none;
  border-top: 1px solid #eee;
}

.demo-section {
  text-align: center;
}

.row {
  display: flex;
  justify-content: center;
  gap: 0;
}

.logo {
  height: 5em;
  padding: 1.2em;
  transition: filter 0.75s;
}

.logo.vite:hover { filter: drop-shadow(0 0 2em #747bff); }
.logo.vue:hover { filter: drop-shadow(0 0 2em #249b73); }
.logo.tauri:hover { filter: drop-shadow(0 0 2em #24c8db); }
</style>
<style>
/* ========== 全局样式 ========== */
:root {
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
  font-size: 16px;
  line-height: 1.5;
  color: #0f0f0f;
  background-color: #f0f2f5;
}

* {
  box-sizing: border-box;
}

body {
  margin: 0;
  padding: 0;
}

h1 { text-align: center; }

input, button { font-family: inherit; }

@media (prefers-color-scheme: dark) {
  :root {
    color: #f0f0f0;
    background-color: #1a1a2e;
  }
  .search-form,
  .card {
    background: #1e1e3a !important;
    box-shadow: 0 2px 12px rgba(0, 0, 0, 0.3) !important;
  }
  .field input {
    background: #2a2a4a;
    color: #f0f0f0;
    border-color: #444;
  }
  .detail-item .detail-label { color: #999 !important; }
  .detail-item .detail-value { color: #eee !important; }
  .aqi-item { background: #2a2a4a !important; }
  .aqi-item label { color: #aaa !important; }
  .aqi-item span { color: #eee !important; }
  .hour-item { background: #2a2a4a !important; }
  .hour-item .hour-time { color: #aaa !important; }
  .hour-item .hour-wind { color: #888 !important; }
  .index-level { background: #2a3a6a !important; color: #88bbff !important; }
  .index-content { color: #aaa !important; }
  .error-msg { background: #3a1a1a !important; }
  .weather-main-card { box-shadow: 0 4px 20px rgba(0, 0, 0, 0.3) !important; }
  .update-time { color: #aaa !important; }
  .weather-desc { color: #bbb !important; }
  .temp-range { color: #999 !important; }
  .section-divider { border-top-color: #333 !important; }
  .toggle-btn { border-color: #555 !important; color: #aaa !important; }
  .toggle-btn:hover { border-color: #88bbff !important; color: #88bbff !important; }
}
</style>
