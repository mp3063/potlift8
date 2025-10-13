# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FlashComponent, type: :component do
  describe 'rendering' do
    context 'with notice flash' do
      let(:flash) { { notice: 'Operation successful!' } }

      it 'renders notice message' do
        render_inline(described_class.new(flash: flash))

        expect(page).to have_text('Operation successful!')
      end

      it 'uses green color scheme' do
        render_inline(described_class.new(flash: flash))

        expect(page).to have_css('.bg-green-50')
        expect(page).to have_css('.text-green-800')
      end

      it 'renders check-circle icon' do
        render_inline(described_class.new(flash: flash))

        expect(page).to have_css('svg')
      end
    end

    context 'with alert flash' do
      let(:flash) { { alert: 'Something went wrong!' } }

      it 'renders alert message' do
        render_inline(described_class.new(flash: flash))

        expect(page).to have_text('Something went wrong!')
      end

      it 'uses red color scheme' do
        render_inline(described_class.new(flash: flash))

        expect(page).to have_css('.bg-red-50')
        expect(page).to have_css('.text-red-800')
      end

      it 'renders x-circle icon' do
        render_inline(described_class.new(flash: flash))

        expect(page).to have_css('svg')
      end
    end

    context 'with warning flash' do
      let(:flash) { { warning: 'Please review this action!' } }

      it 'renders warning message' do
        render_inline(described_class.new(flash: flash))

        expect(page).to have_text('Please review this action!')
      end

      it 'uses yellow color scheme' do
        render_inline(described_class.new(flash: flash))

        expect(page).to have_css('.bg-yellow-50')
        expect(page).to have_css('.text-yellow-800')
      end

      it 'renders exclamation-triangle icon' do
        render_inline(described_class.new(flash: flash))

        expect(page).to have_css('svg')
      end
    end

    context 'with multiple flash messages' do
      let(:flash) { { notice: 'Success!', alert: 'Error!', warning: 'Warning!' } }

      it 'renders all messages' do
        render_inline(described_class.new(flash: flash))

        expect(page).to have_text('Success!')
        expect(page).to have_text('Error!')
        expect(page).to have_text('Warning!')
      end

      it 'applies correct color schemes to each' do
        render_inline(described_class.new(flash: flash))

        expect(page).to have_css('.bg-green-50')
        expect(page).to have_css('.bg-red-50')
        expect(page).to have_css('.bg-yellow-50')
      end
    end

    context 'with no flash messages' do
      let(:flash) { {} }

      it 'renders without errors' do
        expect {
          render_inline(described_class.new(flash: flash))
        }.not_to raise_error
      end
    end
  end

  describe 'dismiss functionality' do
    let(:flash) { { notice: 'Test message' } }

    it 'includes flash controller' do
      render_inline(described_class.new(flash: flash))

      expect(page).to have_css('[data-controller="flash"]')
    end

    it 'includes dismiss button' do
      render_inline(described_class.new(flash: flash))

      dismiss_button = page.find('button[data-action*="flash#dismiss"]')
      expect(dismiss_button).to be_present
    end

    it 'has target for message' do
      render_inline(described_class.new(flash: flash))

      expect(page).to have_css('[data-flash-target="message"]')
    end

    it 'has sr-only dismiss text' do
      render_inline(described_class.new(flash: flash))

      expect(page).to have_css('.sr-only', text: 'Dismiss')
    end
  end

  describe 'helper methods' do
    describe '#flash_config' do
      let(:component) { described_class.new }

      it 'returns notice config' do
        config = component.send(:flash_config, :notice)

        expect(config[:icon]).to eq('check-circle')
        expect(config[:bg_color]).to eq('bg-green-50')
        expect(config[:text_color]).to eq('text-green-800')
        expect(config[:icon_color]).to eq('text-green-400')
      end

      it 'returns alert config' do
        config = component.send(:flash_config, :alert)

        expect(config[:icon]).to eq('x-circle')
        expect(config[:bg_color]).to eq('bg-red-50')
        expect(config[:text_color]).to eq('text-red-800')
        expect(config[:icon_color]).to eq('text-red-400')
      end

      it 'returns warning config' do
        config = component.send(:flash_config, :warning)

        expect(config[:icon]).to eq('exclamation-triangle')
        expect(config[:bg_color]).to eq('bg-yellow-50')
        expect(config[:text_color]).to eq('text-yellow-800')
        expect(config[:icon_color]).to eq('text-yellow-400')
      end

      it 'defaults to notice config for unknown types' do
        config = component.send(:flash_config, :unknown_type)

        expect(config[:icon]).to eq('check-circle')
      end

      it 'handles string keys' do
        config = component.send(:flash_config, 'notice')

        expect(config[:icon]).to eq('check-circle')
      end
    end
  end

  describe 'accessibility' do
    let(:flash) { { notice: 'Test message' } }

    it 'has proper ARIA labels' do
      render_inline(described_class.new(flash: flash))

      expect(page).to have_css('.sr-only', text: 'Dismiss')
    end

    it 'has semantic structure' do
      render_inline(described_class.new(flash: flash))

      # Should be wrapped in divs with proper classes
      expect(page).to have_css('div > div.flex')
    end
  end

  describe 'integration with view flash' do
    it 'uses view flash when flash param is nil' do
      # Mock helpers.flash
      component = described_class.new
      allow(component).to receive(:helpers).and_return(double(flash: { notice: 'From view' }))

      expect(component.flash[:notice]).to eq('From view')
    end

    it 'uses provided flash over view flash' do
      component = described_class.new(flash: { notice: 'Provided flash' })
      allow(component).to receive(:helpers).and_return(double(flash: { notice: 'From view' }))

      expect(component.flash[:notice]).to eq('Provided flash')
    end
  end
end
