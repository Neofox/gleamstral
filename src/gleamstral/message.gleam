import gleam/dynamic/decode
import gleam/json
import gleam/option.{type Option, None, Some}

pub type MessageRole {
  System
  User
  Assistant
  Tool
}

pub type ToolCall {
  ToolCall(id: String, tool_type: String, function: FunctionCall, index: Int)
}

pub type FunctionCall {
  FunctionCall(name: String, arguments: String)
}

pub type Message {
  SystemMessage(content: MessageContent)
  UserMessage(content: MessageContent)
  AssistantMessage(
    content: String,
    tool_calls: Option(List(ToolCall)),
    prefix: Bool,
  )
  ToolMessage(content: MessageContent, tool_call_id: String, name: String)
}

pub type MessageContent {
  TextContent(String)
  MultiContent(List(ContentPart))
}

pub type ContentPart {
  Text(String)
  ImageUrl(String)
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
      use content <- decode.field("content", decode.string)

      use tool_calls <- decode.field(
        "tool_calls",
        decode.optional(decode.list(tool_call_decoder())),
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
  use content_part_type <- decode.then(decode.string)
  case content_part_type {
    "text" -> {
      use text <- decode.field("text", decode.string)
      decode.success(Text(text))
    }
    "image_url" -> {
      use url <- decode.field("image_url", decode.string)
      decode.success(ImageUrl(url))
    }
    _ -> decode.failure(Text(""), "Unknown content part type")
  }
}

fn tool_call_decoder() -> decode.Decoder(ToolCall) {
  use id <- decode.field("id", decode.string)
  use function <- decode.field("function", function_call_decoder())
  use index <- decode.field("index", decode.int)

  decode.success(ToolCall(id, function, index, tool_type: "function"))
}

fn function_call_decoder() -> decode.Decoder(FunctionCall) {
  use name <- decode.field("name", decode.string)
  use arguments <- decode.field("arguments", decode.string)

  decode.success(FunctionCall(name, arguments))
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
        #("content", json.string(content)),
        #("tool_calls", tool_calls_encoder(tool_calls)),
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
        }
      })
  }
}

fn tool_calls_encoder(tool_calls: Option(List(ToolCall))) -> json.Json {
  case tool_calls {
    None -> json.null()
    Some(calls) ->
      json.array(calls, of: fn(call) {
        json.object([
          #("id", json.string(call.id)),
          #("type", json.string(call.tool_type)),
          #(
            "function",
            json.object([
              #("name", json.string(call.function.name)),
              #("arguments", json.string(call.function.arguments)),
            ]),
          ),
          #("index", json.int(call.index)),
        ])
      })
  }
}
