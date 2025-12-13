class QuotationModel {
  final int id;
  final int price;
  final String validTill;
  final String message;
  final List<String> services;

  QuotationModel({
    required this.id,
    required this.price,
    required this.validTill,
    required this.message,
    required this.services,
  });

  factory QuotationModel.fromJson(Map<String, dynamic> json) {
    return QuotationModel(
      id: json['id'],
      price: json['quote']['price'],
      validTill: json['quote']['validTill'],
      message: json['quote']['message'],
      services: List<String>.from(json['quote']['servicesIncluded']),
    );
  }
}
