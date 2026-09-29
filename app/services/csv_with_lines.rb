require "csv"

# Parses CSV with headers into [headers, rows], pairing each row with the physical file line it
# starts on (header is line 1). CSV#lineno counts rows, so it is wrong once a quoted field holds a line break.
module CsvWithLines
  def self.parse(content, **csv_options)
    csv = CSV.new(content, headers: true, **csv_options)
    line = 2
    rows = csv.each.map do |row|
      raw = csv.line
      [ row, line ].tap { line += raw.count("\n") + (raw.end_with?("\n") ? 0 : 1) }
    end
    headers = csv.headers.is_a?(Array) ? csv.headers : [] # csv.headers is `true` when no header row was read
    [ headers, rows ]
  end
end
