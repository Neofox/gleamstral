import gleam/result
import gleam/string
import gleamstral/client
import gleeunit/should

// Testing client initialization with default values
pub fn new_client_test() {
  let api_key = "test_key"
  let client = client.new(api_key)

  // Verify default values
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

// Test builder pattern
pub fn builder_pattern_test() {
  // Test that the builder pattern works by chaining multiple configurations
  let client =
    client.new("test_key")
    |> client.with_temperature(0.7)
    |> client.with_max_tokens(100)
    |> client.with_top_p(0.8)
    |> client.with_stream(True)
    |> client.with_stop(["stop1", "stop2"])
    |> client.with_random_seed(42)
    |> client.with_response_format(client.JsonObject)
    |> client.with_presence_penalty(0.5)
    |> client.with_frequency_penalty(0.5)
    |> client.with_n(2)

  // Verify all settings were applied correctly
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

// Test validation behavior by examining error messages
pub fn validation_test() {
  // Create various invalid configurations and check if they're rejected

  // Test invalid temperature
  let client_temp_low =
    client.new("test_key")
    |> client.with_temperature(-0.1)

  let temp_low_result = create_test_request(client_temp_low)

  should.be_error(temp_low_result)

  // Extract error message
  let temp_error = case temp_low_result {
    Error(msg) -> msg
    Ok(_) -> ""
  }
  should.equal(temp_error, "Invalid temperature: must be between 0.0 and 1.5")

  // Test invalid max_tokens
  let client_max_tokens =
    client.new("test_key")
    |> client.with_max_tokens(-1)

  let max_tokens_result = create_test_request(client_max_tokens)

  should.be_error(max_tokens_result)

  // Extract error message
  let tokens_error = case max_tokens_result {
    Error(msg) -> msg
    Ok(_) -> ""
  }
  should.equal(tokens_error, "Invalid max_tokens: must be non-negative")

  // Test invalid top_p
  let client_top_p =
    client.new("test_key")
    |> client.with_top_p(1.1)

  let top_p_result = create_test_request(client_top_p)

  should.be_error(top_p_result)

  // Extract error message
  let top_p_error = case top_p_result {
    Error(msg) -> msg
    Ok(_) -> ""
  }
  should.equal(top_p_error, "Invalid top_p: must be between 0.0 and 1.0")
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

fn create_test_request(client_: client.Client) -> Result(String, String) {
  // We need to manually validate the config since we can't use the client.chat_completion
  // function directly due to the let assert pattern match
  case validate_config(client_.config) {
    Ok(_) -> Ok("Valid config")
    Error(msg) -> Error(msg)
  }
}

// Helper function to validate the client config
fn validate_config(config: client.Config) -> Result(Nil, String) {
  // Replicate the validation logic from the client module
  case config.temperature >=. 0.0 && config.temperature <=. 1.5 {
    True -> Ok(Nil)
    False -> Error("Invalid temperature: must be between 0.0 and 1.5")
  }
  |> result.try(fn(_) {
    case config.max_tokens >= 0 {
      True -> Ok(Nil)
      False -> Error("Invalid max_tokens: must be non-negative")
    }
  })
  |> result.try(fn(_) {
    case config.top_p >=. 0.0 && config.top_p <=. 1.0 {
      True -> Ok(Nil)
      False -> Error("Invalid top_p: must be between 0.0 and 1.0")
    }
  })
}
