require 'httparty'
require 'cgi'
require 'multi_json'
require "pocket_api/version"
require "pocket_api/connection"

module PocketApi
  class UnauthorizedError < StandardError; end
  class ApiLimitError < StandardError; end
  class MaintenanceError < StandardError; end

  class <<self
    attr_accessor :client_key

    def configure(credentials={})
      @client_key   = credentials[:client_key]
    end

    # Retrieve API
    # Options:
    # * state
    #   unread = only return unread items (default)
    #   archive = only return archived items
    #   all = return both unread and archived items
    # * favorite
    #   0 = only return un-favorited items
    #   1 = only return favorited items
    # * tag
    #   tag_name = only return items tagged with tag_name
    #   _untagged_ = only return untagged items
    # * contentType
    #   article = only return articles
    #   video = only return videos or articles with embedded videos
    #   image = only return images
    # * sort
    #   newest = return items in order of newest to oldest
    #   oldest = return items in order of oldest to newest
    #   title = return items in order of title alphabetically
    #   site = return items in order of url alphabetically
    # * detailType
    #   simple = only return the titles and urls of each item
    #   complete = return all data about each item, including tags, images, authors, videos and more
    # * search - search query
    # * domain - search within a domain
    # * since - timestamp of modifed items after a date
    # * count - limit of items to return
    # * offset - Used only with count; start returning from offset position of results
    def retrieve(access_token, options={})
      response = request(access_token, :get, "/v3/get", {:body => options})
      response
    end

    # Add API
    # Options:
    # * title
    # * tags - comma-seperated list of tags
    # * tweet_id - Twitter tweet_id
    def add(access_token, url, options={})
      request(access_token, :post, '/v3/add', :body => {:url => url}.merge(options))
    end

    # Modify API
    # Actions:
    # * add
    # * archive
    # * readd - re-add
    # * favorite
    # * unfavorite
    # * delete
    # * tags_add
    # * tags_remove
    # * tags_replace
    # * tags_clear
    # * tags_rename
    def modify(access_token, action, options={})
      request(access_token, :post, '/v3/send', :body => {:action => action}.merge(options))
    end

    def multi_modify(access_token, actions)
      request(access_token, :post, '/v3/send', :body => {:actions => actions})
    end

    def request(access_token, method, *arguments)
      arguments[1] ||= {}
      arguments[1][:body] ||= {}
      arguments[1][:body] = MultiJson.dump(arguments[1][:body].merge({:consumer_key => @client_key, :access_token => access_token}))
      response = Connection.__send__(method.downcase.to_sym, *arguments)

      error_message = ''
      error_message = response.headers["X-Error"] if response.headers["X-Error"]
      case response.code
      when 200
        # nothing
      when 400
        raise error_message # RuntimeError
      when 401
        raise PocketApi::UnauthorizedError.new(error_message)
      when 403
        raise PocketApi::ApiLimitError.new(error_message)
      when 503
        raise PocketApi::MaintenanceError.new(error_message)
      else
        raise error_message
      end

      response.parsed_response
    end

  end # <<self
end
