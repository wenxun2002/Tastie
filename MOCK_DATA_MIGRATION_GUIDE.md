# 本地 Mock 与 Firestore 说明

业务数据（首页 Feed、菜谱详情、用户互动）已以 **Cloud Firestore** 为准。历史上用于导入的 **`index_list.json`**、**`card_detail_list.json`** 及集合 **`index_cards`** / **`card_details`** 已从仓库与规则中移除，不再作为数据流的一部分。

---

## 当前状态

### Firestore 为唯一业务数据源

- **菜谱**：`recipes`（Explore 列表 + 详情）
- **标签**：`tags`（可通过脚本从 JSON 种子导入）
- **用户与互动**：`users` 及其 `likes` / `collections` 子集合

客户端相关实现见 `FirestoreIndexRepository`、`FirestoreRecipeRepository`、`FirestoreTagRepository`、`RecipeEngagementRepository` 等。

### 仍保留的本地 Mock（非 Firestore）

| 用途 | 位置 | 说明 |
|------|------|------|
| 天气选择 / 测试场景 | `lib/mock/mock_weather.dart` | 供 `IndexController`、天气选择器等使用 |
| 发帖页等本地占位 | `lib/mock/mock_recipe_data.dart` | 如 `create_post_page.dart` 引用 |

这些文件**不替代**线上菜谱数据；仅开发或 UI 辅助。

---

## 可选：仅维护标签种子 JSON

若需要向空项目灌入标签文档，可保留并编辑：

- `assets/mock/tag_list.json`

通过 `scripts/firestore_import` 执行导入（详见该目录下 `README.md`）。**App 的 `pubspec.yaml` 未将 `assets/mock/` 整体声明为 bundle 资源**，运行时不会 `rootBundle` 读取该文件。

---

## 文件结构（与 Mock 相关）

```
assets/mock/
  └── tag_list.json          # 可选：仅 firestore_import 使用

lib/mock/
  ├── mock_weather.dart      # 天气 Mock
  └── mock_recipe_data.dart  # 发帖等本地辅助

scripts/firestore_import/
  ├── index.js               # → 写入 tags
  └── upload_images_and_update_firestore.js  # 扫描 recipes 图片路径
```

---

## 历史说明（已废弃）

以下已不再使用，避免按旧文档操作：

- `MockIndexRepository` / `MockCardDetailRepository` 从 JSON 加载首页与详情
- `CardDetailData` 模型与 `card_details` 集合
- `index_list.json`、`card_detail_list.json` 作为运行时数据源

若需回顾旧架构，请使用 Git 历史查看此前版本的 `DATA_FLOW_GUIDE.md` 与代码。
