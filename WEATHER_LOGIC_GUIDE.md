## 🌦 Weather Logic Guide (Tastie)

本文件说明与天气相关的几个核心文件的职责、字段含义，以及 `classifyWeather` 的完整规则，方便你在报告中引用和维护。

---

### 1. `lib/models/weather_data.dart`

**用途**：统一封装“当前天气”在应用中的数据模型，不直接依赖 API 原始结构。

**字段说明：**

- **`temperature`** (`double`, °C)  
  - WeatherAPI: `current.temp_c`
  - 实际气温，用于判断冷热。

- **`humidity`** (`double`, %)  
  - WeatherAPI: `current.humidity`
  - 相对湿度。

- **`feelsLike`** (`double`, °C)  
  - WeatherAPI: `current.feelslike_c`
  - 体感温度，综合温度、湿度、风速等，是报告中重点使用的变量。

- **`condition`** (`String`)  
  - WeatherAPI: `current.condition.text`
  - 天气文本描述，如 `"Sunny"`, `"Partly cloudy"`, `"Light rain shower"`。

- **`uvIndex`** (`double`)  
  - WeatherAPI: `current.uv`
  - 紫外线指数，配合温度和湿度识别 “hot & dry”。

- **`precipitation`** (`double`, mm/h)  
  - WeatherAPI: `current.precip_mm`
  - 降水量，用来区分小雨/大雨、雷暴强度。

- **`conditionCode`** (`int?`)  
  - WeatherAPI: `current.condition.code`
  - 规范化的天气代码，辅助文本匹配（更稳定），用于判断：雷暴/雨/雪/雾等大类。  
  - 对于本地 `MockWeather` 可以为固定的 code（例如 Clear=1000, Rain=1183）或 `null`。

---

### 2. `lib/repositories/weather_repository.dart`

**用途**：对 WeatherAPI 进行封装，将经纬度 → `WeatherData`。

**核心逻辑：**

- 请求：`GET http://api.weatherapi.com/v1/current.json?key=API_KEY&q=<lat>,<lon>&aqi=no`
- 从返回 JSON 中抽取：
  - `location.name`, `location.region` → 城市/地区名（用于 UI 显示）
  - `current.*` → 填充 `WeatherData`：
    - `temp_c` → `temperature`
    - `feelslike_c` → `feelsLike`
    - `humidity` → `humidity`
    - `condition.text` → `condition`
    - `condition.code` → `conditionCode`
    - `uv` → `uvIndex`
    - `precip_mm` → `precipitation`

**输出：**

- `(weather: WeatherData, locationName: String)` record

---

### 3. `lib/data/weather_tag_weight.dart` + `assets/config/weather_tag_weight.json`

**用途**：定义“天气类别 → 食物标签权重”映射，用于排序 feed。

#### 3.1 `WeatherCategory` 枚举（业务级 6 类天气）

- **`hotHumid`**：高温 + 高湿 + 高体感（闷热潮湿 / 极端热压）
- **`hotDry`**：炎热天气（含一般热湿 / 日常热带天气）
- **`rainy`**：典型雨天（降水 + 心理上的“阴天”感受）
- **`cold`**：低温或空调感（在马来西亚语境下的“凉”）
- **`neutral`**：舒适中性天气（气温/湿度/体感都在合理区间）
- **`stormy`**（冬天 / `winter` 权重）：雪 / 冬季天气，用于非热带地区的扩展场景

#### 3.2 `weather_tag_weight.json`

示例结构（完整见实际文件）：

```json
{
  "hotHumid": {
    "Cooling": 1.0,
    "Hydrating": 0.9,
    "Light": 0.7,
    "Energy": 0.1,
    "Warming": -0.3,
    "Comfort": 0.2
  },
  "rainy": {
    "Cooling": 0.1,
    "Hydrating": 0.3,
    "Light": 0.4,
    "Energy": 0.6,
    "Warming": 1.0,
    "Comfort": 0.9
  },
  ...
}
```

**语义：**

- key：`WeatherCategory` 的字符串版本（通过 `parseCategory` 映射回枚举）
- value：`tag → weight`，数值范围约 \[0.0, 1.0\]（允许负值表示不推荐）
  - **Cooling**：清凉感（冰饮、凉菜等）
  - **Hydrating**：补水（喝水、汤类、水果等）
  - **Light**：清淡/轻负担
  - **Energy**：高能量、饱腹感
  - **Warming**：温热、驱寒
  - **Comfort**：安慰/治愈系食物

