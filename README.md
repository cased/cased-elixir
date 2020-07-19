# cased-elixir

A Cased client for Elixir applications in your organization to control and monitor the access of information within your organization.

## Overview

- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
  - [Publishing events to Cased](#publishing-events-to-cased)
  - [Retrieving events from a Cased Policy](#retrieving-events-from-a-cased-policy)
  - [Retrieving events from a Cased Policy containing variables](#retrieving-events-from-a-cased-policy-containing-variables)
  - [Retrieving events from multiple Cased Policies](#retrieving-events-from-multiple-cased-policies)
  - [Exporting events](#exporting-events)
  - [Masking & filtering sensitive information](#masking-and-filtering-sensitive-information)
  - [Disable publishing events](#disable-publishing-events)
  - [Context](#context)
  - [Testing](#testing)
- [Customizing cased-elixir](#customizing-cased-elixir)

## Installation

The package can be installed by adding `cased` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:cased, "~> 0.1.0"}
  ]
end
```

## Configuration

`cased-elixir` follows Elixir's [Library Guidelines](https://hexdocs.pm/elixir/master/library-guidelines.html#avoid-application-configuration), avoiding the use of a global `:cased` application configuration in favor of more flexible, ad hoc configuration at runtime (using your own application configuration, environment variables, etc).

### For Publisher

Add a worker specification for `Cased.Publisher.HTTP` to your application's supervisor.

The publisher accepts the following options:

- `:key` — Your [Cased publish key](https://docs.cased.com/apis#authentication-and-api-keys) (**required**).
- `:url` — The URL used to publish audit trail events via HTTP POST (**optional**;
  defaults to `https://publish.cased.com`).
- `:silence` — Whether audit trail events will be discarded, rather than sent; useful for
  non-production usage (**optional**; defaults to `false`).
- `:timeout` — The request timeout, in milliseconds (**optional**; defaults to `15_000`)

You can source your configuration values from your application configuration,
runtime environment variables, or hard-code them directly; the following is just
an example:

```elixir
children = [
  # Other workers...
  {
    Cased.Publisher.HTTP,
    key: System.get_env("CASED_PUBLISH_KEY") || Application.fetch_env!(:your_app, :cased_publish_key),
    silence: System.get_env("CASED_SILENCE") || Application.fetch_env!(:your_app, :cased_silence, false),
  }
]

# Other config...
Supervisor.start_link(children, opts)
```

In the event you provide an invalid configuration, a `Cased.ConfigurationError` will be raised with details.

### For Client

To access Cased API routes and functionality other than publishing, configure a
client using `Cased.Client.create/1`:

The function accepts the following options:

- `:key` — Your `default` [Cased policy key](https://docs.cased.com/apis#authentication-and-api-keys). This is
  shorthand for providing `:keys`, as explained below, with a value for
  `:default`:
- `:keys` - Your [Cased policy keys](https://docs.cased.com/apis#authentication-and-api-keys), by audit trail ([example below](#keys-example))
- `:url` — The API URL (**optional**; defaults to `https://api.cased.com`).
- `:timeout` — The request timeout, in milliseconds (**optional**; defaults to
  `15_000`)

These configuration values can be provided a number of ways, as shown in the
examples below.

#### Examples

Create a client with the policy key for your `default` audit trail:

```elixir
{:ok, client} = Cased.Client.create(key: "policy_live_...")
```

<a name="keys-example"></a>
Create a client key with policy keys for specific audit trails:

```elixir
{:ok, client} = Cased.Client.create(keys: [default: "policy_live_...", users: "policy_live_..."])
```

Clients can be configured using runtime environment variables, your application
configuration, hardcoded values, or any combination you choose:

```elixir
# Just using runtime environment variable:
{:ok, client} = Cased.Client.create(key: System.fetch_env!("CASED_POLICY_KEY"))

# Just using application configuration:
{:ok, client} = Cased.Client.create(key: Application.fetch_env!(:your_app, :cased_policy_key))

# Either/or
{:ok, client} = Cased.Client.create!(key: System.get_env("CASED_POLICY_KEY") || Application.fetch_env!(:your_app, :cased_policy_key))
```

In the event your client is misconfigured, you'll get a `Cased.ConfigurationError` exception struct instead:

```elixir
# Not providing required options:
{:error, %Cased.ConfigurationError{}} = Cased.Client.create()
```

You can also use `Cased.Client.create!/1` if you know you're passing the correct configuration options (otherwise it raises a `Cased.ConfigurationError` exception):

```elixir
client = Cased.Client.create!(key: "policy_live_...")
```

To simplify using clients across your application, consider writing a centralized function to handle constructing them:

```elixir
defmodule YourApp do

  # Rest of contents ...

  def cased_client do
    default_policy_key = System.get_env("CASED_POLICY_KEY") || Application.fetch_env!(:your_app, :cased_policy_key)
    Cased.Client.create!(key: default_policy_key)
  end
end
```

For reuse, consider caching your client structs in GenServer state, ETS, or another Elixir caching mechanism.

## Usage

### Publishing events to Cased

#### Manually

Provided you've [configured](#for-publisher) the Cased publisher, use `Cased.publish/1`:

```elixir
%{
  action: "credit_card.charge",
  amount: 2000,
  currency: "usd",
  source: "tok_amex",
  description: "My First Test Charge (created for API docs)",
  credit_card_id: "card_1dQpXqQwXxsQs9sohN9HrzRAV6y"
}
|> Cased.publish()

```

### Retrieving events from a Cased Policy

If you plan on retrieving events from your audit trails you must use an Cased Policy token.

```elixir
{:ok, client} = Cased.Client.create(key: "policy_live_1dQpY5JliYgHSkEntAbMVzuOROh")

events =
  client
  |> Cased.Event.query()
  |> Cased.Request.stream()

events
|> Enum.take(10)
|> Enum.each(fn event ->
  IO.inspect(event)
end)
```

### Retrieving events from a Cased Policy containing variables

Cased policies allow you to filter events by providing variables to your Cased
Policy events query. One example of a Cased Policy is to have a single Cased
Policy that you can use to query events for any user in your database without
having to create a Cased Policy for each user.

For example, printing the first 100 events in the default audit trail that
matches a specific user ID:

```elixir
client = Cased.Client.create(key: "policy_live_1dQpY5JliYgHSkEntAbMVzuOROh")

variables = [user_id: "user_1dSHQSNtAH90KA8zGTooMnmMdiD"]

events =
  client
  |> Cased.Event.query(variables: variables)
  |> Cased.Request.stream()

events
|> Enum.take(100)
|> Enum.each(fn event ->
  IO.inspect(event)
end)
```

### Retrieving events from multiple Cased Policies

To retrieve events from one or more Cased Policies you can configure multiple
Cased Policy API keys and retrieve events for each one.

For example, printing the first 100 events for the user and organization audit
trails:

```elixir
client = Cased.Client.create(keys: [
  users: "policy_live_1dQpY8bBgEwdpmdpVrrtDzMX4fH",
  organizations: "policy_live_1dSHQRurWX8JMYMbkRdfzVoo62d"
])

users_events =
  client
  |> Cased.Event.query(audit_trail: :users, variables: variables)
  |> Cased.Request.stream()

users_events
|> Enum.take(100)
|> Enum.each(fn event ->
  IO.inspect(event)
end)

org_events =
  client
  |> Cased.Event.query(audit_trail: :organizations, variables: variables)
  |> Cased.Request.stream()

org_events
|> Enum.take(100)
|> Enum.each(fn event ->
  IO.inspect(event)
end)
```

### Exporting events

Exporting events from a Cased Policy allows you to provide users with exports of their own data or to respond to data requests.

```elixir
export =
  client
  |> Cased.Export.create(audit_trails: [:organizations, :users], fields: ~w(action timestamp))
  |> Cased.Request.run()

export.download_url
# => https://api.cased.com/exports/export_1dSHQSNtAH90KA8zGTooMnmMdiD/download?token=eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoidXNlcl8xZFFwWThiQmdFd2RwbWRwVnJydER6TVg0ZkgiLCJ
```

The following options are available:

- `:audit_trails` — The list of audit trails to export
- `:audit_trail` — When passing a single audit trail, you can use this instead of `:audit_trails`.
- `:fields` — The fields to export
- `:key` — The Cased policy key allowing access to the audit trails and fields.

The only required option is `:fields`.

- When both `:audit_trail` and `:audit_trails` are omitted, `:audit_trail` is assumed to be `default`.
- When `:key` is omitted, the key configured for the `:audit_trail` (or first of `:audit_trails`) in
  the client is used.

### Masking & filtering sensitive information

If you are handling sensitive information on behalf of your users, you should consider masking or filtering any sensitive information.

You can do this manually by using `Cased.Sensitive.String.new/2`:

```elixir
%{
  action: "credit_card.charge",
  user: Cased.Sensitive.String.new("john@example.com", label: :email)
}
|> Cased.publish()
```

You can also use handlers to find sensitive values for you automatically. Here's an example checking for usernames:

```elixir
username_handler = {Cased.Sensitive.RegexHandler, :username, ~r<@\w+>}

%{
  action: "comment.create",
  body: "@username, I'm not sure."
}
|> Cased.publish(handlers: [username_handler])
```

If you're regularly using the same handlers, consider storing them in your application config and defining your own function to use them in your application:

```elixir
defmodule MyApp do

  @doc """
  Publish an audit event to Cased.
  """
  @spec publish_to_cased(audit_event :: map()) :: :ok | {:error, any()}
  def publish_to_cased(audit_event) do
    handlers = Application.get_env(:my_app, :cased_handlers, [])

    audit_event
    |> Cased.publish(handlers: handlers)
  end
end
```

For more information, see the `Cased.Sensitive.Handler` module.

### Console Usage

TK

### Disable publishing events

TK

### Context

TK

### Testing

TK

## Customizing cased-elixir

TK

## Contributing

1. Fork it ( https://github.com/cased/cased-elixir/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
