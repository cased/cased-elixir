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

### For Publishing

Add a worker specification for `Cased.Publisher.HTTP` to your application's supervisor.

The publisher accepts the following options:
- `:key` — Your [Cased publish key](https://docs.cased.com/apis#authentication-and-api-keys) (**required**).
- `:url` — The URL used to publish audit trail events via HTTP POST (**optional**;
  defaults to `https://publish.cased.com`).
- `:silence` — Whether audit trail events will be discarded, rather than sent; useful for
  non-production usage (**optional**; defaults to `false`).

You can source your configuration values from your application configuration,
runtime environment variables, or hard-code them directly; the following is just
an example:

```elixir
children = [
  # Other workers...
  {
    Cased.Publisher.HTTP,
    key: System.get_env("CASED_PUBLISH_KEY") || Application.fetch_env!(:your_app, :cased_publish_key),
    silence: Mix.env() != :prod
  }
]

# Other config...
Supervisor.start_link(children, opts)
```

### For Data Retrieval

TK

## Usage

### Publishing events to Cased

#### Manually

Provided you've [configured](#for-publishing) the Cased publisher, use `Cased.publish/1`:

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

TK

### Retrieving events from a Cased Policy containing variables

TK

### Retrieving events from multiple Cased Policies

TK

### Exporting events

TK

### Masking & filtering sensitive information

TK

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
