# frozen_string_literal: true

namespace :product_attributes do
  desc "Ensure all companies have system attributes"
  task ensure_system: :environment do
    Company.find_each do |company|
      ProductAttribute.ensure_system_attributes!(company)
      puts "System attributes ensured for #{company.name} (#{company.code})"
    end
  end
end
