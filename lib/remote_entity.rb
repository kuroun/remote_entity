# frozen_string_literal: true

require_relative "remote_entity/version"
require "oauth2"
require "time"
require "cgi"
require "json"
require "net/http"

# RemoteEntity is a gem that allows you to define a class that can call remote APIs.
module RemoteEntity
  class Error < StandardError; end

  # Your code goes here...
  def self.configure(options)
    raise "missing required parameter - name" if options[:name].nil?
    raise "missing required parameter - methods" if options[:methods].nil?

    RemoteEntity.const_set(options[:name], build_dynamic_class(options))
  end

  def self.build_dynamic_class(options)
    Class.new do
      options[:methods].each do |method|
        singleton_class.send(:define_method, method[:name]) do |arg|
          raise "invalid parameter type - accepted only hash" unless arg.is_a? Hash

          url = RemoteEntity.build_url(method, arg)
          https = Net::HTTP.new(url.host, url.port)
          https.use_ssl = true
          http_class = Object.const_get("Net::HTTP::#{method[:http_method]}")
          request = http_class.new(url)
          request["Content-Type"] = "application/json"

          RemoteEntity.set_authorization_header(request, method, arg, options) if method[:authentication]

          if method[:param_mapping] && method[:param_mapping][:body_params]
            request.body = JSON.dump(RemoteEntity.build_body_params(method[:param_mapping][:body_params], arg))
          end

          response = https.request(request)

          return JSON.parse(response.read_body) if method[:r_turn] && !response.read_body.empty?
        end
      end
    end
  end

  def self.set_authorization_header(request, method, arg, options)
    accepting_instant_token_key = method[:authentication][:accepting_instant_token]

    if accepting_instant_token_key && arg[accepting_instant_token_key]
      request["Authorization"] = "Bearer #{arg[accepting_instant_token_key]}"
    elsif method[:authentication][:method].include?("oauth2")
      request["Authorization"] =
        RemoteEntity.build_oauth2_authorized_token_header(method[:authentication][:method],
                                                          options[:authentications])
    end
  end

  def self.build_url(method, arg)
    url = method[:url]

    if method[:param_mapping] && method[:param_mapping][:path_params]
      url = RemoteEntity.build_path_params(url, method[:param_mapping][:path_params], arg)
    end

    if method[:param_mapping] && method[:param_mapping][:query_params]
      url = RemoteEntity.build_query_params(url, method[:param_mapping][:query_params], arg)
    end

    URI(url)
  end

  def self.build_path_params(base_url, keys, params)
    result = base_url
    keys.each do |k|
      result = result.gsub(":#{k}", params[k].to_s)
    end
    result
  end

  def self.build_query_params(base_url, keys, params)
    if keys.size.positive?
      result = "#{base_url}?"
      keys.each do |k|
        result = "#{result}#{k}=#{CGI.escape(params[k].to_s)}&"
      end
      # remove the last &
      return result[0...-1]
    end
    base_url
  end

  def self.build_body_params(keys, params)
    result = {}
    keys.each do |k|
      result[k.to_sym] = params[k.to_sym]
    end
    result
  end

  def self.build_oauth2_authorized_token_header(method, method_inventory)
    # TODO: implement cache
    grant_type = method.split(".")[1].to_sym
    credentials_info = method_inventory[:oauth2][grant_type]

    client = OAuth2::Client.new(credentials_info[:client_id],
                                credentials_info[:client_secret],
                                site: credentials_info[:site],
                                token_url: credentials_info[:token_url])
    token = client.send(grant_type).get_token(scope: credentials_info[:scope]).token

    "Bearer #{token}"
  end

  private_class_method :build_dynamic_class
end
