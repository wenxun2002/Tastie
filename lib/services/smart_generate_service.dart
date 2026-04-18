import 'package:cloud_functions/cloud_functions.dart';

/// Calls the `smartGenerate` callable (Gen2) in region [defaultRegion].
class SmartGenerateService {
  SmartGenerateService._();
  static final SmartGenerateService instance = SmartGenerateService._();

  static const String defaultRegion = 'asia-southeast1';

  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: defaultRegion,
  );

  /// Returns a map with `ingredients`, `nutrition`, and `procedures` only.
  Future<Map<String, dynamic>> call({
    required String title,
    required String content,
    String userInput = '',
    List<Map<String, String>> images = const [],
  }) async {
    final HttpsCallable callable = _functions.httpsCallable('smartGenerate');
    final HttpsCallableResult<dynamic> result = await callable.call(
      <String, dynamic>{
        'title': title,
        'content': content,
        'userInput': userInput,
        if (images.isNotEmpty) 'images': images,
      },
    );
    final Object? data = result.data;
    if (data is! Map) {
      throw const FormatException('smartGenerate: response is not a map');
    }
    return Map<String, dynamic>.from(data);
  }
}
