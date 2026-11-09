/// Claims from a cryptographically verified Apple ID token.
class AppleIdentity {
  const AppleIdentity({
    required this.subject,
    required this.email,
    required this.name,
  });
  final String subject, email, name;
}
