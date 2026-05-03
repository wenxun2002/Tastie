/// Explore / Search 等公开列表：排除 admin 标记为 `banned` 的文档。
///
/// **注意**：Firestore 的 `status is null` 条件**不会**匹配「字段不存在」的旧文档，因此不能在查询里用 OR 表达「未写 status = 视为 active」。
/// 公开列表应在拉取后对本函数做客户端过滤（或一次性把旧数据 backfill 为 `status: active`）。
bool recipeDocIsPublicCatalogVisible(Map<String, dynamic> data) {
  final s = data['status']?.toString().toLowerCase();
  return s != 'banned';
}
