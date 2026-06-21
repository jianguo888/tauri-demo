<script setup lang="ts">
import { ref, computed, watch } from "vue";
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

const PROVINCE_CITY_MAP: Record<string, string[]> = {
  "北京": ["北京"],
  "上海": ["上海"],
  "天津": ["天津"],
  "重庆": ["重庆"],
  "河北": ["石家庄", "唐山", "秦皇岛", "邯郸", "保定", "张家口", "承德", "沧州", "廊坊", "衡水"],
  "山西": ["太原", "大同", "阳泉", "长治", "晋城", "朔州", "晋中", "运城", "忻州", "临汾", "吕梁"],
  "内蒙古": ["呼和浩特", "包头", "乌海", "赤峰", "通辽", "鄂尔多斯", "呼伦贝尔", "巴彦淖尔", "乌兰察布"],
  "辽宁": ["沈阳", "大连", "鞍山", "抚顺", "本溪", "丹东", "锦州", "营口", "阜新", "辽阳", "盘锦", "铁岭", "朝阳", "葫芦岛"],
  "吉林": ["长春", "吉林", "四平", "辽源", "通化", "白山", "松原", "白城", "延边"],
  "黑龙江": ["哈尔滨", "齐齐哈尔", "鸡西", "鹤岗", "双鸭山", "大庆", "伊春", "佳木斯", "七台河", "牡丹江", "黑河", "绥化"],
  "江苏": ["南京", "无锡", "徐州", "常州", "苏州", "南通", "连云港", "淮安", "盐城", "扬州", "镇江", "泰州", "宿迁"],
  "浙江": ["杭州", "宁波", "温州", "嘉兴", "湖州", "绍兴", "金华", "衢州", "舟山", "台州", "丽水"],
  "安徽": ["合肥", "芜湖", "蚌埠", "淮南", "马鞍山", "淮北", "铜陵", "安庆", "黄山", "滁州", "阜阳", "宿州", "六安", "亳州", "池州", "宣城"],
  "福建": ["福州", "厦门", "莆田", "三明", "泉州", "漳州", "南平", "龙岩", "宁德"],
  "江西": ["南昌", "景德镇", "萍乡", "九江", "新余", "鹰潭", "赣州", "吉安", "宜春", "抚州", "上饶"],
  "山东": ["济南", "青岛", "淄博", "枣庄", "东营", "烟台", "潍坊", "济宁", "泰安", "威海", "日照", "临沂", "德州", "聊城", "滨州", "菏泽"],
  "河南": ["郑州", "开封", "洛阳", "平顶山", "安阳", "鹤壁", "新乡", "焦作", "濮阳", "许昌", "漯河", "三门峡", "南阳", "商丘", "信阳", "周口", "驻马店"],
  "湖北": ["武汉", "黄石", "十堰", "宜昌", "襄阳", "鄂州", "荆门", "孝感", "荆州", "黄冈", "咸宁", "随州", "恩施"],
  "湖南": ["长沙", "株洲", "湘潭", "衡阳", "邵阳", "岳阳", "常德", "张家界", "益阳", "郴州", "永州", "怀化", "娄底", "湘西"],
  "广东": ["广州", "韶关", "深圳", "珠海", "汕头", "佛山", "江门", "湛江", "茂名", "肇庆", "惠州", "梅州", "汕尾", "河源", "阳江", "清远", "东莞", "中山", "潮州", "揭阳", "云浮"],
  "广西": ["南宁", "柳州", "桂林", "梧州", "北海", "防城港", "钦州", "贵港", "玉林", "百色", "贺州", "河池", "来宾", "崇左"],
  "海南": ["海口", "三亚", "三沙", "儋州"],
  "四川": ["成都", "自贡", "攀枝花", "泸州", "德阳", "绵阳", "广元", "遂宁", "内江", "乐山", "南充", "眉山", "宜宾", "广安", "达州", "雅安", "巴中", "资阳", "阿坝", "甘孜", "凉山"],
  "贵州": ["贵阳", "六盘水", "遵义", "安顺", "毕节", "铜仁", "黔西南", "黔东南", "黔南"],
  "云南": ["昆明", "曲靖", "玉溪", "保山", "昭通", "丽江", "普洱", "临沧", "楚雄", "红河", "文山", "西双版纳", "大理", "德宏", "怒江", "迪庆"],
  "西藏": ["拉萨", "日喀则", "昌都", "林芝", "山南", "那曲", "阿里"],
  "陕西": ["西安", "铜川", "宝鸡", "咸阳", "渭南", "延安", "汉中", "榆林", "安康", "商洛"],
  "甘肃": ["兰州", "嘉峪关", "金昌", "白银", "天水", "武威", "张掖", "平凉", "酒泉", "庆阳", "定西", "陇南", "临夏", "甘南"],
  "青海": ["西宁", "海东", "海北", "黄南", "海南", "果洛", "玉树", "海西"],
  "宁夏": ["银川", "石嘴山", "吴忠", "固原", "中卫"],
  "新疆": ["乌鲁木齐", "克拉玛依", "吐鲁番", "哈密", "昌吉", "博尔塔拉", "巴音郭楞", "阿克苏", "克孜勒苏", "喀什", "和田", "伊犁", "塔城", "阿勒泰"],
  "台湾": ["台北", "高雄", "台中", "台南"],
  "香港": ["香港"],
  "澳门": ["澳门"],
};

