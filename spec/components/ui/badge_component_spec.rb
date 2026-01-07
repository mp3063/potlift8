# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ui::BadgeComponent, type: :component do
  describe 'variants' do
    it 'renders success variant with green colors' do
      render_inline(described_class.new(variant: :success)) { "Active" }

      aggregate_failures do
        expect(page).to have_css('.bg-green-100')
        expect(page).to have_css('.text-green-800')
        expect(page).to have_css('.border-green-200')
        expect(page).to have_text('Active')
      end
    end

    it 'renders info variant with blue colors' do
      render_inline(described_class.new(variant: :info)) { "Information" }

      aggregate_failures do
        expect(page).to have_css('.bg-blue-100')
        expect(page).to have_css('.text-blue-800')
        expect(page).to have_css('.border-blue-200')
        expect(page).to have_text('Information')
      end
    end

    it 'renders warning variant with yellow colors' do
      render_inline(described_class.new(variant: :warning)) { "Draft" }

      aggregate_failures do
        expect(page).to have_css('.bg-yellow-100')
        expect(page).to have_css('.text-yellow-800')
        expect(page).to have_css('.border-yellow-200')
        expect(page).to have_text('Draft')
      end
    end

    it 'renders danger variant with red colors' do
      render_inline(described_class.new(variant: :danger)) { "Error" }

      aggregate_failures do
        expect(page).to have_css('.bg-red-100')
        expect(page).to have_css('.text-red-800')
        expect(page).to have_css('.border-red-200')
        expect(page).to have_text('Error')
      end
    end

    it 'renders gray variant with gray colors' do
      render_inline(described_class.new(variant: :gray)) { "Inactive" }

      aggregate_failures do
        expect(page).to have_css('.bg-gray-100')
        expect(page).to have_css('.text-gray-800')
        expect(page).to have_css('.border-gray-200')
        expect(page).to have_text('Inactive')
      end
    end

    it 'renders primary variant with blue background and white text' do
      render_inline(described_class.new(variant: :primary)) { "Featured" }

      aggregate_failures do
        expect(page).to have_css('.bg-blue-600')
        expect(page).to have_css('.text-white')
        expect(page).to have_css('.border-blue-600')
        expect(page).to have_text('Featured')
      end
    end

    it 'defaults to gray variant when not specified' do
      render_inline(described_class.new) { "Default" }

      aggregate_failures do
        expect(page).to have_css('.bg-gray-100')
        expect(page).to have_css('.text-gray-800')
        expect(page).to have_text('Default')
      end
    end
  end

  describe 'sizes' do
    it 'renders small size with compact padding and text-xs' do
      render_inline(described_class.new(size: :sm)) { "Small" }

      aggregate_failures do
        expect(page).to have_css('.px-2')
        expect(page).to have_css('.py-0\.5')
        expect(page).to have_css('.text-xs')
        expect(page).to have_text('Small')
      end
    end

    it 'renders medium size with standard padding and text-sm' do
      render_inline(described_class.new(size: :md)) { "Medium" }

      aggregate_failures do
        expect(page).to have_css('.px-2\.5')
        expect(page).to have_css('.py-1')
        expect(page).to have_css('.text-sm')
        expect(page).to have_text('Medium')
      end
    end

    it 'renders large size with generous padding and text-base' do
      render_inline(described_class.new(size: :lg)) { "Large" }

      aggregate_failures do
        expect(page).to have_css('.px-3')
        expect(page).to have_css('.py-1\.5')
        expect(page).to have_css('.text-base')
        expect(page).to have_text('Large')
      end
    end

    it 'defaults to small size when not specified' do
      render_inline(described_class.new) { "Default Size" }

      aggregate_failures do
        expect(page).to have_css('.text-xs')
        expect(page).to have_text('Default Size')
      end
    end
  end

  describe 'dot indicator' do
    it 'renders dot when enabled' do
      render_inline(described_class.new(dot: true)) { "With Dot" }

      aggregate_failures do
        expect(page).to have_css('span.h-1\.5.w-1\.5.rounded-full.bg-current')
        expect(page).to have_text('With Dot')
      end
    end

    it 'does not render dot when disabled' do
      render_inline(described_class.new(dot: false)) { "No Dot" }

      aggregate_failures do
        expect(page).not_to have_css('span.h-1\.5.w-1\.5.rounded-full')
        expect(page).to have_text('No Dot')
      end
    end

    it 'does not render dot by default' do
      render_inline(described_class.new) { "Default" }

      expect(page).not_to have_css('span.h-1\.5.w-1\.5.rounded-full')
    end

    it 'renders dot with margin spacing' do
      render_inline(described_class.new(dot: true)) { "Spaced" }

      expect(page).to have_css('span.mr-1\.5')
    end
  end

  describe 'content rendering' do
    it 'renders text content' do
      render_inline(described_class.new) { "Text Content" }

      expect(page).to have_text('Text Content')
    end

    it 'renders HTML content' do
      render_inline(described_class.new) { '<strong>Bold</strong>'.html_safe }

      expect(page).to have_css('strong', text: 'Bold')
    end

    it 'renders complex content' do
      render_inline(described_class.new) do
        '<span class="custom">Custom</span>'.html_safe
      end

      expect(page).to have_css('span.custom', text: 'Custom')
    end

    it 'handles empty content' do
      render_inline(described_class.new) { "" }

      expect(page).to have_css('span.inline-flex')
    end
  end

  describe 'HTML options' do
    it 'passes through additional CSS classes' do
      render_inline(described_class.new(class: 'custom-class')) { "Custom" }

      # Additional classes are added via **@options, so base classes should still be present
      aggregate_failures do
        expect(page).to have_css('span.custom-class')
        expect(page).to have_text('Custom')
      end
    end

    it 'passes through data attributes' do
      render_inline(described_class.new(data: { controller: 'badge', action: 'click->badge#toggle' })) { "Data" }

      aggregate_failures do
        expect(page).to have_css('[data-controller="badge"]')
        expect(page).to have_css('[data-action="click->badge#toggle"]')
      end
    end

    it 'passes through id attribute' do
      render_inline(described_class.new(id: 'custom-badge')) { "ID" }

      expect(page).to have_css('#custom-badge')
    end

    it 'passes through aria attributes' do
      render_inline(described_class.new(aria: { label: 'Status badge' })) { "Status" }

      expect(page).to have_css('[aria-label="Status badge"]')
    end

    it 'passes through title attribute' do
      render_inline(described_class.new(title: 'Hover text')) { "Hover" }

      expect(page).to have_css('[title="Hover text"]')
    end
  end

  describe 'base classes' do
    it 'always includes inline-flex' do
      render_inline(described_class.new) { "Base" }

      expect(page).to have_css('.inline-flex')
    end

    it 'always includes items-center for vertical alignment' do
      render_inline(described_class.new) { "Base" }

      expect(page).to have_css('.items-center')
    end

    it 'always includes font-medium' do
      render_inline(described_class.new) { "Base" }

      expect(page).to have_css('.font-medium')
    end

    it 'always includes rounded-full' do
      render_inline(described_class.new) { "Base" }

      expect(page).to have_css('.rounded-full')
    end

    it 'always includes border' do
      render_inline(described_class.new) { "Base" }

      expect(page).to have_css('.border')
    end
  end

  describe 'combinations' do
    it 'combines variant and size correctly' do
      render_inline(described_class.new(variant: :success, size: :lg)) { "Large Success" }

      aggregate_failures do
        expect(page).to have_css('.bg-green-100')
        expect(page).to have_css('.text-green-800')
        expect(page).to have_css('.px-3')
        expect(page).to have_css('.text-base')
        expect(page).to have_text('Large Success')
      end
    end

    it 'combines all features together' do
      render_inline(described_class.new(
        variant: :danger,
        size: :md,
        dot: true,
        class: 'ml-2',
        data: { id: '123' }
      )) { "Complete" }

      aggregate_failures do
        # Check for badge variant and size classes
        expect(page).to have_text('Complete')
        expect(page).to have_css('span.h-1\.5.w-1\.5.rounded-full') # Dot indicator
        expect(page).to have_css('span.ml-2') # Custom class
        expect(page).to have_css('[data-id="123"]') # Data attribute
        # Check that the badge contains proper structure
        badge = page.find('span[data-id="123"]')
        expect(badge[:class]).to include('bg-red-100')
        expect(badge[:class]).to include('text-red-800')
        expect(badge[:class]).to include('px-2.5')  # md size uses px-2.5
        expect(badge[:class]).to include('text-sm')
      end
    end
  end

  describe 'edge cases' do
    it 'handles nil content gracefully' do
      expect {
        render_inline(described_class.new) { nil }
      }.not_to raise_error
    end

    it 'handles very long content' do
      long_text = "A" * 100
      render_inline(described_class.new) { long_text }

      expect(page).to have_text(long_text)
    end

    it 'handles special characters in content' do
      render_inline(described_class.new) { "Test & <special> 'chars'" }

      expect(page).to have_text("Test & <special> 'chars'")
    end

    it 'handles unicode content' do
      render_inline(described_class.new) { "🎉 Success! 中文 العربية" }

      expect(page).to have_text("🎉 Success! 中文 العربية")
    end
  end

  describe 'accessibility' do
    it 'uses semantic span element' do
      render_inline(described_class.new) { "Semantic" }

      expect(page).to have_css('span')
    end

    it 'has sufficient color contrast with dark text on light backgrounds' do
      render_inline(described_class.new(variant: :success)) { "Readable" }

      # Success variant has dark text (text-green-800) on light background (bg-green-100)
      expect(page).to have_css('.text-green-800')
      expect(page).to have_css('.bg-green-100')
    end

    it 'has sufficient color contrast with light text on dark background' do
      render_inline(described_class.new(variant: :primary)) { "Readable" }

      # Primary variant has white text on dark background
      expect(page).to have_css('.text-white')
      expect(page).to have_css('.bg-blue-600')
    end

    it 'can be made accessible with aria-label' do
      render_inline(described_class.new(aria: { label: 'Product status: Active' })) { "Active" }

      expect(page).to have_css('[aria-label="Product status: Active"]')
    end
  end
end
