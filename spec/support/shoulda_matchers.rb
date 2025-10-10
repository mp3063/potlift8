# frozen_string_literal: true

# Shoulda Matchers configuration for RSpec
# Provides elegant, readable matchers for common Rails functionality
#
# Usage examples:
#
#   # Model validations
#   RSpec.describe User, type: :model do
#     it { should validate_presence_of(:email) }
#     it { should validate_uniqueness_of(:email).case_insensitive }
#     it { should validate_length_of(:password).is_at_least(8) }
#     it { should allow_value('user@example.com').for(:email) }
#   end
#
#   # Associations
#   RSpec.describe Post, type: :model do
#     it { should belong_to(:user) }
#     it { should have_many(:comments).dependent(:destroy) }
#     it { should have_one(:featured_image) }
#   end
#
#   # Database columns
#   RSpec.describe User, type: :model do
#     it { should have_db_column(:email).of_type(:string) }
#     it { should have_db_index(:email).unique }
#   end
#
#   # Controller matchers
#   RSpec.describe UsersController, type: :controller do
#     describe "GET #index" do
#       it { should respond_with(:success) }
#       it { should render_template(:index) }
#       it { should set_flash[:notice] }
#     end
#   end

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    # Choose a test framework:
    with.test_framework :rspec

    # Choose one or more libraries:
    with.library :active_record
    with.library :active_model
    with.library :action_controller

    # Or, choose all of the above:
    # with.library :rails
  end
end
