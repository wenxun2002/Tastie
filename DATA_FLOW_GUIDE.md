# 📊 数据流指南：从 JSON 到 UI

本文档详细说明 Card 和 CardDetail 数据是如何从 JSON 文件流到 UI 展示的。

---

## 🗂️ 数据源

### 1. JSON 文件位置
```
assets/mock/
  ├── index_list.json          # 首页卡片列表数据
  └── card_detail_list.json    # 详情页数据
```

### 2. JSON 结构示例

**index_list.json** (首页卡片):
```json
[
  {
    "id": 1,
    "uid": 1000,
    "cover": "assets/images/Cover/Comfort.png",
    "content": "Comfort",
    "avatar": "assets/images/Frame 22.png",
    "nickname": "Tastie user 1",
    "fav": 119,
    "like": 10,
    "tags": ["Comfort"]
  }
]
```

**card_detail_list.json** (详情页):
```json
[
  {
    "id": 1,
    "uid": 1000,
    "title": "Comfort",
    "content": "This is a detailed content...",
    "author": {
      "nickname": "Tastie user 1",
      "avatar": "assets/images/Frame 22.png"
    },
    "ingredients": [
      { "name": "Sugar", "amount": 200, "unit": "g" }
    ],
    "procedures": ["Step 1...", "Step 2..."],
    "nutrition": { "calories": 500, ... },
    "fav": 119,
    "like": 10,
    "date": "2023-08-09 10:54:27",
    "address": "Malaysia"
  }
]
```

---

## 🔄 数据流路径

### 📱 **路径 1: 首页卡片列表 (Index Page)**

```
JSON 文件
  ↓
Repository (数据层)
  ↓
Controller (业务逻辑层)
  ↓
UI Widget (展示层)
```

#### 详细步骤：

**步骤 1: Repository 加载 JSON**
```dart
// lib/repositories/mock_index_repository.dart
class MockIndexRepository {
  Future<List<CardData>> getAll() async {
    // 1. 从 assets 加载 JSON 字符串
    final String jsonString = await rootBundle.loadString(
      'assets/mock/index_list.json',
    );
    
    // 2. 解析 JSON 字符串为 List<dynamic>
    final List<dynamic> jsonList = json.decode(jsonString);
    
    // 3. 将每个 JSON 对象转换为 CardData Model
    return jsonList
        .map((json) => CardData.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
```

**步骤 2: Model 解析 JSON**
```dart
// lib/models/card_data.dart
class CardData {
  factory CardData.fromJson(Map<String, dynamic> json) {
    return CardData(
      id: json['id'] as int,
      cover: json['cover'] as String,
      content: json['content'] as String,
      avatar: json['avatar'] as String,
      nickname: json['nickname'] as String,
      fav: json['fav'] as int,
      like: json['like'] as int,
      tags: (json['tags'] as List<dynamic>).map((e) => e as String).toList(),
    );
  }
}
```

**步骤 3: Controller 使用 Repository**
```dart
// lib/pages/index_page/index_controller.dart
class IndexController extends GetxController {
  List<CardData> data = []; // 用于 UI 显示的数据

  void loadData() async {
    // 1. 创建 Repository 实例
    final repository = MockIndexRepository();
    
    // 2. 从 JSON 加载数据
    _allData = await repository.getAll();
    
    // 3. 根据天气排序数据
    _sortData();
    
    // 4. 通知 UI 更新
    update(['post_list']);
  }

  void _sortData() {
    // 根据当前天气对数据进行排序
    data = sortPostsByWeather(
      posts: List.from(_allData),
      weather: currentWeather,
    );
    update(['post_list']); // 触发 UI 更新
  }
}
```

**步骤 4: UI 显示数据**
```dart
// lib/pages/index_page/index_page.dart
class IndexPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final IndexController controller = Get.put(IndexController());

    return GetBuilder<IndexController>(
      id: 'post_list', // 只监听这个 ID 的更新
      builder: (_) {
        return MasonryGridView.count(
          itemCount: controller.data.length,
          itemBuilder: (context, index) {
            final cardData = controller.data[index];
            
            // 使用 CardItem Widget 显示每个卡片
            return CardItem(
              cardData: cardData,
              onTap: () => controller.openIndexDetailPage(cardData.id),
            );
          },
        );
      },
    );
  }
}
```

