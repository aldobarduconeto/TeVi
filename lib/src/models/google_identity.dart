/// Claims from a cryptographically verified Google ID token.
class GoogleIdentity {
  const GoogleIdentity({
    required this.subject,
    required this.email,
    required this.name,
  });
  final String subject, email, name;
}
