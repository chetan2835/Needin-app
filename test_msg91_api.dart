import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  final envFile = File('.env');
  final lines = await envFile.readAsLines();
  
  String widgetId = '';
  String tokenAuth = '';
  
  for (final line in lines) {
    if (line.startsWith('MSG91_WIDGET_ID=')) {
      widgetId = line.substring('MSG91_WIDGET_ID='.length).trim();
    }
    if (line.startsWith('MSG91_AUTH_TOKEN=')) {
      tokenAuth = line.substring('MSG91_AUTH_TOKEN='.length).trim();
    }
  }

  print('--- SEND OTP TRACE ---');
  print('WIDGET ID: $widgetId');
  
  final payload = {
    'widgetId': widgetId,
    'tokenAuth': tokenAuth,
    'identifier': '919999999999' // Dummy test number
  };
  
  print('SEND OTP PAYLOAD: $payload');
  
  final sendRes = await http.post(
    Uri.parse('https://control.msg91.com/api/v5/widget/sendOtpMobile'),
    headers: {'Content-Type': 'application/json; charset=UTF-8'},
    body: jsonEncode(payload),
  );
  
  print('SEND OTP RAW RESPONSE BODY: "${sendRes.body}"');
  print('SEND OTP STATUS CODE: ${sendRes.statusCode}');
  
  if (sendRes.body.isEmpty) {
    print('ERROR: MSG91 returned empty body!');
    return;
  }
  
  final responseMap = jsonDecode(sendRes.body);
  final reqId = responseMap['message'] ?? '';
  print('EXTRACTED REQID: $reqId');
  
  print('\n--- VERIFY OTP TRACE ---');
  final verifyPayload = {
    'widgetId': widgetId,
    'tokenAuth': tokenAuth,
    'identifier': '919999999999',
    'reqId': reqId,
    'otp': '123456' // Wrong OTP intentionally just to see the structure
  };
  print('VERIFY OTP PAYLOAD: $verifyPayload');
  
  final verifyRes = await http.post(
    Uri.parse('https://control.msg91.com/api/v5/widget/verifyOtp'),
    headers: {'Content-Type': 'application/json; charset=UTF-8'},
    body: jsonEncode(verifyPayload),
  );
  
  print('VERIFY OTP RAW RESPONSE: ${verifyRes.body}');
}
