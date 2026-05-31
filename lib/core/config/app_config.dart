class AppConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.100.192:8000/api',
  );

  static const bool isMidtransProduction = bool.fromEnvironment(
    'MIDTRANS_PRODUCTION',
    defaultValue: false,
  );

  static const String configuredPaymentReturnUrl = String.fromEnvironment(
    'PAYMENT_RETURN_URL',
    defaultValue: 'findus://subscription/payment-finish',
  );

  static String get paymentReturnUrl {
    if (configuredPaymentReturnUrl.isNotEmpty) {
      return configuredPaymentReturnUrl;
    }

    final currentUrl = Uri.base;
    if (currentUrl.hasScheme &&
        (currentUrl.scheme == 'http' || currentUrl.scheme == 'https')) {
      final queryParameters = Map<String, String>.from(
        currentUrl.queryParameters,
      );
      queryParameters['payment'] = 'return';

      return currentUrl.replace(queryParameters: queryParameters).toString();
    }

    return '';
  }

  static String get paymentNotificationUrl {
    final normalizedBaseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), '');
    return '$normalizedBaseUrl/midtrans/notification';
  }

  static String get midtransSnapBaseUrl {
    if (isMidtransProduction) {
      return 'https://app.midtrans.com/snap/v2/vtweb';
    }

    return 'https://app.sandbox.midtrans.com/snap/v2/vtweb';
  }
}
