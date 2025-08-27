# Security Policy

## Supported Versions

We actively support the following versions of RealtimeKit with security updates:

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

If you discover a security vulnerability in RealtimeKit, please report it responsibly:

### How to Report

1. **Email**: Send details to security@yourcompany.com
2. **Subject**: Include "RealtimeKit Security" in the subject line
3. **Details**: Provide a detailed description of the vulnerability
4. **Impact**: Describe the potential impact and affected components

### What to Include

- Description of the vulnerability
- Steps to reproduce the issue
- Potential impact assessment
- Suggested fix (if available)
- Your contact information

### Response Timeline

- **Initial Response**: Within 24 hours
- **Assessment**: Within 72 hours
- **Fix Development**: Within 7-14 days (depending on severity)
- **Public Disclosure**: After fix is released and users have time to update

## Security Best Practices

### For Developers Using RealtimeKit

1. **Keep Updated**: Always use the latest version
2. **Secure Storage**: Use @SecureRealtimeStorage for sensitive data
3. **Token Management**: Implement proper token rotation
4. **Input Validation**: Validate all user inputs
5. **Network Security**: Use HTTPS/WSS for all communications

### For Contributors

1. **Code Review**: All code must be reviewed before merging
2. **Dependency Scanning**: Regular dependency vulnerability scans
3. **Static Analysis**: Use static analysis tools
4. **Testing**: Include security-focused tests

## Security Features

RealtimeKit includes several built-in security features:

- **Secure Storage**: Keychain integration for sensitive data
- **Token Management**: Automatic token renewal and validation
- **Input Sanitization**: Built-in input validation and sanitization
- **Network Security**: Encrypted communications
- **Permission Management**: Role-based access control

## Known Security Considerations

1. **Third-Party SDKs**: Security depends on underlying provider SDKs
2. **Network Communications**: Ensure secure network configurations
3. **Data Storage**: Sensitive data should use secure storage options
4. **Authentication**: Implement proper authentication mechanisms

## Contact

For security-related questions or concerns:
- Email: security@yourcompany.com
- Website: https://github.com/your-org/RealtimeKit/security