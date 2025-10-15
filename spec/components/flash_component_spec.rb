# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FlashComponent, type: :component do
  describe 'rendering' do
    context 'with success flash' do
      let(:flash) { { success: 'Operation successful!' } }

      it 'renders success message' do
        render_inline(described_class.new(flash: flash))

        expect(page).to have_text('Operation successful!')
      end

      it 'uses green color scheme' do
        render_inline(described_class.new(flash: flash))

        aggregate_failures do
          expect(page).to have_css('.bg-green-50.border-green-200')
          expect(page).to have_css('.text-green-800')
          expect(page).to have_css('.text-green-500')
        end
      end

      it 'renders check-circle icon' do
        render_inline(described_class.new(flash: flash))

        expect(page).to have_css('svg.h-5.w-5.text-green-500')
      end
    end

    context 'with error flash' do
      let(:flash) { { error: 'Something went wrong!' } }

      it 'renders error message' do
        render_inline(described_class.new(flash: flash))

        expect(page).to have_text('Something went wrong!')
      end

      it 'uses red color scheme' do
        render_inline(described_class.new(flash: flash))

        aggregate_failures do
          expect(page).to have_css('.bg-red-50.border-red-200')
          expect(page).to have_css('.text-red-800')
          expect(page).to have_css('.text-red-500')
        end
      end

      it 'renders x-circle icon' do
        render_inline(described_class.new(flash: flash))

        expect(page).to have_css('svg.h-5.w-5.text-red-500')
      end
    end

    context 'with alert flash' do
      let(:flash) { { alert: 'Please review this action!' } }

      it 'renders alert message' do
        render_inline(described_class.new(flash: flash))

        expect(page).to have_text('Please review this action!')
      end

      it 'uses yellow color scheme' do
        render_inline(described_class.new(flash: flash))

        aggregate_failures do
          expect(page).to have_css('.bg-yellow-50.border-yellow-200')
          expect(page).to have_css('.text-yellow-800')
          expect(page).to have_css('.text-yellow-500')
        end
      end

      it 'renders exclamation-triangle icon' do
        render_inline(described_class.new(flash: flash))

        expect(page).to have_css('svg.h-5.w-5.text-yellow-500')
      end
    end

    context 'with notice flash' do
      let(:flash) { { notice: 'Information message' } }

      it 'renders notice message' do
        render_inline(described_class.new(flash: flash))

        expect(page).to have_text('Information message')
      end

      it 'uses blue color scheme' do
        render_inline(described_class.new(flash: flash))

        aggregate_failures do
          expect(page).to have_css('.bg-blue-50.border-blue-200')
          expect(page).to have_css('.text-blue-800')
          expect(page).to have_css('.text-blue-500')
        end
      end

      it 'renders info icon' do
        render_inline(described_class.new(flash: flash))

        expect(page).to have_css('svg.h-5.w-5.text-blue-500')
      end
    end

    context 'with multiple flash messages' do
      let(:flash) { { success: 'Success!', error: 'Error!', alert: 'Warning!' } }

      it 'renders all messages' do
        render_inline(described_class.new(flash: flash))

        aggregate_failures do
          expect(page).to have_text('Success!')
          expect(page).to have_text('Error!')
          expect(page).to have_text('Warning!')
        end
      end

      it 'applies correct color schemes to each' do
        render_inline(described_class.new(flash: flash))

        aggregate_failures do
          expect(page).to have_css('.bg-green-50')
          expect(page).to have_css('.bg-red-50')
          expect(page).to have_css('.bg-yellow-50')
        end
      end

      it 'wraps messages in space-y container' do
        render_inline(described_class.new(flash: flash))

        expect(page).to have_css('.space-y-4')
      end
    end

    context 'with no flash messages' do
      let(:flash) { {} }

      it 'renders nothing when empty' do
        render_inline(described_class.new(flash: flash))

        expect(page.text.strip).to be_empty
      end

      it 'does not render flash controller' do
        render_inline(described_class.new(flash: flash))

        expect(page).not_to have_css('[data-controller="flash"]')
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

      expect(page).to have_css('button[data-action="click->flash#dismiss"]')
    end

    it 'has target for message' do
      render_inline(described_class.new(flash: flash))

      expect(page).to have_css('[data-flash-target="message"]')
    end

    it 'dismiss button has proper aria-label' do
      render_inline(described_class.new(flash: flash))

      expect(page).to have_css('button[aria-label="Dismiss notification"]')
    end

    it 'dismiss button has X icon' do
      render_inline(described_class.new(flash: flash))

      within('button[data-action="click->flash#dismiss"]') do
        expect(page).to have_css('svg.h-5.w-5')
      end
    end

    it 'each flash message has its own dismiss button' do
      flash = { success: 'Success!', error: 'Error!' }
      render_inline(described_class.new(flash: flash))

      expect(page).to have_css('button[data-action="click->flash#dismiss"]', count: 2)
    end
  end

  describe 'helper methods' do
    describe '#flash_config' do
      let(:component) { described_class.new }

      it 'returns success config' do
        config = component.send(:flash_config, :success)

        aggregate_failures do
          expect(config[:container]).to eq('bg-green-50 border-green-200')
          expect(config[:icon]).to eq('text-green-500')
          expect(config[:text]).to eq('text-green-800')
          expect(config[:icon_path]).to include('M9 12l2 2 4-4')
        end
      end

      it 'returns error config' do
        config = component.send(:flash_config, :error)

        aggregate_failures do
          expect(config[:container]).to eq('bg-red-50 border-red-200')
          expect(config[:icon]).to eq('text-red-500')
          expect(config[:text]).to eq('text-red-800')
          expect(config[:icon_path]).to include('M10 14l2-2')
        end
      end

      it 'returns alert config' do
        config = component.send(:flash_config, :alert)

        aggregate_failures do
          expect(config[:container]).to eq('bg-yellow-50 border-yellow-200')
          expect(config[:icon]).to eq('text-yellow-500')
          expect(config[:text]).to eq('text-yellow-800')
          expect(config[:icon_path]).to include('M12 9v2m0 4h.01')
        end
      end

      it 'returns notice config' do
        config = component.send(:flash_config, :notice)

        aggregate_failures do
          expect(config[:container]).to eq('bg-blue-50 border-blue-200')
          expect(config[:icon]).to eq('text-blue-500')
          expect(config[:text]).to eq('text-blue-800')
          expect(config[:icon_path]).to include('M13 16h-1v-4h-1m1-4h.01')
        end
      end

      it 'defaults to notice config for unknown types' do
        config = component.send(:flash_config, :unknown_type)

        expect(config[:container]).to eq('bg-blue-50 border-blue-200')
      end

      it 'handles string keys' do
        config = component.send(:flash_config, 'success')

        expect(config[:container]).to eq('bg-green-50 border-green-200')
      end
    end
  end

  describe 'accessibility' do
    let(:flash) { { notice: 'Test message' } }

    it 'has role="alert" on each message' do
      render_inline(described_class.new(flash: flash))

      expect(page).to have_css('[role="alert"]')
    end

    it 'has aria-label on dismiss button' do
      render_inline(described_class.new(flash: flash))

      expect(page).to have_css('button[aria-label="Dismiss notification"]')
    end

    it 'has aria-hidden on decorative icons' do
      render_inline(described_class.new(flash: flash))

      expect(page).to have_css('svg[aria-hidden="true"]', count: 2) # Message icon and close icon
    end

    it 'has semantic structure with proper divs' do
      render_inline(described_class.new(flash: flash))

      aggregate_failures do
        expect(page).to have_css('div.flex')
        expect(page).to have_css('div.flex-shrink-0')
        expect(page).to have_css('div.flex-1')
      end
    end

    it 'has sufficient color contrast' do
      flash = { success: 'Success', error: 'Error', alert: 'Alert', notice: 'Notice' }
      render_inline(described_class.new(flash: flash))

      aggregate_failures do
        expect(page).to have_css('.text-green-800')
        expect(page).to have_css('.text-red-800')
        expect(page).to have_css('.text-yellow-800')
        expect(page).to have_css('.text-blue-800')
      end
    end
  end

  describe 'styling and layout' do
    let(:flash) { { success: 'Test' } }

    it 'has proper rounded corners' do
      render_inline(described_class.new(flash: flash))

      expect(page).to have_css('.rounded-lg')
    end

    it 'has proper padding' do
      render_inline(described_class.new(flash: flash))

      expect(page).to have_css('.p-4')
    end

    it 'has border styling' do
      render_inline(described_class.new(flash: flash))

      expect(page).to have_css('.border')
    end

    it 'has bottom margin on container' do
      render_inline(described_class.new(flash: flash))

      expect(page).to have_css('.mb-6')
    end

    it 'uses flexbox layout' do
      render_inline(described_class.new(flash: flash))

      expect(page).to have_css('.flex')
    end

    it 'has proper spacing between elements' do
      render_inline(described_class.new(flash: flash))

      aggregate_failures do
        expect(page).to have_css('.ml-3') # Message margin
        expect(page).to have_css('.ml-auto') # Dismiss button margin
      end
    end

    it 'stacks multiple messages with space-y' do
      flash = { success: 'Success', error: 'Error' }
      render_inline(described_class.new(flash: flash))

      expect(page).to have_css('.space-y-4')
    end
  end

  describe 'integration with view flash' do
    it 'uses view flash when flash param is nil' do
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

  describe 'edge cases' do
    it 'handles very long messages' do
      flash = { success: 'A' * 500 }
      render_inline(described_class.new(flash: flash))

      expect(page).to have_text('A' * 500)
    end

    it 'handles HTML in messages safely' do
      flash = { success: 'Message with <script>alert("XSS")</script> tags' }
      render_inline(described_class.new(flash: flash))

      expect(page).to have_text('Message with <script>alert("XSS")</script> tags')
    end

    it 'handles unicode in messages' do
      flash = { success: '成功 العربية 🎉' }
      render_inline(described_class.new(flash: flash))

      expect(page).to have_text('成功 العربية 🎉')
    end

    it 'handles newlines in messages' do
      flash = { success: "Line 1\nLine 2" }
      render_inline(described_class.new(flash: flash))

      expect(page).to have_text("Line 1\nLine 2")
    end

    it 'handles empty message strings' do
      flash = { success: '' }
      render_inline(described_class.new(flash: flash))

      expect(page).to have_css('[role="alert"]')
    end
  end
end
