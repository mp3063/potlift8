class SwitchApiTokenToDigest < ActiveRecord::Migration[8.0]
  def up
    add_column :companies, :api_token_digest, :string
    add_index :companies, :api_token_digest, unique: true

    # Backfill digests from existing plaintext tokens using the same
    # algorithm Rails has_secure_token uses internally (SHA-256 hex)
    Company.where.not(api_token: nil).find_each do |company|
      digest = ::OpenSSL::Digest::SHA256.hexdigest(company.api_token)
      company.update_column(:api_token_digest, digest)
    end
  end

  def down
    remove_index :companies, :api_token_digest
    remove_column :companies, :api_token_digest
  end
end
