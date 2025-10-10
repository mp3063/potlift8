# Potlift8

Potlift8 is a modern Rails 8 application for cannabis inventory management, featuring multi-tenancy and OAuth2 integration with Authlift8.

## System Requirements

- **Ruby**: 3.4.7
- **Rails**: 8.0.3
- **PostgreSQL**: 16+
- **Redis**: 7+
- **Node.js**: 18+ (for asset compilation)
- **Yarn**: Latest

## Local Development Setup

### Prerequisites Installation

#### macOS (using Homebrew)

```bash
# Install PostgreSQL and Redis
brew install postgresql@16 redis

# Start services
brew services start postgresql@16
brew services start redis
```

#### Linux (Ubuntu/Debian)

```bash
# Update package list
sudo apt-get update

# Install PostgreSQL and Redis
sudo apt-get install postgresql-16 postgresql-contrib redis-server

# Start services
sudo systemctl start postgresql
sudo systemctl start redis-server

# Enable services to start on boot
sudo systemctl enable postgresql
sudo systemctl enable redis-server
```

### Application Setup

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd Potlift8
   ```

2. **Run the setup script**
   ```bash
   bin/setup
   ```

   This script will:
   - Install Ruby dependencies (bundle install)
   - Install JavaScript dependencies (yarn install)
   - Create `.env` file from `.env.example`
   - Create PostgreSQL user and databases
   - Set up the database schema
   - Clear logs and temporary files

3. **Configure environment variables**

   Edit `.env` and update the following values:
   ```bash
   AUTHLIFT8_CLIENT_ID=your_actual_client_id
   AUTHLIFT8_CLIENT_SECRET=your_actual_client_secret
   ```

   You can obtain these credentials from your Authlift8 instance running on port 3231.

4. **Start the development server**
   ```bash
   bin/dev
   ```

   This will:
   - Check that PostgreSQL and Redis are running
   - Start the Rails server on port 3246
   - Start the Tailwind CSS watcher

5. **Visit the application**

   Open your browser and navigate to:
   ```
   http://localhost:3246
   ```

## Development Workflow

### Running Tests

```bash
# Run all tests
bin/test

# Run specific test file
bin/test spec/models/company_spec.rb

# Run tests matching a pattern
bin/test spec/models

# Run with additional RSpec options
bin/test --format documentation
```

### Database Management

```bash
# Create databases
bin/rails db:create

# Run migrations
bin/rails db:migrate

# Rollback last migration
bin/rails db:rollback

# Reset database (drop, create, migrate, seed)
bin/rails db:reset

# Prepare database (create if needed, then migrate)
bin/rails db:prepare
```

### Code Quality

```bash
# Run security audit
bin/brakeman

# Run code style checks
bin/rubocop

# Auto-fix style issues
bin/rubocop -a
```

### Console Access

```bash
# Rails console
bin/rails console

# Rails console with Pry (enhanced debugging)
bin/rails console
# (pry-rails is automatically loaded)
```

## Architecture Overview

### Multi-Tenancy
- Company-based isolation using PostgreSQL schemas
- Company context established via Authlift8 JWT tokens
- All queries automatically scoped to current company

### Authentication
- OAuth2 integration with Authlift8 (http://localhost:3231)
- JWT token validation with RS256 signatures
- Secure session management with httponly cookies
- CSRF protection via state tokens

### Technology Stack
- **Framework**: Rails 8.0.3
- **Database**: PostgreSQL 16
- **Cache/Queue**: Redis 7 (via Solid Cache/Queue)
- **Asset Pipeline**: Propshaft
- **CSS**: Tailwind CSS
- **JavaScript**: Hotwire (Turbo + Stimulus)
- **Testing**: RSpec, FactoryBot, Capybara

## Project Structure

```
Potlift8/
├── app/
│   ├── controllers/
│   ├── models/
│   ├── views/
│   └── ...
├── bin/
│   ├── dev          # Start development server
│   ├── setup        # Initial setup
│   └── test         # Run RSpec tests
├── config/
│   ├── database.yml
│   ├── routes.rb
│   └── ...
├── lib/
│   └── authlift/    # OAuth2 client library
├── spec/           # RSpec test suite
├── .env.example    # Environment variables template
└── Procfile.dev    # Development processes
```

## Environment Variables

See `.env.example` for all available configuration options. Key variables include:

- `DATABASE_URL`: PostgreSQL connection string
- `REDIS_URL`: Redis connection string
- `AUTHLIFT8_URL`: Authlift8 OAuth provider URL
- `AUTHLIFT8_CLIENT_ID`: OAuth client ID
- `AUTHLIFT8_CLIENT_SECRET`: OAuth client secret
- `PORT`: Application port (default: 3246)

## Troubleshooting

### PostgreSQL Connection Issues

```bash
# Check if PostgreSQL is running
pg_isready

# macOS: Start PostgreSQL
brew services start postgresql@16

# Linux: Start PostgreSQL
sudo systemctl start postgresql
```

### Redis Connection Issues

```bash
# Check if Redis is running
redis-cli ping

# macOS: Start Redis
brew services start redis

# Linux: Start Redis
sudo systemctl start redis-server
```

### Port Already in Use

If port 3246 is already in use, you can change it in your `.env` file:
```bash
PORT=3247
```

### Database Permission Issues

```bash
# Grant superuser privileges to potlift user
psql postgres -c "ALTER USER potlift WITH SUPERUSER;"
```

## Contributing

1. Create a feature branch
2. Make your changes
3. Run tests: `bin/test`
4. Run security audit: `bin/brakeman`
5. Run style checks: `bin/rubocop`
6. Submit a pull request

## License

[Your License Here]
