# cased-elixir

A Cased client for Elixir applications in your organization to publish audit trail events to Datadog Logs.

## Overview

- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
  - [Publishing events to Cased](#publishing-events-to-cased)
  - [Masking & filtering sensitive information](#masking-and-filtering-sensitive-information)
  - [Context](#context)
  - [Testing](#testing)
- [Contribution Guidelines](#contributing)


## Installation

The package can be installed by adding `cased` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:cased, "~> 0.2.0"}
  ]
end
```

## Configuration

`cased-elixir` follows Elixir's [Library Guidelines](https://hexdocs.pm/elixir/master/library-guidelines.html#avoid-application-configuration), avoiding the use of a global `:cased` application configuration in favor of more flexible, ad hoc configuration at runtime (using your own application configuration, environment variables, etc).

### For Publisher

Add a worker specification for `Cased.Publisher.Datadog` to your application's supervisor.

The publisher accepts the following options:

- `:key` — Your [Cased publish key](https://docs.cased.com/apis#authentication-and-api-keys) (**required**).
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
    Cased.Publisher.Datadog,
    key: System.get_env("DD_API_KEY") || Application.fetch_env!(:your_app, :datadog_api_key),
    silence: System.get_env("CASED_SILENCE") || Application.fetch_env!(:your_app, :cased_silence, false),
  }
]

# Other config...
Supervisor.start_link(children, opts)
```

In the event you provide an invalid configuration, a `Cased.ConfigurationError` will be raised with details.

## Usage

### Publishing events to Cased

Provided you've [configured](#for-publisher) the Cased publisher, use `Cased.publish/1`:

```elixir
iex> %{
...>   action: "credit_card.charge",
...>   amount: 2000,
...>   currency: "usd",
...>   source: "tok_amex",
...>   description: "My First Test Charge (created for API docs)",
...>   credit_card_id: "card_1dQpXqQwXxsQs9sohN9HrzRAV6y"
...> }
...> |> Cased.publish()
:ok
```

:information_source: See the documentation for `Cased.publish/2` for more options.

### Masking & filtering sensitive information

If you are handling sensitive information on behalf of your users, you should consider masking or filtering any sensitive information.

You can do this manually by using `Cased.Sensitive.String.new/2`:

```elixir
iex> %{
...>   action: "credit_card.charge",
...>   user: Cased.Sensitive.String.new("john@example.com", label: :email)
...> }
...> |> Cased.publish()
:ok
```

You can also use handlers to find sensitive values for you automatically. Here's an example checking for usernames:

```elixir
iex> username_handler = {Cased.Sensitive.RegexHandler, :username, ~r<@\w+>}
iex> %{
...>   action: "comment.create",
...>   body: "@username, I'm not sure."
...> }
...> |> Cased.publish(handlers: [username_handler])
:ok
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

### Context

One of the most easiest ways to publish detailed events to Cased is to push contextual information into the Cased context.

**Note that the Cased context is tied to the current process** (it's actually stored in the [process dictionary](https://hexdocs.pm/elixir/Process.html)). Different process, different context.

```elixir
iex> Cased.Context.merge(location: "hostname.local")
:ok
iex> %{
...>   action: "console.start",
...>   user: "john"
...> }
...> |> Cased.publish()
:ok
```

Any information stored using `Cased.Context` will be included any time an event is published.

```json
{
  "cased_id": "5f8559cd-4cd9-48c3-b1d0-6eedc4019ec1",
  "action": "user.login",
  "user": "john",
  "location": "hostname.local",
  "timestamp": "2020-06-22T21:43:06.157336"
}
```

You can provide `Cased.Context.merge/2` a function and the context will only be present for the duration of the function execution:

```elixir
iex> Cased.Context.merge(location: "hostname.local") do
...>   # Will include { "location": "hostname.local" }
...>   %{
...>     action: "console.start",
...>     user: "john"
...>   }
...>   |> Cased.publish()
...> end
:ok
iex> # Will not include {"location": "hostname.local"}
iex> %{
...>   action: "console.end",
...>   user: "john"
...> }
...> |> Cased.publish()
:ok
```

(You can also use `Cased.Context.put/2` and `Cased.Context.put/3` for single-value additions to the context.)

To reset the context, use `Cased.Context.reset/0`:

```elixir
iex> Cased.Context.reset()
:ok # or `nil` if no data was stored in the context
```

See the `Cased.Context` module for more information.

### Testing

See `Cased.TestHelper`.

## Contributing

1. Fork it ( https://github.com/cased/cased-elixir/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
