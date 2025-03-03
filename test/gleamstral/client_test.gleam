import gleam/json
import gleam/list
import gleam/option
import gleam/string
import gleamstral/client
import gleamstral/message
import gleamstral/model
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

// Test mocking for chat completion function
// Since we can't directly test the API, we'll use reflection to check our request structure
pub fn chat_completion_request_structure_test() {
  let client =
    client.new("test_key")
    |> client.set_temperature(0.7)
    |> client.set_max_tokens(100)

  // Create messages - handling Result return types
  let user_msg = message.UserMessage(message.TextContent("Hello"))

  let system_msg =
    message.SystemMessage(message.TextContent("You are a helpful assistant"))

  let messages = [user_msg, system_msg]

  // Generate a request body
  let body =
    client.body_encoder(client, model.MistralSmall, messages)
    |> json.to_string

  // Check that the body contains expected fields
  should.be_true(string.contains(body, "\"model\":\"mistral-small-latest\""))
  should.be_true(string.contains(body, "\"temperature\":0.7"))
  should.be_true(string.contains(body, "\"max_tokens\":100"))
  should.be_true(string.contains(body, "\"messages\":["))
  should.be_true(string.contains(body, "\"role\":\"user\""))
  should.be_true(string.contains(body, "\"role\":\"system\""))
}

// Test response parsing
pub fn parse_response_test() {
  // Create a sample response JSON
  let sample_response =
    "{
    \"id\": \"79fc5dfa8ca94fc7b23499281190d801\",
    \"object\": \"chat.completion\",
    \"created\": 1740999100,
    \"model\": \"mistral-small-latest\",
    \"choices\": [
      {
        \"index\": 0,
        \"message\": {
          \"role\": \"assistant\",
          \"tool_calls\": null,
          \"content\": \"Hello! How can I help you today?\"
        },
        \"finish_reason\": \"stop\"
      }
    ],
    \"usage\": {
      \"prompt_tokens\": 10,
      \"completion_tokens\": 9,
      \"total_tokens\": 19
    }
  }"

  // Test standard response
  json.parse(from: sample_response, using: client.response_decoder())
  |> should.be_ok
}

// Test invalid response parsing
pub fn parse_invalid_response_test() {
  let invalid_response = "{\"invalid\": \"json\"}"

  json.parse(from: invalid_response, using: client.response_decoder())
  |> should.be_error
}

// Test the client's return type structure
pub fn client_return_type_test() {
  // Create a client
  let client = client.new("test_key")

  // Check that the client has the expected structure
  should.equal(client.api_key, "test_key")
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

  // Test that the Response type has the expected structure
  let mock_response =
    client.Response(
      id: "test-id",
      object: "chat.completion",
      created: 123_456_789,
      model: "mistral-small-latest",
      choices: [
        client.ChatCompletionChoice(
          index: 0,
          message: message.AssistantMessage(
            content: "Test content",
            tool_calls: option.None,
            prefix: False,
          ),
          finish_reason: client.Stop,
        ),
      ],
      usage: client.Usage(
        prompt_tokens: 10,
        completion_tokens: 5,
        total_tokens: 15,
      ),
    )

  // Verify the response structure
  should.equal(mock_response.id, "test-id")
  should.equal(mock_response.object, "chat.completion")
  should.equal(mock_response.created, 123_456_789)
  should.equal(mock_response.model, "mistral-small-latest")
  should.equal(list.length(mock_response.choices), 1)

  // Check the first choice
  let choice =
    list.first(mock_response.choices)
    |> should.be_ok

  should.equal(choice.index, 0)
  should.equal(choice.finish_reason, client.Stop)

  case choice.message {
    message.AssistantMessage(content, _, _) -> {
      should.equal(content, "Test content")
    }
    _ -> {
      should.fail()
    }
  }

  // Check usage
  should.equal(mock_response.usage.prompt_tokens, 10)
  should.equal(mock_response.usage.completion_tokens, 5)
  should.equal(mock_response.usage.total_tokens, 15)
}
