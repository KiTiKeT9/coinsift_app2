// models/bank_models.dart

class ConnectedBankInfo {
  final String bankId;
  final String bankName;
  final DateTime connectedAt;

  ConnectedBankInfo({
    required this.bankId,
    required this.bankName,
    required this.connectedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'bankId': bankId,
      'bankName': bankName,
      'connectedAt': connectedAt.toIso8601String(),
    };
  }

  factory ConnectedBankInfo.fromJson(Map<String, dynamic> json) {
    return ConnectedBankInfo(
      bankId: json['bankId'],
      bankName: json['bankName'],
      connectedAt: DateTime.parse(json['connectedAt']),
    );
  }
}