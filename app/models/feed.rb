require_relative '../../lib/finds_or_creates_feeds'

# Feeds are pretty central to everything. They're a representation of a PuSH
# enabled Atom feed. Every user has a feed of their updates, we keep feeds
# for remote users that our users are subscribed to, and maybe even other
# things in the future, like hashtags.

class Feed
  # XXX: Are these even needed? Bundler should be require-ing them.
  require 'osub'
  require 'opub'
  require 'nokogiri'
  require 'atom'

  include MongoMapper::Document

  # Feed url (and an indicator that it is local if this is nil)
  key :remote_url, String

  # OStatus subscriber information
  key :verify_token, String
  key :secret, String

  # For both pubs and subs, it needs to know what hubs the feed is in
  # communication with in order to control pub/sub operations
  key :hubs, Array

  belongs_to :author
  key :author_id, ObjectId

  many :updates, :order => 'created_at desc'

  timestamps!

  after_create :default_hubs

  def self.find_or_create(subscribe_to)
    FindsOrCreatesFeeds.find_or_create(subscribe_to)
  end

  def self.create_from_feed_data(feed_data)
    feed = Feed.create(:remote_url => feed_data.url)
    feed.populate(feed_data.finger_data)
    feed
  end

   # This is because sometimes the mongomapper association returns nil
  # even though there is an author_id and the Author exists; see Issue #421
  def author
    Author.find(author_id)
  end

  def populate(finger_data)
    # TODO: More entropy would be nice
    self.verify_token = Digest::MD5.hexdigest(rand.to_s)
    self.secret = Digest::MD5.hexdigest(rand.to_s)

    ostatus_feed = OStatus::Feed.from_url(url)

    avatar_url = ostatus_feed.icon
    if avatar_url == nil
      avatar_url = ostatus_feed.logo
    end

    a = ostatus_feed.author

    self.author = Author.create(:name => a.portable_contacts.display_name,
                                :username => a.name,
                                :email => a.email,
                                :remote_url => a.uri,
                                :domain => a.uri,
                                :salmon_url => ostatus_feed.salmon,
                                :bio => a.portable_contacts.note,
                                :image_url => avatar_url)

    if(finger_data)
      self.author.public_key = finger_data.public_key
      self.author.reset_key_lease

      self.author.salmon_url = finger_data.salmon_url
      self.author.save
    end

    self.hubs = ostatus_feed.hubs

    save

    # Save the first 3 updates in our feed
    entries = ostatus_feed.entries

    if entries.length > 3
      entries = entries[0..2]
    end
    populate_entries(entries)

    save
  end

  def populate_entries(os_entries)
    os_entries.each do |entry|
      if entry.url # This will drop some RTs from identica until ostatus
                   # issue #4 is fixed, but at least this'll fix issue #458
        existing_update = Update.first(:remote_url => entry.url)

        if existing_update
          # Don't change anything about an existing update unless this
          # is an update event.
          if entry.activity && entry.activity.verb == "update"
            existing_update.sanitize_external_text(entry.content, entry.url)
            existing_update.save
            self.updates << existing_update
          end
        else
          u = Update.create_from_ostatus(entry, self)
          self.updates << u
        end
      end
    end
    save
  end

  # Pings hub
  # needs absolute url for feed to give to hub for callback
  def ping_hubs
    feed_url = "#{url}.atom"
    OPub::Publisher.new(feed_url, hubs).ping_hubs
  end

  def local?
    remote_url.nil?
  end

  def url(atom_format = false)
    if remote_url.nil? && author
      protocol = author.use_ssl ? "https" : "http"
      url = "#{protocol}://#{author.domain}/feeds/#{id}"
    else
      url = remote_url
    end
    url << ".atom" if atom_format
    url
  end

  def update_entries(atom_xml, callback_url, feed_url, signature)
    sub = OSub::Subscription.new(callback_url, feed_url, self.secret)

    if sub.verify_content(atom_xml, signature)
      os_feed = OStatus::Feed.from_string(atom_xml)
      # XXX: Update author if necessary

      populate_entries(os_feed.entries)
    end
  end

  def default_hubs
    self.hubs << "http://rstatus.superfeedr.com/"

    save
  end

  # create atom feed
  # need base_uri since urls outgoing should be absolute
  def atom(base_uri, params = {})
    if params[:since]
      atom_updates = updates.where(:created_at => {:$gt => params[:since]})
    elsif params[:num]
      atom_updates = updates.limit(params[:num])
    else
      atom_updates = updates.limit(20)
    end

    # Create the OStatus::Author object
    os_auth = author.to_atom

    # Gather entries as OStatus::Entry objects
    entries = atom_updates.map do |update|
      update.to_atom(base_uri)
    end

    avatar_url_abs = author.avatar_url
    if avatar_url_abs.start_with?("/")
      avatar_url_abs = "#{base_uri}#{author.avatar_url[1..-1]}"
    end

    # Create a Feed representation which we can generate
    # the Atom feed and send out.
    atom_url   = "#{base_uri}feeds/#{id}.atom"
    salmon_url = "#{base_uri}feeds/#{id}/salmon"

    feed = OStatus::Feed.from_data(
      atom_url,
      :title   => "#{author.username}'s Updates",
      :logo    => avatar_url_abs,
      :id      => atom_url,
      :author  => os_auth,
      :updated => updated_at,
      :entries => entries,
      :links   => {
        :hub    => [{:href => hubs.first}],
        :salmon => [{:href => salmon_url}],
        :"http://salmon-protocol.org/ns/salmon-replies" =>
          [{:href => salmon_url}],
        :"http://salmon-protocol.org/ns/salmon-mention" =>
          [{:href => salmon_url}]
      }
    )

    feed.atom
  end

  def last_update
    updates.first
  end
end
