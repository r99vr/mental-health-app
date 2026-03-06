class User {
  final int? userID;
  final String name;
  final String email;
  final String password;

  User({
    this.userID,
    required this.name,
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toMap() {
    return {
      'userID': userID,
      'name': name,
      'email': email,
      'password': password,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      userID: map['userID'],
      name: map['name'],
      email: map['email'],
      password: map['password'],
    );
  }
}
