import gleam/string
import gleamstral/client
import gleeunit/should

pub fn new_client_test() {
  let api_key = "test_key"
  let client = client.new(api_key)

  should.equal(client.api_key, api_key)
  should.equal(client.config.temperature, 1.0)
  should.equal(client.config.max_tokens, 0)
  should.equal(client.config.top_p, 1.0)
  should.equal(client.config.stream, False)
  should.equal(client.config.stop, [])
  should.equal(client.config.random_seed, 0)
  should.equal(client.config.response_format, client.Text)
  should.equal(client.config.tools, [])
  should.equal(client.config.tool_choice, client.Auto)
  should.equal(client.config.presence_penalty, 0.0)
  should.equal(client.config.frequency_penalty, 0.0)
  should.equal(client.config.n, 1)
}

pub fn builder_pattern_test() {
  let client =
    client.new("test_key")
    |> client.set_temperature(0.7)
    |> client.set_max_tokens(100)
    |> client.set_top_p(0.8)
    |> client.set_stream(True)
    |> client.set_stop(["stop1", "stop2"])
    |> client.set_random_seed(42)
    |> client.set_response_format(client.JsonObject)
    |> client.set_presence_penalty(0.5)
    |> client.set_frequency_penalty(0.5)
    |> client.set_n(2)

  should.equal(client.config.temperature, 0.7)
  should.equal(client.config.max_tokens, 100)
  should.equal(client.config.top_p, 0.8)
  should.equal(client.config.stream, True)
  should.equal(client.config.stop, ["stop1", "stop2"])
  should.equal(client.config.random_seed, 42)
  should.equal(client.config.response_format, client.JsonObject)
  should.equal(client.config.presence_penalty, 0.5)
  should.equal(client.config.frequency_penalty, 0.5)
  should.equal(client.config.n, 2)
}

pub fn validation_test() {
  // Test invalid temperature
  let client_temp_low =
    client.new("test_key")
    |> client.set_temperature(-0.1)

  should.equal(client_temp_low.config.temperature, 0.0)

  // Test invalid max_tokens
  let client_max_tokens =
    client.new("test_key")
    |> client.set_max_tokens(-1)

  should.equal(client_max_tokens.config.max_tokens, 0)

  // Test invalid top_p
  let client_top_p =
    client.new("test_key")
    |> client.set_top_p(1.1)

  should.equal(client_top_p.config.top_p, 1.0)
}

// Test response format conversion
pub fn response_format_test() {
  should.equal(
    client.response_format_to_string(client.JsonObject),
    "json_object",
  )
  should.equal(client.response_format_to_string(client.Text), "text")
}

// Test tool choice conversion
pub fn tool_choice_test() {
  should.equal(client.tool_choice_to_string(client.Auto), "auto")
  should.equal(client.tool_choice_to_string(client.None), "none")
  should.equal(client.tool_choice_to_string(client.Any), "any")
  should.equal(client.tool_choice_to_string(client.Required), "required")

  // Test specific function choice
  let tool =
    client.Function(
      name: "calculator",
      description: "Calculator",
      strict: True,
      parameters: "{}",
    )

  let result = client.tool_choice_to_string(client.Choice(tool))
  should.be_true(string.contains(result, "calculator"))
  should.be_true(string.contains(result, "function"))
}
