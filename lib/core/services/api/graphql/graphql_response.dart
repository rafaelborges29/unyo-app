import 'graphql_error.dart';
import 'graphql_exception.dart';

class ApiGraphQLResponse<T> {
  final T data;
  final List<GraphQLError>? errors;

  ApiGraphQLResponse({required this.data, this.errors});

  factory ApiGraphQLResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final errors = (json['errors'] as List<dynamic>?)
        ?.map((e) => GraphQLError.fromJson(e))
        .toList();
    // Match repository handling: reject errors even when partial data is present.
    if (errors != null && errors.isNotEmpty) {
      throw GraphQLException(errors);
    }
    return ApiGraphQLResponse(data: fromJson(json['data']), errors: errors);
  }
}
