# Security Testing Guide - Authentication Bypass Fixes

**Quick Reference for Testing Authentication Security Fixes**

---

## Prerequisites

1. Potlift8 running on `http://localhost:3246`
2. Authlift8 running on `http://localhost:3231`
3. Test user account in Authlift8
4. Browser with Developer Tools

---

## Test 1: Verify GET Logout Route Removed

**Objective:** Confirm GET /logout route no longer exists

### Steps:
```bash
# 1. Check routes
rails routes | grep logout

# Expected output:
# POST   /auth/logout(.:format)   sessions#destroy
# DELETE /auth/logout(.:format)   sessions#destroy
# NO GET route should appear!

# 2. Try accessing GET /logout directly
curl http://localhost:3246/logout

# Expected: 404 Not Found or redirect to /auth/login
# ❌ FAIL: If you see any content or 200 OK
# ✅ PASS: 404 Not Found
```

### Browser Test:
```
1. Open http://localhost:3246/logout
2. Expected: "404 Not Found" or redirect to login
3. ❌ FAIL: If logout happens
4. ✅ PASS: Route doesn't exist
```

**Status:** [ ] PASS  [ ] FAIL

---

## Test 2: Verify CSRF Protection on Logout

**Objective:** Confirm logout requires CSRF token and POST method

### Steps:
```bash
# Try logout without CSRF token
curl -X POST http://localhost:3246/auth/logout

# Expected: 422 Unprocessable Entity (CSRF token missing)
# ✅ PASS: 422 error
# ❌ FAIL: Logout succeeds
```

### Browser Test:
```html
<!-- Create test HTML file: test_csrf.html -->
<html>
<body>
  <h1>CSRF Test - Should NOT logout user</h1>
  <img src="http://localhost:3246/logout" style="display:none">
  <form action="http://localhost:3246/auth/logout" method="POST">
    <button type="submit">Try Logout (will fail - no CSRF token)</button>
  </form>
</body>
</html>

Test:
1. Login to Potlift8
2. Open test_csrf.html in browser
3. Click button
4. Expected: Error or no logout
5. ✅ PASS: User remains logged in
6. ❌ FAIL: User is logged out
```

**Status:** [ ] PASS  [ ] FAIL

---

## Test 3: Complete Logout Flow

**Objective:** Verify complete SSO logout chain works

### Steps:
```
1. Open Potlift8: http://localhost:3246
2. Click "Sign in with Authlift8"
3. Login with test credentials
4. Verify you're logged in (see navbar with user menu)
5. Click user dropdown → "Sign out"

Expected behavior:
✅ Redirect to Authlift8 logout page
✅ Authlift8 shows "You have been logged out"
✅ Redirect back to Potlift8 login page
✅ No navbar visible (not authenticated)
✅ Trying to access /products redirects to login

6. Try accessing: http://localhost:3246/products
7. Expected: Redirect to /auth/login with alert "Please sign in to continue."
```

**Checklist:**
- [ ] Redirects to Authlift8 logout
- [ ] Authlift8 shows logout confirmation
- [ ] Redirects back to Potlift8 login
- [ ] No user menu visible
- [ ] /products redirects to login
- [ ] Session cookies cleared

**Status:** [ ] PASS  [ ] FAIL

---

## Test 4: Session Invalidation After Authlift8 Logout

**Objective:** Verify Potlift8 session cleared when logged out from Authlift8

### Steps:
```
1. Login to Potlift8
2. Open Authlift8 in another tab: http://localhost:3231
3. Logout from Authlift8 directly (not through Potlift8)
4. Return to Potlift8 tab
5. Refresh the page or click any link

Expected:
✅ Redirect to /auth/login
✅ Alert: "Please sign in to continue"
✅ Products/data no longer accessible
✅ Session cleared

❌ FAIL if:
- Products still visible
- Navbar still shows user menu
- No redirect to login
```

**Checklist:**
- [ ] Session invalidated after Authlift8 logout
- [ ] Products inaccessible
- [ ] Redirect to login
- [ ] No stale session data

**Status:** [ ] PASS  [ ] FAIL

---

## Test 5: Token Revocation

**Objective:** Verify tokens are revoked on logout

