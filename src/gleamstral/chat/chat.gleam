import gleam/float
import gleam/http
import gleam/http/request
import gleam/httpc
import gleam/int
import gleam/json
import gleamstral/chat/response
import gleamstral/client
import gleamstral/message
import gleamstral/model
import gleamstral/tool

/// Represents a chat conversation with configuration options
pub type Chat {
  Chat(client: client.Client, config: Config)
}

pub type Config {
  Config(
    temperature: Float,
    max_tokens: Int,
    top_p: Float,
    stream: Bool,
    stop: List(String),
    random_seed: Int,
    response_format: ResponseFormat,
    tools: List(tool.Tool),
    tool_choice: tool.ToolChoice,
    presence_penalty: Float,
    frequency_penalty: Float,
    n: Int,
    prediction: Prediction,
    safe_prompt: Bool,
  )
}

fn default_config() -> Config {
  Config(
    temperature: 1.0,
    max_tokens: 0,
    top_p: 1.0,
    stream: False,
    stop: [],
    random_seed: 0,
    response_format: Text,
    tools: [],
    tool_choice: tool.Auto,
    presence_penalty: 0.0,
    frequency_penalty: 0.0,
    n: 1,
    prediction: Content(""),
    safe_prompt: False,
  )
}

pub type ResponseFormat {
  JsonObject
  Text
}

fn response_format_encoder(response_format: ResponseFormat) -> json.Json {
  case response_format {
    JsonObject -> json.string("json_object")
    Text -> json.string("text")
  }
}

pub type Prediction {
  Content(String)
}

/// Creates a new Chat with default configuration using the provided client
///
/// ## Example
///
/// ```gleam
/// let client = client.new("your-api-key")
/// let chat = chat.new(client)
/// ```
pub fn new(client: client.Client) -> Chat {
  Chat(client: client, config: default_config())
}

pub fn set_temperature(chat: Chat, temperature: Float) -> Chat {
  Chat(
    client: chat.client,
    config: Config(
      ..chat.config,
      temperature: float.clamp(temperature, 0.0, 1.5),
    ),
  )
}

pub fn set_max_tokens(chat: Chat, max_tokens: Int) -> Chat {
  Chat(
    client: chat.client,
    config: Config(..chat.config, max_tokens: int.max(max_tokens, 0)),
  )
}

pub fn set_top_p(chat: Chat, top_p: Float) -> Chat {
  Chat(
    ..chat,
    config: Config(..chat.config, top_p: float.clamp(top_p, 0.0, 1.0)),
  )
}

pub fn set_stream(chat: Chat, stream: Bool) -> Chat {
  Chat(..chat, config: Config(..chat.config, stream:))
}

pub fn set_stop(chat: Chat, stop: List(String)) -> Chat {
  Chat(..chat, config: Config(..chat.config, stop:))
}

pub fn set_random_seed(chat: Chat, random_seed: Int) -> Chat {
  Chat(
    client: chat.client,
    config: Config(..chat.config, random_seed: int.max(random_seed, 0)),
  )
}

pub fn set_response_format(chat: Chat, response_format: ResponseFormat) -> Chat {
  Chat(..chat, config: Config(..chat.config, response_format:))
}

pub fn set_tools(chat: Chat, tools: List(tool.Tool)) -> Chat {
  Chat(..chat, config: Config(..chat.config, tools: tools))
}

pub fn set_tool_choice(chat: Chat, tool_choice: tool.ToolChoice) -> Chat {
  Chat(..chat, config: Config(..chat.config, tool_choice: tool_choice))
}

pub fn set_presence_penalty(chat: Chat, presence_penalty: Float) -> Chat {
  Chat(
    ..chat,
    config: Config(
      ..chat.config,
      presence_penalty: float.clamp(presence_penalty, -2.0, 2.0),
    ),
  )
}

pub fn set_frequency_penalty(chat: Chat, frequency_penalty: Float) -> Chat {
  Chat(
    ..chat,
    config: Config(
      ..chat.config,
      frequency_penalty: float.clamp(frequency_penalty, -2.0, 2.0),
    ),
  )
}

pub fn set_n(chat: Chat, n: Int) -> Chat {
  Chat(..chat, config: Config(..chat.config, n: int.max(n, 1)))
}

pub fn set_prediction(chat: Chat, prediction: Prediction) -> Chat {
  Chat(..chat, config: Config(..chat.config, prediction:))
}

pub fn set_safe_prompt(chat: Chat, safe_prompt: Bool) -> Chat {
  Chat(..chat, config: Config(..chat.config, safe_prompt:))
}

/// Sends a chat completion request to the API and returns the response
///
/// ### Parameters
///
/// - `chat`: The configured Chat instance
/// - `model`: The model to use for the completion
/// - `messages`: The conversation history as a list of messages
///
/// ### Returns
///
/// - `Ok(response.Response)`: The successful response from the API
/// - `Error(client.Error)`: An error that occurred during the request
///
/// ### Example
///
/// ```gleam
/// let result = chat
///   |> chat.set_temperature(0.7)
///   |> chat.complete(model.MistralSmall, messages)
/// ```
pub fn complete(
  chat: Chat,
  model: model.Model,
  messages: List(message.Message),
) -> Result(response.Response, client.Error) {
  let body = body_encoder(chat, model, messages) |> json.to_string

  let request =
    request.new()
    |> request.set_method(http.Post)
    |> request.set_header("authorization", "Bearer " <> chat.client.api_key)
    |> request.set_header("content-type", "application/json")
    |> request.set_host(client.api_endpoint)
    |> request.set_path("/v1/chat/completions")
    |> request.set_body(body)

  let assert Ok(http_result) = httpc.send(request)
  case http_result.status {
    200 -> {
      let assert Ok(response) =
        json.parse(from: http_result.body, using: response.response_decoder())
      Ok(response)
    }
    429 -> Error(client.RateLimitExceeded)
    401 -> Error(client.Unauthorized)
    _ -> {
      case json.parse(from: http_result.body, using: client.error_decoder()) {
        Ok(error) -> Error(error)
        Error(_) -> Error(client.Unknown(http_result.body))
      }
    }
  }
}

fn body_encoder(
  chat: Chat,
  model: model.Model,
  messages: List(message.Message),
) -> json.Json {
  json.object([
    #("model", json.string(model.to_string(model))),
    #("temperature", json.float(chat.config.temperature)),
    #("top_p", json.float(chat.config.top_p)),
    #("max_tokens", case chat.config.max_tokens {
      0 -> json.null()
      max_tokens -> json.int(max_tokens)
    }),
    #("stream", json.bool(chat.config.stream)),
    #("stop", json.array(chat.config.stop, of: json.string)),
    #("random_seed", case chat.config.random_seed {
      0 -> json.null()
      random_seed -> json.int(random_seed)
    }),
    #("messages", json.array(messages, of: message.message_encoder)),
    #(
      "response_format",
      json.object([
        #("type", response_format_encoder(chat.config.response_format)),
      ]),
    ),
    #("tools", json.array(chat.config.tools, of: tool.tool_encoder)),
    #("tool_choice", tool.tool_choice_encoder(chat.config.tool_choice)),
    #("presence_penalty", json.float(chat.config.presence_penalty)),
    #("frequency_penalty", json.float(chat.config.frequency_penalty)),
    #("n", json.int(chat.config.n)),
    #("prediction", case chat.config.prediction {
      Content(content) ->
        json.object([
          #("type", json.string("content")),
          #("content", json.string(content)),
        ])
    }),
    #("safe_prompt", json.bool(chat.config.safe_prompt)),
  ])
}
