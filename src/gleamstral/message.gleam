import gleam/dynamic/decode
import gleam/json
import gleam/option.{type Option}
import gleamstral/tool

/// Represents the role of a message in a conversation
///
/// - `System`: System messages provide context and instructions to the model
/// - `User`: User messages represent the human interacting with the model
/// - `Assistant`: Assistant messages are the model's responses
/// - `Tool`: Tool messages contain the results of tool function calls
pub type MessageRole {
  System
  User
  Assistant
  Tool
}

/// Represents a message in a conversation with the AI model
///
/// - `SystemMessage`: Instructions or context for the model
/// - `UserMessage`: Input from the user to the model
/// - `AssistantMessage`: Response from the model, potentially including tool calls
/// - `ToolMessage`: Result of a tool function execution
pub type Message {
  SystemMessage(content: MessageContent)
  UserMessage(content: MessageContent)
  AssistantMessage(
    content: MessageContent,
    tool_calls: Option(List(tool.ToolCall)),
    prefix: Bool,
  )
  ToolMessage(content: MessageContent, tool_call_id: String, name: String)
}

/// Content of a message, which can be text-only or multi-modal
///
/// - `TextContent`: Simple text message
/// - `MultiContent`: Message with multiple content parts (text and/or images)
pub type MessageContent {
  TextContent(String)
  MultiContent(List(ContentPart))
}

/// Individual content part in a multi-modal message
///
/// - `Text`: Text content
/// - `ImageUrl`: URL pointing to an image or a base64 encoded image string
/// - `Thinking`: Thinking content for reasoning traces
pub type ContentPart {
  Text(String)
  ImageUrl(String)
  Thinking(List(String))
}

/// Extract text content from MessageContent for simple display
/// For MultiContent, this will return the first text part or empty string
pub fn content_to_text(content: MessageContent) -> String {
  case content {
    TextContent(text) -> text
    MultiContent(parts) -> {
      case parts {
        [] -> ""
        [first, ..] -> {
          case first {
            Text(text) -> text
            _ -> content_parts_to_text(parts)
          }
        }
      }
    }
  }
}

/// Extract thinking content from MessageContent
/// Returns the thinking traces if present, otherwise empty string
pub fn extract_thinking(content: MessageContent) -> String {
  case content {
    TextContent(_) -> ""
    MultiContent(parts) -> extract_thinking_from_parts(parts)
  }
}

/// Extract the main text response (non-thinking content) from MessageContent
pub fn extract_response_text(content: MessageContent) -> String {
  case content {
    TextContent(text) -> text
    MultiContent(parts) -> extract_response_from_parts(parts)
  }
}

fn extract_thinking_from_parts(parts: List(ContentPart)) -> String {
  case parts {
    [] -> ""
    [Thinking(thinking_contents), ..rest] -> {
      extract_thinking_content_text(thinking_contents)
      <> extract_thinking_from_parts(rest)
    }
    [_, ..rest] -> extract_thinking_from_parts(rest)
  }
}

fn extract_response_from_parts(parts: List(ContentPart)) -> String {
  case parts {
    [] -> ""
    [Text(text), ..rest] -> text <> extract_response_from_parts(rest)
    [_, ..rest] -> extract_response_from_parts(rest)
  }
}

fn extract_thinking_content_text(contents: List(String)) -> String {
  case contents {
    [] -> ""
    [text, ..rest] -> text <> " " <> extract_thinking_content_text(rest)
  }
}

fn content_parts_to_text(parts: List(ContentPart)) -> String {
  case parts {
    [] -> ""
    [Text(text), ..] -> text
    [_, ..rest] -> content_parts_to_text(rest)
  }
}

pub fn message_decoder() -> decode.Decoder(Message) {
  use role <- decode.field("role", decode.string)

  case role {
    "system" -> {
      use content <- decode.field("content", content_decoder())
      decode.success(SystemMessage(content))
    }
    "user" -> {
      use content <- decode.field("content", content_decoder())
      decode.success(UserMessage(content))
    }
    "assistant" -> {
      use content <- decode.field("content", content_decoder())

      use tool_calls <- decode.field(
        "tool_calls",
        decode.optional(decode.list(tool.tool_call_decoder())),
      )
      use prefix <- decode.optional_field("prefix", False, decode.bool)
      decode.success(AssistantMessage(content, tool_calls, prefix))
    }
    "tool" -> {
      use content <- decode.field("content", content_decoder())
      use tool_call_id <- decode.field("tool_call_id", decode.string)
      use name <- decode.field("name", decode.string)
      decode.success(ToolMessage(content, tool_call_id, name))
    }
    _ -> decode.failure(UserMessage(TextContent("")), "Invalid message role")
  }
}

fn content_decoder() -> decode.Decoder(MessageContent) {
  decode.one_of(decode.string |> decode.map(TextContent), or: [
    decode.list(content_part_decoder()) |> decode.map(MultiContent),
  ])
}

fn content_part_decoder() -> decode.Decoder(ContentPart) {
  use content_part_type <- decode.field("type", decode.string)
  case content_part_type {
    "text" -> {
      use text <- decode.field("text", decode.string)
      decode.success(Text(text))
    }
    "image_url" -> {
      use url <- decode.field("image_url", decode.string)
      decode.success(ImageUrl(url))
    }
    "thinking" -> {
      use thinking <- decode.field(
        "thinking",
        decode.list(thinking_content_decoder()),
      )
      decode.success(Thinking(thinking))
    }
    _ -> decode.failure(Text(""), "Unknown content part type")
  }
}

fn thinking_content_decoder() -> decode.Decoder(String) {
  use content_type <- decode.field("type", decode.string)
  case content_type {
    "text" -> {
      use text <- decode.field("text", decode.string)
      decode.success(text)
    }
    _ -> decode.failure("", "Unknown thinking content type")
  }
}

pub fn message_encoder(message: Message) -> json.Json {
  case message {
    SystemMessage(content) ->
      json.object([
        #("role", json.string("system")),
        #("content", content_encoder(content)),
      ])

    UserMessage(content) ->
      json.object([
        #("role", json.string("user")),
        #("content", content_encoder(content)),
      ])

    AssistantMessage(content, tool_calls, prefix) ->
      json.object([
        #("role", json.string("assistant")),
        #("content", content_encoder(content)),
        #("tool_calls", tool.tool_calls_encoder(tool_calls)),
        #("prefix", json.bool(prefix)),
      ])

    ToolMessage(content, tool_call_id, name) ->
      json.object([
        #("role", json.string("tool")),
        #("content", content_encoder(content)),
        #("tool_call_id", json.string(tool_call_id)),
        #("name", json.string(name)),
      ])
  }
}

fn content_encoder(content: MessageContent) -> json.Json {
  case content {
    TextContent(text) -> json.string(text)
    MultiContent(parts) ->
      json.array(parts, of: fn(part: ContentPart) {
        case part {
          Text(text) ->
            json.object([
              #("type", json.string("text")),
              #("text", json.string(text)),
            ])
          ImageUrl(url) ->
            json.object([
              #("type", json.string("image_url")),
              #("image_url", json.string(url)),
            ])
          Thinking(thinking_contents) ->
            json.object([
              #("type", json.string("thinking")),
              #(
                "thinking",
                json.array(thinking_contents, of: thinking_content_encoder),
              ),
            ])
        }
      })
  }
}

fn thinking_content_encoder(content: String) -> json.Json {
  case content {
    text ->
      json.object([#("type", json.string("text")), #("text", json.string(text))])
  }
}
