# frozen_string_literal: true

# Security Headers Configuration
#
# Implements OWASP recommended security headers to protect against common attacks
#
# Headers Implemented:
# 1. X-Frame-Options: Prevents clickjacking attacks
# 2. X-Content-Type-Options: Prevents MIME-type sniffing
# 3. X-XSS-Protection: Legacy XSS protection (browser-level)
# 4. Referrer-Policy: Controls referrer information leakage
# 5. Permissions-Policy: Controls browser feature access
# 6. Strict-Transport-Security (HSTS): Enforces HTTPS (production only)
#
# OWASP References:
# - https://owasp.org/www-project-secure-headers/
# - https://cheatsheetseries.owasp.org/cheatsheets/HTTP_Headers_Cheat_Sheet.html

Rails.application.config.action_dispatch.default_headers = {
  # X-Frame-Options: SAMEORIGIN
  # Prevents clickjacking by only allowing framing from same origin
  # Options: DENY (no framing), SAMEORIGIN (same origin only), ALLOW-FROM uri
  # OWASP Rating: Essential
  'X-Frame-Options' => 'SAMEORIGIN',

  # X-Content-Type-Options: nosniff
  # Prevents browsers from MIME-type sniffing (interpreting files as different type)
  # Protects against attacks where attacker uploads image.jpg containing JavaScript
  # OWASP Rating: Essential
  'X-Content-Type-Options' => 'nosniff',

  # X-XSS-Protection: 1; mode=block
  # Legacy XSS filter (browser-level protection)
  # Note: Modern browsers rely on CSP; this is for older browsers
  # mode=block: Blocks page rendering if XSS detected
  # OWASP Rating: Recommended (legacy support)
  'X-XSS-Protection' => '1; mode=block',

  # Referrer-Policy: strict-origin-when-cross-origin
  # Controls how much referrer information is sent with requests
  # - same-origin: Full URL for same origin, no referrer for cross-origin
  # - strict-origin-when-cross-origin: Full URL for same origin, origin only for cross-origin HTTPS
  # OWASP Rating: Recommended
  'Referrer-Policy' => 'strict-origin-when-cross-origin',

  # Permissions-Policy (formerly Feature-Policy)
  # Controls which browser features and APIs can be used
  # Denying unnecessary features reduces attack surface
  # OWASP Rating: Recommended
  'Permissions-Policy' => 'geolocation=(), microphone=(), camera=()'
}

# Strict-Transport-Security (HSTS)
# Forces browsers to use HTTPS for all future requests
# Only enable in production with valid SSL certificate
# max-age: Duration in seconds (31536000 = 1 year)
# includeSubDomains: Apply to all subdomains
# OWASP Rating: Critical for production
if Rails.env.production?
  Rails.application.config.action_dispatch.default_headers['Strict-Transport-Security'] =
    'max-age=31536000; includeSubDomains'
end

# Security Headers Notes:
#
# 1. X-Frame-Options (Clickjacking Protection):
#    - SAMEORIGIN allows embedding in same-origin iframes (e.g., admin dashboards)
#    - Use DENY for maximum protection if no iframes needed
#    - Modern alternative: CSP frame-ancestors directive
#
# 2. X-Content-Type-Options (MIME Sniffing Protection):
#    - Prevents browser from interpreting files as different MIME type
#    - Critical for preventing attacks via uploaded files
#    - Example: Uploading HTML file disguised as image
#
# 3. X-XSS-Protection (Legacy XSS Protection):
#    - Browser-level XSS filter (deprecated in modern browsers)
#    - Modern protection: Content Security Policy (CSP)
#    - Keep for older browser support
#    - mode=block: Stops page rendering instead of sanitizing
#
# 4. Referrer-Policy (Information Leakage Prevention):
#    - Prevents leaking sensitive URLs to third parties
#    - strict-origin-when-cross-origin: Balances privacy and functionality
#    - Alternatives: no-referrer (maximum privacy), same-origin
#
# 5. Permissions-Policy (Feature Control):
#    - Denies access to sensitive browser APIs
#    - Reduces attack surface
#    - Add more policies as needed: payment=(), usb=(), etc.
#
# 6. Strict-Transport-Security / HSTS (HTTPS Enforcement):
#    - Forces HTTPS for all requests after first visit
#    - Prevents downgrade attacks and cookie hijacking
#    - Production only (requires valid SSL certificate)
#    - max-age: Start with short duration, increase gradually
#    - includeSubDomains: Ensure all subdomains support HTTPS
#    - preload: Submit to HSTS preload list (optional, permanent)
#
# 7. Content-Security-Policy (CSP):
#    - Configured separately in content_security_policy.rb
#    - Most powerful security header for XSS prevention
#    - Requires careful configuration
#
# Production Checklist:
# ✅ X-Frame-Options: SAMEORIGIN or DENY
# ✅ X-Content-Type-Options: nosniff
# ✅ X-XSS-Protection: 1; mode=block
# ✅ Referrer-Policy: strict-origin-when-cross-origin
# ✅ Permissions-Policy: Deny unnecessary features
# ✅ Strict-Transport-Security: max-age=31536000; includeSubDomains
# ⚠️  Content-Security-Policy: Configure in content_security_policy.rb
#
# Testing:
# - SecurityHeaders.com: Scan headers
# - Observatory by Mozilla: Security analysis
# - curl -I https://yourapp.com: Verify headers
#
# Compliance:
# - OWASP Secure Headers Project: Compliant
# - PCI DSS: Meets requirements
# - GDPR: Privacy-focused referrer policy