### Setup:
```ruby
# In Rails console before test
# Enable debug logging
Rails.logger.level = :debug
```

### Steps:
```
1. Login to Potlift8
2. Open browser DevTools → Application → Cookies
3. Note the session cookie value
4. Check Rails logs: tail -f log/development.log
5. Click "Sign out"

Expected in logs:
✅ "Access token revoked successfully"
✅ "User logged out: [user_id]"
✅ "Redirected to Authlift8 logout"

6. After logout, check cookies
Expected:
✅ All cookies cleared
✅ No _potlift_session cookie
```

### Rails Console Verification:
```ruby
# In rails console (after logout)
client = Authlift::Client.new

# Try to use a revoked token (get from logs before logout)
old_token = "eyJhbGciOiJSUzI1NiJ9..."
client.decode_jwt(old_token)

# Expected: Raises Authlift::Client::TokenValidationError
# ✅ PASS: TokenValidationError raised
# ❌ FAIL: Token still valid
```

**Status:** [ ] PASS  [ ] FAIL

---

## Test 6: JWT Validation on Every Request

**Objective:** Verify JWT token validated on every authenticated request

### Steps:
```ruby
# In Rails console - simulate expired token

# 1. Create test session with expired token
session = ActionDispatch::Request::Session.new({})
session[:user_id] = 1
session[:access_token] = "expired_or_revoked_token"
session[:authenticated_at] = Time.now.to_i

# 2. Try to access authenticated? method
controller = ApplicationController.new
controller.send(:session=, session)
controller.send(:authenticated?)

# Expected: false (JWT validation fails)
# ✅ PASS: Returns false
# ❌ FAIL: Returns true
```

### Browser Test:
```
1. Login to Potlift8
2. Open DevTools → Console
3. Paste this JavaScript to corrupt access_token:
   document.cookie = "_potlift_session=corrupted; path=/";
4. Refresh page or navigate to /products

Expected:
✅ Redirect to login
✅ Alert about authentication failure
✅ Session cleared

❌ FAIL: Products still accessible
```

**Status:** [ ] PASS  [ ] FAIL

---

## Test 7: Prefetch Attack Prevention

**Objective:** Confirm browsers can't logout users via prefetch/prerender

### Steps:
```html
<!-- Create test file: prefetch_test.html -->
<html>
<head>
  <link rel="prefetch" href="http://localhost:3246/logout">
  <link rel="prerender" href="http://localhost:3246/logout">
</head>
<body>
  <h1>Prefetch/Prerender Test</h1>
  <p>If GET /logout existed, you'd be logged out!</p>
  <img src="http://localhost:3246/logout" style="display:none">
  <iframe src="http://localhost:3246/logout" style="display:none"></iframe>
</body>
</html>

Test:
1. Login to Potlift8
2. Open prefetch_test.html
3. Wait 10 seconds
4. Return to Potlift8 and refresh

Expected:
✅ Still logged in
✅ User menu visible
✅ Products accessible

❌ FAIL: Logged out
```

**Status:** [ ] PASS  [ ] FAIL

---

## Test 8: Email Tracking Pixel Attack Prevention

**Objective:** Verify logout can't be triggered via email tracking pixels

### Steps:
```html
<!-- Simulate malicious email HTML -->
<html>
<body>
  <h1>Simulated Phishing Email</h1>
  <p>This email tries to logout Potlift8 users!</p>

  <!-- These should NOT logout users anymore -->
  <img src="http://localhost:3246/logout" width="1" height="1">
  <img src="http://localhost:3246/auth/logout" width="1" height="1">
  <div style="background: url('http://localhost:3246/logout')"></div>
</body>
</html>

Test:
1. Login to Potlift8
2. Open email HTML in browser
3. Check if still logged in

Expected:
✅ User remains logged in
✅ Tracking pixels fail (404)
✅ No session cleared

❌ FAIL: User logged out
```

**Status:** [ ] PASS  [ ] FAIL

---

## Test 9: Multiple Tab Session Management

**Objective:** Verify session synchronized across tabs

### Steps:
```
1. Login to Potlift8
2. Open 3 tabs, all showing /products
3. In Tab 1: Click "Sign out"
4. Switch to Tab 2: Refresh or click a link
5. Switch to Tab 3: Refresh or click a link

Expected:
✅ All tabs redirect to login
✅ Session cleared in all tabs
✅ No stale authenticated state

❌ FAIL: Some tabs still show products
```

