# Authentication Security Documentation

## Overview

This document outlines the security measures implemented in Potlift8's authentication system to protect against common authentication vulnerabilities.

**Last Updated:** 2025-11-17
**Security Standard:** OWASP Top 10 2021 Compliant
**Authentication Method:** OAuth2 with Authlift8

---

## Security Vulnerabilities Addressed

### 1. Session Fixation (OWASP A07:2021 - Identification and Authentication Failures)

**Vulnerability:** Attacker sets victim's session ID before authentication, then hijacks the session after victim logs in.

**Mitigation Implemented:**
- Session ID is regenerated after successful authentication
- Located in: `SessionsController#create` (line 130-136)
- OWASP Recommendation: Always regenerate session ID on privilege level changes

**Code Example:**
```ruby
# CRITICAL SECURITY FIX: Regenerate session ID after authentication
old_session_data = session.to_hash
reset_session
old_session_data.each { |k, v| session[k] = v unless k.start_with?('oauth_') }
```

**Testing:**
- Manual test: Verify session cookie changes after login
- Automated test: `spec/security/authentication_security_spec.rb`

---

### 2. Broken Authentication State (OWASP A07:2021)

**Vulnerability:** User or company deleted from database, but session remains valid, leading to broken application state (e.g., navbar not showing, errors on every request).

**Mitigation Implemented:**

#### User Record Validation
- `ApplicationController#current_user` validates user exists in database
- If user missing, session is cleared and user must re-authenticate
- Located in: `ApplicationController#current_user` (line 116-122)

**Code Example:**
```ruby
@current_user ||= User.find_by(id: session[:user_id])

# SECURITY FIX: If user doesn't exist, clear session and force re-authentication
if @current_user.nil? && session[:user_id].present?
  Rails.logger.warn("User #{session[:user_id]} not found in database, clearing session")
  reset_session
  return nil
end
```

#### Company Record Validation
- `ApplicationController#current_potlift_company` validates company exists
- If company missing, session is cleared and user must re-authenticate
- Located in: `ApplicationController#current_potlift_company` (line 193-199)

**Benefits:**
- Prevents broken UI state (missing navbar, errors)
- Forces re-authentication when database inconsistencies detected
- Logs warnings for debugging

**Testing:**
- Manual test: Delete user/company from console, access protected page
- Expected: Redirect to login, session cleared
- Automated test: `spec/security/authentication_security_spec.rb`

---

### 3. Session Hijacking (OWASP A07:2021)

**Vulnerability:** Attacker intercepts or steals session cookie to impersonate victim.

**Mitigation Implemented:**

#### Secure Session Cookies
- **HttpOnly flag:** Prevents JavaScript access (XSS protection)
- **Secure flag:** HTTPS-only transmission (production)
- **SameSite: Lax:** Prevents CSRF attacks
- **24-hour expiration:** Limits hijacking window
- Located in: `config/initializers/session_store.rb`

**Code Example:**
```ruby
Rails.application.config.session_store :cookie_store,
  key: '_potlift8_session',
  httponly: true,                # XSS protection
  secure: Rails.env.production?, # HTTPS only
  same_site: :lax,               # CSRF protection
  expire_after: 24.hours         # Auto-expiration
```

#### Session Timeout
- 24-hour inactivity timeout enforced in `ApplicationController#authenticated?`
- Located in: `ApplicationController#authenticated?` (line 54-59)

**Code Example:**
```ruby
authenticated_at = session[:authenticated_at]
if authenticated_at.nil? || Time.now.to_i - authenticated_at > 86400
  Rails.logger.info("Session timeout for user: #{session[:user_id]}")
  reset_session
  return false
end
```

**Testing:**
- Manual test: Wait 24 hours or manipulate session timestamp
- Expected: Session cleared, redirect to login

---

### 4. Missing Security Headers (OWASP A05:2021 - Security Misconfiguration)

**Vulnerability:** Missing HTTP security headers allow various attacks (clickjacking, XSS, MIME sniffing, etc.)

**Mitigation Implemented:**

All security headers configured in: `config/initializers/security_headers.rb`

#### X-Frame-Options: SAMEORIGIN
- **Protects against:** Clickjacking attacks
- **Value:** `SAMEORIGIN`
- **Purpose:** Prevents embedding in cross-origin iframes

