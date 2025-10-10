# Potlift8 Testing Guide

## Overview

This document provides comprehensive guidance on the testing infrastructure for Potlift8, a Rails 8 application using RSpec for testing.

## Table of Contents

- [Quick Start](#quick-start)
- [Running Tests](#running-tests)
- [Testing Framework](#testing-framework)
- [Authentication Testing](#authentication-testing)
- [Configuration Files](#configuration-files)
- [Writing Tests](#writing-tests)
- [Code Coverage](#code-coverage)
- [Best Practices](#best-practices)

## Quick Start

### Setup

```bash
# Install dependencies
bundle install

# Setup test database
RAILS_ENV=test bundle exec rails db:create db:migrate

# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/models/user_spec.rb

# Run specific test
bundle exec rspec spec/models/user_spec.rb:25
```

### Environment Configuration

Tests use `.env.test` for configuration. This file is already configured with test-appropriate values:

```bash
# Database uses your system user to avoid permission issues
POSTGRES_USER=sin
POSTGRES_PASSWORD=

# Mock Authlift8 credentials (not used in tests, mocked by AuthHelper)
AUTHLIFT8_CLIENT_ID=test_client_id
AUTHLIFT8_CLIENT_SECRET=test_client_secret
```

## Running Tests

### Basic Commands

```bash
# Run all tests
bundle exec rspec

# Run with documentation format
bundle exec rspec --format documentation

# Run specific directory
bundle exec rspec spec/models
bundle exec rspec spec/controllers
bundle exec rspec spec/requests

# Run with specific seed (for reproducible test order)
bundle exec rspec --seed 12345

# Run only failed tests from last run
bundle exec rspec --only-failures

# Run tests matching a pattern
bundle exec rspec --example "authentication"
```

### Useful Options

```bash
# Show top 10 slowest examples
bundle exec rspec --profile 10

# Fail fast (stop on first failure)
bundle exec rspec --fail-fast

# Run tests in random order
bundle exec rspec --order random

# Verbose output
bundle exec rspec --format documentation --color
```

## Testing Framework

### Installed Gems

#### Core Testing
- **rspec-rails** (~> 7.1) - RSpec for Rails testing framework
- **factory_bot_rails** - Test data generation using factories
- **faker** - Realistic fake data generation

#### Test Utilities
- **shoulda-matchers** - Elegant matchers for common Rails functionality
- **database_cleaner-active_record** - Database cleaning strategies
- **simplecov** - Code coverage analysis
- **vcr** - HTTP request recording and replay
- **webmock** - HTTP request stubbing

#### System Testing
- **capybara** - Integration testing for web applications
- **selenium-webdriver** - Browser automation for system tests

### Directory Structure

```
spec/
├── controllers/           # Controller specs
├── models/               # Model specs
├── requests/             # Request specs (API/integration tests)
├── system/               # System/feature specs (full browser tests)
├── helpers/              # Helper specs
├── mailers/              # Mailer specs
├── jobs/                 # Background job specs
├── services/             # Service object specs
├── factories/            # FactoryBot factory definitions
├── fixtures/             # Test fixtures and VCR cassettes
│   └── vcr_cassettes/    # Recorded HTTP interactions
├── support/              # Test support files
│   ├── auth_helper.rb    # Authentication test helpers
│   ├── factory_bot.rb    # FactoryBot configuration
│   ├── database_cleaner.rb  # Database cleaning setup
│   ├── shoulda_matchers.rb  # Shoulda matchers config
│   └── vcr.rb            # VCR configuration
├── rails_helper.rb       # Rails-specific RSpec configuration
├── spec_helper.rb        # General RSpec configuration
└── TESTING_README.md     # This file
```

## Authentication Testing

### Using AuthHelper

The `AuthHelper` module provides utilities for mocking JWT authentication in tests without requiring actual Authlift8 API calls.

#### Basic Usage

```ruby
RSpec.describe SomeController, type: :controller do
  describe "GET #index" do
    it "returns success for authenticated user" do
      # Sign in as a user with specific attributes
      sign_in_as(
        id: 123,
        email: "user@example.com",
        first_name: "John",
        last_name: "Doe",
        company_id: 456,
        company_code: "ACME",
        company_name: "Acme Corp",
        role: "admin",
        scopes: ["read", "write"]
      )

      get :index
      expect(response).to be_successful
    end
  end
end
```

#### For Request Specs

```ruby
RSpec.describe "Users API", type: :request do
  it "returns user data" do
    # Generate a mock JWT token
    token = mock_jwt_token(
      id: 1,
      email: "user@example.com",
      role: "user"
    )

    # Use token in Authorization header
    get "/api/v1/users",
        headers: { "Authorization" => "Bearer #{token}" }

    expect(response).to be_successful
  end
end
```

#### Sign Out

```ruby
it "signs out the user" do
  sign_in_as(id: 1, email: "user@example.com")
  sign_out

  get :index
  expect(response).to redirect_to(auth_login_path)
end
```

### AuthHelper Methods

- `sign_in_as(user_data)` - Sign in with mocked user data
- `mock_jwt_token(user_data)` - Generate a mock JWT token
- `sign_out` - Clear session and sign out
- `current_user_payload` - Get current user JWT payload

### Default User Attributes

When using `sign_in_as` or `mock_jwt_token` without all attributes, these defaults are used:

```ruby
{
  id: 1,
  email: "test@example.com",
  first_name: "Test",
  last_name: "User",
  company_id: 1,
  company_code: "TEST",
  company_name: "Test Company",
  role: "user",
  scopes: ["read"],
  iat: Time.current.to_i,
  exp: 1.hour.from_now.to_i
}
```

## Configuration Files

### spec/rails_helper.rb

Main RSpec configuration for Rails integration:
- Loads SimpleCov for code coverage
- Configures Capybara for system tests
- Sets up WebMock for HTTP stubbing
- Enables DatabaseCleaner
- Loads all support files
- Configures test behavior (random order, aggregate failures, etc.)

### spec/support/

#### auth_helper.rb
Authentication testing utilities for mocking JWT tokens and sessions.

#### factory_bot.rb
FactoryBot configuration - enables `create`, `build`, `build_stubbed` syntax.

#### database_cleaner.rb
Ensures clean database state between tests:
- Uses `:transaction` strategy for fast tests
- Uses `:truncation` strategy for system tests with JavaScript

#### shoulda_matchers.rb
Elegant matchers for:
- Model validations: `should validate_presence_of(:email)`
- Associations: `should belong_to(:user)`
- Database columns: `should have_db_column(:email)`

#### vcr.rb
HTTP request recording for external API testing:
- Records real HTTP interactions once
- Replays them in subsequent test runs
- Filters sensitive data (API keys, secrets)

### .simplecov

Code coverage configuration:
- Minimum coverage threshold: 80%
- Minimum per-file coverage: 50%
- Excludes test code, config, vendor from coverage
- Groups results by Models, Controllers, Services, etc.

## Writing Tests

### Model Specs

```ruby
# spec/models/user_spec.rb
require 'rails_helper'

RSpec.describe User, type: :model do
  describe "validations" do
    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email).case_insensitive }
  end

  describe "associations" do
    it { should belong_to(:company) }
    it { should have_many(:posts) }
  end

  describe "#full_name" do
    it "returns first and last name" do
      user = build(:user, first_name: "John", last_name: "Doe")
      expect(user.full_name).to eq("John Doe")
    end
  end
end
```

### Controller Specs

```ruby
# spec/controllers/users_controller_spec.rb
require 'rails_helper'

RSpec.describe UsersController, type: :controller do
  describe "GET #index" do
    context "when authenticated" do
      before do
        sign_in_as(id: 1, email: "admin@example.com", role: "admin")
      end

      it "returns success" do
        get :index
        expect(response).to be_successful
      end

      it "assigns @users" do
        user = create(:user)
        get :index
        expect(assigns(:users)).to include(user)
      end
    end

    context "when not authenticated" do
      it "redirects to login" do
        get :index
        expect(response).to redirect_to(auth_login_path)
      end
    end
  end
end
```

### Request Specs (API Testing)

```ruby
# spec/requests/api/v1/users_spec.rb
require 'rails_helper'

RSpec.describe "API::V1::Users", type: :request do
  let(:token) { mock_jwt_token(id: 1, role: "admin") }
  let(:headers) { { "Authorization" => "Bearer #{token}" } }

  describe "GET /api/v1/users" do
    it "returns users list" do
      create_list(:user, 3)

      get "/api/v1/users", headers: headers

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["users"].size).to eq(3)
    end
  end

  describe "POST /api/v1/users" do
    let(:user_params) do
      {
        user: {
          email: "new@example.com",
          first_name: "New",
          last_name: "User"
        }
      }
    end

    it "creates a new user" do
      expect {
        post "/api/v1/users", params: user_params, headers: headers
      }.to change(User, :count).by(1)

      expect(response).to have_http_status(:created)
    end
  end
end
```

### System Specs (Full Integration)

```ruby
# spec/system/user_login_spec.rb
require 'rails_helper'

RSpec.describe "User Login", type: :system do
  it "allows user to log in" do
    visit root_path

    # Should redirect to login
    expect(page).to have_current_path(auth_login_path)

    click_link "Sign in with Authlift"

    # In tests, this would be mocked
    # In real scenario, user would complete OAuth flow
    expect(page).to have_content("Welcome")
  end
end
```

### Using FactoryBot

```ruby
# spec/factories/users.rb
FactoryBot.define do
  factory :user do
    email { Faker::Internet.email }
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }

    trait :admin do
      role { "admin" }
    end

    trait :with_company do
      association :company
    end
  end
end

# Usage in specs
user = create(:user)                    # Persisted user
admin = create(:user, :admin)            # Admin user
user_with_company = create(:user, :with_company)

# Build without saving
user = build(:user)

# Build stubbed (no database)
user = build_stubbed(:user)

# Attributes hash
attrs = attributes_for(:user)

# Create multiple
users = create_list(:user, 5)
```

### Using Faker for Realistic Data

```ruby
# Random but realistic data
email = Faker::Internet.email
name = Faker::Name.name
company = Faker::Company.name
phone = Faker::PhoneNumber.phone_number
address = Faker::Address.full_address

# Specific types
uuid = Faker::Internet.uuid
url = Faker::Internet.url
color = Faker::Color.hex_color
```

## Code Coverage

### Viewing Coverage Reports

After running tests, SimpleCov generates a coverage report:

```bash
# Run tests (generates coverage)
bundle exec rspec

# Open coverage report in browser
open coverage/index.html
```

### Coverage Thresholds

Current configuration requires:
- **80% overall coverage** - All code must be at least 80% covered
- **50% per-file coverage** - Each file must be at least 50% covered

Tests will fail if coverage drops below these thresholds.

### Excluding Code from Coverage

```ruby
# Exclude single line
# :nocov:
def some_untestable_method
end
# :nocov:

# Or in .simplecov
add_filter '/lib/tasks/'  # Exclude rake tasks
add_filter '/db/'         # Exclude migrations
```

## Best Practices

### Test Organization

1. **Follow AAA Pattern** (Arrange, Act, Assert)
   ```ruby
   it "creates a user" do
     # Arrange - set up test data
     params = { name: "John" }

     # Act - perform the action
     post :create, params: params

     # Assert - verify the result
     expect(User.count).to eq(1)
   end
   ```

2. **One Assertion Per Test** (when practical)
   ```ruby
   # Good
   it "sets the email" do
     user = create(:user, email: "test@example.com")
     expect(user.email).to eq("test@example.com")
   end

   it "sets the name" do
     user = create(:user, name: "John")
     expect(user.name).to eq("John")
   end
   ```

3. **Descriptive Test Names**
   ```ruby
   # Bad
   it "works" do
   end

   # Good
   it "creates a user with valid attributes" do
   end

   it "rejects invalid email format" do
   end
   ```

### Factory Usage

1. **Use `build` when database persistence isn't needed**
   ```ruby
   # Faster - no database
   user = build(:user)
   expect(user.valid?).to be true
   ```

2. **Use `create` when testing database interactions**
   ```ruby
   # Persists to database
   user = create(:user)
   expect(User.find(user.id)).to eq(user)
   ```

3. **Override attributes inline**
   ```ruby
   user = create(:user, email: "specific@example.com")
   ```

### Mocking and Stubbing

1. **Mock external services**
   ```ruby
   it "calls external API" do
     allow(ExternalService).to receive(:call).and_return({ success: true })

     result = MyService.new.call

     expect(ExternalService).to have_received(:call)
   end
   ```

2. **Use VCR for HTTP requests**
   ```ruby
   it "fetches weather data", vcr: true do
     # First run: makes real request and records it
     # Subsequent runs: replays recorded response
     weather = WeatherService.fetch("New York")
     expect(weather.temperature).to be > 0
   end
   ```

3. **Stub time-dependent code**
   ```ruby
   it "expires after 1 hour" do
     travel_to Time.zone.parse("2024-01-01 12:00:00") do
       token = create(:token)
       expect(token.expired?).to be false
     end

     travel_to Time.zone.parse("2024-01-01 13:01:00") do
       expect(token.expired?).to be true
     end
   end
   ```

### Performance

1. **Use `build_stubbed` for non-database tests**
   ```ruby
   # Fastest - no database at all
   user = build_stubbed(:user)
   ```

2. **Use `let` for lazy evaluation**
   ```ruby
   # Only created when referenced
   let(:user) { create(:user) }

   # Created once per example, even if referenced multiple times
   let!(:user) { create(:user) }
   ```

3. **Clean up after tests**
   - DatabaseCleaner handles this automatically
   - For manual cleanup: use `after` hooks

### Security Testing

1. **Test authorization**
   ```ruby
   it "prevents unauthorized access" do
     sign_in_as(role: "user")

     get :admin_panel
     expect(response).to have_http_status(:forbidden)
   end
   ```

2. **Test authentication**
   ```ruby
   it "requires authentication" do
     # No sign_in_as call

     get :index
     expect(response).to redirect_to(auth_login_path)
   end
   ```

3. **Test parameter sanitization**
   ```ruby
   it "filters sensitive parameters" do
     params = { password: "secret123" }
     post :create, params: params

     expect(Rails.logger).not_to have_received(:info).with(/secret123/)
   end
   ```

## Troubleshooting

### Common Issues

#### Database Connection Errors

```bash
# Ensure test database exists
RAILS_ENV=test bundle exec rails db:create

# Reset test database
RAILS_ENV=test bundle exec rails db:reset
```

#### Gem Version Conflicts

```bash
# Update Gemfile.lock
bundle update

# Or reinstall specific gem
bundle update rspec-rails
```

#### Slow Tests

```bash
# Identify slow tests
bundle exec rspec --profile 20

# Common causes:
# - Creating too many records (use build instead of create)
# - Making real HTTP requests (use VCR or WebMock)
# - Not using database transactions (check DatabaseCleaner setup)
```

#### Flaky Tests

- Check for time-dependent code (use Timecop or travel_to)
- Check for order-dependent tests (ensure proper isolation)
- Check for race conditions (in system tests)
- Use `--seed` to reproduce specific test order

## Additional Resources

- [RSpec Documentation](https://rspec.info/)
- [FactoryBot Documentation](https://github.com/thoughtbot/factory_bot)
- [Shoulda Matchers](https://github.com/thoughtbot/shoulda-matchers)
- [Capybara Documentation](https://github.com/teamcapybara/capybara)
- [SimpleCov Documentation](https://github.com/simplecov-ruby/simplecov)
- [VCR Documentation](https://github.com/vcr/vcr)

## Support

For questions or issues with the testing setup, please contact the development team or create an issue in the project repository.