**Status:** [ ] PASS  [ ] FAIL

---

## Test 10: API Token Revocation

**Objective:** Verify API access blocked after logout

### Setup:
```bash
# Before logout, capture access token
# DevTools → Application → Cookies → _potlift_session
# Or Rails console: session[:access_token]
```

### Steps:
```bash
# 1. Login and get access token
ACCESS_TOKEN="eyJhbGciOiJSUzI1NiJ9..."

# 2. Test API access (should work)
curl -H "Authorization: Bearer $ACCESS_TOKEN" \
  http://localhost:3246/api/v1/products

# Expected: 200 OK with product list

# 3. Logout from Potlift8

# 4. Try API access again with same token
curl -H "Authorization: Bearer $ACCESS_TOKEN" \
  http://localhost:3246/api/v1/products

# Expected: 401 Unauthorized
# ✅ PASS: 401 error
# ❌ FAIL: Still returns products
```

**Status:** [ ] PASS  [ ] FAIL

---

## Security Regression Testing

### Daily/CI Tests:
```bash
# Add to CI pipeline
bundle exec rspec spec/controllers/sessions_controller_spec.rb
bundle exec rspec spec/requests/authentication_spec.rb

# Check routes don't have GET logout
rails routes | grep -c "GET.*logout"
# Expected: 0
```

### Weekly Manual Tests:
- [ ] Test 1: GET logout blocked
- [ ] Test 3: Complete logout flow
- [ ] Test 4: Session invalidation

### Monthly Security Audit:
- [ ] All 10 tests above
- [ ] Penetration testing
- [ ] Security log review

---

## Common Issues & Troubleshooting

### Issue 1: Logout redirects to Authlift8 but then errors
**Cause:** Authlift8 logout endpoint not configured properly
**Fix:** Check AUTHLIFT8_SITE environment variable
```bash
echo $AUTHLIFT8_SITE
# Should be: http://localhost:3231
```

### Issue 2: Token revocation fails silently
**Cause:** Authlift8 /oauth/revoke endpoint not available
**Fix:** Check Authlift8 logs, ensure OAuth revocation enabled
```bash
# Check if endpoint exists
curl -X POST http://localhost:3231/oauth/revoke
# Should return 401 or 422, not 404
```

### Issue 3: Session persists after logout
**Cause:** Browser caching, cookies not cleared
**Fix:**
```ruby
# In sessions_controller.rb, verify reset_session is called
reset_session
```

### Issue 4: CSRF token errors on logout
**Cause:** Missing CSRF meta tags in layout
**Fix:**
```erb
<!-- In app/views/layouts/application.html.erb -->
<%= csrf_meta_tags %>
```

---

## Test Results Summary

| Test | Description | Status | Notes |
|------|-------------|--------|-------|
| 1 | GET logout removed | [ ] | |
| 2 | CSRF protection | [ ] | |
| 3 | Complete logout flow | [ ] | |
| 4 | Session invalidation | [ ] | |
| 5 | Token revocation | [ ] | |
| 6 | JWT validation | [ ] | |
| 7 | Prefetch prevention | [ ] | |
| 8 | Email pixel prevention | [ ] | |
| 9 | Multi-tab session | [ ] | |
| 10 | API token revocation | [ ] | |

**Overall Status:** [ ] ALL PASS  [ ] SOME FAIL

**Tester:** _______________
**Date:** _______________
**Environment:** [ ] Development  [ ] Staging  [ ] Production

---

## Emergency Rollback (If Tests Fail)

If critical tests fail, rollback immediately:

```bash
# 1. Revert routes.rb
git checkout HEAD -- config/routes.rb

# 2. Revert sessions_controller.rb
git checkout HEAD -- app/controllers/sessions_controller.rb

# 3. Revert application_controller.rb
git checkout HEAD -- app/controllers/application_controller.rb

# 4. Restart server
bin/rails restart

# 5. Report issues immediately
```

---

**CLASSIFICATION:** INTERNAL - SECURITY TESTING
**RETENTION:** 1 year - Security Documentation
