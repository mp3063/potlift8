# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Search::ModalComponent, type: :component do
  describe "rendering" do
    before do
      render_inline(described_class.new)
    end

    it "renders the modal container with global-search target" do
      # Note: data-controller="global-search" is on body in layout, not on component
      expect(page).to have_css('[data-global-search-target="modal"]')
    end

    it "renders modal backdrop with correct attributes" do
      expect(page).to have_css('[data-global-search-target="modal"]')
      expect(page).to have_css('[aria-role="dialog"]')
      expect(page).to have_css('[aria-labelledby="search-modal-title"]')
    end

    it "renders modal as hidden by default" do
      expect(page).to have_css('.hidden[data-global-search-target="modal"]')
    end

    it "renders search input with correct attributes" do
      expect(page).to have_field('search',
        type: 'text',
        placeholder: /Search products, storage, attributes, labels, catalogs/
      )
      expect(page).to have_css('input[data-global-search-target="input"]')
      expect(page).to have_css('input[data-action="input->global-search#handleInput"]')
      expect(page).to have_css('input[aria-label="Search"]')
      expect(page).to have_css('input[autocomplete="off"]')
    end

    it "renders search icon" do
      expect(page).to have_css('svg[aria-hidden="true"]', minimum: 1) # Search icon
    end

    it "renders close button with aria-label" do
      expect(page).to have_button(type: 'button', count: 1)
      expect(page).to have_css('button[aria-label="Close search"]')
      expect(page).to have_css('button[data-action="click->global-search#close"]')
    end

    it "renders results area" do
      expect(page).to have_css('[data-global-search-target="results"]')
      expect(page).to have_css('[role="listbox"]')
    end

    it "renders initial instructions in results area" do
      expect(page).to have_text('Type at least 2 characters to search')
      expect(page).to have_text('Or press CMD/CTRL+K anytime to open search')
    end

    it "renders footer with keyboard hints" do
      expect(page).to have_css('kbd', text: '↑↓')
      expect(page).to have_css('kbd', text: 'Enter')
      expect(page).to have_css('kbd', text: 'Esc')
      expect(page).to have_text('Navigate')
      expect(page).to have_text('Select')
      expect(page).to have_text('Close')
    end

    it "renders keyboard shortcut hint in footer" do
      expect(page).to have_text('Press ⌘K to open anytime')
    end

    it "has proper modal structure hierarchy" do
      # Modal is the outermost container with target
      expect(page).to have_css('[data-global-search-target="modal"]')

      # Modal content container with preventClose
      within('[data-global-search-target="modal"]') do
        expect(page).to have_css('[data-action="click->global-search#preventClose"]')

        # Close button inside modal
        expect(page).to have_css('[data-action="click->global-search#close"]')
      end
    end

    it "uses correct Tailwind CSS classes for responsive design" do
      expect(page).to have_css('.max-w-2xl') # Modal max width
      expect(page).to have_css('.top-20') # Fixed positioning from top
      expect(page).to have_css('.max-h-96') # Results max height
    end
  end

  describe "accessibility" do
    before do
      render_inline(described_class.new)
    end

    it "has proper ARIA attributes for dialog" do
      expect(page).to have_css('[aria-role="dialog"]')
      expect(page).to have_css('[aria-labelledby="search-modal-title"]')
    end

    it "has aria-labelledby pointing to modal title" do
      expect(page).to have_css('[aria-labelledby="search-modal-title"]')
    end

    it "has aria-label for search input" do
      expect(page).to have_css('input[aria-label="Search"]')
    end

    it "has aria-autocomplete for search input" do
      expect(page).to have_css('input[aria-autocomplete="list"]')
    end

    it "has aria-label for close button" do
      expect(page).to have_css('button[aria-label="Close search"]')
    end

    it "has role=listbox for results area" do
      expect(page).to have_css('[role="listbox"]')
    end

    it "marks icons as aria-hidden" do
      svg_elements = page.all('svg[aria-hidden="true"]')
      expect(svg_elements.count).to be >= 1
    end
  end

  describe "Stimulus integration" do
    before do
      render_inline(described_class.new)
    end

    it "connects to global-search controller via targets" do
      # Note: data-controller="global-search" is on body in layout
      # Component provides targets that connect to the parent controller
      expect(page).to have_css('[data-global-search-target="modal"]')
      expect(page).to have_css('[data-global-search-target="input"]')
      expect(page).to have_css('[data-global-search-target="results"]')
    end

    it "defines modal target" do
      expect(page).to have_css('[data-global-search-target="modal"]')
    end

    it "defines input target" do
      expect(page).to have_css('[data-global-search-target="input"]')
    end

    it "defines results target" do
      expect(page).to have_css('[data-global-search-target="results"]')
    end

    it "defines input action" do
      expect(page).to have_css('[data-action="input->global-search#handleInput"]')
    end

    it "defines close actions" do
      expect(page).to have_css('[data-action="click->global-search#close"]', count: 1) # Close button only
    end

    it "defines preventClose action" do
      expect(page).to have_css('[data-action="click->global-search#preventClose"]')
    end
  end

  describe "component initialization" do
    it "initializes without parameters" do
      component = described_class.new
      expect(component).to be_a(described_class)
    end

    it "renders successfully without errors" do
      expect {
        render_inline(described_class.new)
      }.not_to raise_error
    end
  end

  describe "visual structure" do
    before do
      render_inline(described_class.new)
    end

    it "renders header with search input and close button" do
      within('.flex.items-center.border-b.border-gray-200') do
        expect(page).to have_css('svg') # Search icon
        expect(page).to have_field('search')
        expect(page).to have_button(type: 'button') # Close button
      end
    end

    it "renders results area between header and footer" do
      expect(page).to have_css('.max-h-96.overflow-y-auto.border-b.border-gray-200')
    end

    it "renders footer with keyboard hints" do
      expect(page).to have_css('.flex.items-center.justify-between.bg-gray-50')
    end
  end
end
