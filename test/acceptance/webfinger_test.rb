require 'require_relative' if RUBY_VERSION[0,3] == '1.8'
require_relative 'acceptance_helper'

describe "Webfinger" do
  include AcceptanceHelper

  it "404s if that user doesnt exist" do
    get "/users/acct:nonexistent@somedomain.com/xrd.xml"
    if last_response.status == 301
      follow_redirect!
    end
    last_response.status.must_equal(404)
  end

  it "renders the user's xrd" do
    @user = Fabricate(:user)
    param = "acct:#{@user.username}@#{@user.author.domain}"
    get "/users/#{param}/xrd.xml"
    if last_response.status == 301
      follow_redirect!
    end

    xml = Nokogiri.XML(last_response.body)
    subject = xml.xpath("//xmlns:Subject").first.content

    subject.must_equal(param)
  end

  it "has the correct absolute uri template in host-meta" do
    get "/.well-known/host-meta"
    xml = Nokogiri.XML(last_response.body)
    
    template_uri = xml.xpath('//xmlns:Link[@rel="lrdd"]').first.attr('template')

    template_uri.must_match /^http(?:s)?:\/\/.*\/users\/\{uri\}\/xrd.xml$/
  end
end