**运行时：**

- `WeatherWeightRepository.load()` 会从 JSON 载入并填充：
  - `Map<WeatherCategory, Map<String, double>> weatherWeights`
- `getTagWeight(weather: ..., tag: ...)` 用于在排序时查询权重：
  - 如不存在 → 返回 `0.0`

---

### 4. `lib/utils/weather_classifier.dart`

**用途**：把一个具体的 `WeatherData`（包含 `feelsLike`）归类到 6 个 `WeatherCategory` 之一。

#### 4.1 输入信号

- `temperature`（实际温度，°C）
- `feelsLike`（体感温度，°C）✅ 报告中重点使用
- `humidity`（%）
- `precipitation`（mm/h）
- `uvIndex`
- `condition` 文本描述（lowercase 后做关键词匹配）
- `conditionCode`（WeatherAPI 代码，用于稳定判断雨/雪/雾/雷暴等）

#### 4.2 分类规则（按优先级）

1. **雷暴 / 暴风雨 (`stormy` / `rainy`)**
   - 文本包含 `thunder` **或** `conditionCode ∈ {1273, 1276, 1279, 1282}`：
     - 若 `precipitation ≥ 20` **或** `humidity ≥ 90` → **`stormy`**
     - 否则 → **`rainy`**（轻微雷雨）

2. **雨天 (`rainy` / 其它)**
   - 文本包含 `rain` / `drizzle` / `shower`（且不包含 `snow`）  
     **或** `conditionCode` 落在主雨段（约 1063–1201, 1240–1246）：
     - 若 `precipitation ≥ 5` **或** `humidity ≥ 80` → **`rainy`**
     - 否则：如果 `_isHotAndHumid` → **`hotHumid`**；否则 **`neutral`**

3. **雪 / 冰粒 / 雨夹雪 (`cold`)**
   - 文本包含 `snow`, `sleet`, `blizzard`, `ice pellets`, `blowing snow`  
     **或** `conditionCode` 属于 1066–1237, 1249–1264 → **`cold`**

4. **雾 / 霾 / 薄雾 (`cold` or `neutral`)**
   - 文本包含 `fog`, `mist`, `haze`  
     **或** `conditionCode ∈ {1030, 1135, 1147}`：
     - 若 `feelsLike < 18` **或** `temperature < 18` → **`cold`**
     - 否则 → **`neutral`**

5. **晴/多云无明显降水场景：用温度 + 体感温度 + 湿度 + UV**

   - `_isHotAndHumid(w)`：
     - `temperature ≥ 32`  
     - `humidity ≥ 80`  
     - `feelsLike ≥ 38`  
     → **`hotHumid`**

   - `_isHotAndDry(w)`：
     - `temperature ≥ 33`  
     - `humidity < 40`  
     - `uvIndex ≥ 9`  
     → **`hotDry`**

   - `_isCold(w)`：
     - `temperature < 18` **或** `feelsLike < 16`  
     → **`cold`**

   - `_isComfortableNeutral(w)`：
     - `24 ≤ temperature ≤ 30`  
     - `24 ≤ feelsLike ≤ 32`  
     - `40 ≤ humidity ≤ 70`  
     → **`neutral`**

6. **兜底**
   - 若不满足上述任何条件 → **`neutral`**

#### 4.3 与 tag 权重的关系

最终流程：

1. 从 WeatherAPI 得到 `WeatherData`（包含 `feelsLike` 和 `conditionCode`）。
2. `classifyWeather(weather)` → 得到一个 `WeatherCategory`。
3. 在排序逻辑中，通过 `getTagWeight(weather: category, tag: 'Cooling' 等)` 查出权重。
4. 将权重应用到每个卡片的标签上，算出综合得分，从而调整 feed 顺序。

---

### 5. 适合写进报告的简短总结（可直接引用）

- **输入变量**：`temperature`, `humidity`, `feelsLike`, `condition(text/code)`, `uvIndex`, `precipitation`。  
- **中间层**：使用 `classifyWeather` 将原始天气归类为 6 个业务类别（hotHumid, hotDry, rainy, cold, neutral, stormy）。  
- **决策规则**：优先依据 WeatherAPI 的 condition code / 文本识别雨、雪、雾、雷暴等显著天气，再结合温度和体感温度区分闷热、干热、寒冷和中性。  
- **输出层**：每个天气类别对应一组食物标签权重（Cooling / Hydrating / Light / Energy / Warming / Comfort），驱动推荐排序逻辑。


