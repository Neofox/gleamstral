import gleam/json
import gleam/option.{None, Some}
import gleam/string
import gleamstral/message
import gleeunit/should

pub fn system_text_message_creation_test() {
  // Test creating a valid system message with text content
  message.system(message.TextContent("System instructions"))
  |> should.be_ok
}

pub fn system_multi_text_message_creation_test() {
  // Test creating a valid system message with multi-content containing only Text parts
  message.system(
    message.MultiContent([message.Text("Part 1"), message.Text("Part 2")]),
  )
  |> should.be_ok
}

pub fn system_with_image_invalid_test() {
  // Test that system message with images is invalid
  message.system(
    message.MultiContent([
      message.Text("Text part"),
      message.ImageUrl("https://example.com/image.jpg"),
    ]),
  )
  |> should.be_error
  |> should.equal(message.InvalidSystemMessage)
}

pub fn assistant_text_message_creation_test() {
  // Test creating a valid assistant message with text content
  let test_message = message.assistant("Assistant response", None, False)
  // Check that it's the expected type
  case test_message {
    message.AssistantMessage(_, _, _) -> True
    _ -> False
  }
  |> should.be_true
}

pub fn assistant_with_tool_calls_test() {
  // Create a sample tool call
  let tool_call =
    message.ToolCall(
      id: "call_123456",
      tool_type: "function",
      function: message.FunctionCall(
        name: "get_weather",
        arguments: "{\"location\":\"New York\",\"unit\":\"celsius\"}",
      ),
      index: 0,
    )

  // Test creating an assistant message with tool calls
  let test_message =
    message.assistant(
      "I'll check the weather for you",
      Some([tool_call]),
      False,
    )

  // Verify it has the expected structure
  case test_message {
    message.AssistantMessage(content, tool_calls, _) -> {
      should.equal("I'll check the weather for you", content)
      should.equal(Some([tool_call]), tool_calls)
      True
    }
    _ -> False
  }
  |> should.be_true
}

pub fn assistant_multi_content_invalid_test() {
  // No longer applicable with the simplified API
  // We'll just check that assistant message accepts strings
  let msg = message.assistant("Plain text only", None, False)
  case msg {
    message.AssistantMessage(_, _, _) -> True
    _ -> False
  }
  |> should.be_true
}

pub fn user_message_creation_test() {
  // Text content
  message.user(message.TextContent("User message"))

  // Multi-content with text and image
  message.user(
    message.MultiContent([
      message.Text("User question"),
      message.ImageUrl("https://example.com/image.jpg"),
    ]),
  )
}

pub fn tool_message_with_tool_fields_test() {
  // With text content
  message.tool(
    message.TextContent("Tool function result"),
    "call_123456",
    "weather_tool",
  )

  // With multi-content
  message.tool(
    message.MultiContent([
      message.Text("Tool result"),
      message.ImageUrl("https://example.com/result.jpg"),
    ]),
    "call_789012",
    "image_generator",
  )
}

pub fn get_role_test() {
  // Test that get_role correctly returns the role for each message type
  let assert Ok(system_msg) = message.system(message.TextContent("System"))
  let user_msg = message.user(message.TextContent("User"))
  let assistant_msg = message.assistant("Assistant", None, False)
  let assistant_with_tools_msg =
    message.assistant(
      "Assistant with tools",
      Some([
        message.ToolCall(
          id: "call_abc",
          tool_type: "function",
          function: message.FunctionCall(name: "test", arguments: "{}"),
          index: 0,
        ),
      ]),
      False,
    )
  let tool_msg = message.tool(message.TextContent("Tool"), "id", "name")

  should.equal(message.System, message.get_role(system_msg))
  should.equal(message.User, message.get_role(user_msg))
  should.equal(message.Assistant, message.get_role(assistant_msg))
  should.equal(message.Assistant, message.get_role(assistant_with_tools_msg))
  should.equal(message.Tool, message.get_role(tool_msg))
}

pub fn tool_message_to_json_text_test() {
  // Create a tool message with text content
  let test_message =
    message.tool(
      message.TextContent("Tool output"),
      "call_abc123",
      "data_processor",
    )

  // Convert to JSON string
  let json_string =
    test_message
    |> message.to_json
    |> json.to_string

  // Basic string content checks
  should.be_true(string.contains(json_string, "\"role\":\"tool\""))
  should.be_true(string.contains(json_string, "\"content\":\"Tool output\""))
  should.be_true(string.contains(
    json_string,
    "\"tool_call_id\":\"call_abc123\"",
  ))
  should.be_true(string.contains(json_string, "\"name\":\"data_processor\""))
}

