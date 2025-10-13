# frozen_string_literal: true

require 'rails_helper'
require 'authlift/client'

RSpec.describe Authlift::Client do
  let(:client) { described_class.new }
  let(:public_key) { OpenSSL::PKey::RSA.new(2048) }
  let(:private_key) { public_key }

  before do
    ENV['AUTHLIFT8_CLIENT_ID'] = 'test_client_id'
    ENV['AUTHLIFT8_CLIENT_SECRET'] = 'test_client_secret'
    ENV['AUTHLIFT8_SITE'] = 'https://authlift8.test'
    ENV['AUTHLIFT8_REDIRECT_URI'] = 'https://potlift8.test/auth/callback'

    # Clear cache before each test to avoid cross-test pollution
    Rails.cache.clear
  end

  describe '#initialize' do
    it 'initializes with environment variables' do
      expect(client.client_id).to eq('test_client_id')
      expect(client.client_secret).to eq('test_client_secret')
      expect(client.site).to eq('https://authlift8.test')
      expect(client.redirect_uri).to eq('https://potlift8.test/auth/callback')
    end

    context 'when configuration is missing' do
      before do
        ENV.delete('AUTHLIFT8_CLIENT_ID')
      end

      it 'raises ConfigurationError' do
        expect {
          described_class.new
        }.to raise_error(Authlift::Client::ConfigurationError, /CLIENT_ID is required/)
      end
    end

    context 'when site URL is invalid' do
      before do
        ENV['AUTHLIFT8_SITE'] = 'invalid-url'
      end

      it 'raises ConfigurationError' do
        expect {
          described_class.new
        }.to raise_error(Authlift::Client::ConfigurationError, /must be a valid URL/)
      end
    end
  end

  describe '#authorization_url' do
    let(:state) { SecureRandom.hex(32) }

    it 'generates authorization URL with state' do
      url = client.authorization_url(state: state)

      expect(url).to include('https://authlift8.test/oauth/authorize')
      expect(url).to include("state=#{state}")
      expect(url).to include('client_id=test_client_id')
      expect(url).to include('redirect_uri=')
      expect(url).to include('scope=public')
    end

    context 'with custom scope' do
      it 'includes custom scope' do
        url = client.authorization_url(state: state, scope: 'openid read write')

        # URL encoding uses %20 for spaces, not +
        expect(url).to include('scope=openid%20read%20write')
      end
    end

    context 'with invalid state' do
      it 'raises error for blank state' do
        expect {
          client.authorization_url(state: '')
        }.to raise_error(ArgumentError, /state cannot be blank/)
      end

      it 'raises error for short state' do
        expect {
          client.authorization_url(state: 'short')
        }.to raise_error(ArgumentError, /at least 32 characters/)
      end
    end
  end

  describe '#exchange_code' do
    let(:code) { 'auth_code_123' }
    let(:state) { 'state_token_456' }
    let(:expected_state) { 'state_token_456' }
    let(:refresh_token) { 'refresh_token_xyz' }

    # In Authlift8/Doorkeeper, the access_token IS the JWT containing user payload
    let(:access_token_payload) do
      {
        'sub' => 'user_123',
        'email' => 'user@example.com',
        'iss' => 'https://authlift8.test',
        'iat' => Time.now.to_i,
        'exp' => 1.hour.from_now.to_i
      }
    end
    let(:access_token) { JWT.encode(access_token_payload, private_key, 'RS256') }

    let(:oauth_token) do
      instance_double(OAuth2::AccessToken,
                      token: access_token,
                      refresh_token: refresh_token,
                      expires_at: 1.hour.from_now.to_i,
                      params: {}) # Authlift8 doesn't return id_token
    end

    before do
      allow(client).to receive(:fetch_public_key).and_return(public_key)
      allow_any_instance_of(OAuth2::Strategy::AuthCode).to receive(:get_token).and_return(oauth_token)
    end

    it 'validates state token' do
      expect {
        client.exchange_code(code, 'wrong_state', expected_state)
      }.to raise_error(Authlift::Client::AuthenticationError, /State token mismatch/)
    end

    it 'exchanges code for tokens and decodes access_token JWT' do
      result = client.exchange_code(code, state, expected_state)

      expect(result[:access_token]).to eq(access_token)
      expect(result[:refresh_token]).to eq(refresh_token)
      expect(result[:id_token]).to be_nil # Authlift8 doesn't use separate id_token
      expect(result[:user_payload]['sub']).to eq('user_123')
      expect(result[:user_payload]['email']).to eq('user@example.com')
    end

    context 'when OAuth2 exchange fails' do
      before do
        allow_any_instance_of(OAuth2::Strategy::AuthCode).to receive(:get_token)
          .and_raise(OAuth2::Error.new(double(status: 400, body: 'Bad request')))
      end

      it 'raises AuthenticationError' do
        expect {
          client.exchange_code(code, state, expected_state)
        }.to raise_error(Authlift::Client::AuthenticationError, /Token exchange failed/)
      end
    end
  end

  describe '#decode_jwt' do
    let(:payload) do
      {
        'sub' => 'user_123',
        'email' => 'user@example.com',
        'iss' => 'https://authlift8.test',
        'iat' => Time.now.to_i,
        'exp' => 1.hour.from_now.to_i
      }
    end
    let(:token) { JWT.encode(payload, private_key, 'RS256') }

    before do
      allow(client).to receive(:fetch_public_key).and_return(public_key)
    end

    it 'decodes and validates JWT token' do
      result = client.decode_jwt(token)

      expect(result['sub']).to eq('user_123')
      expect(result['email']).to eq('user@example.com')
    end

    it 'validates RS256 signature' do
      # Token signed with different key should fail
      wrong_key = OpenSSL::PKey::RSA.new(2048)
      wrong_token = JWT.encode(payload, wrong_key, 'RS256')

      expect {
        client.decode_jwt(wrong_token)
      }.to raise_error(Authlift::Client::TokenValidationError)
    end

    context 'when token is expired' do
      let(:expired_payload) do
        payload.merge('exp' => 1.hour.ago.to_i)
      end
      let(:expired_token) { JWT.encode(expired_payload, private_key, 'RS256') }

      it 'raises TokenValidationError' do
        expect {
          client.decode_jwt(expired_token)
        }.to raise_error(Authlift::Client::TokenValidationError, /expired/)
      end
    end

    context 'when required claims are missing' do
      let(:invalid_payload) do
        {
          'email' => 'user@example.com',
          'iss' => 'https://authlift8.test',
          'iat' => Time.now.to_i,
          'exp' => 1.hour.from_now.to_i
          # Missing 'sub' claim
        }
      end
      let(:invalid_token) { JWT.encode(invalid_payload, private_key, 'RS256') }

      it 'raises TokenValidationError' do
        expect {
          client.decode_jwt(invalid_token)
        }.to raise_error(Authlift::Client::TokenValidationError, /Missing required claims/)
      end
    end

    context 'when token is blank' do
      it 'raises ArgumentError' do
        expect {
          client.decode_jwt('')
        }.to raise_error(ArgumentError, /token cannot be blank/)
      end
    end

    context 'when verification fails and retries' do
      it 'refreshes public key and retries once' do
        allow(client).to receive(:fetch_public_key).and_return(public_key)
        allow(client).to receive(:clear_public_key_cache!)

        # First call fails, second succeeds
        call_count = 0
        allow(JWT).to receive(:decode) do
          call_count += 1
          if call_count == 1
            raise JWT::VerificationError
          else
            [payload, {}]
          end
        end

        result = client.decode_jwt(token)

        expect(client).to have_received(:clear_public_key_cache!).once
        expect(result['sub']).to eq('user_123')
      end
    end
  end

  describe '#refresh_token' do
    let(:refresh_token_value) { 'refresh_token_abc' }
    let(:new_access_token) { 'new_access_token' }
    let(:new_refresh_token) { 'new_refresh_token' }

    let(:new_oauth_token) do
      instance_double(OAuth2::AccessToken,
                      token: new_access_token,
                      refresh_token: new_refresh_token,
                      expires_at: 1.hour.from_now.to_i)
    end

    let(:old_oauth_token) do
      instance_double(OAuth2::AccessToken,
                      refresh!: new_oauth_token)
    end

    before do
      allow(OAuth2::AccessToken).to receive(:new).and_return(old_oauth_token)
    end

    it 'refreshes access token' do
      result = client.refresh_token(refresh_token_value)

      expect(result[:access_token]).to eq(new_access_token)
      expect(result[:refresh_token]).to eq(new_refresh_token)
      expect(result[:expires_at]).to be_present
    end

    context 'when refresh_token is blank' do
      it 'raises ArgumentError' do
        expect {
          client.refresh_token('')
        }.to raise_error(ArgumentError, /refresh_token cannot be blank/)
      end
    end

    context 'when refresh fails' do
      before do
        allow(old_oauth_token).to receive(:refresh!)
          .and_raise(OAuth2::Error.new(double(status: 401, body: 'Invalid token')))
      end

      it 'raises AuthenticationError' do
        expect {
          client.refresh_token(refresh_token_value)
        }.to raise_error(Authlift::Client::AuthenticationError, /Token refresh failed/)
      end
    end
  end

  describe '#token_expired?' do
    context 'when expires_at is nil' do
      it 'returns true' do
        expect(client.token_expired?(nil)).to be true
      end
    end

    context 'with integer timestamp' do
      it 'returns true for expired token' do
        expired_at = 1.minute.ago.to_i
        expect(client.token_expired?(expired_at)).to be true
      end

      it 'returns true for token expiring soon (within buffer)' do
        expires_soon = 4.minutes.from_now.to_i
        expect(client.token_expired?(expires_soon)).to be true
      end

      it 'returns false for token not expiring soon' do
        expires_later = 10.minutes.from_now.to_i
        expect(client.token_expired?(expires_later)).to be false
      end
    end

    context 'with Time object' do
      it 'handles Time objects' do
        expires_later = 10.minutes.from_now
        expect(client.token_expired?(expires_later)).to be false
      end
    end

    context 'with custom buffer' do
      it 'uses custom buffer seconds' do
        expires_at = 15.minutes.from_now.to_i
        expect(client.token_expired?(expires_at, buffer_seconds: 20.minutes)).to be true
      end
    end
  end

  describe '#fetch_public_key' do
    let(:jwks_response) do
      {
        'keys' => [
          {
            'kty' => 'RSA',
            'n' => Base64.urlsafe_encode64(public_key.n.to_s(2), padding: false),
            'e' => Base64.urlsafe_encode64(public_key.e.to_s(2), padding: false)
          }
        ]
      }.to_json
    end

    before do
      stub_request(:get, 'https://authlift8.test/api/v1/.well-known/jwks.json')
        .to_return(status: 200, body: jwks_response, headers: { 'Content-Type' => 'application/json' })
    end

    it 'fetches public key from server' do
      key = client.send(:fetch_public_key)

      expect(key).to be_a(OpenSSL::PKey::RSA)
    end

    it 'caches public key' do
      # Cache is already cleared in before block
      # First call fetches from server
      key1 = client.send(:fetch_public_key)
      expect(key1).to be_a(OpenSSL::PKey::RSA)

      # Second call uses cache (no additional HTTP request)
      key2 = client.send(:fetch_public_key)
      expect(key2).to be_a(OpenSSL::PKey::RSA)

      # Should only make one HTTP request (second was cached)
      expect(WebMock).to have_requested(:get, 'https://authlift8.test/api/v1/.well-known/jwks.json').once
    end

    context 'when server returns error' do
      before do
        stub_request(:get, 'https://authlift8.test/api/v1/.well-known/jwks.json')
          .to_return(status: 500)
      end

      it 'raises PublicKeyError' do
        expect {
          client.send(:fetch_public_key)
        }.to raise_error(Authlift::Client::PublicKeyError, /Failed to fetch public key/)
      end
    end

    context 'when JWKS has no keys' do
      before do
        stub_request(:get, 'https://authlift8.test/api/v1/.well-known/jwks.json')
          .to_return(status: 200, body: { 'keys' => [] }.to_json)
      end

      it 'raises PublicKeyError' do
        expect {
          client.send(:fetch_public_key)
        }.to raise_error(Authlift::Client::PublicKeyError, /No keys found/)
      end
    end
  end

  describe '#validate_state!' do
    it 'passes with matching state tokens' do
      expect {
        client.send(:validate_state!, 'token123', 'token123')
      }.not_to raise_error
    end

    it 'uses timing-safe comparison' do
      expect(ActiveSupport::SecurityUtils).to receive(:secure_compare)
        .with('token123', 'token123')
        .and_return(true)

      client.send(:validate_state!, 'token123', 'token123')
    end

    context 'with mismatched tokens' do
      it 'raises AuthenticationError' do
        expect {
          client.send(:validate_state!, 'token123', 'token456')
        }.to raise_error(Authlift::Client::AuthenticationError, /State token mismatch/)
      end
    end

    context 'with blank state' do
      it 'raises AuthenticationError' do
        expect {
          client.send(:validate_state!, '', 'token123')
        }.to raise_error(Authlift::Client::AuthenticationError, /Missing state token/)
      end
    end

    context 'with blank expected_state' do
      it 'raises AuthenticationError' do
        expect {
          client.send(:validate_state!, 'token123', '')
        }.to raise_error(Authlift::Client::AuthenticationError, /Missing state token/)
      end
    end
  end

  describe '#clear_public_key_cache!' do
    let(:jwks_response) do
      {
        'keys' => [
          {
            'kty' => 'RSA',
            'n' => Base64.urlsafe_encode64(public_key.n.to_s(2), padding: false),
            'e' => Base64.urlsafe_encode64(public_key.e.to_s(2), padding: false)
          }
        ]
      }.to_json
    end

    before do
      stub_request(:get, 'https://authlift8.test/api/v1/.well-known/jwks.json')
        .to_return(status: 200, body: jwks_response, headers: { 'Content-Type' => 'application/json' })
    end

    it 'clears cached public key' do
      # Fetch public key which stores it in cache
      key = client.send(:fetch_public_key)
      expect(key).to be_a(OpenSSL::PKey::RSA)

      # Verify it's cached
      cache_key = client.send(:public_key_cache_key)
      cached_value = Rails.cache.read(cache_key)
      expect(cached_value).to be_present

      # Clear the cache
      client.clear_public_key_cache!

      # Verify it's no longer cached
      expect(Rails.cache.exist?(cache_key)).to be false
    end
  end
end
