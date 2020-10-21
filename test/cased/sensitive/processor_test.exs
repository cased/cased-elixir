defmodule Cased.Sensitive.ProcessorTest do
  use Cased.TestCase
  doctest Cased.Sensitive.Processor

  setup context do
    Map.merge(context, %{
      username_handler: {Cased.Sensitive.RegexHandler, :username, ~r/@\w+/},
      phone_number_handler: {Cased.Sensitive.RegexHandler, :phone_number, ~r/\d{3}\-\d{3}\-\d{4}/}
    })
  end

  describe "process/2" do
    test "processes audit event with various value types" do
      result =
        Cased.Sensitive.Processor.process(%{
          string: "string",
          int: 1234,
          float: 12.34,
          bool: true,
          empty: nil,
          date: ~U[2020-07-22 13:25:22.390906Z],
          nested: %{
            string: "nested"
          }
        })

      expected_result = %{
        string: "string",
        int: 1234,
        float: 12.34,
        bool: true,
        empty: nil,
        date: ~U[2020-07-22 13:25:22.390906Z],
        nested: %{
          string: "nested"
        }
      }

      assert expected_result == result
    end

    test "processes audit event with various value types using handlers", %{
      username_handler: username_handler
    } do
      result =
        Cased.Sensitive.Processor.process(
          %{
            string: "string",
            int: 1234,
            float: 12.34,
            bool: true,
            empty: nil,
            date: ~U[2020-07-22 13:25:22.390906Z],
            nested: %{
              string: "nested"
            }
          },
          handlers: [username_handler]
        )

      expected_result = %{
        string: "string",
        int: 1234,
        float: 12.34,
        bool: true,
        empty: nil,
        date: ~U[2020-07-22 13:25:22.390906Z],
        nested: %{
          string: "nested"
        }
      }

      assert expected_result == result
    end

    test "processes audit event with manual Sensitive.String structs, returning embedded data" do
      result =
        Cased.Sensitive.Processor.process(%{
          owner: Cased.Sensitive.String.new("foo@example.com", label: :email)
        })

      expected_result = %{
        owner: "foo@example.com",
        ".cased": %{
          pii: %{
            ".owner" => [
              %Cased.Sensitive.Range{
                key: :owner,
                label: :email,
                begin_offset: 0,
                end_offset: 15
              }
            ]
          }
        }
      }

      assert expected_result == result
    end

    test "processes audit event with manual Sensitive.String structs, returning PII only" do
      result =
        Cased.Sensitive.Processor.process(
          %{owner: Cased.Sensitive.String.new("foo@example.com", label: :email)},
          return: :pii
        )

      expected_result = %{
        ".owner" => [
          %Cased.Sensitive.Range{
            key: :owner,
            label: :email,
            begin_offset: 0,
            end_offset: 15
          }
        ]
      }

      assert expected_result == result
    end

    test "processes audit event, returning just PII", %{username_handler: handler} do
      data = %{
        action: "comment.create",
        body: "Hello @username"
      }

      result =
        Cased.Sensitive.Processor.process(data,
          handlers: [handler],
          return: :pii
        )

      expected_result = %{
        ".body" => [
          %Cased.Sensitive.Range{
            key: :body,
            label: :username,
            begin_offset: 6,
            end_offset: 15
          }
        ]
      }

      assert expected_result == result
    end

    test "processes audit event, returning empty PII when none found", %{
      username_handler: handler
    } do
      result =
        Cased.Sensitive.Processor.process(%{action: "Hello not-a-username"},
          handlers: [handler],
          return: :pii
        )

      expected_result = %{}

      assert expected_result == result
    end

    test "result serializes PII", %{username_handler: handler} do
      result =
        Cased.Sensitive.Processor.process(%{action: "Hello @username"},
          handlers: [handler],
          return: :pii
        )

      expected_result =
        %{
          ".action" => [
            %{
              label: :username,
              begin: 6,
              end: 15
            }
          ]
        }
        |> Jason.encode!()

      assert expected_result == Jason.encode!(result)
    end

    test "processes audit event, returning embedded PII by default", %{
      phone_number_handler: handler
    } do
      result =
        Cased.Sensitive.Processor.process(%{body: "Hello 111-222-3333"}, handlers: [handler])

      expected_result = %{
        body: "Hello 111-222-3333",
        ".cased": %{
          pii: %{
            ".body" => [
              %Cased.Sensitive.Range{
                key: :body,
                label: :phone_number,
                begin_offset: 6,
                end_offset: 18
              }
            ]
          }
        }
      }

      assert expected_result == result
    end

    test "processes audit event, doesn't include empty embedded PII", %{
      phone_number_handler: handler
    } do
      result =
        Cased.Sensitive.Processor.process(%{body: "Hello not-a-phone-number"}, handlers: [handler])

      expected_result = %{
        body: "Hello not-a-phone-number"
      }

      assert expected_result == result
    end

    test "result serializes with embedded PII", %{phone_number_handler: handler} do
      result =
        Cased.Sensitive.Processor.process(%{body: "Hello 111-222-3333"}, handlers: [handler])

      expected_result =
        %{
          body: "Hello 111-222-3333",
          ".cased": %{
            pii: %{
              ".body" => [
                %{
                  label: :phone_number,
                  begin: 6,
                  end: 18
                }
              ]
            }
          }
        }
        |> Jason.encode!()

      assert expected_result == Jason.encode!(result)
    end

    test "result serializes with simple embedded, nested PII with lists" do
      input = %{
        users: [
          Cased.Sensitive.String.new("dewski1", label: :username),
          Cased.Sensitive.String.new("dewski2", label: :username)
        ]
      }

      result = Cased.Sensitive.Processor.process(input)

      expected_result =
        %{
          "users" => ["dewski1", "dewski2"],
          ".cased" => %{
            "pii" => %{
              ".users[0]" => [
                %{
                  "begin" => 0,
                  "end" => 7,
                  "label" => "username"
                }
              ],
              ".users[1]" => [
                %{
                  "begin" => 0,
                  "end" => 7,
                  "label" => "username"
                }
              ]
            }
          }
        }
        |> Jason.encode!()

      assert expected_result == Jason.encode!(result)
    end

    test "result serializes with simple embedded, nested PII with maps" do
      input = %{
        users: %{
          one: Cased.Sensitive.String.new("dewski1", label: :username),
          two: Cased.Sensitive.String.new("dewski2", label: :username)
        }
      }

      result = Cased.Sensitive.Processor.process(input)

      expected_result =
        %{
          "users" => %{
            "one" => "dewski1",
            "two" => "dewski2"
          },
          ".cased" => %{
            "pii" => %{
              ".users.one" => [
                %{
                  "begin" => 0,
                  "end" => 7,
                  "label" => "username"
                }
              ],
              ".users.two" => [
                %{
                  "begin" => 0,
                  "end" => 7,
                  "label" => "username"
                }
              ]
            }
          }
        }
        |> Jason.encode!()

      assert expected_result == Jason.encode!(result)
    end

    test "result serializes with embedded, nested PII" do
      input = %{
        user: Cased.Sensitive.String.new("dewski", label: :username),
        issue: %{
          title: Cased.Sensitive.String.new("Test", label: :title),
          "key.with.dot": Cased.Sensitive.String.new("true", label: :boolean),
          comments: [
            %{
              author: Cased.Sensitive.String.new("dewski", label: :username)
            },
            %{
              author: Cased.Sensitive.String.new("tnm", label: :username)
            },
            Cased.Sensitive.String.new("element", label: :string),
            [
              Cased.Sensitive.String.new("hello", label: :string)
            ]
          ]
        }
      }

      result = Cased.Sensitive.Processor.process(input)

      expected_result =
        %{
          ".cased" => %{
            "pii" => %{
              ".user" => [
                %{
                  "begin" => 0,
                  "end" => 6,
                  "label" => "username"
                }
              ],
              ".issue.title" => [
                %{
                  "begin" => 0,
                  "end" => 4,
                  "label" => "title"
                }
              ],
              ~s(.issue."key.with.dot") => [
                %{
                  "begin" => 0,
                  "end" => 4,
                  "label" => "boolean"
                }
              ],
              ".issue.comments[0].author" => [
                %{
                  "begin" => 0,
                  "end" => 6,
                  "label" => "username"
                }
              ],
              ".issue.comments[1].author" => [
                %{
                  "begin" => 0,
                  "end" => 3,
                  "label" => "username"
                }
              ],
              ".issue.comments[2]" => [
                %{
                  "begin" => 0,
                  "end" => 7,
                  "label" => "string"
                }
              ],
              ".issue.comments[3][0]" => [
                %{
                  "begin" => 0,
                  "end" => 5,
                  "label" => "string"
                }
              ]
            }
          },
          "user" => "dewski",
          "issue" => %{
            "title" => "Test",
            "key.with.dot" => "true",
            "comments" => [
              %{
                "author" => "dewski"
              },
              %{
                "author" => "tnm"
              },
              "element",
              [
                "hello"
              ]
            ]
          }
        }
        |> Jason.encode!()

      assert expected_result == Jason.encode!(result)
    end

    test "result serializes with embedded, nested PII using handlers", %{
      phone_number_handler: handler
    } do
      result =
        Cased.Sensitive.Processor.process(
          %{
            business: %{
              name: "Example",
              phone: "111-222-3333"
            }
          },
          handlers: [handler]
        )

      expected_result =
        %{
          "business" => %{
            "name" => "Example",
            "phone" => "111-222-3333"
          },
          ".cased": %{
            pii: %{
              ".business.phone" => [
                %{
                  label: :phone_number,
                  begin: 0,
                  end: 12
                }
              ]
            }
          }
        }
        |> Jason.encode!()

      assert expected_result == Jason.encode!(result)
    end
  end

  describe "build_path/1" do
    test "for a simple address" do
      assert ".body" == Cased.Sensitive.Processor.build_path(["body"])
    end

    test "for a nested address" do
      assert ".body.name" == Cased.Sensitive.Processor.build_path(["name", "body"])
    end

    test "for a nested address, with a dotted name" do
      assert ~s(.body."has.dot") == Cased.Sensitive.Processor.build_path(["has.dot", "body"])
    end

    test "for a nested address with list notation" do
      assert ".body[2].name" == Cased.Sensitive.Processor.build_path(["name", 2, "body"])
    end

    test "for a nested address with multiple list notations" do
      assert ".body[3][2].name" == Cased.Sensitive.Processor.build_path(["name", 2, 3, "body"])
    end
  end
end
