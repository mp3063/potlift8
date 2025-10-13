# Pagy Initializer
#
# Configuration for Pagy pagination gem.
# See: https://ddnexus.github.io/pagy/docs/api/pagy/

require 'pagy/extras/overflow'

# Default items per page
Pagy::DEFAULT[:items] = 25

# Overflow handling: :last_page (default) redirects to last page when page > pages
Pagy::DEFAULT[:overflow] = :last_page

# Enable metadata for APIs (optional, can be removed if not needed)
Pagy::DEFAULT[:metadata] = [:page, :count, :from, :to, :prev, :next, :pages]

# Enable Pagy::Frontend methods in ApplicationHelper
# This makes pagy helpers available in views
require 'pagy/extras/metadata'
