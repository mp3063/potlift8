require "csv"

# Parses CSV with headers and pairs each row with the physical file line it starts on
# (header is line 1). CSV#lineno counts rows, so it is wrong once a quoted field holds a line break.
module CsvWithLines
  def self.parse(content, **csv_options)
    csv = CSV.new(content, headers: true, **csv_options)
    line = 2
    csv.each.map do |row|
      raw = csv.line
      [ row, line ].tap { line += raw.count("\n") + (raw.end_with?("\n") ? 0 : 1) }
    end
  end
end
