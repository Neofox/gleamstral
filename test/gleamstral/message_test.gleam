import gleam/json
import gleam/string
import gleamstral/message
import gleeunit/should

pub fn system_text_message_creation_test() {
  // Test creating a valid system message with text content
  message.new(message.System, message.TextContent("System instructions"))
  |> should.be_ok
}

pub fn system_multi_text_message_creation_test() {
  // Test creating a valid system message with multi-content containing only Text parts
  message.new(
    message.System,
    message.MultiContent([message.Text("Part 1"), message.Text("Part 2")]),
  )
  |> should.be_ok
}

pub fn system_with_image_invalid_test() {
  // Test that system message with images is invalid
  message.new(
    message.System,
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
  message.new(message.Assistant, message.TextContent("Assistant response"))
  |> should.be_ok
}

pub fn assistant_multi_content_invalid_test() {
  // Test that assistant message with multi-content is invalid
  message.new(
    message.Assistant,
    message.MultiContent([message.Text("Not allowed")]),
  )
  |> should.be_error
  |> should.equal(message.InvalidAssistantMessage)
}

pub fn user_message_creation_test() {
  // Test that user messages accept any content type

  // Text content
  message.new(message.User, message.TextContent("User message"))
  |> should.be_ok

  // Multi-content with text and image
  message.new(
    message.User,
    message.MultiContent([
      message.Text("User question"),
      message.ImageUrl("https://example.com/image.jpg"),
    ]),
  )
  |> should.be_ok
}

pub fn tool_message_creation_test() {
  // Test that tool messages accept any content type

  // Text content
  message.new(message.Tool, message.TextContent("Tool response"))
  |> should.be_ok

  // Multi-content with text and image
  message.new(
    message.Tool,
    message.MultiContent([
      message.Text("Tool result"),
      message.ImageUrl("https://example.com/result.jpg"),
    ]),
  )
  |> should.be_ok
}

pub fn text_content_to_json_test() {
  // Create a text content message
  let assert Ok(test_message) =
    message.new(message.User, message.TextContent("Hello world"))

  // Convert to JSON string
  let json_string =
    test_message
    |> message.to_json
    |> json.to_string

  // Basic string content checks
  should.be_true(string.contains(json_string, "\"role\":\"user\""))
  should.be_true(string.contains(json_string, "\"content\":\"Hello world\""))
}

pub fn multi_content_to_json_test() {
  // Create a multi-content message
  let assert Ok(test_message) =
    message.new(
      message.User,
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