const PROVINCES = Object.keys(PROVINCE_CITY_MAP);

const greetMsg = ref("");
const name = ref("");

const token = ref(import.meta.env.VITE_WEATHER_TOKEN || "");
const selectedProvince = ref("北京");
const selectedCity = ref("北京");
const loading = ref(false);
const weatherData = ref<WeatherData | null>(null);
const error = ref("");
const showAllIndexes = ref(false);

const cities = computed(() => {
  return PROVINCE_CITY_MAP[selectedProvince.value] || [];
});

// 省份切换时，自动选择该省第一个城市
watch(selectedProvince, (newProv) => {
  const list = PROVINCE_CITY_MAP[newProv];
  if (list && !list.includes(selectedCity.value)) {
    selectedCity.value = list[0];
  }
});

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
      city: selectedCity.value,
      province: selectedProvince.value,
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

// ==================== 历史上的今天 ====================
const todayData = ref<any>(null);
const todayLoading = ref(false);
const todayError = ref("");

async function fetchTodayHistory() {
  if (todayData.value) return; // 已缓存
  todayLoading.value = true;
  todayError.value = "";
  try {
    const res = await invoke<string>("today", {
      token: token.value,
      date: null,
    });
    const parsed = JSON.parse(res);
    if (parsed.success && parsed.data) {
      todayData.value = parsed.data;
    } else {
      todayError.value = parsed.message || "获取失败";
    }
  } catch (e) {
    todayError.value = `请求出错: ${e}`;
  } finally {
    todayLoading.value = false;
  }
}

// ==================== 星座运势 ====================
const CONSTELLATIONS = [
  "白羊座", "金牛座", "双子座", "巨蟹座",
  "狮子座", "处女座", "天秤座", "天蝎座",
  "射手座", "摩羯座", "水瓶座", "双鱼座",
];
const selectedConstellation = ref("白羊座");
const starData = ref<any>(null);
const starLoading = ref(false);
const starError = ref("");

async function fetchConstellation() {
  starLoading.value = true;
  starError.value = "";
  starData.value = null;
  try {
    const res = await invoke<string>("constellation", {
      token: token.value,
      constellation: selectedConstellation.value,
    });
    const parsed = JSON.parse(res);
    if (parsed.success && parsed.data) {
      starData.value = parsed.data;
    } else {
      starError.value = parsed.message || "获取失败";
    }
  } catch (e) {
    starError.value = `请求出错: ${e}`;
  } finally {
    starLoading.value = false;
  }
}

// ==================== 每日早报 ====================
const morningData = ref<any>(null);
const morningLoading = ref(false);
const morningError = ref("");

