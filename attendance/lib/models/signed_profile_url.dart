import 'dart:convert';

/// Expiry is advisory for refreshing a download, never proof of authorization.
class SignedProfileUrl {
  const SignedProfileUrl(this.url, this.expiresAt);
  final String url;
  final DateTime? expiresAt;

  factory SignedProfileUrl.fromUrl(String url) {
    try {
      final token = Uri.tryParse(url)?.queryParameters['token'];
      final parts = token?.split('.');
      if (parts != null && parts.length == 3) {
        final value = jsonDecode(
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
        );
        if (value case {
          'exp': final num expiry,
        } when expiry.isFinite && expiry > 0 && expiry < 253402300800) {
          return SignedProfileUrl(
            url,
            DateTime.fromMillisecondsSinceEpoch(
              (expiry * 1000).round(),
              isUtc: true,
            ),
          );
        }
      }
    } on FormatException {
      // An opaque/malformed token is refreshed rather than trusted indefinitely.
    }
    return SignedProfileUrl(url, null);
  }

  bool needsRefresh(DateTime now) =>
      isSigned(url) &&
      (expiresAt == null ||
          !expiresAt!.isAfter(now.add(const Duration(seconds: 10))));

  static bool isSigned(String url) =>
      Uri.tryParse(
        url,
      )?.path.startsWith('/storage/v1/object/sign/profile-media/') ??
      false;
}
