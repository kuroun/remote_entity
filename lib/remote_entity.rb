# frozen_string_literal: true

require_relative "remote_entity/version"
require "oauth2"
require "time"
require 'cgi'
require "json"
require "net/http"
require 'pry'

module RemoteEntity
  class Error < StandardError; end
  # Your code goes here...
  def self.configure(options)
    raise "missing required parameter - name" if options[:name].nil?
    raise "missing required parameter - methods" if options[:methods].nil?

    Object.const_set(
      options[:name], Class.new do
        options[:methods].each do |method|
          singleton_class.send(:define_method, method[:name]) do |arg|
            raise "invalid parameter type - accepted only hash" unless arg.is_a? Hash

            url = method[:url]

            if method[:param_mapping] && method[:param_mapping][:path_params]
              url = RemoteEntity.build_path_params(url, method[:param_mapping][:path_params], arg)
            end

            if method[:param_mapping] && method[:param_mapping][:query_params]
              url = RemoteEntity.build_query_params(url, method[:param_mapping][:query_params], arg)
            end

            url = URI(url)
            https = Net::HTTP.new(url.host, url.port)
            https.use_ssl = true
            http_class = Object.const_get("Net::HTTP::#{method[:http_method]}")
            request = http_class.new(url)
            request["Content-Type"] = "application/json"

            if method[:authentication]
              if method[:authentication][:method].include?("oauth2")
                request["Authorization"] = RemoteEntity.build_oauth2_authorized_token_header(method[:authentication][:method], options[:authentications])
              end
            end

            if method[:param_mapping] && method[:param_mapping][:body_params]
              request.body = JSON.dump(RemoteEntity.build_body_params(url, method[:param_mapping][:body_params], arg))
            end

            response = https.request(request)
            attributes = JSON.parse(response.read_body)
            if method[:r_turn]
              return attributes
            end

          end
        end
      end
    )
  end

  def self.build_path_params(base_url, keys, params)
    result = base_url
    keys.each do |k|
      result = result.gsub(":#{k.to_s}", params[k].to_s)
    end
    result
  end

  def self.build_query_params(base_url, keys, params)
    if keys.size > 0
      result = "#{base_url}?"
      keys.each do |k|
        result = "#{result}#{k.to_s}=#{CGI.escape(params[k].to_s)}&"
      end
      # remove the last &
      return result[0...-1]
    end
    base_url
  end

  def self.build_body_params(base_url, keys, params)
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
end
