# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BundleSkuGeneratorService do
  describe '#generate' do
    context 'with multiple variant codes' do
      it 'generates SKU with base and variant codes joined by hyphens' do
        service = described_class.new('SUMKIT', [ 'S', 'M' ])
        expect(service.generate).to eq('SUMKIT-S-M')
      end

      it 'handles multiple variant codes' do
        service = described_class.new('BUNDLE', [ 'S', 'RED', 'COTTON' ])
        expect(service.generate).to eq('BUNDLE-S-RED-COTTON')
      end
    end

    context 'with single variant code' do
      it 'generates SKU with base and single variant code' do
        service = described_class.new('BUNDLE', [ 'L' ])
        expect(service.generate).to eq('BUNDLE-L')
      end
    end

    context 'with no variant codes' do
      it 'returns base SKU only' do
        service = described_class.new('KIT', [])
        expect(service.generate).to eq('KIT')
      end

      it 'returns base SKU when variant codes is nil' do
        service = described_class.new('KIT', nil)
        expect(service.generate).to eq('KIT')
      end
    end

    context 'with special characters in variant codes' do
      it 'sanitizes slashes and spaces' do
        service = described_class.new('TEST', [ 'X/L', 'Red Color' ])
        expect(service.generate).to eq('TEST-XL-RED-COLOR')
      end

      it 'removes special characters and collapses multiple hyphens' do
        service = described_class.new('PROD', [ 'Size: M', 'Color - Red' ])
        expect(service.generate).to eq('PROD-SIZE-M-COLOR-RED')
      end

      it 'handles lowercase variant codes by upcasing' do
        service = described_class.new('kit', [ 'small', 'blue' ])
        expect(service.generate).to eq('KIT-SMALL-BLUE')
      end

      it 'handles variant codes with multiple special characters' do
        service = described_class.new('BUNDLE', [ 'X//L', 'Red___Color' ])
        expect(service.generate).to eq('BUNDLE-XL-RED-COLOR')
      end
    end

    context 'with long SKUs exceeding MAX_SKU_LENGTH' do
      it 'truncates variant codes proportionally while keeping base SKU intact' do
        base_sku = 'BUNDLE'
        long_variants = [ 'VERYLONGVARIANT1', 'VERYLONGVARIANT2', 'VERYLONGVARIANT3' ]
        service = described_class.new(base_sku, long_variants)
        result = service.generate

        expect(result.length).to be <= described_class::MAX_SKU_LENGTH
        expect(result).to start_with('BUNDLE-')
      end

      it 'handles case where base SKU itself is near max length' do
        base_sku = 'A' * 45
        variants = [ 'LONG', 'VARIANT' ]
        service = described_class.new(base_sku, variants)
        result = service.generate

        expect(result.length).to be <= described_class::MAX_SKU_LENGTH
        expect(result).to start_with(base_sku)
      end

      it 'returns base SKU only when variants would exceed max length' do
        base_sku = 'A' * 50
        variants = [ 'X' ]
        service = described_class.new(base_sku, variants)
        result = service.generate

        expect(result.length).to be <= described_class::MAX_SKU_LENGTH
        expect(result).to eq(base_sku)
      end
    end

    context 'edge cases' do
      it 'handles empty string base SKU' do
        service = described_class.new('', [ 'S', 'M' ])
        expect(service.generate).to eq('-S-M')
      end

      it 'handles variant codes with only special characters' do
        service = described_class.new('TEST', [ '///' ])
        expect(service.generate).to eq('TEST')
      end

      it 'removes leading and trailing hyphens from variant codes' do
        service = described_class.new('BUNDLE', [ '-SIZE-', '--COLOR--' ])
        expect(service.generate).to eq('BUNDLE-SIZE-COLOR')
      end
    end
  end

  describe '.generate' do
    it 'provides class method shortcut' do
      result = described_class.generate('BUNDLE', [ 'S', 'M' ])
      expect(result).to eq('BUNDLE-S-M')
    end

    it 'works with all the same functionality as instance method' do
      result = described_class.generate('TEST', [ 'X/L', 'Red Color' ])
      expect(result).to eq('TEST-XL-RED-COLOR')
    end
  end
end
