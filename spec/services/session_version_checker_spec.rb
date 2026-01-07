# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SessionVersionChecker, type: :service do
  let(:redis) { Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1')) }
  let(:session) do
    {
      user_id: 123,
      company_id: 456,
      access_token: 'test_token',
      session_version_user: 1000,
      session_version_company: 1000,
      session_version_customer_group: 1000
    }
  end
  let(:checker) { described_class.new(session) }

  before do
    # Clear Redis session version keys before each test
    redis.keys('session_version:*').each { |key| redis.del(key) }
  end

  after do
    # Clean up after each test
    redis.keys('session_version:*').each { |key| redis.del(key) }
  end

  describe '#initialize' do
    it 'accepts a session hash' do
      expect(checker.session).to eq(session)
    end
  end

  describe '#needs_refresh?' do
    context 'when user_id is not present' do
      let(:session) { { company_id: 456, access_token: 'test_token' } }

      it 'returns false' do
        expect(checker.needs_refresh?).to be false
      end
    end

    context 'when user_id is blank' do
      let(:session) { { user_id: '', company_id: 456 } }

      it 'returns false' do
        expect(checker.needs_refresh?).to be false
      end
    end

    context 'when no versions exist in Redis' do
      it 'returns false (no version = current)' do
        expect(checker.needs_refresh?).to be false
      end
    end

    context 'when user version is newer in Redis' do
      before { redis.set('session_version:user:123', 2000) }

      it 'returns true' do
        expect(checker.needs_refresh?).to be true
      end
    end

    context 'when company version is newer in Redis' do
      before { redis.set('session_version:company:456', 2000) }

      it 'returns true' do
        expect(checker.needs_refresh?).to be true
      end
    end

    context 'when customer_group version is newer in Redis' do
      before { redis.set('session_version:customer_group:456', 2000) }

      it 'returns true' do
        expect(checker.needs_refresh?).to be true
      end
    end

    context 'when all versions are current' do
      before do
        redis.set('session_version:user:123', 1000)
        redis.set('session_version:company:456', 1000)
        redis.set('session_version:customer_group:456', 1000)
      end

      it 'returns false' do
        expect(checker.needs_refresh?).to be false
      end
    end

    context 'when session versions are older than Redis versions' do
      before do
        redis.set('session_version:user:123', 500)
        redis.set('session_version:company:456', 500)
        redis.set('session_version:customer_group:456', 500)
      end

      it 'returns false (session has newer versions)' do
        expect(checker.needs_refresh?).to be false
      end
    end

    context 'when company_id is nil' do
      let(:session) do
        {
          user_id: 123,
          company_id: nil,
          access_token: 'test_token',
          session_version_user: 1000
        }
      end

      before { redis.set('session_version:user:123', 2000) }

      it 'checks only user version' do
        expect(checker.needs_refresh?).to be true
      end
    end

    context 'when Redis is unavailable' do
      before do
        allow_any_instance_of(Redis).to receive(:get).and_raise(Redis::BaseError.new('Connection refused'))
      end

      it 'returns false and does not raise' do
        expect { checker.needs_refresh? }.not_to raise_error
        expect(checker.needs_refresh?).to be false
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/Redis error/)
        checker.needs_refresh?
      end
    end
  end

  describe '#store_current_versions!' do
    before do
      redis.set('session_version:user:123', 5000)
      redis.set('session_version:company:456', 6000)
      redis.set('session_version:customer_group:456', 7000)
    end

    it 'stores current Redis versions in session' do
      checker.store_current_versions!

      expect(session[:session_version_user]).to eq(5000)
      expect(session[:session_version_company]).to eq(6000)
      expect(session[:session_version_customer_group]).to eq(7000)
    end

    context 'when Redis has no versions' do
      before do
        redis.del('session_version:user:123')
        redis.del('session_version:company:456')
        redis.del('session_version:customer_group:456')
      end

      it 'stores 0 for missing versions' do
        checker.store_current_versions!

        expect(session[:session_version_user]).to eq(0)
        expect(session[:session_version_company]).to eq(0)
        expect(session[:session_version_customer_group]).to eq(0)
      end
    end

    context 'when company_id is nil' do
      let(:session) do
        {
          user_id: 123,
          company_id: nil,
          access_token: 'test_token',
          session_version_user: 1000
        }
      end

      before do
        redis.set('session_version:user:123', 5000)
      end

      it 'stores user version and 0 for company-related versions' do
        checker.store_current_versions!

        expect(session[:session_version_user]).to eq(5000)
        expect(session[:session_version_company]).to eq(0)
        expect(session[:session_version_customer_group]).to eq(0)
      end
    end
  end

  describe '#current_versions' do
    before do
      redis.set('session_version:user:123', 5000)
      redis.set('session_version:company:456', 6000)
      redis.set('session_version:customer_group:456', 7000)
    end

    it 'returns current Redis versions' do
      versions = checker.current_versions

      expect(versions[:user]).to eq(5000)
      expect(versions[:company]).to eq(6000)
      expect(versions[:customer_group]).to eq(7000)
    end

    context 'when company_id is nil' do
      let(:session) { { user_id: 123, company_id: nil } }

      it 'returns 0 for company-related versions' do
        versions = checker.current_versions

        expect(versions[:user]).to eq(5000)
        expect(versions[:company]).to eq(0)
        expect(versions[:customer_group]).to eq(0)
      end
    end
  end

  describe '#session_versions' do
    it 'returns stored session versions' do
      versions = checker.session_versions

      expect(versions[:user]).to eq(1000)
      expect(versions[:company]).to eq(1000)
      expect(versions[:customer_group]).to eq(1000)
    end

    context 'when session versions are nil' do
      let(:session) { { user_id: 123, company_id: 456 } }

      it 'returns 0 for nil versions' do
        versions = checker.session_versions

        expect(versions[:user]).to eq(0)
        expect(versions[:company]).to eq(0)
        expect(versions[:customer_group]).to eq(0)
      end
    end
  end

  describe '#refresh_session!' do
    let(:authlift8_site) { ENV.fetch('AUTHLIFT8_SITE', 'http://localhost:3231') }
    let(:profile_response) do
      {
        'id' => 123,
        'email' => 'updated@example.com',
        'full_name' => 'Updated Name',
        'locale' => 'en',
        'company' => {
          'id' => 456,
          'code' => 'ACME',
          'name' => 'Acme Corp',
          'customer_groups' => [
            { 'id' => 1, 'name' => 'Wholesale', 'group_type' => 'pricing', 'pricing_rules' => {} }
          ]
        },
        'membership' => {
          'role' => 'admin',
          'scopes' => ['products:write', 'orders:read']
        }
      }
    end

    context 'when access_token is missing' do
      let(:session) { { user_id: 123, company_id: 456 } }

      it 'returns false' do
        expect(checker.refresh_session!).to be false
      end
    end

    context 'when access_token is blank' do
      let(:session) { { user_id: 123, company_id: 456, access_token: '' } }

      it 'returns false' do
        expect(checker.refresh_session!).to be false
      end
    end

    context 'when API call succeeds' do
      before do
        stub_request(:get, "#{authlift8_site}/api/v1/users/profile")
          .with(headers: { 'Authorization' => 'Bearer test_token' })
          .to_return(
            status: 200,
            body: profile_response.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        # Mock User and Company to avoid database calls
        allow(User).to receive(:find_by).and_return(nil)
        allow(Company).to receive(:from_authlift8).and_return(nil)
      end

      it 'updates session with user data' do
        checker.refresh_session!

        expect(session[:email]).to eq('updated@example.com')
        expect(session[:user_name]).to eq('Updated Name')
        expect(session[:locale]).to eq('en')
      end

      it 'updates session with company data' do
        checker.refresh_session!

        expect(session[:company_id]).to eq(456)
        expect(session[:company_code]).to eq('ACME')
        expect(session[:company_name]).to eq('Acme Corp')
        expect(session[:customer_groups]).to be_an(Array)
        expect(session[:customer_groups].first['name']).to eq('Wholesale')
      end

      it 'updates session with membership data' do
        checker.refresh_session!

        expect(session[:role]).to eq('admin')
        expect(session[:scopes]).to eq(['products:write', 'orders:read'])
      end

      it 'stores current versions after refresh' do
        redis.set('session_version:user:123', 9000)
        redis.set('session_version:company:456', 9000)
        redis.set('session_version:customer_group:456', 9000)

        checker.refresh_session!

        expect(session[:session_version_user]).to eq(9000)
        expect(session[:session_version_company]).to eq(9000)
        expect(session[:session_version_customer_group]).to eq(9000)
      end

      it 'returns true' do
        expect(checker.refresh_session!).to be true
      end

      it 'logs the refresh' do
        expect(Rails.logger).to receive(:info).with(/Refreshing session/)
        expect(Rails.logger).to receive(:info).with(/Session refreshed successfully/)

        checker.refresh_session!
      end

      it 'syncs local User record' do
        user = instance_double(User)
        allow(User).to receive(:find_by).with(id: 123).and_return(user)
        expect(user).to receive(:update).with(
          email: 'updated@example.com',
          name: 'Updated Name'
        )

        checker.refresh_session!
      end

      it 'syncs local Company record' do
        expect(Company).to receive(:from_authlift8).with(profile_response['company'])

        checker.refresh_session!
      end
    end

    context 'when API returns 401' do
      before do
        stub_request(:get, "#{authlift8_site}/api/v1/users/profile")
          .to_return(status: 401, body: '{"error": "Unauthorized"}')
      end

      it 'returns false' do
        expect(checker.refresh_session!).to be false
      end
    end

    context 'when API returns 500' do
      before do
        stub_request(:get, "#{authlift8_site}/api/v1/users/profile")
          .to_return(status: 500, body: '{"error": "Internal Server Error"}')
      end

      it 'returns false' do
        expect(checker.refresh_session!).to be false
      end
    end

    context 'when API call times out' do
      before do
        stub_request(:get, "#{authlift8_site}/api/v1/users/profile")
          .to_timeout
      end

      it 'returns false' do
        expect(checker.refresh_session!).to be false
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/API error/)

        checker.refresh_session!
      end
    end

    context 'when API returns invalid JSON' do
      before do
        stub_request(:get, "#{authlift8_site}/api/v1/users/profile")
          .to_return(status: 200, body: 'invalid json', headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns false' do
        expect(checker.refresh_session!).to be false
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/API error/)

        checker.refresh_session!
      end
    end

    context 'when profile has no company' do
      let(:profile_response) do
        {
          'id' => 123,
          'email' => 'updated@example.com',
          'full_name' => 'Updated Name',
          'locale' => 'en',
          'company' => nil,
          'membership' => nil
        }
      end

      before do
        stub_request(:get, "#{authlift8_site}/api/v1/users/profile")
          .to_return(
            status: 200,
            body: profile_response.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        allow(User).to receive(:find_by).and_return(nil)
      end

      it 'updates user data without company' do
        checker.refresh_session!

        expect(session[:email]).to eq('updated@example.com')
        expect(session[:user_name]).to eq('Updated Name')
      end

      it 'does not call Company.from_authlift8' do
        expect(Company).not_to receive(:from_authlift8)

        checker.refresh_session!
      end
    end

    context 'when company has no customer_groups' do
      let(:profile_response) do
        {
          'id' => 123,
          'email' => 'updated@example.com',
          'full_name' => 'Updated Name',
          'locale' => 'en',
          'company' => {
            'id' => 456,
            'code' => 'ACME',
            'name' => 'Acme Corp',
            'customer_groups' => nil
          },
          'membership' => {
            'role' => 'member',
            'scopes' => []
          }
        }
      end

      before do
        stub_request(:get, "#{authlift8_site}/api/v1/users/profile")
          .to_return(
            status: 200,
            body: profile_response.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        allow(User).to receive(:find_by).and_return(nil)
        allow(Company).to receive(:from_authlift8).and_return(nil)
      end

      it 'sets customer_groups to empty array' do
        checker.refresh_session!

        expect(session[:customer_groups]).to eq([])
      end
    end
  end

  describe 'integration scenario' do
    let(:authlift8_site) { ENV.fetch('AUTHLIFT8_SITE', 'http://localhost:3231') }

    it 'detects stale session and refreshes' do
      # Set up a stale session
      redis.set('session_version:user:123', 2000)

      expect(checker.needs_refresh?).to be true

      # Mock the API call
      profile_response = {
        'id' => 123,
        'email' => 'new@example.com',
        'full_name' => 'New Name',
        'locale' => 'en',
        'company' => {
          'id' => 456,
          'code' => 'ACME',
          'name' => 'Acme Corp',
          'customer_groups' => []
        },
        'membership' => {
          'role' => 'admin',
          'scopes' => []
        }
      }

      stub_request(:get, "#{authlift8_site}/api/v1/users/profile")
        .to_return(
          status: 200,
          body: profile_response.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      allow(User).to receive(:find_by).and_return(nil)
      allow(Company).to receive(:from_authlift8).and_return(nil)

      expect(checker.refresh_session!).to be true
      expect(session[:email]).to eq('new@example.com')
      expect(session[:session_version_user]).to eq(2000)

      # After refresh, session should be current
      expect(checker.needs_refresh?).to be false
    end
  end
end
