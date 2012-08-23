require_relative 'converts_subscriber_to_feed_data'

class FindsOrCreatesFeeds
  def self.find_or_create(subscribe_to)
    feed = Feed.first(:id => subscribe_to)

    unless feed
      feed_data = ConvertsSubscriberToFeedData.get_feed_data(subscribe_to)
      feed = Feed.first(:remote_url => feed_data.url)
      feed = Feed.create_from_feed_data(feed_data) if feed.nil?
      feed.populate(feed_data.finger_data) if !feed.subscribed
    end

    feed
  end
end

