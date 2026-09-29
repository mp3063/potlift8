# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Inline attribute editing', type: :system, js: true do
  let(:company) { create(:company, code: "TEST#{SecureRandom.hex(4).upcase}", name: 'Test Company') }
  let(:current_user) { create(:user, company: company, name: 'Test User') }
  let(:product) { create(:product, company: company) }
  let(:price) { company.product_attributes.find_by!(code: 'price') }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(current_user)
    allow_any_instance_of(ApplicationController).to receive(:current_company).and_return({
      id: company.id,
      code: company.code,
      name: company.name
    })
    allow_any_instance_of(ApplicationController).to receive(:current_potlift_company).and_return(company)
    allow_any_instance_of(ApplicationController).to receive(:authenticated?).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:pundit_user).and_return(
      UserContext.new(nil, "admin", [ "read", "write" ], company)
    )
  end

  it 'shows the new price in the row after Save without a reload' do
    create(:product_attribute_value, product: product, product_attribute: price, value: '1234')
    row_id = "value_product_attribute_#{price.id}"

    visit product_path(product)
    page.execute_script('window.noReloadMarker = true')

    find("##{row_id}").hover
    within("##{row_id}") do
      expect(page).to have_text('12,34 €')
      find("button[aria-label='Edit Price']").click
      fill_in "#{row_id}_input", with: '12,35'
      click_button 'Save'
    end

    expect(page).to have_css("##{row_id}", text: '12,35 €')
    expect(page).not_to have_css("##{row_id}", text: '12,34 €')
    expect(page.evaluate_script('window.noReloadMarker')).to be(true)
    expect(price.product_attribute_values.find_by(product: product).value).to eq('1235')
  end
end
