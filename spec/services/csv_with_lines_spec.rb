require 'rails_helper'

RSpec.describe CsvWithLines do
  def lines_of(content)
    described_class.parse(content).last.map(&:last)
  end

  it 'gives the physical line each row starts on' do
    expect(lines_of("sku,name\nA,x\nB,y\nC,z\n")).to eq([ 2, 3, 4 ])
  end

  it 'counts line breaks inside quoted fields' do
    expect(lines_of("sku,name\nA,\"x\ny\"\nB,z")).to eq([ 2, 4 ])
  end

  it 'counts CRLF line breaks inside quoted fields' do
    expect(lines_of("sku,name\r\nA,\"x\r\ny\"\r\nB,z\r\n")).to eq([ 2, 4 ])
  end

  it 'passes CSV options through' do
    headers, rows = described_class.parse("SKU,Name\nA,x\n", header_converters: :symbol)

    expect(headers).to eq([ :sku, :name ])
    expect(rows.first.first[:sku]).to eq('A')
  end

  it 'gives the headers of a header-only file and no rows' do
    expect(described_class.parse("sku,name\n")).to eq([ [ 'sku', 'name' ], [] ])
  end

  it 'gives no headers and no rows for an empty file' do
    expect(described_class.parse('')).to eq([ [], [] ])
  end
end
