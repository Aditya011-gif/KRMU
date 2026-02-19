/// Land details registration model.
class LandDetailsModel {
  final String? id;
  final String userId;
  final double latitude;
  final double longitude;
  final double? landArea;
  final String areaUnit;
  final String? cropType;
  final String? cropQualityGrade;
  final String? currentSeason;
  final double? pastLoanAmount;
  final String? loanProvider;
  final String? loanStatus;
  final List<String>? loanDocuments;
  final List<String>? ownershipDocuments;
  final DateTime? createdAt;

  LandDetailsModel({
    this.id,
    required this.userId,
    required this.latitude,
    required this.longitude,
    this.landArea,
    this.areaUnit = 'Acres',
    this.cropType,
    this.cropQualityGrade,
    this.currentSeason,
    this.pastLoanAmount,
    this.loanProvider,
    this.loanStatus,
    this.loanDocuments,
    this.ownershipDocuments,
    this.createdAt,
  });

  factory LandDetailsModel.fromJson(Map<String, dynamic> json) {
    return LandDetailsModel(
      id: json['id'],
      userId: json['user_id'] ?? '',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      landArea: json['land_area']?.toDouble(),
      areaUnit: json['area_unit'] ?? 'Acres',
      cropType: json['crop_type'],
      cropQualityGrade: json['crop_quality_grade'],
      currentSeason: json['current_season'],
      pastLoanAmount: json['past_loan_amount']?.toDouble(),
      loanProvider: json['loan_provider'],
      loanStatus: json['loan_status'],
      loanDocuments: (json['loan_documents'] as List?)
          ?.map((e) => e as String)
          .toList(),
      ownershipDocuments: (json['ownership_documents'] as List?)
          ?.map((e) => e as String)
          .toList(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toInsertJson() => {
    'user_id': userId,
    'latitude': latitude,
    'longitude': longitude,
    'land_area': landArea,
    'area_unit': areaUnit,
    'crop_type': cropType,
    'crop_quality_grade': cropQualityGrade,
    'current_season': currentSeason,
    'past_loan_amount': pastLoanAmount,
    'loan_provider': loanProvider,
    'loan_status': loanStatus,
    'loan_documents': loanDocuments,
    'ownership_documents': ownershipDocuments,
  };
}
