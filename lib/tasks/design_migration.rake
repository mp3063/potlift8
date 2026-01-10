# frozen_string_literal: true

namespace :design do
  desc "Migrate color scheme from indigo to blue to match Authlift8 design system"
  task migrate_colors: :environment do
    puts "\n" + "=" * 80
    puts "POTLIFT8 DESIGN MIGRATION: Indigo → Blue Color Scheme"
    puts "=" * 80
    puts "\nMigrating color classes to match Authlift8 design system..."
    puts "This will replace all indigo-* classes with blue-* equivalents.\n\n"

    # Color mapping from indigo to blue (all Tailwind shades)
    color_map = {
      "indigo-50" => "blue-50",
      "indigo-100" => "blue-100",
      "indigo-200" => "blue-200",
      "indigo-300" => "blue-300",
      "indigo-400" => "blue-400",
      "indigo-500" => "blue-500",
      "indigo-600" => "blue-600",
      "indigo-700" => "blue-700",
      "indigo-800" => "blue-800",
      "indigo-900" => "blue-900",
      "indigo-950" => "blue-950"
    }

    # File patterns to search
    patterns = [
      "app/components/**/*.rb",
      "app/components/**/*.html.erb",
      "app/views/**/*.html.erb",
      "app/assets/stylesheets/**/*.css"
    ]

    # Collect all matching files
    files = patterns.flat_map { |pattern| Dir.glob(pattern) }.uniq

    puts "Scanning #{files.count} files for indigo color references...\n\n"

    updated_files = []
    total_replacements = 0

    files.each do |file|
      begin
        content = File.read(file)
        original_content = content.dup
        replacements_in_file = 0

        # Replace each color mapping
        color_map.each do |old_color, new_color|
          count = content.scan(/\b#{Regexp.escape(old_color)}\b/).count
          if count > 0
            content.gsub!(/\b#{Regexp.escape(old_color)}\b/, new_color)
            replacements_in_file += count
          end
        end

        # Write file if modified
        if content != original_content
          File.write(file, content)
          updated_files << file
          total_replacements += replacements_in_file

          # Show progress
          relative_path = file.gsub(/^#{Regexp.escape(Rails.root.to_s)}\//, "")
          puts "✓ Updated: #{relative_path} (#{replacements_in_file} replacements)"
        end
      rescue StandardError => e
        puts "✗ Error processing #{file}: #{e.message}"
      end
    end

    puts "\n" + "=" * 80
    puts "MIGRATION COMPLETE"
    puts "=" * 80
    puts "\nSummary:"
    puts "  Files scanned:     #{files.count}"
    puts "  Files updated:     #{updated_files.count}"
    puts "  Total replacements: #{total_replacements}"

    if updated_files.any?
      puts "\nUpdated files:"
      updated_files.each do |file|
        relative_path = file.gsub(/^#{Regexp.escape(Rails.root.to_s)}\//, "")
        puts "  • #{relative_path}"
      end
    else
      puts "\n  No indigo color references found. Migration already complete!"
    end

    puts "\n" + "=" * 80
    puts "NEXT STEPS"
    puts "=" * 80
    puts "\n1. Verify migration:"
    puts "   grep -r \"indigo-\" app/components app/views --include=\"*.rb\" --include=\"*.erb\""
    puts "\n2. Run tests:"
    puts "   bin/test"
    puts "\n3. Start dev server and visually verify:"
    puts "   bin/dev"
    puts "   Visit http://localhost:3246\n\n"
  end

  desc "Verify color migration completion (checks for remaining indigo references)"
  task verify_colors: :environment do
    puts "\n" + "=" * 80
    puts "VERIFYING COLOR MIGRATION"
    puts "=" * 80
    puts "\nChecking for remaining indigo color references...\n\n"

    patterns = [
      "app/components/**/*.rb",
      "app/components/**/*.html.erb",
      "app/views/**/*.html.erb",
      "app/assets/stylesheets/**/*.css"
    ]

    files = patterns.flat_map { |pattern| Dir.glob(pattern) }.uniq
    indigo_references = []

    files.each do |file|
      begin
        content = File.read(file)
        line_number = 0

        content.each_line do |line|
          line_number += 1
          if line.match?(/\bindigo-\d+\b/)
            relative_path = file.gsub(/^#{Regexp.escape(Rails.root.to_s)}\//, "")
            indigo_references << {
              file: relative_path,
              line: line_number,
              content: line.strip
            }
          end
        end
      rescue StandardError => e
        puts "✗ Error checking #{file}: #{e.message}"
      end
    end

    if indigo_references.empty?
      puts "✓ SUCCESS! No indigo color references found."
      puts "  Migration is complete.\n\n"
    else
      puts "✗ FOUND #{indigo_references.count} REMAINING INDIGO REFERENCES:\n\n"

      indigo_references.each do |ref|
        puts "  File: #{ref[:file]}:#{ref[:line]}"
        puts "  Code: #{ref[:content]}"
        puts ""
      end

      puts "\nPlease review and manually fix these references if needed.\n\n"
    end

    puts "=" * 80 + "\n\n"
  end

  desc "Rollback color migration (blue → indigo) - USE WITH CAUTION"
  task rollback_colors: :environment do
    puts "\n" + "=" * 80
    puts "WARNING: ROLLBACK COLOR MIGRATION"
    puts "=" * 80
    puts "\nThis will revert all blue-* classes back to indigo-*."
    puts "Are you sure you want to proceed? (yes/no)"

    response = STDIN.gets.chomp.downcase

    unless response == "yes"
      puts "\nRollback cancelled.\n\n"
      exit
    end

    puts "\nRolling back color migration...\n\n"

    # Reverse color mapping (blue to indigo)
    color_map = {
      "blue-50" => "indigo-50",
      "blue-100" => "indigo-100",
      "blue-200" => "indigo-200",
      "blue-300" => "indigo-300",
      "blue-400" => "indigo-400",
      "blue-500" => "indigo-500",
      "blue-600" => "indigo-600",
      "blue-700" => "indigo-700",
      "blue-800" => "indigo-800",
      "blue-900" => "indigo-900",
      "blue-950" => "indigo-950"
    }

    patterns = [
      "app/components/**/*.rb",
      "app/components/**/*.html.erb",
      "app/views/**/*.html.erb",
      "app/assets/stylesheets/**/*.css"
    ]

    files = patterns.flat_map { |pattern| Dir.glob(pattern) }.uniq
    updated_count = 0

    files.each do |file|
      begin
        content = File.read(file)
        original_content = content.dup

        # Only replace in specific contexts to avoid replacing legitimate blue colors
        # This is a simplified rollback - manual review may be needed
        color_map.each do |old_color, new_color|
          content.gsub!(/\b#{Regexp.escape(old_color)}\b/, new_color)
        end

        if content != original_content
          File.write(file, content)
          relative_path = file.gsub(/^#{Regexp.escape(Rails.root.to_s)}\//, "")
          puts "✓ Rolled back: #{relative_path}"
          updated_count += 1
        end
      rescue StandardError => e
        puts "✗ Error processing #{file}: #{e.message}"
      end
    end

    puts "\n" + "=" * 80
    puts "ROLLBACK COMPLETE"
    puts "=" * 80
    puts "\nFiles rolled back: #{updated_count}\n\n"
  end
end