**步骤 5: CardItem Widget 渲染**
```dart
// lib/pages/index_page/widgets/card_item.dart
class CardItem extends StatelessWidget {
  final CardData cardData; // 接收 CardData 对象

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        children: [
          // 显示封面图片
          ImageUtils.loadImage(cardData.cover, ...),
          
          // 显示内容
          Text(cardData.content),
          
          // 显示用户信息
          Row(
            children: [
              ImageUtils.loadImage(cardData.avatar, ...),
              Text(cardData.nickname),
              Icon(Icons.favorite_border),
              Text(cardData.like.toString()),
            ],
          ),
        ],
      ),
    );
  }
}
```

---

### 📄 **路径 2: 详情页 (Detail Page)**

```
用户点击卡片
  ↓
路由跳转 (传递 ID)
  ↓
Detail Controller 初始化
  ↓
Repository 根据 ID 加载数据
  ↓
Model 解析 JSON
  ↓
UI 显示详情
```

#### 详细步骤：

**步骤 1: 用户点击卡片**
```dart
// lib/pages/index_page/index_controller.dart
void openIndexDetailPage(int id) {
  // 使用 GetX 路由跳转，传递卡片 ID
  Get.toNamed(Pages.indexDetail, arguments: {"id": id});
}
```

**步骤 2: Detail Controller 初始化**
```dart
// lib/pages/index_page/index_detail_page/index_detail_controller.dart
class IndexDetailController extends GetxController {
  late CardDetailData cardDetailData;
  bool isLoading = true;

  @override
  void onInit() {
    super.onInit();
    // 1. 从路由参数获取 ID
    final args = Get.arguments;
    final id = args["id"] as int;
    
    // 2. 加载详情数据
    getIndexDetailData(id);
  }
}
```

**步骤 3: Repository 根据 ID 加载数据**
```dart
// lib/repositories/mock_card_detail_repository.dart
class MockCardDetailRepository {
  Future<CardDetailData?> getById(int id) async {
    // 1. 先加载所有数据
    final allData = await getAll();
    
    // 2. 根据 ID 查找匹配的数据
    try {
      return allData.firstWhere((item) => item.id == id);
    } catch (e) {
      return null; // ID 不存在
    }
  }
}
```

**步骤 4: Model 解析 JSON**
```dart
// lib/models/card_detail_data.dart
class CardDetailData {
  factory CardDetailData.fromJson(Map<String, dynamic> json) {
    return CardDetailData(
      id: json['id'] as int,
      title: json['title'] as String,
      author: Author.fromJson(json['author'] as Map<String, dynamic>),
      ingredients: (json['ingredients'] as List<dynamic>)
          .map((e) => Ingredient.fromJson(e as Map<String, dynamic>))
          .toList(),
      procedures: (json['procedures'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      nutrition: Nutrition.fromJson(json['nutrition'] as Map<String, dynamic>),
      // ... 其他字段
    );
  }
}
```

**步骤 5: UI 显示详情**
```dart
// lib/pages/index_page/index_detail_page/index_detail_page.dart
class IndexDetailPage extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    final IndexDetailController controller = Get.put(IndexDetailController());

    return GetBuilder<IndexDetailController>(
      builder: (_) {
        if (controller.isLoading) {
          return CircularProgressIndicator();
        }
        
        // 显示详情数据
        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                // 显示作者头像
                ImageUtils.loadImage(
                  controller.cardDetailData.avatar,
                  width: 38,
                  height: 38,
                ),
                // 显示作者昵称
                Text(controller.cardDetailData.nickname),
              ],
            ),
          ),
          body: Column(
            children: [
              // 显示图片轮播
              Swiper(
                itemCount: controller.cardDetailData.images.length,
                itemBuilder: (context, index) {
                  return ImageUtils.loadImage(
                    controller.cardDetailData.images[index],
                  );
                },
              ),
              // 显示标题
              Text(controller.cardDetailData.title),
              // 显示内容
              Text(controller.cardDetailData.content),
              // 显示标签
              Wrap(
                children: controller.cardDetailData.tags.map((tag) {
                  return Chip(label: Text("#$tag"));
                }).toList(),
              ),
              // 显示配料和步骤 (TabBarView)
              TabBarView(
                children: [
                  buildIngredientsTab(controller),
                  buildProceduresTab(controller),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
```

