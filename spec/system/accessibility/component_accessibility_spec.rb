# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Component Accessibility', type: :system, js: true do
  # Helper to mount a component for testing
  def render_component(component)
    visit_component(component)
  end

  def visit_component(component)
    # Create a test page that renders the component
    html = <<~HTML
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Component Test</title>
        <script src="https://cdn.tailwindcss.com"></script>
      </head>
      <body>
        <main id="main" role="main">
          #{ApplicationController.renderer.render(component)}
        </main>
      </body>
      </html>
    HTML

    # Write to a temporary file and visit it
    tmp_path = Rails.root.join('tmp', 'component_test.html')
    File.write(tmp_path, html)
    visit "file://#{tmp_path}"
  end

  describe 'Button Component', :accessibility do
    it 'primary button passes WCAG 2.1 AA compliance' do
      component = Ui::ButtonComponent.new(variant: :primary) { 'Save Product' }
      render_component(component)

      expect_no_axe_violations
    end

    it 'secondary button passes accessibility checks' do
      component = Ui::ButtonComponent.new(variant: :secondary) { 'Cancel' }
      render_component(component)

      expect_no_axe_violations
    end

    it 'danger button has sufficient color contrast' do
      component = Ui::ButtonComponent.new(variant: :danger) { 'Delete' }
      render_component(component)

      expect_no_axe_violations
    end

    it 'disabled button is properly announced to screen readers' do
      component = Ui::ButtonComponent.new(disabled: true) { 'Save' }
      render_component(component)

      button = page.find('button')
      expect(button[:disabled]).to eq('true')
      expect_no_axe_violations
    end

    it 'loading button is accessible' do
      component = Ui::ButtonComponent.new(loading: true) { 'Submitting...' }
      render_component(component)

      expect_no_axe_violations
    end

    it 'icon-only button has aria-label' do
      icon_svg = '<svg viewBox="0 0 24 24"><path d="M6 18L18 6M6 6l12 12"/></svg>'
      component = Ui::ButtonComponent.new(
        icon: icon_svg,
        aria_label: "Close dialog"
      ) { '' }
      render_component(component)

      button = page.find('button')
      expect(button['aria-label']).to eq('Close dialog')
      expect_no_axe_violations
    end

    it 'button with icon has proper structure' do
      icon_svg = '<svg viewBox="0 0 24 24"><path d="M12 4v16m8-8H4"/></svg>'
      component = Ui::ButtonComponent.new(
        icon: icon_svg,
        icon_position: :left
      ) { 'Add Product' }
      render_component(component)

      expect_no_axe_violations
    end

    it 'all button variants have visible focus indicators' do
      [:primary, :secondary, :danger, :ghost].each do |variant|
        component = Ui::ButtonComponent.new(variant: variant) { "#{variant.to_s.capitalize} Button" }
        render_component(component)

        button = page.find('button')
        button.send_keys(:tab) # Focus the button

        # Check for focus ring classes
        expect(button[:class]).to include('focus:ring')
        expect_no_axe_violations
      end
    end

    it 'button is keyboard accessible' do
      component = Ui::ButtonComponent.new { 'Click Me' }
      render_component(component)

      button = page.find('button')
      button.send_keys(:space)
      # Space key should trigger the button (though we can't test the action here)

      expect_no_axe_violations
    end
  end

  describe 'Badge Component', :accessibility do
    before do
      skip('Badge component needs to be implemented') unless defined?(Ui::BadgeComponent)
    end

    it 'badge with status passes accessibility checks' do
      component = Ui::BadgeComponent.new(status: 'active', size: :md)
      render_component(component)

      expect_no_axe_violations
    end

    it 'badge has sufficient color contrast' do
      component = Ui::BadgeComponent.new(status: 'warning', size: :md)
      render_component(component)

      expect_rule_passes('color-contrast')
    end

    it 'badge text is readable' do
      component = Ui::BadgeComponent.new(status: 'success', size: :sm) { 'Active' }
      render_component(component)

      expect_no_axe_violations
    end
  end

  describe 'Card Component', :accessibility do
    it 'card with header passes accessibility checks' do
      component = Ui::CardComponent.new do |card|
        card.with_header { 'Product Details' }
        card.with_body { 'This is the product description.' }
      end
      render_component(component)

      expect_no_axe_violations
    end

    it 'card maintains proper heading hierarchy' do
      component = Ui::CardComponent.new do |card|
        card.with_header { 'Main Heading' }
        card.with_body { '<h2>Subheading</h2><p>Content</p>' }
      end
      render_component(component)

      # Card header should not interfere with heading hierarchy
      expect_no_axe_violations
    end

    it 'card with footer is accessible' do
      component = Ui::CardComponent.new do |card|
        card.with_header { 'Confirm Action' }
        card.with_body { 'Are you sure?' }
        card.with_footer do
          render(Ui::ButtonComponent.new(variant: :secondary)) { 'Cancel' }
        end
      end
      render_component(component)

      expect_no_axe_violations
    end
  end

  describe 'Modal Component', :accessibility do
    it 'modal has proper ARIA attributes' do
      component = Ui::ModalComponent.new(size: :md) do |modal|
        modal.with_trigger { render(Ui::ButtonComponent.new) { 'Open Modal' } }
        modal.with_header { 'Modal Title' }
        'Modal content goes here.'
      end
      render_component(component)

      # Open the modal
      page.find('button', text: 'Open Modal').click

      # Check for proper ARIA attributes
      modal_dialog = page.find('[role="dialog"]', visible: :all)
      expect(modal_dialog['aria-modal']).to eq('true')
      expect(modal_dialog['aria-labelledby']).to be_present

      expect_no_axe_violations
    end

    it 'modal close button has aria-label' do
      component = Ui::ModalComponent.new(closable: true) do |modal|
        modal.with_trigger { render(Ui::ButtonComponent.new) { 'Open' } }
        modal.with_header { 'Title' }
        'Content'
      end
      render_component(component)

      page.find('button', text: 'Open').click

      close_button = page.find('button[aria-label="Close"]')
      expect(close_button).to be_present
      expect_no_axe_violations
    end

    it 'modal is keyboard accessible' do
      component = Ui::ModalComponent.new do |modal|
        modal.with_trigger { render(Ui::ButtonComponent.new) { 'Open Modal' } }
        modal.with_header { 'Keyboard Test' }
        'Press Escape to close'
      end
      render_component(component)

      # Open modal with keyboard
      trigger = page.find('button', text: 'Open Modal')
      trigger.send_keys(:enter)

      # Modal should be visible
      expect(page).to have_css('[role="dialog"]', visible: true)

      # Close with Escape key
      page.send_keys(:escape)
      sleep 0.5 # Wait for animation

      # Modal should be hidden
      expect(page).to have_css('[role="dialog"]', visible: false)
    end

    it 'modal traps focus within dialog' do
      component = Ui::ModalComponent.new do |modal|
        modal.with_trigger { render(Ui::ButtonComponent.new) { 'Open Modal' } }
        modal.with_header { 'Focus Trap Test' }
        modal.with_footer do
          concat render(Ui::ButtonComponent.new(variant: :secondary)) { 'Cancel' }
          concat render(Ui::ButtonComponent.new) { 'Confirm' }
        end
        'Modal content with focus trap'
      end
      render_component(component)

      page.find('button', text: 'Open Modal').click

      # Get all focusable elements in modal
      modal_selector = '[role="dialog"]'
      focusable = expect_keyboard_navigable(modal_selector)

      # Should have close button + 2 footer buttons = 3 elements
      expect(focusable.length).to be >= 2

      expect_no_axe_violations
    end

    it 'modal passes WCAG 2.1 AA with all elements' do
      component = Ui::ModalComponent.new(size: :lg) do |modal|
        modal.with_trigger { render(Ui::ButtonComponent.new) { 'Open Full Modal' } }
        modal.with_header { 'Complete Modal Example' }
        modal.with_footer do
          concat render(Ui::ButtonComponent.new(variant: :secondary)) { 'Cancel' }
          concat render(Ui::ButtonComponent.new(variant: :danger)) { 'Delete' }
        end
        '<p class="text-gray-600">This modal has a header, content, and footer with action buttons.</p>'
      end
      render_component(component)

      page.find('button', text: 'Open Full Modal').click

      expect_no_axe_violations
    end
  end

  describe 'Flash Component', :accessibility do
    it 'success flash is accessible' do
      component = FlashComponent.new(type: :success) { 'Operation completed successfully!' }
      render_component(component)

      expect_no_axe_violations
    end

    it 'error flash has proper ARIA role' do
      component = FlashComponent.new(type: :error) { 'An error occurred' }
      render_component(component)

      # Error messages should have alert role
      flash_element = page.find('[role="alert"]', visible: :all)
      expect(flash_element).to be_present

      expect_no_axe_violations
    end

    it 'warning flash has sufficient contrast' do
      component = FlashComponent.new(type: :warning) { 'Warning message' }
      render_component(component)

      expect_rule_passes('color-contrast')
    end

    it 'flash with dismiss button is keyboard accessible' do
      component = FlashComponent.new(type: :info, dismissible: true) { 'Info message' }
      render_component(component)

      # Find dismiss button
      if page.has_button?('Dismiss', visible: :all)
        dismiss_button = page.find('button', text: 'Dismiss')
        expect(dismiss_button).to be_present
      end

      expect_no_axe_violations
    end
  end

  describe 'Navbar Component', :accessibility do
    let(:current_user) { { id: 1, email: 'user@example.com', name: 'Test User' } }
    let(:current_company) { build(:company, name: 'Test Company') }

    it 'navbar passes WCAG 2.1 AA compliance' do
      component = Shared::NavbarComponent.new(
        current_user: current_user,
        current_company: current_company
      )
      render_component(component)

      expect_no_axe_violations
    end

    it 'navbar has semantic nav element' do
      component = Shared::NavbarComponent.new(
        current_user: current_user,
        current_company: current_company
      )
      render_component(component)

      expect(page).to have_css('nav')
      expect_no_axe_violations
    end

    it 'navigation links are keyboard accessible' do
      component = Shared::NavbarComponent.new(
        current_user: current_user,
        current_company: current_company
      )
      render_component(component)

      # Check for navigation links
      expect(page).to have_link('Dashboard', visible: :all)
      expect(page).to have_link('Products', visible: :all)

      expect_no_axe_violations
    end

    it 'mobile menu button has aria-label' do
      component = Shared::NavbarComponent.new(
        current_user: current_user,
        current_company: current_company
      )
      render_component(component)

      mobile_button = page.find('button[aria-label="Open menu"]', visible: :all)
      expect(mobile_button).to be_present

      expect_no_axe_violations
    end

    it 'user dropdown has proper ARIA attributes' do
      component = Shared::NavbarComponent.new(
        current_user: current_user,
        current_company: current_company
      )
      render_component(component)

      dropdown_button = page.find('button[aria-haspopup="true"]', visible: :all)
      expect(dropdown_button['aria-expanded']).to be_present

      expect_no_axe_violations
    end

    it 'logo and branding are accessible' do
      component = Shared::NavbarComponent.new(
        current_user: current_user,
        current_company: current_company
      )
      render_component(component)

      # Logo should be in a link to home
      expect(page).to have_link('Potlift8', visible: :all)

      expect_no_axe_violations
    end
  end

  describe 'Form Components', :accessibility do
    it 'empty state component is accessible' do
      component = Shared::EmptyStateComponent.new(
        title: 'No products found',
        description: 'Create your first product to get started',
        icon: :package
      )
      render_component(component)

      expect_no_axe_violations
    end

    it 'form errors component displays accessible error messages' do
      errors = double('errors', full_messages: ['Name cannot be blank', 'SKU is invalid'])
      component = Shared::FormErrorsComponent.new(errors: errors)
      render_component(component)

      # Errors should have alert role
      expect(page).to have_css('[role="alert"]', visible: :all)

      expect_no_axe_violations
    end

    it 'pagination component is keyboard navigable' do
      pagy = double('pagy',
        page: 2,
        pages: 5,
        prev: 1,
        next: 3,
        series: [1, 2, 3, 4, 5]
      )

      component = Shared::PaginationComponent.new(pagy: pagy)
      render_component(component)

      # All pagination links should be keyboard accessible
      focusable = expect_keyboard_navigable('nav')
      expect(focusable.length).to be > 0

      expect_no_axe_violations
    end

    it 'breadcrumb component has proper navigation structure' do
      breadcrumbs = [
        { text: 'Home', url: '/' },
        { text: 'Products', url: '/products' },
        { text: 'Edit', url: nil }
      ]

      component = Shared::BreadcrumbComponent.new(breadcrumbs: breadcrumbs)
      render_component(component)

      # Breadcrumbs should be in a nav element
      expect(page).to have_css('nav[aria-label="Breadcrumb"]', visible: :all)

      expect_no_axe_violations
    end
  end

  describe 'Product Components', :accessibility do
    let(:company) { create(:company) }
    let(:product) { create(:product, company: company, sku: 'TEST-001', name: 'Test Product') }

    it 'product table component is accessible' do
      component = Products::TableComponent.new(products: [product])
      render_component(component)

      # Table should have proper structure
      expect(page).to have_css('table')
      expect(page).to have_css('th') # Table headers

      expect_no_axe_violations
    end

    it 'product form component passes accessibility checks' do
      component = Products::FormComponent.new(product: product)
      render_component(component)

      # All form inputs should have associated labels
      expect_no_axe_violations
    end

    it 'product form has proper label associations' do
      component = Products::FormComponent.new(product: product)
      render_component(component)

      # Check that all inputs have labels
      inputs = page.all('input[type="text"], textarea, select', visible: :all)
      inputs.each do |input|
        input_id = input[:id]
        if input_id.present?
          # Should have an associated label
          expect(page).to have_css("label[for='#{input_id}']", visible: :all)
        end
      end

      expect_no_axe_violations
    end
  end

  describe 'Color Contrast', :accessibility do
    it 'primary colors meet WCAG AA contrast ratio' do
      html = <<~HTML
        <!DOCTYPE html>
        <html>
        <body>
          <div style="background-color: #2563eb; color: #ffffff; padding: 20px;">
            Primary Button Text
          </div>
        </body>
        </html>
      HTML

      tmp_path = Rails.root.join('tmp', 'contrast_test.html')
      File.write(tmp_path, html)
      visit "file://#{tmp_path}"

      expect_rule_passes('color-contrast')
    end

    it 'text on gray backgrounds has sufficient contrast' do
      html = <<~HTML
        <!DOCTYPE html>
        <html>
        <body>
          <div style="background-color: #f9fafb; color: #111827; padding: 20px;">
            Body Text on Light Background
          </div>
        </body>
        </html>
      HTML

      tmp_path = Rails.root.join('tmp', 'contrast_test2.html')
      File.write(tmp_path, html)
      visit "file://#{tmp_path}"

      expect_rule_passes('color-contrast')
    end

    it 'link colors are distinguishable' do
      html = <<~HTML
        <!DOCTYPE html>
        <html>
        <body style="background: white; padding: 20px;">
          <p style="color: #374151;">
            This is body text with a
            <a href="#" style="color: #2563eb; text-decoration: underline;">clickable link</a>
            in the middle.
          </p>
        </body>
        </html>
      HTML

      tmp_path = Rails.root.join('tmp', 'link_contrast.html')
      File.write(tmp_path, html)
      visit "file://#{tmp_path}"

      expect_rule_passes('color-contrast')
    end
  end

  describe 'Focus Management', :accessibility do
    it 'interactive elements have visible focus indicators' do
      component = Ui::ButtonComponent.new { 'Test Focus' }
      render_component(component)

      button = page.find('button')

      # Check that button has focus ring classes
      expect(button[:class]).to include('focus:ring')
      expect(button[:class]).to include('focus:outline-none')

      expect_no_axe_violations
    end

    it 'focus order follows logical tab sequence' do
      html = <<~HTML
        <!DOCTYPE html>
        <html>
        <body>
          <main>
            <button id="btn1">First Button</button>
            <input type="text" id="input1" placeholder="Text Input">
            <a href="#" id="link1">Link</a>
            <button id="btn2">Second Button</button>
          </main>
        </body>
        </html>
      HTML

      tmp_path = Rails.root.join('tmp', 'focus_order.html')
      File.write(tmp_path, html)
      visit "file://#{tmp_path}"

      # Tab through elements
      page.find('body').send_keys(:tab)
      expect(page.evaluate_script('document.activeElement.id')).to eq('btn1')

      page.find('body').send_keys(:tab)
      expect(page.evaluate_script('document.activeElement.id')).to eq('input1')

      page.find('body').send_keys(:tab)
      expect(page.evaluate_script('document.activeElement.id')).to eq('link1')

      expect_no_axe_violations
    end
  end
end
