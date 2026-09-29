require 'rails_helper'

RSpec.describe CsvWithLines do
  def lines_of(content)
    described_class.parse(content).map(&:last)
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
    row, = described_class.parse("SKU,Name\nA,x\n", header_converters: :symbol).first

    expect(row[:sku]).to eq('A')
  end
end
