require 'rails_helper'

RSpec.describe Shared::SkeletonTableComponent, type: :component do
  it "renders skeleton table with default rows" do
    render_inline(described_class.new)

    expect(page).to have_css('table.min-w-full')
    expect(page).to have_css('tbody tr.animate-pulse', count: 10)
  end

  it "renders custom number of rows" do
    render_inline(described_class.new(rows: 5))

    expect(page).to have_css('tbody tr.animate-pulse', count: 5)
  end

  it "renders custom columns" do
    render_inline(described_class.new(
      columns: [ 'SKU', 'Name', 'Status' ]
    ))

    expect(page).to have_css('thead th', text: 'SKU')
    expect(page).to have_css('thead th', text: 'Name')
    expect(page).to have_css('thead th', text: 'Status')
    expect(page).to have_css('thead th', count: 3)
  end

  it "renders skeleton cells with varied widths" do
    render_inline(described_class.new(rows: 1))

    expect(page).to have_css('td .bg-gray-200.rounded')
  end

  it "applies animate-pulse class to rows" do
    render_inline(described_class.new(rows: 3))

    expect(page).to have_css('tr.animate-pulse', count: 3)
  end

  it "renders table structure with proper classes" do
    render_inline(described_class.new)

    expect(page).to have_css('div.flow-root')
    expect(page).to have_css('div.overflow-x-auto')
    expect(page).to have_css('table.divide-y.divide-gray-300')
    expect(page).to have_css('thead.bg-gray-50')
    expect(page).to have_css('tbody.divide-y.divide-gray-200.bg-white')
  end

  it "renders empty column headers when columns not specified" do
    render_inline(described_class.new)

    expect(page).to have_css('thead th', count: 5)
  end

  it "renders different skeleton widths for different columns" do
    render_inline(described_class.new(rows: 1, columns: [ 'A', 'B', 'C', 'D' ]))

    # Check that different width classes are used
    skeleton_divs = page.all('td div.bg-gray-200')
    expect(skeleton_divs.length).to eq(4)

    # First column should be w-24
    expect(skeleton_divs[0][:class]).to include('w-24')
    # Second column should be w-48
    expect(skeleton_divs[1][:class]).to include('w-48')
    # Third column should be w-32
    expect(skeleton_divs[2][:class]).to include('w-32')
    # Fourth column should be w-20
    expect(skeleton_divs[3][:class]).to include('w-20')
  end
end