async function fetchMorning() {
  if (morningData.value) return; // 已缓存
  morningLoading.value = true;
  morningError.value = "";
  try {
    const res = await invoke<string>("morning", {
      token: token.value,
    });
    const parsed = JSON.parse(res);
    if (parsed.success || parsed.code === 200) {
      morningData.value = parsed.data;
    } else {
      morningError.value = parsed.message || "获取失败";
    }
  } catch (e) {
    morningError.value = `请求出错: ${e}`;
  } finally {
    morningLoading.value = false;
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

    <!-- ========== 历史上的今天 ========== -->
    <section class="card feature-card">
      <h3 class="feature-header" @click="fetchTodayHistory">
        📜 历史上的今天
        <span class="toggle-hint">{{ todayData ? '' : '点击加载' }}</span>
      </h3>
      <div v-if="todayLoading" class="feature-loading"><span class="spinner"></span> 加载中...</div>
      <div v-else-if="todayError" class="error-msg">{{ todayError }}</div>
      <div v-else-if="todayData" class="today-list">
        <div v-for="evt in todayData" :key="evt.id" class="today-item">
          <span class="today-year">{{ evt.year }}年</span>
          <div class="today-body">
            <strong>{{ evt.title }}</strong>
            <p v-if="evt.desc">{{ evt.desc }}</p>
          </div>
        </div>
      </div>
    </section>

    <!-- ========== 星座运势 ========== -->
    <section class="card feature-card">
      <h3 class="feature-header">🔮 星座运势</h3>
      <div class="star-form">
        <select v-model="selectedConstellation" class="star-select">
          <option v-for="s in CONSTELLATIONS" :key="s" :value="s">{{ s }}</option>
        </select>
        <button class="star-btn" @click="fetchConstellation" :disabled="starLoading">
          <span v-if="starLoading" class="spinner"></span>
          {{ starLoading ? '查询中...' : '查询运势' }}
        </button>
      </div>
      <div v-if="starError" class="error-msg">{{ starError }}</div>
      <div v-if="starData" class="star-content">
        <div class="star-date">{{ starData.day?.date }} · {{ selectedConstellation }}</div>
        <div class="star-grid">
          <div class="star-metric"><label>综合</label><span>{{ starData.day?.all }}</span></div>
          <div class="star-metric"><label>爱情</label><span>{{ starData.day?.love }}</span></div>
          <div class="star-metric"><label>事业</label><span>{{ starData.day?.work }}</span></div>
          <div class="star-metric"><label>财运</label><span>{{ starData.day?.money }}</span></div>
          <div class="star-metric"><label>健康</label><span>{{ starData.day?.health }}</span></div>
        </div>
        <div class="star-lucky">
          <span>🌟 {{ starData.day?.lucky_star }}</span>
          <span>🎨 {{ starData.day?.lucky_color }}</span>
          <span>🔢 {{ starData.day?.lucky_number }}</span>
        </div>
        <div class="star-text">{{ starData.day?.all_text }}</div>
      </div>
    </section>

    <!-- ========== 每日早报 ========== -->
    <section class="card feature-card">
      <h3 class="feature-header" @click="fetchMorning">
        📰 每日早报
        <span class="toggle-hint">{{ morningData ? '' : '点击加载' }}</span>
      </h3>
      <div v-if="morningLoading" class="feature-loading"><span class="spinner"></span> 加载中...</div>
      <div v-else-if="morningError" class="error-msg">{{ morningError }}</div>
      <div v-else-if="morningData" class="morning-content">
        <div class="morning-date">{{ morningData.date }}</div>
        <div v-for="(news, i) in morningData.news" :key="i" class="morning-news-item">
          <span class="morning-index">{{ i + 1 }}</span>
          <span>{{ news }}</span>
        </div>
        <div v-if="morningData.weiyu" class="morning-weiyu">{{ morningData.weiyu }}</div>
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

.field input,
.field select {
  padding: 10px 12px;
  border: 1.5px solid #e0e0e0;
  border-radius: 10px;
  font-size: 0.95em;
  transition: border-color 0.2s;
  background: #fff;
  color: #333;
  appearance: auto;
}

.field input:focus,
.field select:focus {
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

/* ========== 历史上的今天 ========== */
.feature-card .feature-header {
  cursor: pointer;
  display: flex;
  justify-content: space-between;
  align-items: center;
  user-select: none;
}
.feature-card .toggle-hint {
  font-size: 0.75em;
  font-weight: 400;
  color: #396cd8;
}
.feature-loading {
  display: flex;
  align-items: center;
  gap: 8px;
  justify-content: center;
  padding: 16px 0;
  color: #999;
}
.today-list {
  display: flex;
  flex-direction: column;
  gap: 12px;
  max-height: 400px;
  overflow-y: auto;
}
.today-item {
  display: flex;
  gap: 10px;
  align-items: flex-start;
}
.today-year {
  font-size: 0.78em;
  font-weight: 700;
  color: #396cd8;
  white-space: nowrap;
  padding-top: 2px;
  min-width: 48px;
}
.today-body {
  flex: 1;
}
.today-body strong {
  font-size: 0.92em;
}
.today-body p {
  margin: 2px 0 0;
  font-size: 0.82em;
  color: #888;
  line-height: 1.5;
}

/* ========== 星座运势 ========== */
.star-form {
  display: flex;
  gap: 10px;
  margin-bottom: 12px;
}
.star-select {
  flex: 1;
  padding: 10px 12px;
  border: 1.5px solid #e0e0e0;
  border-radius: 10px;
  font-size: 0.95em;
  background: #fff;
  color: #333;
  appearance: auto;
}
.star-btn {
  padding: 10px 18px;
  border: none;
  border-radius: 10px;
  background: linear-gradient(135deg, #d4366c 0%, #b82d5a 100%);
  color: #fff;
  font-weight: 600;
  cursor: pointer;
  display: flex;
  align-items: center;
  gap: 6px;
  white-space: nowrap;
}
.star-btn:disabled {
  opacity: 0.6;
}
.star-content {
  margin-top: 8px;
}
.star-date {
  font-size: 0.85em;
  color: #999;
  margin-bottom: 10px;
  text-align: center;
}
.star-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 8px;
  margin-bottom: 10px;
}
.star-metric {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 10px 6px;
  background: #f8f8f8;
  border-radius: 10px;
}
.star-metric label {
  font-size: 0.72em;
  color: #999;
}
.star-metric span {
  font-size: 1.1em;
  font-weight: 700;
  color: #d4366c;
}
.star-lucky {
  display: flex;
  justify-content: center;
  gap: 12px;
  flex-wrap: wrap;
  font-size: 0.85em;
  color: #666;
  margin-bottom: 10px;
}
.star-text {
  font-size: 0.85em;
  color: #555;
  line-height: 1.7;
  background: #fafafa;
  border-radius: 10px;
  padding: 12px;
  max-height: 260px;
  overflow-y: auto;
}

/* ========== 每日早报 ========== */
.morning-content {
  max-height: 520px;
  overflow-y: auto;
}
.morning-date {
  font-size: 0.85em;
  color: #999;
  margin-bottom: 10px;
  text-align: center;
}
.morning-news-item {
  display: flex;
  gap: 8px;
  padding: 6px 0;
  font-size: 0.88em;
  line-height: 1.6;
  border-bottom: 1px solid #f0f0f0;
}
.morning-news-item:last-child {
  border-bottom: none;
}
.morning-index {
  font-weight: 700;
  color: #396cd8;
  min-width: 22px;
  text-align: right;
  flex-shrink: 0;
}
.morning-weiyu {
  margin-top: 12px;
  padding: 12px;
  background: #fef8e8;
  border-radius: 10px;
  font-size: 0.88em;
  color: #b8860b;
  line-height: 1.6;
  font-style: italic;
}

/* ========== 平板 / PC 自适应 ========== */
@media (min-width: 768px) {
  .app-container {
    max-width: 960px;
    padding: 24px 32px 48px;
  }
  .app-header h1 {
    font-size: 2em;
  }
  .search-form {
    display: flex;
    align-items: flex-end;
    gap: 12px;
  }
  .search-form .field-row {
    flex: 1;
    margin-bottom: 0;
  }
  .search-btn {
    width: auto;
    min-width: 160px;
    padding: 10px 24px;
  }
  .weather-main-card {
    padding: 32px;
  }
  .weather-icon-big {
    font-size: 3.6em;
  }
  .temp-big {
    font-size: 4.8em;
  }
  .details-grid {
    grid-template-columns: repeat(6, 1fr);
  }
  .aqi-details {
    grid-template-columns: repeat(6, 1fr);
  }
  .hour-item {
    min-width: 72px;
    padding: 12px 14px;
  }
  .index-list {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 12px 20px;
  }
  .star-grid {
    grid-template-columns: repeat(5, 1fr);
  }
  .today-list {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 10px 20px;
  }
}

@media (min-width: 1024px) {
  .app-container {
    max-width: 1200px;
    padding: 32px 40px 56px;
  }
  /* 主内容区 2 列布局，更充分利用横向空间 */
  .app-container {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 20px;
    align-items: start;
  }
  .app-header,
  .search-section,
  .error-msg,
  .weather-section,
  .section-divider,
  .demo-section {
    grid-column: 1 / -1;
  }
  /* 天气内部卡片也 2 列 */
  .weather-section {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 20px;
  }
  .weather-main-card {
    grid-column: 1 / -1;
  }
  .weather-section .card {
    margin-bottom: 0;
  }
  .details-grid {
    grid-template-columns: repeat(6, 1fr);
  }
  .hourly-scroll {
    justify-content: space-between;
  }
  .hour-item {
    min-width: 80px;
  }
  .index-list {
    grid-template-columns: 1fr 1fr;
  }
  .star-text {
    max-height: 200px;
  }
  .today-list {
    grid-template-columns: 1fr 1fr;
  }
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
  .field select {
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
  /* 新功能暗色适配 */
  .star-select { background: #2a2a4a !important; color: #f0f0f0 !important; border-color: #444 !important; }
  .star-metric { background: #2a2a4a !important; }
  .star-metric label { color: #aaa !important; }
  .star-text { background: #252545 !important; color: #ccc !important; }
  .morning-news-item { border-bottom-color: #333 !important; }
  .morning-weiyu { background: #2a2a1a !important; color: #cca800 !important; }
  .today-body p { color: #aaa !important; }
  .feature-loading { color: #aaa !important; }
}
</style>
