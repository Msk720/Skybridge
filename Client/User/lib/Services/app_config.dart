import 'package:flutter/foundation.dart' show kIsWeb;

const String cloudinarycloudname = 'daajwglxs';
const String cloudinaryuploadpreset = 'SkyBridge';

const String _apiBaseUrlFromEnv = String.fromEnvironment('API_BASE_URL');

const String _localWebBackend = 'http://localhost:5000/api';

const String _mobileWifiBackend = 'http://10.102.164.216:5000/api';


// const String _mobileWifiBackend = 'http://10.41.146.216:5000/api';


String getFunctionsBase() {
  if (_apiBaseUrlFromEnv.isNotEmpty) {
    return _apiBaseUrlFromEnv;
  }

  if (kIsWeb) {
    return _localWebBackend;
  }

  return _mobileWifiBackend;
}