#### X-Content-Type-Options: nosniff
- **Protects against:** MIME-type sniffing attacks
- **Value:** `nosniff`
- **Purpose:** Prevents browser from interpreting files as different type

#### X-XSS-Protection: 1; mode=block
- **Protects against:** Cross-Site Scripting (legacy browser support)
- **Value:** `1; mode=block`
- **Purpose:** Browser-level XSS filter (blocks page if XSS detected)

#### Referrer-Policy: strict-origin-when-cross-origin
- **Protects against:** Information leakage
- **Value:** `strict-origin-when-cross-origin`
- **Purpose:** Controls referrer information sent to third parties

#### Permissions-Policy
- **Protects against:** Unauthorized browser feature access
- **Value:** `geolocation=(), microphone=(), camera=()`
- **Purpose:** Denies access to sensitive browser APIs

#### Strict-Transport-Security (HSTS) - Production Only
- **Protects against:** Downgrade attacks, cookie hijacking
- **Value:** `max-age=31536000; includeSubDomains`
- **Purpose:** Forces HTTPS for all requests (1 year)

**Testing:**
```bash
curl -I https://yourapp.com
# or
# Visit https://securityheaders.com/
```

**Expected Headers:**
```
X-Frame-Options: SAMEORIGIN
X-Content-Type-Options: nosniff
X-XSS-Protection: 1; mode=block
Referrer-Policy: strict-origin-when-cross-origin
Permissions-Policy: geolocation=(), microphone=(), camera=()
Strict-Transport-Security: max-age=31536000; includeSubDomains
```

---

## Authentication Flow

### 1. Login Initiation (`GET /auth/login`)
```
User → Potlift8 → Authlift8
1. Clear any existing session
2. Generate cryptographically secure state token (64 bytes)
3. Store state in session with timestamp
4. Redirect to Authlift8 authorization URL
```

**Security:**
- State token prevents CSRF
- Minimum 32-byte state token (OWASP recommendation)
- 5-minute state timeout

---

### 2. OAuth Callback (`GET /auth/callback`)
```
Authlift8 → Potlift8 → User
1. Validate state token matches session
2. Validate state not expired (< 5 minutes)
3. Exchange authorization code for tokens
4. Validate JWT signature with Authlift8 public key
5. Find or create User record
6. REGENERATE SESSION ID (session fixation protection)
7. Store authentication data
8. Clear OAuth state
9. Redirect to intended destination
```

**Security:**
- State validation prevents CSRF
- JWT signature validation prevents token forgery
- Session regeneration prevents session fixation
- Minimal session data storage
- Secure token storage

---

### 3. Authentication Check (`ApplicationController#authenticated?`)
```
Every Protected Request
1. Check session has user_id and access_token
2. Check session not expired (< 24 hours)
3. Validate JWT token with Authlift8
4. Refresh token if expired but refresh token valid
5. Return true if valid, false if invalid
```

**Security:**
- Multi-layer validation
- Automatic token refresh
- Session timeout enforcement
- JWT revocation support

---

### 4. Current User/Company Retrieval
```
ApplicationController#current_user / current_potlift_company
1. Check authenticated?
2. Query database for User/Company
3. If record missing, clear session and return nil
4. Return memoized record
```

**Security:**
- Database validation prevents broken state
- Session clearing forces re-authentication
- Logging for debugging

---

## Security Testing

### Automated Tests

Run security tests:
```bash
bin/test spec/security/authentication_security_spec.rb
```

**Tests Include:**
- Session fixation protection
- Broken authentication state handling
- Authentication enforcement
- Security headers verification
- Session timeout validation

### Manual Testing

#### Test 1: Broken Authentication State
```bash
# Start Rails console
bin/rails console

# Authenticate in browser, then delete user
User.last.destroy

# Refresh page in browser
# Expected: Redirect to login, session cleared
```

#### Test 2: Session Fixation
```bash
# 1. Get session cookie before login
# 2. Login
# 3. Compare session cookies
# Expected: Session cookie changed
```

#### Test 3: Session Timeout
```bash
# In Rails console
session[:authenticated_at] = 25.hours.ago.to_i

# Refresh page in browser
# Expected: Redirect to login
```

#### Test 4: Security Headers
```bash
curl -I http://localhost:3246/

# Expected headers:
# X-Frame-Options: SAMEORIGIN
# X-Content-Type-Options: nosniff
# X-XSS-Protection: 1; mode=block
# Referrer-Policy: strict-origin-when-cross-origin
# Permissions-Policy: geolocation=(), microphone=(), camera=()
```

