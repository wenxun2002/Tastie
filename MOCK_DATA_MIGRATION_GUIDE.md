# Mock 数据迁移指南

## 📊 当前状态

### ✅ 已完成迁移（JSON 格式）
- **Card Detail Data** → `assets/mock/card_detail_list.json`
  - 使用 `MockCardDetailRepository` 加载
  - 已完全迁移，不再使用 `mock_card_detail.dart`

### ⚠️ 仍在使用 Dart 硬编码
- **Index List Data** → `lib/mock/mock.dart` (Mock.indexData)
  - 被 `index_controller.dart` 使用
  - 需要迁移到 JSON

- **Weather Test Data** → `lib/mock/mock_weather.dart` (MockWeather)
  - 被 `index_controller.dart` 和 `weather_selector.dart` 使用
  - 建议保留（测试数据，非业务数据）

## 🎯 建议操作

### 1. `mock_card_detail.dart` - 可以删除
**状态**: ✅ 已完全迁移到 JSON
**操作**: 
- 可以删除此文件（已不再使用）
- 或保留作为参考（注释掉）

### 2. `mock.dart` - 建议迁移到 JSON
**状态**: ⚠️ 仍在使用
**当前使用位置**:
- `lib/pages/index_page/index_controller.dart` (3处)

**建议操作**:
1. 创建 `assets/mock/index_list.json`
2. 创建 `MockIndexRepository`
3. 更新 `index_controller.dart` 使用 Repository

### 3. `mock_weather.dart` - 建议保留
**状态**: ✅ 可以保留
**原因**: 
- 这是测试数据，不是业务数据
- 用于测试不同天气条件
- 结构简单，不需要迁移

## 📝 数据修改位置

### 修改 Card Detail 数据
**位置**: `assets/mock/card_detail_list.json`
- 直接编辑 JSON 文件
- 支持所有字段：title, author, tags, ingredients, procedures, nutrition 等

### 修改 Index List 数据（待迁移）
**当前位置**: `lib/mock/mock.dart` (Mock.indexData)
**迁移后**: `assets/mock/index_list.json`

### 修改 Weather 测试数据
**位置**: `lib/mock/mock_weather.dart` (MockWeather)
- 保留在 Dart 文件中即可

## 🔄 未来连接后端

### Card Detail Data
```dart
// 当前: MockCardDetailRepository (从 JSON 加载)
// 未来: 只需替换 Repository 实现

class FirebaseCardDetailRepository {
  Future<List<CardDetailData>> getAll() async {
    // 从 Firebase 加载
  }
}
```

### Index List Data（迁移后）
```dart
// 迁移后: MockIndexRepository (从 JSON 加载)
// 未来: 只需替换 Repository 实现

class FirebaseIndexRepository {
  Future<List<CardData>> getAll() async {
    // 从 Firebase 加载
  }
}
```

## 📁 推荐的文件结构

```
assets/mock/
  ├── card_detail_list.json      ✅ 已迁移
  └── index_list.json             ⚠️ 待迁移

lib/mock/
  ├── mock_card_detail.dart      ❌ 可删除（已迁移）
  ├── mock.dart                   ⚠️ 待迁移到 JSON
  └── mock_weather.dart           ✅ 保留（测试数据）

lib/repositories/
  ├── mock_card_detail_repository.dart  ✅ 已创建
  └── mock_index_repository.dart        ⚠️ 待创建
```

