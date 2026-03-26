class ShoppingItem {
  final String id;
  final String name;
  final String category;
  final double estimatedPrice;
  final double? actualPrice;
  final bool isBought;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted; // soft delete for sync

  ShoppingItem({
    required this.id,
    required this.name,
    required this.category,
    required this.estimatedPrice,
    this.actualPrice,
    this.isBought = false,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isDeleted = false,
  })  : createdAt = createdAt ?? DateTime.now().toUtc(),
        updatedAt = updatedAt ?? DateTime.now().toUtc();

  ShoppingItem copyWith({
    String? name,
    String? category,
    double? estimatedPrice,
    double? actualPrice,
    bool clearActualPrice = false,
    bool? isBought,
    String? notes,
    bool? isDeleted,
    DateTime? updatedAt,
  }) {
    return ShoppingItem(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      estimatedPrice: estimatedPrice ?? this.estimatedPrice,
      actualPrice: clearActualPrice ? null : (actualPrice ?? this.actualPrice),
      isBought: isBought ?? this.isBought,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'estimated_price': estimatedPrice,
      'actual_price': actualPrice,
      'is_bought': isBought ? 1 : 0,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  // For Supabase (uses bool not int, no is_bought int)
  Map<String, dynamic> toSupabaseMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'estimated_price': estimatedPrice,
      'actual_price': actualPrice,
      'is_bought': isBought,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_deleted': isDeleted,
    };
  }

  factory ShoppingItem.fromMap(Map<String, dynamic> map) {
    return ShoppingItem(
      id: map['id'] as String,
      name: map['name'] as String,
      category: map['category'] as String,
      estimatedPrice: (map['estimated_price'] as num).toDouble(),
      actualPrice: map['actual_price'] != null
          ? (map['actual_price'] as num).toDouble()
          : null,
      isBought: map['is_bought'] == true || map['is_bought'] == 1,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String).toUtc(),
      updatedAt: DateTime.parse(map['updated_at'] as String).toUtc(),
      isDeleted: map['is_deleted'] == true || map['is_deleted'] == 1,
    );
  }

  @override
  String toString() => 'ShoppingItem(id: $id, name: $name)';
}

const List<String> kCategories = [
  'Home',
  'Kitchen',
  'Sitting Room',
  'Bedroom',
  'Bathroom',
  'Clothing',
  'Electronics',
  'Food & Grocery',
  'Health',
  'Garden',
  'Other',
];

const Map<String, String> kCategoryIcons = {
  'Home': '🏠',
  'Kitchen': '🍳',
  'Sitting Room': '🛋️',
  'Bedroom': '🛏️',
  'Bathroom': '🚿',
  'Clothing': '👕',
  'Electronics': '💻',
  'Food & Grocery': '🛒',
  'Health': '💊',
  'Garden': '🌿',
  'Other': '📦',
};