---

## Deployment Checklist

### Development Environment
- ✅ Session cookies: httponly=true, same_site=lax
- ✅ Session timeout: 24 hours
- ✅ Security headers configured
- ✅ Authentication enforcement enabled
- ⚠️ Secure cookies: false (no HTTPS)
- ⚠️ HSTS: disabled (no HTTPS)

### Production Environment
- ✅ Session cookies: httponly=true, secure=true, same_site=lax
- ✅ Session timeout: 24 hours
- ✅ Security headers configured
- ✅ Authentication enforcement enabled
- ✅ Secure cookies: true (HTTPS only)
- ✅ HSTS: enabled (max-age=1 year)
- ⚠️ SSL certificate: Required
- ⚠️ HTTPS: Required

---

## Incident Response

### User Reports: "I can't see the navbar"

**Diagnosis:**
- Broken authentication state (user/company deleted)
- Session exists but database record missing

**Solution:**
1. Check Rails logs for warnings:
   ```
   User #{id} not found in database, clearing session
   Company #{id} not found in database, clearing session
   ```
2. Verify user/company exists in database
3. Clear all sessions if widespread issue:
   ```bash
   bin/rails runner "Rails.cache.clear"
   # or for database sessions:
   bin/rails runner "ActiveRecord::SessionStore::Session.delete_all"
   ```
4. User must re-authenticate

**Prevention:**
- ✅ Implemented in this PR
- Automatic session clearing on missing records
- Graceful re-authentication flow

---

### User Reports: "Session keeps expiring"

**Diagnosis:**
- 24-hour session timeout
- JWT token expired and refresh failed

**Solution:**
1. Check JWT token expiration in Authlift8
2. Check refresh token validity
3. Verify Authlift8 connectivity
4. Review logs for refresh errors

**Prevention:**
- Automatic token refresh (< 5 min expiry)
- Clear error messages
- Logging for debugging

---

## Security Monitoring

### Key Metrics to Monitor

1. **Session Invalidations**
   - Log: `Session timeout for user: {id}`
   - Alert if spike in invalidations

2. **Missing User/Company Records**
   - Log: `User {id} not found in database, clearing session`
   - Log: `Company {id} not found in database, clearing session`
   - Alert if frequent occurrences

3. **Token Refresh Failures**
   - Log: `Token refresh failed: {error}`
   - Alert if high failure rate

4. **OAuth Errors**
   - Log: `OAuth error: {error} - {description}`
   - Alert if unusual patterns

### Recommended Monitoring Tools
- Application Performance Monitoring (APM): New Relic, DataDog
- Log Aggregation: Papertrail, Loggly
- Security Scanning: Brakeman, OWASP ZAP
- Header Validation: SecurityHeaders.com

---

## References

### OWASP Resources
- [OWASP Top 10 2021](https://owasp.org/www-project-top-ten/)
- [OWASP Session Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html)
- [OWASP Authentication Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html)
- [OWASP Secure Headers Project](https://owasp.org/www-project-secure-headers/)

### Implementation Files
- `app/controllers/application_controller.rb` - Authentication logic
- `app/controllers/sessions_controller.rb` - OAuth flow
- `config/initializers/session_store.rb` - Session configuration
- `config/initializers/security_headers.rb` - Security headers
- `spec/security/authentication_security_spec.rb` - Security tests

### Security Standards
- OWASP Top 10 2021: Compliant
- PCI DSS: Session security requirements met
- GDPR: Privacy-focused referrer policy

---

## Version History

**v1.0 - 2025-11-17**
- Initial implementation
- Session fixation protection
- Broken authentication state handling
- Security headers configuration
- Comprehensive testing suite

---

## Contact

For security issues or questions:
- Create GitHub issue (non-sensitive)
- Email security team (sensitive issues)
- Review SECURITY.md for vulnerability reporting

---

## Future Enhancements

**Potential Improvements:**
1. Implement rate limiting for login attempts
2. Add multi-factor authentication (MFA) support
3. Implement device fingerprinting
4. Add anomaly detection for session hijacking
5. Implement IP address validation
6. Add geolocation-based access controls
7. Implement passwordless authentication option
8. Add session activity logging
9. Implement concurrent session management
10. Add security event notifications

**Priority:** Medium
**Timeline:** Future releases