pub fn tool_message_to_json_multi_test() {
  // Create a tool message with multi-content
  let test_message =
    message.tool(
      message.MultiContent([
        message.Text("Analysis result"),
        message.ImageUrl("https://example.com/chart.jpg"),
      ]),
      "call_def456",
      "data_visualizer",
    )

  // Convert to JSON string
  let json_string =
    test_message
    |> message.to_json
    |> json.to_string

  // Basic string content checks
  should.be_true(string.contains(json_string, "\"role\":\"tool\""))
  should.be_true(string.contains(json_string, "\"type\":\"text\""))
  should.be_true(string.contains(json_string, "\"text\":\"Analysis result\""))
  should.be_true(string.contains(json_string, "\"type\":\"image_url\""))
  should.be_true(string.contains(
    json_string,
    "\"image_url\":\"https://example.com/chart.jpg\"",
  ))
  should.be_true(string.contains(
    json_string,
    "\"tool_call_id\":\"call_def456\"",
  ))
  should.be_true(string.contains(json_string, "\"name\":\"data_visualizer\""))
}

pub fn assistant_message_with_tool_calls_to_json_test() {
  // Create an assistant message with tool calls
  let tool_call =
    message.ToolCall(
      id: "call_xyz789",
      tool_type: "function",
      function: message.FunctionCall(
        name: "search_database",
        arguments: "{\"query\":\"restaurants\",\"location\":\"Paris\"}",
      ),
      index: 0,
    )

  let test_message =
    message.assistant(
      "I'll search for restaurants in Paris",
      Some([tool_call]),
      False,
    )

  // Convert to JSON string
  let json_string =
    test_message
    |> message.to_json
    |> json.to_string

  // Basic string content checks
  should.be_true(string.contains(json_string, "\"role\":\"assistant\""))
  should.be_true(string.contains(
    json_string,
    "\"content\":\"I'll search for restaurants in Paris\"",
  ))
  should.be_true(string.contains(json_string, "\"tool_calls\":["))
  should.be_true(string.contains(json_string, "\"id\":\"call_xyz789\""))
  should.be_true(string.contains(json_string, "\"type\":\"function\""))
  should.be_true(string.contains(json_string, "\"name\":\"search_database\""))
  should.be_true(string.contains(
    json_string,
    "\"arguments\":\"{\\\"query\\\":\\\"restaurants\\\",\\\"location\\\":\\\"Paris\\\"}\"",
  ))
  should.be_true(string.contains(json_string, "\"index\":0"))
}

pub fn system_message_to_json_test() {
  // Create a system message
  let assert Ok(test_message) =
    message.system(message.TextContent("System instructions"))

  // Convert to JSON string
  let json_string =
    test_message
    |> message.to_json
    |> json.to_string

  // Basic string content checks
  should.be_true(string.contains(json_string, "\"role\":\"system\""))
  should.be_true(string.contains(
    json_string,
    "\"content\":\"System instructions\"",
  ))
}

pub fn user_message_to_json_test() {
  // Create a user message
  let test_message = message.user(message.TextContent("Hello world"))

  // Convert to JSON string
  let json_string =
    test_message
    |> message.to_json
    |> json.to_string

  // Basic string content checks
  should.be_true(string.contains(json_string, "\"role\":\"user\""))
  should.be_true(string.contains(json_string, "\"content\":\"Hello world\""))
}

pub fn assistant_message_to_json_test() {
  // Create an assistant message without tool calls
  let test_message = message.assistant("I'm an assistant", None, False)

  // Convert to JSON string
  let json_string =
    test_message
    |> message.to_json
    |> json.to_string

  // Basic string content checks
  should.be_true(string.contains(json_string, "\"role\":\"assistant\""))
  should.be_true(string.contains(
    json_string,
    "\"content\":\"I'm an assistant\"",
  ))
  // Should contain null tool_calls
  should.be_true(string.contains(json_string, "\"tool_calls\":null"))
}

pub fn multi_content_to_json_test() {
  // Create a multi-content message
  let test_message =
    message.user(
      message.MultiContent([
        message.Text("Text part"),
        message.ImageUrl("https://example.com/image.jpg"),
      ]),
    )

  // Convert to JSON string
  let json_string =
    test_message
    |> message.to_json
    |> json.to_string

  // Basic string content checks
  should.be_true(string.contains(json_string, "\"role\":\"user\""))
  should.be_true(string.contains(json_string, "\"type\":\"text\""))
  should.be_true(string.contains(json_string, "\"text\":\"Text part\""))
  should.be_true(string.contains(json_string, "\"type\":\"image_url\""))
  should.be_true(string.contains(
    json_string,
    "\"image_url\":\"https://example.com/image.jpg\"",
  ))
}
