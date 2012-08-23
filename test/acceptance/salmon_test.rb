require 'require_relative' if RUBY_VERSION[0,3] == '1.8'
require_relative 'acceptance_helper'

describe "Salmon" do
  include AcceptanceHelper

  it "404s if that feed doesnt exist" do
    visit "/feeds/nonexistent/salmon"
    page.status_code.must_equal(404)
  end

  it "404s if there is no request body" do
    feed = Fabricate(:feed)
    visit "/feeds/#{feed.id}/salmon"
    page.status_code.must_equal(404)
  end

  it "404s if the request body does not contain a magic envelope" do
    VCR.turn_off!
    stub_request(:any, /http[s]?:\/\/identity-provider.com\/.well-known\/host-meta/)

    feed = Fabricate(:feed)
    post "/feeds/#{feed.id}/salmon", "<?xml version='1.0' encoding='UTF-8'?><bogus-xml />"
    if last_response.status == 301
      follow_redirect!
    end

    last_response.status.must_equal(404)
    VCR.turn_on!
  end

  describe "salmon notification" do
    before do
      VCR.turn_off!
    end

    after do
      VCR.turn_on!
    end

    it "is discarded when verification fails due to user xrd not retrievable" do
      # Set up Salmon that points to user xrd that doesn't exist through a web mock
      stub_request(:any, /http[s]?:\/\/identity-provider.com\/.well-known\/host-meta/).
        to_return(:status => 404)

      keypair = RSA::KeyPair.generate(2048)

      salmon = craft_salmon

      feed = Fabricate(:feed)
      post "/feeds/#{feed.id}/salmon", salmon.to_xml(keypair), :content_type => "application/magic-envelope+xml"
      last_response.status.must_equal(404)
    end

    it "is discarded when verification fails due to user signature mismatch" do
      # Set up Salmon that points to user xrd that doesn't exist through a web mock
      user = Fabricate(:user)

      stub_xrd user

      user2 = Fabricate(:user)

      salmon = craft_salmon

      feed = Fabricate(:feed)
      post "/feeds/#{feed.id}/salmon", salmon.to_xml(user2.to_rsa_keypair), :content_type => "application/magic-envelope+xml"
      last_response.status.must_equal(404)
    end

    it "is accepted when verification of signature is successful" do
      # Set up Salmon that points to user xrd that doesn't exist through a web mock
      user = Fabricate(:user)

      stub_xrd user

      salmon = craft_salmon

      feed = Fabricate(:feed)
      post "/feeds/#{feed.id}/salmon", salmon.to_xml(user.to_rsa_keypair), :content_type => "application/magic-envelope+xml"
      last_response.status.wont_equal(404)
    end
  end
end
