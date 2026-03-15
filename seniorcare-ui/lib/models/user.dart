class User {
  final String id;
  final String role; // 'parent' or 'child'
  final String name;
  final String phone;
  final String? email;

  const User({
    required this.id,
    required this.role,
    required this.name,
    required this.phone,
    this.email,
  });
}
