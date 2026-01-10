# frozen_string_literal: true

# Secure session store configuration for Rails 8
#
# Security Features:
# - HttpOnly cookies to prevent XSS attacks
# - Secure flag in production (HTTPS only)
# - SameSite Lax to prevent CSRF attacks
# - 24-hour session timeout
# - Encrypted session store
#
# Session Security Best Practices:
# 1. Always use encrypted session store (Rails default)
# 2. Use HttpOnly to prevent JavaScript access
# 3. Use Secure flag in production
# 4. Use SameSite to prevent CSRF
# 5. Set reasonable session timeout
# 6. Regenerate session ID on authentication
# 7. Clear session on logout

Rails.application.config.session_store :cookie_store,
  key: "_potlift8_session",
  # HttpOnly prevents JavaScript access to session cookie (XSS protection)
  httponly: true,
  # Secure flag ensures cookie only sent over HTTPS (production)
  # In development/test, HTTPS may not be available
  secure: Rails.env.production?,
  # SameSite Lax prevents CSRF attacks while allowing navigation
  # - Strict: Never sent on cross-site requests (breaks OAuth callbacks)
  # - Lax: Sent on top-level navigation (safe for OAuth)
  # - None: Sent on all requests (requires Secure flag)
  same_site: :lax,
  # Session expires after 24 hours of inactivity
  expire_after: 24.hours

# Session Security Notes:
#
# 1. HttpOnly Flag (XSS Protection):
#    - Prevents JavaScript from accessing session cookie
#    - Mitigates XSS attacks that attempt to steal session tokens
#    - OWASP recommendation: Always enable for authentication cookies
#
# 2. Secure Flag (HTTPS Protection):
#    - Ensures cookie only transmitted over encrypted HTTPS connections
#    - Prevents session hijacking via network sniffing
#    - Required in production; optional in development
#    - OWASP recommendation: Always enable in production
#
# 3. SameSite Attribute (CSRF Protection):
#    - Lax: Allows cookie on top-level navigation (GET requests from external sites)
#    - Prevents most CSRF attacks while allowing OAuth callbacks
#    - Modern browsers default to Lax if not specified
#    - OWASP recommendation: Use Lax for session cookies with authentication
#
# 4. Session Timeout:
#    - 24-hour expiration balances security and user experience
#    - Reduces window for session hijacking attacks
#    - Application enforces additional timeout in ApplicationController
#    - Consider shorter timeout for high-security applications
#
# 5. Session Content Security:
#    - Store minimal data in session (user_id, email, company_id)
#    - Never store sensitive data (passwords, credit cards)
#    - Session is encrypted by Rails with secret_key_base
#    - Rotate secret_key_base regularly
#
# 6. Production Considerations:
#    - Use environment variable for session key: ENV['SESSION_KEY']
#    - Enable secure: true (enforced above)
#    - Monitor session size (max 4KB for cookies)
#    - Consider Redis/database session store for larger sessions
#    - Implement session versioning for forced logout
#
# 7. Compliance:
#    - OWASP Session Management Cheat Sheet compliant
#    - GDPR: Session cookies are functional, not tracking
#    - PCI DSS: Secure session handling for payment data
#
# Additional Security Headers (configured in production.rb):
# - Strict-Transport-Security (HSTS)
# - X-Frame-Options: DENY
# - X-Content-Type-Options: nosniff
# - X-XSS-Protection: 1; mode=block
# - Content-Security-Policy

# For production with Redis session store (recommended for scalability):
#
# Rails.application.config.session_store :redis_store,
#   servers: ENV['REDIS_URL'],
#   key: '_potlift8_session',
#   httponly: true,
#   secure: true,
#   same_site: :lax,
#   expire_after: 24.hours,
#   redis: {
#     db: 2,
#     key_prefix: 'potlift8:session:',
#     ttl: 86400 # 24 hours in seconds
#   }
