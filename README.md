# cased-elixir

A Cased client for Elixir applications in your organization to control and monitor the access of information within your organization.

## Overview

- [Installation](#installation)
- [Configuration](#configuration)
  - [Publisher](#for-publisher)
  - [Client](#for-client)
  - [Cased CLI](#cli)
- [Usage](#usage)
  - [Cased CLI](#cased-cli)
    - [Starting an approval workflow](#starting-an-approval-workflow)
  - [Audit trails](#audit-trails)
    - [Publishing events to Cased](#publishing-events-to-cased)
    - [Retrieving events from a Cased Policy](#retrieving-events-from-a-cased-policy)
    - [Retrieving events from a Cased Policy containing variables](#retrieving-events-from-a-cased-policy-containing-variables)
    - [Retrieving events from multiple Cased Policies](#retrieving-events-from-multiple-cased-policies)
    - [Exporting events](#exporting-events)
    - [Masking & filtering sensitive information](#masking-and-filtering-sensitive-information)
- [Context](#context)
- [Testing](#testing)
- [Contribution Guidelines](#contributing)


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

Create a client with the policy key for your `:default` audit trail:

```elixir
iex> Cased.Client.create(key: "policy_live_...")
{:ok, %Cased.Client{...}}
```

<a name="keys-example"></a>
Create a client key with policy keys for specific audit trails:

```elixir
iex> Cased.Client.create(keys: [default: "policy_live_...", users: "policy_live_..."])
{:ok, %Cased.Client{...}}
```

Clients can be configured using runtime environment variables, your application
configuration, hardcoded values, or any combination you choose:

```elixir
# Just using runtime environment variable:
iex> Cased.Client.create(key: System.fetch_env!("CASED_POLICY_KEY"))
{:ok, %Cased.Client{...}}

# Just using application configuration:
iex> Cased.Client.create(key: Application.fetch_env!(:your_app, :cased_policy_key))
{:ok, %Cased.Client{...}}

# Either/or
iex> Cased.Client.create(
...>   key: System.get_env("CASED_POLICY_KEY") || Application.fetch_env!(:your_app, :cased_policy_key)
...> )
{:ok, %Cased.Client{...}}
```

In the event your client is misconfigured, you'll get a `Cased.ConfigurationError` exception struct instead:

```elixir
iex> Cased.Client.create()
{:error, %Cased.ConfigurationError{...}}
```

You can also use `Cased.Client.create!/1` if you know you're passing the correct configuration options (otherwise it raises a `Cased.ConfigurationError` exception):

```elixir
iex> Cased.Client.create!(key: "policy_live_...")
%Cased.Client{...}
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

### CLI

To start an approval workflow you must first obtain your application key. Add your application key `config/config.exs`

``` elixir

 config :cased,
  guard_application_key: "guard_application_xxxxxxxxxxxxxxxxxxxxx"

```
Optional you can add user token.


``` elixir
config :cased,
  guard_application_key: "guard_application_xxxxxxxxxxxxxxxxxxxxxxxxxxx",
  guard_user_token: "user_xxxxxxxxxxxxxxxxxx"
```

And you need to add `Cased.CLI` as a child of your application.

``` elixir
children = [
    # Other workers...
    Cased.CLI.Supervisor
 ]
opts = [strategy: :one_for_one, name: Example.Supervisor]
Supervisor.start_link(children, opts)
```

`Cased.CLI.Supervisor` also can accept `token` and `application_key`:

``` elixir
children = [
    # Other workers...
    {
      Cased.CLI.Supervisor,
      token: System.get_env("GUARD_USER_TOKEN"),
      app_key: System.get_env("GUARD_APPLICATION_KEY")
    }
 ]
opts = [strategy: :one_for_one, name: Example.Supervisor]
Supervisor.start_link(children, opts)
```

In order for the session to automatically run at the start the  console, add `Cased.CLI.Runner.run()` after starting your application.

``` elixir
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Cased.CLI.Supervisor}
    ]
    opts = [strategy: :one_for_one, name: Example.Supervisor]
    res = Supervisor.start_link(children, opts)
    Cased.CLI.Runner.run()
    res
  end
```

Available params of `Cased.CLI`:

- `app_key` - application key (required)
- `token` - user token (option)
- `close_shell` - close main shell after stop cased session

## Usage

### Cased CLI

Keep any command line tool available as your team grows — monitor usage, require peer approvals for sensitive operations, and receive intelligent alerts to suspicious activity.

#### Starting an approval workflow

To start an approval workflow you must first obtain your application key and the
user token for who is requesting access.

``` elixir
    iex(1)> Cased.CLI.Supervisor.start_link(token: "user_xxxxxxxxxxxxxxxxxx", app_key: "guard_application_xxxxxxxxxxxxxxxxxxxxxxxxxxx")
    iex(2)> Cased.CLI.start
```

#### Starting an interactive approval workflow

``` elixir
    Interactive Elixir (1.11.3) - press Ctrl+C to exit (type h() ENTER for help)
    iex(1)> Cased.CLI.start
```


### Audit trails

#### Publishing events to Cased

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

#### Retrieving events from a Cased Policy

If you plan on retrieving events from your audit trails you must use an Cased Policy token.

```elixir
iex> {:ok, client} = Cased.Client.create(key: "policy_live_1dQpY5JliYgHSkEntAbMVzuOROh")

iex> events =
...>  client
...>  |> Cased.Event.query()
...>  |> Cased.Request.stream()

iex> events
...> |> Enum.take(3)
[%Cased.Event{...}, %Cased.Event{...}, %Cased.Event{...}]
```

You can also retrieve an event by ID and audit trail:

```elixir
iex> event =
...>  client
...>  |> Cased.Event.get("event_...", audit_trail: :organizations)
...>  |> Cased.Request.run!()
%Cased.Event{...}
```

#### Retrieving events from a Cased Policy containing variables

Cased policies allow you to filter events by providing variables to your Cased
Policy events query. One example of a Cased Policy is to have a single Cased
Policy that you can use to query events for any user in your database without
having to create a Cased Policy for each user.

For example, getting the first 3 events in the default audit trail that
matches a specific user ID:

```elixir
iex> client = Cased.Client.create!(key: "policy_live_...")
%Cased.Client{...}

iex> variables = [user_id: "user_..."]

iex> events =
...>   client
...>   |> Cased.Event.query(variables: variables)
...>   |> Cased.Request.stream()
...>   |> Enum.take(3)
[%Cased.Event{...}, %Cased.Event{...}, %Cased.Event{...}]
```

#### Retrieving events from multiple Cased Policies

To retrieve events from one or more Cased Policies you can configure multiple
Cased Policy API keys and retrieve events for each one.

For example, getting the first 3 events for the user and organization audit
trails:

```elixir
iex> client = Cased.Client.create!(keys: [
...>   users: "policy_live_1dQpY8bBgEwdpmdpVrrtDzMX4fH",
...>   organizations: "policy_live_1dSHQRurWX8JMYMbkRdfzVoo62d"
...> ])
%Cased.Client{...}

iex> users_events =
...>   client
...>   |> Cased.Event.query(audit_trail: :users, variables: variables)
...>   |> Cased.Request.stream()
...>   |> Enum.take(3)
[%Cased.Event{...}, %Cased.Event{...}, %Cased.Event{...}]

iex> org_events =
...>   client
...>   |> Cased.Event.query(audit_trail: :organizations, variables: variables)
...>   |> Cased.Request.stream()
...>   |> Enum.take(3)
[%Cased.Event{...}, %Cased.Event{...}, %Cased.Event{...}]
```

#### Exporting events

Exporting events from a Cased Policy allows you to provide users with exports of their own data or to respond to data requests.

```elixir
iex> export =
...>  client
...>  |> Cased.Export.create(audit_trails: [:organizations, :users], fields: ~w(action timestamp))
...>  |> Cased.Request.run()
%Cased.Export{download_url: "https://api.cased.com/exports/export_...", ...}
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

##### Retrieving an Export

You can retrieve data about an export using `Cased.Export.get/2` (or `Cased.Export.get/3`):

```elixir
iex> client
...> |> Cased.Export.get("export_...")
...> |> Cased.Request.run!
%Cased.Export{id: "export_...", ...}
```

To download the JSON data for an export, use `Cased.Export.get_download/2` (or `Cased.Export.get_download/3`).

```elixir
iex> client
...> |> Cased.Export.get_download("export_...")
...> |> Cased.Request.run!
"{...}"
```

(Note that the raw JSON string is returned; no automatic decoding is attempted.)

For more information, see the documentation for `Cased.Export.get/3` and `Cased.Export.get_download/3`.

#### Masking & filtering sensitive information

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

### Retrieving and policy information

To retrieve and modify policy information, you need to create your client with your Environment API Key.

For example:

```elixir
iex> Cased.Client.create(
...>   key: "policy_live_...",
...>   environment_key: "environment_live_..."
...> )
{:ok, %Cased.Client{...}}
```

Use `Cased.Policy.query/1` and `Cased.Request.stream/1` in conjunction with one of the `Enum` functions to retrieve policies:

```elixir
iex> first_3_policies =
...>  client
...>  |> Cased.Policy.query()
...>  |> Cased.Request.stream()
...>  |> Enum.take(3)
[%Cased.Policy{...}, %Cased.Policy{...}, %Cased.Policy{...}]
```

#### Creating policies

You can create a policy using `Cased.Policy.create/2`. You must provide a `:name`, `:description`, and at least one other option (see `Cased.Policy.create/2` for details):

```elixir
iex> policy =
...>  client
...>  |> Cased.Policy.create(
...>    name: "limited",
...>    description: "A limited time policy",
...>    export: true,
...>    pii: false,
...>    window: [gte: begin_datetime, lte: end_datetime]
...>  )
...>  |> Cased.Request.run!()
%Cased.Policy{...}
```

#### Updating policies

You can update a policy by ID using `Cased.Policy.update/3`:

```elixir
iex> client
...> |> Cased.Policy.update("THE-POLICY-ID", name: "unlimited", pii: true)
...> |> Cased.Request.run!()
%Cased.Policy{...}
```

#### Deleting Policies

You can delete a policy by ID using `Cased.Policy.delete/2`:

```elixir
iex> client
...> |> Cased.Policy.delete("THE-POLICY-ID")
...> |> Cased.Request.run!()
:ok
```

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
