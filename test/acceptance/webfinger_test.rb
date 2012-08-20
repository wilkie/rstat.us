require 'require_relative' if RUBY_VERSION[0,3] == '1.8'
require_relative 'acceptance_helper'

describe "Webfinger" do
  include AcceptanceHelper

  describe "user xrd" do
    before do
      @user = Fabricate(:user)
      @subject = "acct:#{@user.username}@#{@user.author.domain}"
      get "/users/#{@subject}/xrd.xml"
      if last_response.status == 301
        follow_redirect!
      end

      @xml = Nokogiri.XML(last_response.body)
    end

    it "contains the salmon url" do
      regex = /^http(?:s)?:\/\/.*\/feeds\/#{@user.feed.id}\/salmon$/
      profile_rel = "salmon"
      profile_uri = @xml.xpath("//xmlns:Link[@rel='#{profile_rel}']")
      profile_uri.first.attr("href").must_match regex
    end

    it "contains the salmon-replies url" do
      regex = /^http(?:s)?:\/\/.*\/feeds\/#{@user.feed.id}\/salmon$/
      profile_rel = "http://salmon-protocol.org/ns/salmon-replies"
      profile_uri = @xml.xpath("//xmlns:Link[@rel='#{profile_rel}']")
      profile_uri.first.attr("href").must_match regex
    end

    it "contains the salmon-mention url" do
      regex = /^http(?:s)?:\/\/.*\/feeds\/#{@user.feed.id}\/salmon$/
      profile_rel = "http://salmon-protocol.org/ns/salmon-mention"
      profile_uri = @xml.xpath("//xmlns:Link[@rel='#{profile_rel}']")
      profile_uri.first.attr("href").must_match regex
    end

    it "contains the account name" do
      subject = @xml.xpath("//xmlns:Subject").first.content
      subject.must_equal(@subject)
    end

    it "contains profile uri as a uri for the user" do
      regex = /^http(?:s)?:\/\/.*\/users\/#{@user.username}$/
      aliases = @xml.xpath("//xmlns:Alias")
      aliases = aliases.map(&:content)
      aliases.select{|a| a.match(regex)}
      aliases.wont_be_empty
    end

    it "contains feed uri as a uri for the user" do
      regex = /^http(?:s)?:\/\/.*\/feeds\/#{@user.feed.id}$/
      aliases = @xml.xpath("//xmlns:Alias")
      aliases = aliases.map(&:content)
      aliases.select{|a| a.match(regex)}
      aliases.wont_be_empty
    end

    it "contains the profile page url" do
      regex = /^http(?:s)?:\/\/.*\/users\/#{@user.username}$/
      profile_rel = "http://webfinger.net/rel/profile-page"
      profile_uri = @xml.xpath("//xmlns:Link[@rel='#{profile_rel}']")
      profile_uri.first.attr("href").must_match regex
    end
  end

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
