import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

Future<Dio> getSecureDioClient() async {
  try {
    // Load the ISRG Root X1 certificate (Let's Encrypt's root CA)
    final ByteData data = await rootBundle.load('assets/isrgrootx1.pem');
    final List<int> bytes = data.buffer.asUint8List();

    // Configure Dio with a custom HttpClient that trusts the certificate
    final Dio dio = Dio();
    dio.httpClientAdapter =
        IOHttpClientAdapter()
          ..createHttpClient = () {
            final SecurityContext context = SecurityContext.defaultContext;
            context.setTrustedCertificatesBytes(bytes);
            return HttpClient(context: context);
          };

    return dio;
  } catch (e) {
    throw Exception('Failed to create secure Dio client: $e');
  }
}

Future<http.Client> getSecureHttpClient() async {
  try {
    final ByteData data = await rootBundle.load('assets/isrgrootx1.pem');
    final List<int> bytes = data.buffer.asUint8List();

    final SecurityContext context = SecurityContext.defaultContext;
    context.setTrustedCertificatesBytes(bytes);

    final HttpClient httpClient = HttpClient(context: context);
    return IOClient(httpClient);
  } catch (e) {
    throw Exception('Failed to create secure HTTP client: $e');
  }
}
