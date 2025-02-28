import gleam/json
import gleam/list

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

pub type Message(content) {
  Message(role: MessageRole, content: content)
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
}

pub fn new(
  role: MessageRole,
  content: MessageContent,
) -> Result(Message(MessageContent), Error) {
  case role, content {
    // System role validation
    System, TextContent(_) -> Ok(Message(role, content))
    System, MultiContent(parts) ->
      case
        list.all(parts, fn(part) {
          case part {
            Text(_) -> True
            _ -> False
          }
        })
      {
        True -> Ok(Message(role, content))
        False -> Error(InvalidSystemMessage)
      }

    // Assistant role validation
    Assistant, TextContent(_) -> Ok(Message(role, content))
    Assistant, _ -> Error(InvalidAssistantMessage)

    // Tool and User roles can have any content
    _, _ -> Ok(Message(role, content))
  }
}

pub fn to_json(message: Message(MessageContent)) -> json.Json {
  case message.content {
    TextContent(content) ->
      json.object([
        #("role", json.string(role_to_string(message.role))),
        #("content", json.string(content)),
      ])
    MultiContent(content_parts) ->
      json.object([
        #("role", json.string(role_to_string(message.role))),
        #(
          "content",
          json.array(content_parts, of: fn(part: ContentPart) {
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
          }),
        ),
      ])
  }
}
