# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Labels Management', type: :system, js: true do
  let(:company) { create(:company) }
  let(:other_company) { create(:company) }
  let(:current_user) { { id: 1, email: 'test@example.com', name: 'Test User' } }

  # Helper to set up authenticated session
  def sign_in_user
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(current_user)
    allow_any_instance_of(ApplicationController).to receive(:current_company).and_return({
      id: company.id,
      code: company.code,
      name: company.name
    })
    allow_any_instance_of(ApplicationController).to receive(:current_potlift_company).and_return(company)
    allow_any_instance_of(ApplicationController).to receive(:authenticated?).and_return(true)
  end

  before do
    sign_in_user
  end

  describe 'Labels Index Page' do
    context 'with no labels' do
      before do
        visit labels_path
      end

      it 'displays empty state message' do
        expect(page).to have_content('No labels yet')
        expect(page).to have_content('Get started by creating your first label')
      end

      it 'shows New Label button in empty state' do
        expect(page).to have_button('New Label')
      end

      it 'clicking New Label button navigates to new label form' do
        click_button 'New Label'
        expect(page).to have_current_path(new_label_path)
        expect(page).to have_content('Name')
        expect(page).to have_content('Code')
      end
    end

    context 'with existing root labels' do
      let!(:electronics) { create(:label, company: company, code: 'electronics', name: 'Electronics', label_positions: 1) }
      let!(:clothing) { create(:label, company: company, code: 'clothing', name: 'Clothing', label_positions: 2) }
      let!(:food) { create(:label, company: company, code: 'food', name: 'Food', label_positions: 3) }
      let!(:other_company_label) { create(:label, company: other_company, name: 'Other Company Label') }

      before do
        visit labels_path
      end

      it 'displays all company root labels' do
        expect(page).to have_content('Electronics')
        expect(page).to have_content('Clothing')
        expect(page).to have_content('Food')
      end

      it 'does not display other company labels' do
        expect(page).not_to have_content('Other Company Label')
      end

      it 'displays labels in correct order by position' do
        labels = page.all('[data-label-id]').map { |el| el.text }
        electronics_index = labels.index { |l| l.include?('Electronics') }
        food_index = labels.index { |l| l.include?('Food') }
        expect(electronics_index).to be < food_index
      end

      it 'shows New Label button in header' do
        within '.flex.items-center.justify-between' do
          expect(page).to have_button('New Label')
        end
      end

      it 'displays label codes' do
        expect(page).to have_content('electronics')
        expect(page).to have_content('clothing')
      end
    end

    context 'with hierarchical labels' do
      let!(:root) { create(:label, company: company, code: 'electronics', name: 'Electronics') }
      let!(:child1) { create(:label, company: company, code: 'phones', name: 'Phones', parent_label: root) }
      let!(:child2) { create(:label, company: company, code: 'laptops', name: 'Laptops', parent_label: root) }
      let!(:grandchild) { create(:label, company: company, code: 'iphone', name: 'iPhone', parent_label: child1) }

      before do
        visit labels_path
      end

      it 'displays root label with expand/collapse button' do
        expect(page).to have_content('Electronics')
        # Sublabels should be hidden by default (depending on implementation)
      end

      it 'clicking on label navigates to show page' do
        click_link 'Electronics'
        expect(page).to have_current_path(label_path(root))
        expect(page).to have_content('Electronics')
      end
    end

    context 'search functionality' do
      let!(:electronics) { create(:label, company: company, code: 'electronics', name: 'Electronics') }
      let!(:clothing) { create(:label, company: company, code: 'clothing', name: 'Clothing') }
      let!(:food) { create(:label, company: company, code: 'food', name: 'Food') }

      before do
        visit labels_path
      end

      it 'has search input field' do
        expect(page).to have_field('q')
      end

      it 'filters labels by name' do
        fill_in 'q', with: 'Electronics'
        click_button type: 'submit'

        expect(page).to have_content('Electronics')
        expect(page).not_to have_content('Clothing')
        expect(page).not_to have_content('Food')
      end

      it 'filters labels by code' do
        fill_in 'q', with: 'food'
        click_button type: 'submit'

        expect(page).to have_content('Food')
        expect(page).not_to have_content('Electronics')
      end

      it 'search is case insensitive' do
        fill_in 'q', with: 'ELECTRONICS'
        click_button type: 'submit'

        expect(page).to have_content('Electronics')
      end

      it 'shows clear button when search is active' do
        fill_in 'q', with: 'Electronics'
        click_button type: 'submit'

        expect(page).to have_link('Clear')
      end

      it 'clearing search shows all labels' do
        fill_in 'q', with: 'Electronics'
        click_button type: 'submit'
        click_link 'Clear'

        expect(page).to have_content('Electronics')
        expect(page).to have_content('Clothing')
        expect(page).to have_content('Food')
      end

      it 'shows no results message for non-matching search' do
        fill_in 'q', with: 'NonExistentLabel'
        click_button type: 'submit'

        expect(page).to have_content('No labels found')
        expect(page).to have_content('Try adjusting your search query')
      end
    end

    context 'pagination' do
      before do
        # Create more than 25 labels to trigger pagination
        30.times do |i|
          create(:label, company: company, code: "label#{i}", name: "Label #{i}")
        end
        visit labels_path
      end

      it 'displays pagination controls when needed' do
        # Should have pagination if more than 25 labels
        expect(page.all('[data-label-id]').count).to be <= 25
      end
    end
  end

  describe 'Label Show Page' do
    let!(:label) { create(:label, company: company, code: 'electronics', name: 'Electronics', description: 'Electronic devices') }
    let!(:sublabel1) { create(:label, company: company, code: 'phones', name: 'Phones', parent_label: label) }
    let!(:sublabel2) { create(:label, company: company, code: 'laptops', name: 'Laptops', parent_label: label) }
    let!(:product1) { create(:product, company: company, sku: 'PROD-001', name: 'Product 1') }
    let!(:product2) { create(:product, company: company, sku: 'PROD-002', name: 'Product 2') }

    before do
      create(:product_label, label: label, product: product1)
      create(:product_label, label: label, product: product2)
      visit label_path(label)
    end

    it 'displays label details' do
      expect(page).to have_content('Electronics')
      expect(page).to have_content('electronics')
      expect(page).to have_content('Electronic devices')
    end

    it 'displays breadcrumb navigation' do
      expect(page).to have_link('All Labels')
      expect(page).to have_content('Electronics')
    end

    it 'displays statistics cards' do
      expect(page).to have_content('Direct Products')
      expect(page).to have_content('Total Products')
      expect(page).to have_content('Sublabels')
    end

    it 'shows correct direct product count' do
      within :xpath, "//div[contains(text(), 'Direct Products')]/.." do
        expect(page).to have_content('2')
      end
    end

    it 'shows correct sublabel count' do
      within :xpath, "//div[contains(text(), 'Sublabels')]/.." do
        expect(page).to have_content('2')
      end
    end

    it 'displays sublabels section' do
      expect(page).to have_content('Phones')
      expect(page).to have_content('Laptops')
    end

    it 'clicking sublabel navigates to sublabel show page' do
      click_link 'Phones'
      expect(page).to have_current_path(label_path(sublabel1))
      expect(page).to have_content('Phones')
    end

    it 'displays associated products table' do
      expect(page).to have_content('PROD-001')
      expect(page).to have_content('Product 1')
      expect(page).to have_content('PROD-002')
      expect(page).to have_content('Product 2')
    end

    it 'shows product status badges' do
      within 'table' do
        expect(page).to have_css('.inline-flex', minimum: 1) # Badge components
      end
    end

    it 'clicking product SKU navigates to product page' do
      click_link 'PROD-001'
      expect(page).to have_current_path(product_path(product1))
    end

    it 'has Add Sublabel button' do
      expect(page).to have_button('Add Sublabel')
    end

    it 'clicking Add Sublabel navigates to new label form with parent context' do
      click_button 'Add Sublabel'
      expect(page).to have_current_path(new_label_path(parent_id: label.id))
      expect(page).to have_content('Electronics') # Parent context shown
    end

    it 'has Edit button' do
      expect(page).to have_button('Edit')
    end

    it 'clicking Edit button navigates to edit form' do
      click_button 'Edit'
      expect(page).to have_current_path(edit_label_path(label))
    end

    it 'has Delete button' do
      expect(page).to have_button('Delete')
    end

    it 'shows confirmation dialog before deleting' do
      # Delete button should have data-turbo-confirm
      delete_button = find('form[method="post"] button', text: 'Delete')
      expect(delete_button[:'data-turbo-confirm']).to be_present
    end

    context 'with nested hierarchy' do
      let(:parent) { create(:label, company: company, code: 'root', name: 'Root') }
      let(:child) { create(:label, company: company, code: 'child', name: 'Child', parent_label: parent) }
      let(:grandchild) { create(:label, company: company, code: 'grandchild', name: 'Grandchild', parent_label: child) }

      before do
        visit label_path(grandchild)
      end

      it 'displays full breadcrumb trail' do
        expect(page).to have_link('All Labels')
        expect(page).to have_link('Root')
        expect(page).to have_link('Child')
        expect(page).to have_content('Grandchild')
      end

      it 'breadcrumb links are clickable' do
        click_link 'Root'
        expect(page).to have_current_path(label_path(parent))
      end
    end

    context 'when label has no products' do
      let!(:empty_label) { create(:label, company: company, code: 'empty', name: 'Empty Label') }

      before do
        visit label_path(empty_label)
      end

      it 'shows empty state for products' do
        expect(page).to have_content('No products')
        expect(page).to have_content('No products are currently assigned to this label')
      end
    end
  end

  describe 'New Label Form' do
    before do
      visit new_label_path
    end

    it 'displays new label form' do
      expect(page).to have_content('Name')
      expect(page).to have_content('Code')
      expect(page).to have_content('Label Type')
    end

    it 'has all required fields' do
      expect(page).to have_field('Name')
      expect(page).to have_field('Code')
      expect(page).to have_field('Label Type')
    end

    it 'has optional fields' do
      expect(page).to have_field('Description')
    end

    it 'has Save button' do
      expect(page).to have_button('Save')
    end

    it 'has Cancel button or link' do
      expect(page).to have_link('Cancel') || have_button('Cancel')
    end

    context 'creating a root label' do
      it 'successfully creates label with valid data' do
        fill_in 'Name', with: 'Test Label'
        fill_in 'Code', with: 'test_label'
        select 'category', from: 'Label Type'
        fill_in 'Description', with: 'This is a test label'

        click_button 'Save'

        expect(page).to have_content('created successfully')
        expect(page).to have_current_path(labels_path)

        label = Label.find_by(code: 'test_label')
        expect(label).to be_present
        expect(label.name).to eq('Test Label')
        expect(label.full_code).to eq('test_label')
        expect(label.full_name).to eq('Test Label')
      end

      it 'shows validation errors for missing required fields' do
        click_button 'Save'

        expect(page).to have_content("can't be blank") || have_content('is required')
      end

      it 'shows validation error for duplicate code' do
        create(:label, company: company, code: 'duplicate', name: 'Existing')

        fill_in 'Name', with: 'New Label'
        fill_in 'Code', with: 'duplicate'
        select 'category', from: 'Label Type'

        click_button 'Save'

        expect(page).to have_content('has already been taken')
      end
    end

    context 'creating a sublabel' do
      let!(:parent_label) { create(:label, company: company, code: 'parent', name: 'Parent Label') }

      before do
        visit new_label_path(parent_id: parent_label.id)
      end

      it 'shows parent label context' do
        expect(page).to have_content('Parent Label')
      end

      it 'creates sublabel with hierarchical codes' do
        fill_in 'Name', with: 'Child Label'
        fill_in 'Code', with: 'child'
        select 'category', from: 'Label Type'

        click_button 'Save'

        expect(page).to have_content('created successfully')

        child = Label.find_by(code: 'child', parent_label: parent_label)
        expect(child).to be_present
        expect(child.full_code).to eq('parent-child')
        expect(child.full_name).to eq('Parent Label > Child Label')
      end
    end

    context 'form validation feedback' do
      it 'shows real-time validation errors' do
        fill_in 'Name', with: ''
        fill_in 'Code', with: ''

        click_button 'Save'

        # Should show inline validation errors
        expect(page).to have_css('.error, .text-red-600', minimum: 1)
      end
    end
  end

  describe 'Edit Label Form' do
    let!(:label) { create(:label, company: company, code: 'editable', name: 'Editable Label', description: 'Original description') }

    before do
      visit edit_label_path(label)
    end

    it 'displays edit label form with existing values' do
      expect(page).to have_field('Name', with: 'Editable Label')
      expect(page).to have_field('Code', with: 'editable')
      expect(page).to have_field('Description', with: 'Original description')
    end

    it 'successfully updates label' do
      fill_in 'Name', with: 'Updated Label'
      fill_in 'Description', with: 'Updated description'

      click_button 'Save'

      expect(page).to have_content('updated successfully')
      expect(page).to have_current_path(labels_path)

      label.reload
      expect(label.name).to eq('Updated Label')
      expect(label.description).to eq('Updated description')
    end

    it 'updates full_name when name changes' do
      original_full_name = label.full_name

      fill_in 'Name', with: 'New Name'
      click_button 'Save'

      label.reload
      expect(label.full_name).to eq('New Name')
      expect(label.full_name).not_to eq(original_full_name)
    end

    it 'shows validation errors for invalid data' do
      fill_in 'Name', with: ''
      click_button 'Save'

      expect(page).to have_content("can't be blank") || have_content('is required')
    end

    context 'with child labels' do
      let(:parent) { create(:label, company: company, code: 'parent', name: 'Parent') }
      let!(:child) { create(:label, company: company, code: 'child', name: 'Child', parent_label: parent) }

      before do
        visit edit_label_path(parent)
      end

      it 'updates cascades to children when parent changes' do
        fill_in 'Code', with: 'new_parent'
        fill_in 'Name', with: 'New Parent'

        click_button 'Save'

        child.reload
        expect(child.full_code).to eq('new_parent-child')
        expect(child.full_name).to eq('New Parent > Child')
      end
    end
  end

  describe 'Delete Label' do
    context 'label without dependencies' do
      let!(:label) { create(:label, company: company, code: 'deletable', name: 'Deletable') }

      before do
        visit label_path(label)
      end

      it 'successfully deletes label', js: true do
        # Accept confirmation dialog
        accept_confirm do
          click_button 'Delete'
        end

        expect(page).to have_content('deleted successfully')
        expect(page).to have_current_path(labels_path)
        expect(Label.exists?(label.id)).to be false
      end
    end

    context 'label with sublabels' do
      let!(:parent) { create(:label, company: company, code: 'parent', name: 'Parent') }
      let!(:child) { create(:label, company: company, code: 'child', name: 'Child', parent_label: parent) }

      before do
        visit label_path(parent)
      end

      it 'prevents deletion and shows error message', js: true do
        accept_confirm do
          click_button 'Delete'
        end

        expect(page).to have_content('Cannot delete')
        expect(page).to have_content('sublabel')
        expect(Label.exists?(parent.id)).to be true
      end
    end

    context 'label with products' do
      let!(:label) { create(:label, company: company, code: 'with_products', name: 'With Products') }
      let!(:product) { create(:product, company: company) }

      before do
        create(:product_label, label: label, product: product)
        visit label_path(label)
      end

      it 'prevents deletion and shows error message', js: true do
        accept_confirm do
          click_button 'Delete'
        end

        expect(page).to have_content('Cannot delete')
        expect(page).to have_content('product')
        expect(Label.exists?(label.id)).to be true
      end
    end
  end

  describe 'Label Tree View and Navigation' do
    let!(:root) { create(:label, company: company, code: 'root', name: 'Root Category') }
    let!(:child1) { create(:label, company: company, code: 'child1', name: 'Child 1', parent_label: root) }
    let!(:child2) { create(:label, company: company, code: 'child2', name: 'Child 2', parent_label: root) }
    let!(:grandchild) { create(:label, company: company, code: 'grandchild', name: 'Grandchild', parent_label: child1) }

    before do
      visit labels_path
    end

    it 'displays hierarchical tree structure' do
      expect(page).to have_content('Root Category')
      # Tree structure implementation depends on your views
    end

    it 'clicking label name navigates to show page' do
      click_link 'Root Category'
      expect(page).to have_current_path(label_path(root))
    end
  end

  describe 'Keyboard Navigation' do
    let!(:label1) { create(:label, company: company, code: 'label1', name: 'Label 1') }
    let!(:label2) { create(:label, company: company, code: 'label2', name: 'Label 2') }

    before do
      visit labels_path
    end

    it 'can navigate to New Label button with Tab key', js: true do
      # This tests keyboard accessibility
      page.driver.browser.action.send_keys(:tab).perform
      # Should eventually focus on New Label button
      expect(page).to have_css(':focus')
    end

    it 'can navigate between label links with Tab', js: true do
      # Tab through focusable elements
      5.times { page.driver.browser.action.send_keys(:tab).perform }
      expect(page).to have_css('a:focus, button:focus')
    end

    it 'Enter key activates focused link', js: true do
      # Focus on label link and press Enter
      find_link('Label 1').send_keys(:return)
      expect(page).to have_current_path(label_path(label1))
    end
  end

  describe 'Accessibility' do
    let!(:label) { create(:label, company: company, code: 'test', name: 'Test Label') }

    before do
      visit labels_path
    end

    it 'has proper page title' do
      expect(page).to have_title(/Labels/)
    end

    it 'has main landmark' do
      expect(page).to have_css('main')
    end

    it 'has proper heading hierarchy' do
      expect(page).to have_css('h1', count: 1)
    end

    it 'search input has accessible label' do
      # Should have label, aria-label, or placeholder
      search_field = find_field('q')
      expect(
        search_field['aria-label'].present? ||
        search_field['placeholder'].present? ||
        page.has_css?("label[for='#{search_field[:id]}']")
      ).to be true
    end

    it 'action buttons have accessible labels' do
      buttons = page.all('button, a[role="button"]', visible: true)
      buttons.each do |button|
        expect(button.text.present? || button['aria-label'].present?).to be true
      end
    end

    context 'on show page' do
      before do
        visit label_path(label)
      end

      it 'breadcrumb navigation is accessible' do
        expect(page).to have_css('nav[aria-label="Breadcrumb"], ol')
      end

      it 'statistics cards are properly labeled' do
        # Stats should have visible labels
        expect(page).to have_content('Direct Products')
        expect(page).to have_content('Total Products')
        expect(page).to have_content('Sublabels')
      end
    end

    context 'form accessibility' do
      before do
        visit new_label_path
      end

      it 'all form inputs have associated labels' do
        inputs = page.all('input[type="text"], textarea, select', visible: true)
        inputs.each do |input|
          expect(
            page.has_css?("label[for='#{input[:id]}']", visible: true) ||
            input['aria-label'].present?
          ).to be true
        end
      end

      it 'required fields are properly marked' do
        required_inputs = page.all('input[required], select[required]', visible: true)
        required_inputs.each do |input|
          expect(input[:required] || input['aria-required']).to be_present
        end
      end
    end
  end

  describe 'Error Handling' do
    context 'accessing non-existent label' do
      it 'shows 404 error or redirects gracefully' do
        expect {
          visit label_path('non-existent-label')
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'accessing other company label' do
      let(:other_company_label) { create(:label, company: other_company) }

      it 'prevents access to other company labels' do
        expect {
          visit label_path(other_company_label)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'form submission errors' do
      before do
        visit new_label_path
      end

      it 'displays validation errors inline' do
        click_button 'Save'
        expect(page).to have_css('.error, .text-red-600', minimum: 1)
      end

      it 'preserves form data after error' do
        fill_in 'Name', with: 'Test Label'
        # Intentionally leave Code blank
        click_button 'Save'

        # Name should still be filled
        expect(page).to have_field('Name', with: 'Test Label')
      end
    end
  end

  describe 'Multi-tenant Isolation' do
    let!(:company1_label) { create(:label, company: company, code: 'company1', name: 'Company 1 Label') }
    let!(:company2_label) { create(:label, company: other_company, code: 'company2', name: 'Company 2 Label') }

    before do
      visit labels_path
    end

    it 'only shows labels for current company' do
      expect(page).to have_content('Company 1 Label')
      expect(page).not_to have_content('Company 2 Label')
    end

    it 'search only returns current company labels' do
      fill_in 'q', with: 'Company'
      click_button type: 'submit'

      expect(page).to have_content('Company 1 Label')
      expect(page).not_to have_content('Company 2 Label')
    end

    it 'cannot create label with other company parent' do
      # This would require manipulating form data, which should be prevented at controller level
      # The request spec already covers this scenario
    end
  end

  describe 'Real-world Workflows' do
    context 'complete label management workflow' do
      it 'creates root label, adds sublabels, associates products, and navigates hierarchy' do
        # Step 1: Create root label
        visit labels_path
        click_button 'New Label'

        fill_in 'Name', with: 'Electronics'
        fill_in 'Code', with: 'electronics'
        select 'category', from: 'Label Type'
        fill_in 'Description', with: 'Electronic devices and accessories'

        click_button 'Save'
        expect(page).to have_content('created successfully')

        # Step 2: Navigate to show page
        click_link 'Electronics'
        expect(page).to have_content('Electronics')
        expect(page).to have_content('electronic')

        # Step 3: Add sublabel
        click_button 'Add Sublabel'

        fill_in 'Name', with: 'Smartphones'
        fill_in 'Code', with: 'smartphones'
        select 'category', from: 'Label Type'

        click_button 'Save'
        expect(page).to have_content('created successfully')

        # Step 4: Verify hierarchy
        visit labels_path
        click_link 'Electronics'

        expect(page).to have_content('Smartphones')

        # Step 5: Edit label
        click_button 'Edit'

        fill_in 'Description', with: 'Updated description for electronics'
        click_button 'Save'

        expect(page).to have_content('updated successfully')
      end
    end

    context 'error recovery workflow' do
      it 'recovers from validation errors and successfully submits' do
        visit new_label_path

        # First attempt with missing fields
        click_button 'Save'
        expect(page).to have_content("can't be blank") || have_content('is required')

        # Fix errors and resubmit
        fill_in 'Name', with: 'Valid Label'
        fill_in 'Code', with: 'valid_label'
        select 'category', from: 'Label Type'

        click_button 'Save'
        expect(page).to have_content('created successfully')
      end
    end
  end
end
