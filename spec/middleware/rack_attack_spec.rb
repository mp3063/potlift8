require "rails_helper"

RSpec.describe "Rack::Attack middleware" do
  it "is included in the middleware stack" do
    middlewares = Rails.application.middleware.map(&:name)
    expect(middlewares).to include("Rack::Attack")
  end

  it "has throttle rules configured" do
    expect(Rack::Attack.throttles.keys).to include("req/ip", "api/ip", "login/ip", "api/token")
  end
end
