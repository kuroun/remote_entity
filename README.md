# RemoteEntity

A gem to create entity classes and methods which make http request to remote servers using **configuration style**. It avoids writing duplicated code that communicates to multiple remote services.

It is something less restricts than [her](https://github.com/remi/her) which maps to any http requests (not only for RESTful resources) but comparing to [rest-client](https://github.com/rest-client/rest-client), this gem is more object oriented. See usage below for details.

Currently it supports oauth2 `client_credentials` grant type for API authentication.

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add remote_entity

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install remote_entity

## Usage

```
RemoteEntity.configure(
    name: "User",
    methods: [
        {
            name: "find",
            http_method: "Get",
            url: "https://example.com/users/:id",
            param_mapping: {
                path_params: [:id],
                query_params: [:public]
            },
            authentication: {
                method: "oauth2.client_credentials"
            },
            r_turn: true
        },
        {
            name: "create",
            http_method: "Post",
            url: "https://example.com/users",
            param_mapping: {
                body_params: [:name, :age]
            },
            r_turn: false
        }
    ],
    authentications: {
        oauth2: {
            client_credentials: {
                client_id: "client-id",
                client_secret: "client-secret",
                site: "https:/example.com",
                token_url: "/token",
                scope: "users:read users:write",
            }
        }
    }
)
```
The configuration generated `RemoteEntity::User` class with `find` method which can be used by the following example:

```
RemoteEntity::User.find(id: 1, public: true)
```
**NOTE**:
- All entity classes created are under `RemoteEntity` namespace.
- The classes generated are a typical Ruby class which can be extended, inherited. For example:
```
class UserService < RemoteEntity::User

end
```
- The methods generated are `class method`.
- The method parameter generated from configuration is always key/value pairs (hash)

The method parameters will be transformed into `path parameter`, `query parameter` or `body parameter` of the request by `param_mapping` configuration. It makes the following `GET` http request:
```
curl --location 'https://example.com/users/1?public=true' \
--header 'Content-Type: application/json' \
--header 'Authorization: Bearer <token>'
```

`Content-Type` header as `application/json` is by default.

`Authorization` header is generated by oauth2 request using grant type defined in the configuration. The example above uses ouath2 client_credentials grant type. (The gem uses [oauth2](https://gitlab.com/oauth-xx/oauth2/) gem underdying, so the param structure is pretty the same as oauth2)

Since the `find` method is configured to return value (`r_turn` is set to `true`), it will return whatever the http response has. For example:
```
{
    id: 1,
    name: "Jonas",
    age: 22
}
```
The configuration also creates `create` method. For example:
```
RemoteEntity::User.create(name: "John", age: 23)
```
It will make the following `POST` http request:
```
curl --location 'https://example.com/users' \
--header 'Content-Type: application/json' \
--data-raw '
{
"name": "John",
"age": 23
}'
```
It has no authorization configured, so no `Authorization` header.

It does not return anything as `r_turn` is set to `false`.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/kseung-gpsw/remote_entity. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/remote_entity/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the RemoteEntity project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/remote_entity/blob/main/CODE_OF_CONDUCT.md).
