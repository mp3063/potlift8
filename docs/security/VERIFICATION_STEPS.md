# Security Fixes Verification Steps

## Quick Verification Guide

This guide helps verify that the authentication security fixes are working correctly.

**Date:** 2025-11-17
**Issue:** Broken authentication state causing navbar to disappear

---

## Step 1: Clear All Sessions

First, clear any existing broken sessions:

```bash
# Start Rails console
bin/rails console

# Clear all sessions (if using cookie store, this clears cache)
Rails.cache.clear

# If using database sessions:
# ActiveRecord::SessionStore::Session.delete_all

# Exit console
exit
```

---

## Step 2: Restart the Server

```bash
# Stop the server (Ctrl+C)
# Then restart
bin/dev
```

---

## Step 3: Test Authentication Flow

### Test 3.1: Unauthenticated Access
```bash
# In a new terminal
curl -I http://localhost:3246/products

# Expected output:
# HTTP/1.1 302 Found
# Location: http://localhost:3246/auth/login
```

**Browser Test:**
1. Open browser in incognito/private mode
2. Navigate to http://localhost:3246/products
3. Expected: Redirect to http://localhost:3246/auth/login
4. Expected: Flash message "Please sign in to continue."

### Test 3.2: Security Headers
```bash
curl -I http://localhost:3246/

# Expected headers in output:
# X-Frame-Options: SAMEORIGIN
# X-Content-Type-Options: nosniff
# X-XSS-Protection: 1; mode=block
# Referrer-Policy: strict-origin-when-cross-origin
# Permissions-Policy: geolocation=(), microphone=(), camera=()
```

### Test 3.3: Normal Authentication
1. Click "Sign in with Authlift8"
2. Authenticate with Authlift8
3. Expected: Redirect back to Potlift8
4. Expected: Navbar appears with company name
5. Expected: Can access /products successfully

---

## Step 4: Test Broken State Protection

### Test 4.1: Missing User Record
```bash
# 1. Authenticate normally in browser
# 2. In Rails console:
bin/rails console

# Find and delete the current user
User.last.destroy

# 3. In browser: Refresh any page
# Expected: Redirect to /auth/login
# Expected: Session cleared (check cookies)
# Expected: Flash message "Please sign in to continue."

# 4. Check Rails logs for warning:
# "User {id} not found in database, clearing session"
```

### Test 4.2: Missing Company Record
```bash
# 1. Authenticate normally in browser
# 2. In Rails console:
bin/rails console

# Find and delete the current company
Company.last.destroy

# 3. In browser: Refresh any page
# Expected: Redirect to /auth/login
# Expected: Session cleared
# Expected: Warning in logs about missing company
```

---

## Step 5: Test Session Fixation Protection

This is automatically tested during OAuth flow. To verify:

1. **Before login:** Note session cookie value in browser DevTools
   - Open DevTools (F12)
   - Go to Application > Cookies > localhost:3246
   - Note the value of `_potlift8_session`

2. **Login:** Complete OAuth authentication

3. **After login:** Check session cookie again
   - Expected: Cookie value has changed
   - This proves session was regenerated

---

## Step 6: Run Automated Tests

```bash
# Run security tests
bin/test spec/security/authentication_security_spec.rb

# Run all tests to ensure nothing broke
bin/test
```

---

## Step 7: Verify Logs

Check Rails logs for security-related messages:

```bash
tail -f log/development.log

# Look for:
# ✅ "User {id} not found in database, clearing session"
# ✅ "Company {id} not found in database, clearing session"
# ✅ "Session timeout for user: {id}"
# ✅ "OAuth login initiated for session: {id}"
# ✅ "User authenticated: {sub} (ID: {id})"
```

---

## Expected Behavior Summary

### Before Fixes (Broken State)
- ❌ Navbar missing after user deletion
- ❌ Errors on every page
- ❌ Session persists despite invalid user
- ❌ No automatic recovery

### After Fixes (Working State)
- ✅ Automatic session clearing when user missing
- ✅ Redirect to login page
- ✅ Clear error messages
- ✅ Graceful recovery via re-authentication
- ✅ Session regenerated after login (fixation protection)
- ✅ Security headers present

---

## Troubleshooting

### Issue: "Still seeing broken navbar"
**Solution:**
1. Clear browser cookies manually
2. Use incognito/private mode
3. Clear Rails cache: `Rails.cache.clear`
4. Restart Rails server

### Issue: "Headers not showing"
**Solution:**
1. Verify `config/initializers/security_headers.rb` loaded
2. Restart Rails server
3. Check for initializer errors in startup logs

### Issue: "Authentication not working"
**Solution:**
1. Verify Authlift8 is running (http://localhost:3231)
2. Check OAuth configuration in `.env`
3. Check Rails logs for OAuth errors

---

## Production Checklist

Before deploying to production:

- [ ] SSL certificate installed and valid
- [ ] HTTPS enforced
- [ ] Session cookie `secure: true` (automatic in production)
- [ ] HSTS header enabled (automatic in production)
- [ ] Security headers verified via https://securityheaders.com/
- [ ] All tests passing
- [ ] Security documentation reviewed
- [ ] Incident response plan in place

---

## Security Scanning

### Brakeman Security Scanner
```bash
bin/brakeman

# Expected: No new security warnings
```

### RuboCop Security Checks
```bash
bin/rubocop --only Security

# Expected: No security violations
```

### Manual Security Review
- [ ] Session cookies have HttpOnly flag
- [ ] Session cookies have SameSite=Lax
- [ ] Session regenerated after authentication
- [ ] Missing user/company records handled gracefully
- [ ] Security headers configured
- [ ] No sensitive data in logs
- [ ] Error messages don't leak information

---

## Success Criteria

All of the following must be true:

1. ✅ Unauthenticated access redirects to login
2. ✅ Security headers present on all responses
3. ✅ Session regenerated after authentication
4. ✅ Missing user record clears session
5. ✅ Missing company record clears session
6. ✅ Session timeout enforced (24 hours)
7. ✅ All automated tests pass
8. ✅ No security warnings from Brakeman
9. ✅ Logs show appropriate security messages
10. ✅ Navbar appears after proper authentication

---

## Additional Resources

- Full security documentation: `/Users/sin/RubymineProjects/Ozz-Rails-8/Potlift8/docs/security/AUTHENTICATION_SECURITY.md`
- Security tests: `/Users/sin/RubymineProjects/Ozz-Rails-8/Potlift8/spec/security/authentication_security_spec.rb`
- OWASP Session Management: https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html
