import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';

Future<void> uploadToS3({
  required File file,
  required String accessKey,
  required String secretKey,
  required String bucket,
  required String region,
  required String objectKey, // e.g. 'uploads/myImage.jpg'
}) async {
  final host = '$bucket.s3.$region.amazonaws.com';
  final url = Uri.https(host, objectKey);
  final payload = await file.readAsBytes();
  final date = DateTime.now().toUtc();
  final isoDate = date.toIso8601String().replaceAll('-', '').replaceAll(':', '').split('.').first + 'Z';
  final dateStamp = isoDate.substring(0, 8);

  // --- Create AWS signature (V4 signing) ---
  final credentialScope = '$dateStamp/$region/s3/aws4_request';
  final canonicalHeaders = 'host:$host\nx-amz-content-sha256:UNSIGNED-PAYLOAD\nx-amz-date:$isoDate\n';
  final signedHeaders = 'host;x-amz-content-sha256;x-amz-date';
  final canonicalRequest = 'PUT\n/$objectKey\n\n$canonicalHeaders\n$signedHeaders\nUNSIGNED-PAYLOAD';
  final stringToSign = 'AWS4-HMAC-SHA256\n$isoDate\n$credentialScope\n${sha256.convert(utf8.encode(canonicalRequest)).toString()}';

  // Derive signing key
  List<int> sign(List<int> key, String msg) => Hmac(sha256, key).convert(utf8.encode(msg)).bytes;
  final kDate = sign(utf8.encode('AWS4$secretKey'), dateStamp);
  final kRegion = sign(kDate, region);
  final kService = sign(kRegion, 's3');
  final kSigning = sign(kService, 'aws4_request');
  final signature = Hmac(sha256, kSigning).convert(utf8.encode(stringToSign)).toString();

  final authorization =
      'AWS4-HMAC-SHA256 Credential=$accessKey/$credentialScope, SignedHeaders=$signedHeaders, Signature=$signature';

  // --- Send the file ---
  final response = await http.put(
    url,
    headers: {
      'x-amz-date': isoDate,
      'x-amz-content-sha256': 'UNSIGNED-PAYLOAD',
      'Authorization': authorization,
      'Content-Type': 'image/jpeg',
    },
    body: payload,
  );

  if (response.statusCode == 200) {
    print('✅ Upload successful: $url');
  } else {
    print('❌ Upload failed: ${response.statusCode} ${response.body}');
  }
}
