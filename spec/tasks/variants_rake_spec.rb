# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'variants:inherit_attributes rake task' do
  before(:all) do
    Rails.application.load_tasks
  end

  let(:company) { create(:company) }
  let(:weight) { company.product_attributes.find_by!(code: 'weight') }
  let(:parent) { create(:product, :configurable_variant, company: company) }
  let(:variant) { create(:product, :sellable, company: company) }

  def run_task
    Rake::Task['variants:inherit_attributes'].reenable
    Rake::Task['variants:inherit_attributes'].invoke
  end

  before do
    # Linked before the parent had a weight, so the create callback copied nothing
    create(:product_configuration, superproduct: parent, subproduct: variant)
    create(:product_attribute_value, product: parent, product_attribute: weight, value: '30')
  end

  it 'copies missing values into existing variants' do
    expect { run_task }.to output(/1 values copied into 1 variants/).to_stdout

    expect(variant.product_attribute_values.find_by(product_attribute: weight).value).to eq('30')
  end

  it 'copies nothing on a second run' do
    expect { run_task }.to output.to_stdout

    expect { run_task }.to output(/0 values copied into 0 variants/).to_stdout
  end
end
