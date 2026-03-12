# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'product_attributes:ensure_system rake task' do
  before(:all) do
    Rails.application.load_tasks
  end

  before do
    Rake::Task['product_attributes:ensure_system'].reenable
  end

  it 'runs without error for existing companies' do
    company = create(:company)
    expect { Rake::Task['product_attributes:ensure_system'].invoke }.to output(/System attributes ensured/).to_stdout
  end

  it 'is idempotent — does not create duplicates on repeated runs' do
    company = create(:company)
    initial_count = company.product_attributes.where(system: true).count

    Rake::Task['product_attributes:ensure_system'].invoke
    Rake::Task['product_attributes:ensure_system'].reenable
    Rake::Task['product_attributes:ensure_system'].invoke

    expect(company.reload.product_attributes.where(system: true).count).to eq(initial_count)
  end

  it 'processes all companies' do
    companies = create_list(:company, 3)

    expect { Rake::Task['product_attributes:ensure_system'].invoke }.to output(
      /System attributes ensured.*System attributes ensured.*System attributes ensured/m
    ).to_stdout
  end
end
