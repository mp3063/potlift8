module ApplicationHelper
  # Include Pagy frontend helper for pagination
  # Provides helpers like pagy_nav, pagy_info, etc.
  include Pagy::Frontend

  # Escape a string for safe use in JavaScript string literals
  # Handles quotes, newlines, and other special characters
  #
  # @param str [String] the string to escape
  # @return [String] the escaped string safe for use in JavaScript
  def js_escape_string(str)
    return "" if str.nil?

    str.to_s
       .gsub("\\", "\\\\")  # Backslash must be escaped first
       .gsub("'", "\\\\'")   # Single quotes
       .gsub('"', '\\"')     # Double quotes
       .gsub("\n", '\\n')    # Newlines
       .gsub("\r", '\\r')    # Carriage returns
       .gsub("\t", '\\t')    # Tabs
  end
end