---

## 🔑 关键组件说明

### 1. **Repository (数据层)**
- **职责**: 负责从数据源（JSON/API）加载数据
- **位置**: `lib/repositories/`
- **特点**: 
  - 抽象数据源，未来可以轻松替换为 Firebase/API
  - 提供 `getAll()` 和 `getById()` 方法

### 2. **Model (数据模型)**
- **职责**: 定义数据结构，提供 JSON 序列化/反序列化
- **位置**: `lib/models/`
- **特点**:
  - `fromJson()`: 将 JSON 转换为 Dart 对象
  - `toJson()`: 将 Dart 对象转换为 JSON

### 3. **Controller (业务逻辑层)**
- **职责**: 管理状态，处理业务逻辑
- **位置**: `lib/pages/*/index_controller.dart`
- **特点**:
  - 使用 GetX 进行状态管理
  - `update()`: 通知 UI 更新
  - 处理数据排序、过滤等逻辑

### 4. **UI Widget (展示层)**
- **职责**: 渲染 UI，响应用户交互
- **位置**: `lib/pages/*/index_page.dart`
- **特点**:
  - 使用 `GetBuilder` 监听 Controller 状态变化
  - 从 Controller 获取数据并显示

---

## 📋 数据流总结

### 首页卡片列表流程：
```
1. App 启动
   ↓
2. IndexController.onInit() 调用 loadData()
   ↓
3. MockIndexRepository.getAll() 加载 JSON
   ↓
4. rootBundle.loadString() 读取 assets/mock/index_list.json
   ↓
5. json.decode() 解析 JSON 字符串
   ↓
6. CardData.fromJson() 转换为 CardData 对象列表
   ↓
7. Controller._sortData() 根据天气排序
   ↓
8. Controller.update(['post_list']) 通知 UI 更新
   ↓
9. IndexPage 的 GetBuilder 重建
   ↓
10. MasonryGridView 显示卡片列表
   ↓
11. CardItem Widget 渲染每个卡片
```

### 详情页流程：
```
1. 用户点击卡片
   ↓
2. IndexController.openIndexDetailPage(id) 跳转路由
   ↓
3. IndexDetailController.onInit() 获取 ID
   ↓
4. IndexDetailController.getIndexDetailData(id) 加载数据
   ↓
5. MockCardDetailRepository.getById(id) 查找数据
   ↓
6. rootBundle.loadString() 读取 assets/mock/card_detail_list.json
   ↓
7. json.decode() 解析 JSON
   ↓
8. CardDetailData.fromJson() 转换为对象
   ↓
9. Controller.update() 通知 UI 更新
   ↓
10. IndexDetailPage 显示详情内容
```

---

## 🚀 未来扩展

当需要连接真实后端时，只需要：

1. **创建新的 Repository**:
```dart
class FirebaseCardDetailRepository {
  Future<List<CardDetailData>> getAll() async {
    // 从 Firebase 加载数据
    final snapshot = await FirebaseFirestore.collection('cards').get();
    return snapshot.docs.map((doc) => CardDetailData.fromJson(doc.data())).toList();
  }
}
```

2. **替换 Repository**:
```dart
// 在 Controller 中
final repository = FirebaseCardDetailRepository(); // 替换 MockCardDetailRepository
```

3. **Model 保持不变** - 因为 JSON 结构相同！

---

## 📝 注意事项

1. **异步加载**: 所有数据加载都是异步的，UI 需要处理加载状态
2. **错误处理**: Repository 和 Controller 都应该处理加载失败的情况
3. **状态管理**: 使用 GetX 的 `update()` 来通知 UI 更新，避免不必要的重建
4. **性能优化**: 使用 `GetBuilder` 的 `id` 参数来精确控制更新范围

