# frozen_string_literal: true

require "remote_entity"

RSpec.describe RemoteEntity do
  it "has a version number" do
    expect(RemoteEntity::VERSION).not_to be nil
  end

  describe ".configure" do
    context "when required parameters are missing" do
      it "raises an error if name is missing" do
        expect { RemoteEntity.configure(methods: []) }.to raise_error("missing required parameter - name")
      end

      it "raises an error if methods is missing" do
        expect { RemoteEntity.configure(name: "MyEntity") }.to raise_error("missing required parameter - methods")
      end
    end

    context "when required parameters are provided" do
      let(:options) do
        {
          name: "MyEntity",
          methods: [
            {
              name: "get_data",
              url: "https://example.com/data/:id",
              http_method: "Get",
              param_mapping: {
                query_params: %i[name age],
                path_params: [:id]
              }
            },
            {
              name: :create_data,
              url: "https://example.com/data",
              http_method: "Post",
              param_mapping: {
                body_params: %i[name age],
                path_params: [:id]
              }
            }
          ]
        }
      end

      let(:entity) { RemoteEntity::MyEntity }

      before do
        RemoteEntity.configure(options)
      end

      it "defines a new class with the provided name" do
        expect(Object.const_defined?("RemoteEntity::MyEntity")).to be true
      end

      it "defines methods on the new class" do
        expect(entity).to respond_to(:get_data)
        expect(entity).to respond_to(:create_data)
      end

      describe "RemoteEntity::MyEntity.get_data" do
        before do
          allow_any_instance_of(Net::HTTP).to receive(:request)
            .and_return(
              double(read_body: { last_name: "Doe" }.to_json)
            )
        end

        it "creates a new instance of Net::HTTP::Get" do
          expect(Object).to receive(:const_get).with("Net::HTTP::Get").and_call_original
          entity.get_data(id: 1, name: "John", age: 30)
        end

        context "when path parameters or query params are configured" do
          it "sends a GET request with params in the url" do
            expect(URI).to receive(:parse).with("https://example.com/data/1?name=John&age=30").and_call_original
            entity.get_data(id: 1, name: "John", age: 30)
          end
        end

        context "when authentication is configured with oauth2 client_credentials" do
          before do
            options[:methods][0][:authentication] = {
              method: "oauth2.client_credentials"
            }
          end
          it "sends a GET request with an OAuth2 authorized token header" do
            expect(RemoteEntity).to receive(:build_oauth2_authorized_token_header)
              .with(
                "oauth2.client_credentials",
                options[:authentications]
              )
              .and_return("Bearer token")
            entity.get_data(id: 1, name: "John", age: 30)
          end
        end

        context "when authentication is configured with oauth2 and accepting_instant_token" do
          before do
            options[:methods][0][:authentication] = {
              method: "oauth2.client_credentials",
              accepting_instant_token: :authorized_token
            }
          end

          it "sends a GET request with an instant OAuth2 authorized token header" do
            expect(RemoteEntity).not_to receive(:build_oauth2_authorized_token_header)
            entity.get_data(id: 1, name: "John", age: 30, authorized_token: "token")
          end
        end

        context "when r_turn is configured" do
          before do
            options[:methods][0][:r_turn] = true
          end
          it "returns the response body" do
            expect(entity.get_data(id: 1, name: "John", age: 30)).to eq({ "last_name" => "Doe" })
          end
        end
      end

      describe "RemoteEntity::MyEntity.create_data" do
        before do
          allow_any_instance_of(Net::HTTP).to receive(:request)
            .and_return(
              double(read_body: { last_name: "Doe" }.to_json)
            )
        end

        it "creates a new instance of Net::HTTP::Post" do
          expect(Object).to receive(:const_get).with("Net::HTTP::Post").and_call_original
          entity.create_data(name: "John", age: 30)
        end

        context "when body parameters are configured" do
          it "sends a POST request with body parameters" do
            expect_any_instance_of(Net::HTTP::Post).to receive(:body=).with({ name: "John", age: 30 }.to_json)
            entity.create_data(name: "John", age: 30)
          end
        end
      end
    end
  end

  describe ".build_path_params" do
    let(:base_url) { "https://example.com/users/:id/posts/:post_id" }
    let(:keys) { %i[id post_id] }
    let(:params) { { id: 1, post_id: 10 } }
    let(:expected_result) { "https://example.com/users/1/posts/10" }

    it "replaces path parameters in the base URL with the provided values" do
      expect(RemoteEntity.build_path_params(base_url, keys, params)).to eq(expected_result)
    end
  end

  describe ".build_query_params" do
    let(:base_url) { "https://example.com/data" }
    let(:keys) { %i[email name age] }
    let(:params) { { email: "john@example.com", name: "John", age: 30 } }
    let(:expected_result) { "https://example.com/data?email=john%40example.com&name=John&age=30" }

    it "builds query parameters string with the provided keys and values" do
      expect(RemoteEntity.build_query_params(base_url, keys, params)).to eq(expected_result)
    end

    context "when no keys are provided" do
      let(:keys) { [] }

      it "returns the base URL" do
        expect(RemoteEntity.build_query_params(base_url, keys, params)).to eq(base_url)
      end
    end
  end

  describe ".build_body_params" do
    let(:keys) { %i[name age] }
    let(:params) { { name: "John", age: 30, email: "john@example" } }
    # only keys that are provided are included in the result
    let(:expected_result) { { name: "John", age: 30 } }

    it "builds a hash with the provided keys and values" do
      expect(RemoteEntity.build_body_params(keys, params)).to eq(expected_result)
    end
  end

  describe ".build_oauth2_authorized_token_header" do
    let(:method) { "oauth2.client_credentials" }
    let(:method_inventory) do
      {
        oauth2: {
          client_credentials: {
            client_id: "client_id",
            client_secret: "client_secret",
            site: "https://example.com",
            token_url: "https://example.com/token",
            scope: "read write"
          }
        }
      }
    end
    let(:expected_result) { "Bearer token" }

    before do
      allow(OAuth2::Client).to receive(:new)
        .and_return(double(client_credentials: double(get_token: double(token: "token"))))
    end

    it "builds an OAuth2 authorized token header" do
      expect(RemoteEntity.build_oauth2_authorized_token_header(method, method_inventory)).to eq(expected_result)
    end
  end
end
