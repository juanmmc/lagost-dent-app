import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';

final attachmentsRemoteDataSourceProvider =
    Provider<AttachmentsRemoteDataSource>((ref) {
      final dio = ref.watch(dioProvider);
      return AttachmentsRemoteDataSource(dio);
    });

class UploadedAttachment {
  const UploadedAttachment({required this.id, required this.path});

  final String id;
  final String path;
}

class AttachmentsRemoteDataSource {
  const AttachmentsRemoteDataSource(this._dio);

  final Dio _dio;

  Future<UploadedAttachment> uploadAttachment({
    required PlatformFile file,
    required String type,
  }) async {
    final multipartFile = await _toMultipartFile(file);

    final response = await _dio.post<dynamic>(
      '/api/attachments',
      data: FormData.fromMap({'file': multipartFile, 'type': type}),
    );

    final payload = response.data;
    final data = payload is Map<String, dynamic>
        ? (payload['data'] is Map<String, dynamic>
              ? payload['data'] as Map<String, dynamic>
              : payload)
        : const <String, dynamic>{};

    final id = data['id']?.toString() ?? '';
    final path = data['path']?.toString() ?? '';

    if (id.isEmpty || path.isEmpty) {
      throw const FormatException('Respuesta inválida al subir adjunto');
    }

    return UploadedAttachment(id: id, path: path);
  }

  String resolveErrorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final message = data['message'];
        if (message is String && message.isNotEmpty) return message;
      }
      return 'No se pudo subir el adjunto';
    }
    if (error is FormatException) return error.message;
    return 'Ocurrió un error inesperado al subir el adjunto';
  }

  Future<MultipartFile> _toMultipartFile(PlatformFile file) async {
    if (file.bytes != null) {
      return MultipartFile.fromBytes(file.bytes!, filename: file.name);
    }
    if (file.path != null && file.path!.isNotEmpty) {
      return MultipartFile.fromFile(file.path!, filename: file.name);
    }
    throw const FormatException('No fue posible leer el archivo seleccionado');
  }
}
