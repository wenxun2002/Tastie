# 数据流指南：Firestore → UI

说明首页 Explore 列表与菜谱详情的数据如何从 **Cloud Firestore** 流到界面。旧版基于 `assets/mock/index_list.json`、`card_detail_list.json` 与 Mock Repository 的路径已移除。

---

## 数据源概览

| 数据 | Firestore 路径 | 客户端主要入口 |
|------|------------------|----------------|
| 菜谱（列表 + 详情主体） | `recipes/{recipeId}` | `FirestoreIndexRepository`、`FirestoreRecipeRepository` |
| 标签元数据（筛选等） | `tags/{tagId}` | `FirestoreTagRepository` |
| 用户资料 | `users/{userId}` | `FirestoreUserRepository` |
| 点赞 / 收藏 | `users/{userId}/likes|collections/{recipeId}` | `RecipeEngagementRepository` |
| 举报 | `reports/{reportId}` | `ReportRecipeService`（写）、Admin（读） |

可选维护数据：`assets/mock/tag_list.json` 仅用于 `scripts/firestore_import` 向 **`tags`** 集合做一次性导入，**不参与 App 运行时 bundle 加载**。

---

## 路径 1：首页 Explore（卡片列表）

```
Firestore recipes（查询 + 分页）
  ↓
FirestoreIndexRepository.getPostsPaginated(...)
  ↓
CardData.fromJson（由仓库内 _normalizeCardDataJson 对齐 recipe 字段）
  ↓
IndexController（天气 tag 分层、分页游标、去重）
  ↓
IndexPage / CardItem
```

要点：

- 列表读的是 **`recipes`**，不是历史上的 `index_cards`。
- `IndexController` 使用 `FirestoreIndexRepository()`（默认 `collectionPath == 'recipes'`），按 `createdAt` 或 `likeCount` 排序，并可按 `tags` + `arrayContainsAny` 过滤。
- 展示模型为 **`CardData`**（`lib/models/card_data.dart`），字段由 Firestore 文档映射而来（如 `userId`、`imageUrls`、`author` 等会在 normalize 步骤中变成 `uid`、`cover`、`nickname` 等）。

---

## 路径 2：详情页（菜谱详情）

```
路由传入 recipe 文档 id（String）
  ↓
IndexDetailController.getIndexDetailData(id)
  ↓
FirestoreRecipeRepository.getById(id) → RecipeFirestore
  ↓
RecipeEngagementRepository.watchRecipe(id) 实时更新文档
  ↓
users/{uid}/likes、collections 子文档流 → 心形 / 收藏状态
  ↓
IndexDetailPage（RecipeFirestore：标题、图、步骤、营养等）
```

要点：

- 详情数据模型为 **`RecipeFirestore`**（`lib/models/recipe_firestore.dart`），**不再使用**已删除的 `CardDetailData` / `card_details` 集合。
- 点赞数、收藏数等以 `recipes` 文档上的字段及子集合为准，与列表侧一致。

---

## 分层职责（仍适用）

1. **Repository**：封装 Firestore 访问（`lib/repositories/`）。
2. **Model**：`CardData`（列表）、`RecipeFirestore`（详情）等。
3. **Controller**：分页、天气策略、登录态与流订阅（如 `IndexController`、`IndexDetailController`）。
4. **UI**：`GetBuilder` / `Getx` 订阅控制器状态并渲染。

---

## 运维脚本（非运行时）

| 脚本 | 作用 |
|------|------|
| `scripts/firestore_import/index.js` | 将 `assets/mock/tag_list.json` 写入 **`tags`** |
| `scripts/firestore_import/upload_images_and_update_firestore.js` | 扫描 **`recipes`** 中的 `assets/images/...` 引用，上传 Storage 并回写 URL |

---

## 注意事项

- 列表与详情均以 **`recipes` 文档 id** 为键；路由传参需与 Firestore 文档 ID 一致。
- 复合查询（例如 `tags` + `orderBy`）需在 Firebase 控制台配置相应**索引**。
- 安全规则见项目根目录 **`firestore.rules`**（已不再包含 `card_details`）。
