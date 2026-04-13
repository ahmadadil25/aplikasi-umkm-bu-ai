class TransactionModel {
  final int? id;
  final String type; // 'sale' atau 'expense'
  final int amount;
  final String createdAt;

  TransactionModel({
    this.id,
    required this.type,
    required this.amount,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'amount': amount,
      'created_at': createdAt,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'],
      type: map['type'],
      amount: map['amount'],
      createdAt: map['created_at'],
    );
  }
}