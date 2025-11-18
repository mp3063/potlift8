# frozen_string_literal: true

module Shared
  # Skeleton loading state for table components
  #
  # Displays a placeholder table while actual content loads via Turbo Frames.
  # Provides better perceived performance and visual feedback.
  #
  # @example Basic usage
  #   <%= render Shared::SkeletonTableComponent.new(rows: 10) %>
  #
  # @example With custom columns
  #   <%= render Shared::SkeletonTableComponent.new(
  #     rows: 5,
  #     columns: ['SKU', 'Name', 'Status', 'Actions']
  #   ) %>
  #
  class SkeletonTableComponent < ViewComponent::Base
    attr_reader :rows, :columns

    def initialize(rows: 10, columns: nil)
      @rows = rows
      @columns = columns || ['', '', '', '', '']
    end

    def call
      content_tag(:div, class: "mt-8 flow-root") do
        content_tag(:div, class: "-mx-4 -my-2 overflow-x-auto sm:-mx-6 lg:-mx-8") do
          content_tag(:div, class: "inline-block min-w-full py-2 align-middle sm:px-6 lg:px-8") do
            content_tag(:table, class: "min-w-full divide-y divide-gray-300") do
              concat(render_thead)
              concat(render_tbody)
            end
          end
        end
      end
    end

    private

    def render_thead
      content_tag(:thead, class: "bg-gray-50") do
        content_tag(:tr) do
          @columns.each do |column|
            concat(content_tag(:th, column, class: "px-3 py-3.5 text-left text-sm font-semibold text-gray-900"))
          end
        end
      end
    end

    def render_tbody
      content_tag(:tbody, class: "divide-y divide-gray-200 bg-white") do
        @rows.times do
          concat(render_skeleton_row)
        end
      end
    end

    def render_skeleton_row
      content_tag(:tr, class: "animate-pulse") do
        @columns.each_with_index do |_, index|
          concat(render_skeleton_cell(index))
        end
      end
    end

    def render_skeleton_cell(index)
      content_tag(:td, class: "whitespace-nowrap px-3 py-4") do
        # Vary skeleton widths for more realistic appearance
        width = case index
                when 0 then "w-24"
                when 1 then "w-48"
                when 2 then "w-32"
                else "w-20"
                end
        content_tag(:div, nil, class: "h-4 bg-gray-200 rounded #{width}")
      end
    end
  end
end
