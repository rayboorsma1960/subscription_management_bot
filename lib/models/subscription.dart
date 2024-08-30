class Subscription {
  final String id;
  final String name;
  final double price;
  final DateTime billingDate;

  Subscription({
    required this.id,
    required this.name,
    required this.price,
    required this.billingDate,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id'],
      name: json['name'],
      price: json['price'],
      billingDate: DateTime.parse(json['billingDate']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'billingDate': billingDate.toIso8601String(),
    };
  }
}