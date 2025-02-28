import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}

pub type MessageRole {
  System
  User
  Assistant
  Tool
}

pub fn role_to_string(role: MessageRole) -> String {
  case role {
    System -> "system"
    User -> "user"
    Assistant -> "assistant"
    Tool -> "tool"
  }
}

pub fn get_role(message: Message) -> MessageRole {
  case message {
    SystemMessage(_) -> System
    UserMessage(_) -> User
    AssistantMessage(_, _, _) -> Assistant
    ToolMessage(_, _, _) -> Tool
  }
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

pub type Error {
  InvalidSystemMessage
  InvalidAssistantMessage
  InvalidToolMessage
}

pub fn system(content: MessageContent) -> Result(Message, Error) {
  case content {
    TextContent(_) -> Ok(SystemMessage(content))
    MultiContent(parts) ->
      case
        list.all(parts, fn(part) {
          case part {
            Text(_) -> True
            _ -> False
          }
        })
      {
        True -> Ok(SystemMessage(content))
        False -> Error(InvalidSystemMessage)
      }
  }
}

pub fn user(content: MessageContent) -> Message {
  UserMessage(content)
}

pub fn assistant(
  content: String,
  tool_calls: Option(List(ToolCall)),
  prefix: Bool,
) -> Message {
  AssistantMessage(content, tool_calls, prefix)
}

pub fn tool(
  content: MessageContent,
  tool_call_id: String,
  name: String,
) -> Message {
  ToolMessage(content, tool_call_id, name)
}

pub fn to_json(message: Message) -> json.Json {
  case message {
    SystemMessage(content) ->
      json.object([
        #("role", json.string("system")),
        #("content", content_to_json(content)),
      ])

    UserMessage(content) ->
      json.object([
        #("role", json.string("user")),
        #("content", content_to_json(content)),
      ])

    AssistantMessage(content, tool_calls, prefix) ->
      json.object([
        #("role", json.string("assistant")),
        #("content", json.string(content)),
        #("tool_calls", tool_calls_to_json(tool_calls)),
        #("prefix", json.bool(prefix)),
      ])

    ToolMessage(content, tool_call_id, name) ->
      json.object([
        #("role", json.string("tool")),
        #("content", content_to_json(content)),
        #("tool_call_id", json.string(tool_call_id)),
        #("name", json.string(name)),
      ])
  }
}

fn content_to_json(content: MessageContent) -> json.Json {
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

fn tool_calls_to_json(tool_calls: Option(List(ToolCall))) -> json.Json {
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
