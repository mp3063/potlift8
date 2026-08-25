module ApplicationHelper
  include Pagy::Frontend

  def js_escape_string(str)
    return "" if str.nil?

    str.to_s
       .gsub("\\", "\\\\")  # Backslash must be escaped first
       .gsub("'", "\\\\'")
       .gsub('"', '\\"')
       .gsub("\n", '\\n')
       .gsub("\r", '\\r')
       .gsub("\t", '\\t')
  end
end
