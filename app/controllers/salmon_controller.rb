class SalmonController < ApplicationController
  def feeds
    SalmonInterpreter.new(
      request.body.read,
      {
        :feed_id  => params[:id],
        :root_url => root_url
      }
    ).interpret

    render :text => "", :status => 200
  rescue MongoMapper::DocumentNotFound, ArgumentError, RstatUs::InvalidSalmonMessage
    render :file => "#{Rails.root}/public/404", :status => 404
  end
end
