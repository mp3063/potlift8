# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TopbarComponent, type: :component do
  let(:user) { { id: 1, name: 'John Doe', email: 'john@example.com' } }
  let(:company) { create(:company, name: 'ACME Corp') }
  let(:companies) { [company] }

  describe 'rendering' do
    it 'renders component' do
      render_inline(described_class.new(user: user, company: company, companies: companies))

      expect(page).to have_text('John Doe')
    end

    it 'renders mobile menu toggle button' do
      render_inline(described_class.new(user: user, company: company, companies: companies))

      # Mobile menu button with sr-only text
      expect(page).to have_css('button[data-action*="mobile-sidebar"]')
      expect(page).to have_text('Open sidebar')
    end

    it 'renders search bar' do
      render_inline(described_class.new(user: user, company: company, companies: companies))

      expect(page).to have_field('search-field', type: 'search')
      expect(page).to have_css('input[placeholder*="Search"]')
    end

    it 'renders global search controller' do
      render_inline(described_class.new(user: user, company: company, companies: companies))

      expect(page).to have_css('form[data-controller="global-search"]')
    end
  end

  describe 'user menu' do
    it 'displays user initials' do
      render_inline(described_class.new(user: user, company: company, companies: companies))

      expect(page).to have_text('JD')
    end

    it 'displays user name' do
      render_inline(described_class.new(user: user, company: company, companies: companies))

      expect(page).to have_text('John Doe')
    end

    it 'includes dropdown controller' do
      render_inline(described_class.new(user: user, company: company, companies: companies))

      expect(page).to have_css('[data-controller="dropdown"]')
      expect(page).to have_css('[data-dropdown-target="menu"]')
    end

    it 'has proper button attributes' do
      render_inline(described_class.new(user: user, company: company, companies: companies))

      # Find the user menu button by data-action
      user_button = page.find('button[data-action*="dropdown#toggle"]', match: :first)
      expect(user_button).to be_present
    end
  end

  describe 'company selector' do
    context 'with single company' do
      it 'does not show company selector' do
        render_inline(described_class.new(user: user, company: company, companies: [company]))

        # Should not have the company selector dropdown
        expect(page).not_to have_text('ACME Corp', count: 2) # Only in current company display
      end
    end

    context 'with multiple companies' do
      let(:company2) { create(:company, name: 'Other Corp') }
      let(:multiple_companies) { [company, company2] }

      it 'shows company selector dropdown' do
        render_inline(described_class.new(user: user, company: company, companies: multiple_companies))

        expect(page).to have_text('ACME Corp')
      end

      it 'lists all accessible companies' do
        render_inline(described_class.new(user: user, company: company, companies: multiple_companies))

        expect(page).to have_text('ACME Corp')
        expect(page).to have_text('Other Corp')
      end

      it 'includes dropdown controller' do
        render_inline(described_class.new(user: user, company: company, companies: multiple_companies))

        # Should have multiple dropdown controllers (one for company, one for user)
        expect(page).to have_css('[data-controller="dropdown"]', count: 2)
      end
    end
  end

  describe 'helper methods' do
    describe '#user_initials' do
      it 'returns initials from full name' do
        component = described_class.new(user: user, company: company, companies: companies)
        expect(component.send(:user_initials)).to eq('JD')
      end

      it 'returns first two characters for single name' do
        component = described_class.new(
          user: { id: 1, name: 'Madonna', email: 'madonna@example.com' },
          company: company,
          companies: companies
        )
        expect(component.send(:user_initials)).to eq('MA')
      end

      it 'returns three name initials (first two)' do
        component = described_class.new(
          user: { id: 1, name: 'John Paul Smith', email: 'john@example.com' },
          company: company,
          companies: companies
        )
        expect(component.send(:user_initials)).to eq('JP')
      end

      it 'returns ? for missing user name' do
        component = described_class.new(
          user: { id: 1, name: nil, email: 'test@example.com' },
          company: company,
          companies: companies
        )
        expect(component.send(:user_initials)).to eq('?')
      end

      it 'returns uppercase initials' do
        component = described_class.new(
          user: { id: 1, name: 'john doe', email: 'john@example.com' },
          company: company,
          companies: companies
        )
        expect(component.send(:user_initials)).to eq('JD')
      end
    end

    describe '#multiple_companies?' do
      it 'returns true when user has multiple companies' do
        companies = [company, create(:company)]
        component = described_class.new(user: user, company: company, companies: companies)

        expect(component.send(:multiple_companies?)).to be true
      end

      it 'returns false when user has single company' do
        component = described_class.new(user: user, company: company, companies: [company])

        expect(component.send(:multiple_companies?)).to be false
      end

      it 'returns false when companies is empty' do
        component = described_class.new(user: user, company: company, companies: [])

        expect(component.send(:multiple_companies?)).to be false
      end
    end
  end

  describe 'responsive design' do
    it 'hides menu button on desktop' do
      render_inline(described_class.new(user: user, company: company, companies: companies))

      menu_button = page.find('button', text: 'Open sidebar')
      expect(menu_button[:class]).to include('lg:hidden')
    end

    it 'hides user name on mobile' do
      render_inline(described_class.new(user: user, company: company, companies: companies))

      user_name_span = page.find('span', text: 'John Doe')
      expect(user_name_span[:class]).to include('hidden')
      expect(user_name_span[:class]).to include('lg:flex')
    end
  end

  describe 'accessibility' do
    it 'has sr-only labels for buttons' do
      render_inline(described_class.new(user: user, company: company, companies: companies))

      expect(page).to have_css('.sr-only', text: 'Open sidebar')
      expect(page).to have_css('.sr-only', text: 'Open user menu')
    end

    it 'has proper search label' do
      render_inline(described_class.new(user: user, company: company, companies: companies))

      expect(page).to have_css('label[for="search-field"]')
    end
  end
end
