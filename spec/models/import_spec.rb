require 'rails_helper'

RSpec.describe Import, type: :model do
  let(:company) { create(:company) }
  let(:user) { create(:user, company: company) }

  describe 'associations' do
    it { is_expected.to belong_to(:company) }
    it { is_expected.to belong_to(:user) }
  end

  describe 'validations' do
    subject { described_class.new(company: company, user: user, import_type: "products", status: "pending") }

    it 'requires an import_type' do
      subject.import_type = nil
      expect(subject).not_to be_valid
    end

    it 'rejects unknown import_types' do
      subject.import_type = "widgets"
      expect(subject).not_to be_valid
    end

    it 'accepts known import_types' do
      %w[products catalog_items].each do |t|
        subject.import_type = t
        expect(subject).to be_valid
      end
    end

    it 'rejects unknown status values' do
      subject.status = "nope"
      expect(subject).not_to be_valid
    end
  end

  describe '#row_errors' do
    it 'returns [] when errors_data is blank' do
      import = described_class.new
      expect(import.row_errors).to eq([])
    end

    it 'returns the stored errors_data array' do
      import = described_class.new(errors_data: [ { "row" => 2, "error" => "bad" } ])
      expect(import.row_errors).to eq([ { "row" => 2, "error" => "bad" } ])
    end
  end

  describe '#success_count / #failed_count' do
    it 'sums imported + updated for success' do
      import = described_class.new(imported_count: 3, updated_count: 2)
      expect(import.success_count).to eq(5)
    end

    it 'counts row-level errors for failed' do
      import = described_class.new(errors_data: [ { "row" => 2, "error" => "x" }, { "row" => 3, "error" => "y" } ])
      expect(import.failed_count).to eq(2)
    end
  end

  describe '#finished?' do
    it 'is true for completed or failed' do
      expect(described_class.new(status: "completed").finished?).to be true
      expect(described_class.new(status: "failed").finished?).to be true
    end

    it 'is false for pending or processing' do
      expect(described_class.new(status: "pending").finished?).to be false
      expect(described_class.new(status: "processing").finished?).to be false
    end
  end

  describe 'file attachment' do
    it 'can attach a CSV file' do
      import = company.imports.create!(user: user, import_type: "products")
      import.file.attach(
        io: StringIO.new("sku,name\nABC,Widget\n"),
        filename: "test.csv",
        content_type: "text/csv"
      )
      expect(import.file).to be_attached
      expect(import.file.download).to include("ABC,Widget")
    end
  end
end
