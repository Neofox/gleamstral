import gleam/dynamic/decode
import gleam/float
import gleam/http
import gleam/http/request
import gleam/httpc
import gleam/int
import gleam/io
import gleam/json
import gleamstral/message.{type Message}
import gleamstral/model

const api_endpoint = "api.mistral.ai"

pub type ResponseFormat {
  JsonObject
  Text
}

pub fn response_format_to_string(response_format: ResponseFormat) -> String {
  case response_format {
    JsonObject -> "json_object"
    Text -> "text"
  }
}

pub type ToolChoice {
  Auto
  None
  Any
  Required
  Choice(Tool)
}

pub fn tool_choice_to_string(tool_choice: ToolChoice) -> String {
  case tool_choice {
    Auto -> "auto"
    None -> "none"
    Any -> "any"
    Required -> "required"
    Choice(tool) ->
      json.to_string(
        json.object([
          #("type", json.string("function")),
          #("function", json.object([#("name", json.string(tool.name))])),
        ]),
      )
  }
}

pub type Tool {
  Function(name: String, description: String, strict: Bool, parameters: String)
}

pub fn tool_to_json(tool: Tool) -> json.Json {
  case tool {
    Function(name, description, strict, parameters) ->
      json.object([
        #("type", json.string("function")),
        #(
          "function",
          json.object([
            #("name", json.string(name)),
            #("description", json.string(description)),
            #("strict", json.bool(strict)),
            #("parameters", json.string(parameters)),
          ]),
        ),
      ])
  }
}

pub type Prediction {
  Content(String)
}

pub type Response {
  Response(
    id: String,
    object: String,
    created: Int,
    model: String,
    choices: List(ChatCompletionChoice),
    usage: Usage,
  )
}

pub type FinishReason {
  Stop
  Length
  ModelLength
  Err
  ToolCalls
}

pub type ChatCompletionChoice {
  ChatCompletionChoice(
    index: Int,
    message: message.Message,
    finish_reason: FinishReason,
  )
}

pub type Usage {
  Usage(prompt_tokens: Int, completion_tokens: Int, total_tokens: Int)
}

fn usage_decoder() -> decode.Decoder(Usage) {
  use prompt_tokens <- decode.field("prompt_tokens", decode.int)
  use completion_tokens <- decode.field("completion_tokens", decode.int)
  use total_tokens <- decode.field("total_tokens", decode.int)
  decode.success(Usage(prompt_tokens:, completion_tokens:, total_tokens:))
}

pub fn response_decoder() -> decode.Decoder(Response) {
  use id <- decode.field("id", decode.string)
  use object <- decode.field("object", decode.string)
  use created <- decode.field("created", decode.int)
  use model <- decode.field("model", decode.string)
  use choices <- decode.field(
    "choices",
    decode.list(chat_completion_choice_decoder()),
  )
  use usage <- decode.field("usage", usage_decoder())
  decode.success(Response(id:, object:, created:, model:, choices:, usage:))
}

fn chat_completion_choice_decoder() -> decode.Decoder(ChatCompletionChoice) {
  use index <- decode.field("index", decode.int)
  use message <- decode.field("message", message.message_decoder())
  use finish_reason <- decode.field("finish_reason", finish_reason_decoder())
  decode.success(ChatCompletionChoice(index:, message:, finish_reason:))
}

fn finish_reason_decoder() -> decode.Decoder(FinishReason) {
  use finish_reason <- decode.then(decode.string)
  case finish_reason {
    "stop" -> decode.success(Stop)
    "length" -> decode.success(Length)
    "model_length" -> decode.success(ModelLength)
    "error" -> decode.success(Err)
    "tool_calls" -> decode.success(ToolCalls)
    _ -> decode.failure(Stop, "Invalid finish reason")
  }
}

/// Config type to hold all configuration parameters for a client.
pub type Config {
  Config(
    temperature: Float,
    max_tokens: Int,
    top_p: Float,
    stream: Bool,
    stop: List(String),
    random_seed: Int,
    response_format: ResponseFormat,
    tools: List(Tool),
    tool_choice: ToolChoice,
    presence_penalty: Float,
    frequency_penalty: Float,
    n: Int,
    prediction: Prediction,
    safe_prompt: Bool,
  )
}

/// The Client type represents a configured client for the Mistral AI API.
/// It contains an API key and a configuration object.
///
/// ## Example
///
/// ```gleam
/// let client = 
///   client.new("your_api_key")
///   |> client.set_temperature(0.7)
///   |> client.set_max_tokens(100)
/// ```
pub type Client {
  Client(api_key: String, config: Config)
}

// Create default configuration
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
    tool_choice: Auto,
    presence_penalty: 0.0,
    frequency_penalty: 0.0,
    n: 1,
    prediction: Content(""),
    safe_prompt: False,
  )
}

/// Create a new client with default configuration.
///
/// ### Example
///
/// ```gleam
/// let client = client.new("your_api_key")
/// ```
pub fn new(api_key: String) -> Client {
  Client(api_key: api_key, config: default_config())
}

/// Set the temperature parameter for the client.
/// Temperature controls randomness. Lower values make responses more deterministic.
///
/// ### Example
///
/// ```gleam
/// let client = client.new("api_key") |> client.set_temperature(0.7)
/// ```
pub fn set_temperature(client: Client, temperature: Float) -> Client {
  Client(
    ..client,
    config: Config(
      ..client.config,
      temperature: float.clamp(temperature, 0.0, 1.5),
    ),
  )
}

/// Set the maximum number of tokens to generate.
///
/// ### Example
///
/// ```gleam
/// let client = client.new("api_key") |> client.set_max_tokens(100)
/// ```
pub fn set_max_tokens(client: Client, max_tokens: Int) -> Client {
  Client(
    ..client,
    config: Config(..client.config, max_tokens: int.max(max_tokens, 0)),
  )
}

/// Set the top_p parameter for nucleus sampling.
///
/// ### Example
///
/// ```gleam
/// let client = client.new("api_key") |> client.set_top_p(0.9)
/// ```
pub fn set_top_p(client: Client, top_p: Float) -> Client {
  Client(
    ..client,
    config: Config(..client.config, top_p: float.clamp(top_p, 0.0, 1.0)),
  )
}

/// Set the stop sequences for the client.
///
/// ### Example
///
/// ```gleam
/// let client = client.new("api_key") |> client.set_stop(["END", "STOP"])
/// ```
pub fn set_stop(client: Client, stop: List(String)) -> Client {
  Client(..client, config: Config(..client.config, stop:))
}

/// Set the random seed for deterministic outputs.
///
/// ### Example
///
/// ```gleam
/// let client = client.new("api_key") |> client.set_random_seed(42)
/// ```
pub fn set_random_seed(client: Client, random_seed: Int) -> Client {
  Client(
    ..client,
    config: Config(..client.config, random_seed: int.max(random_seed, 0)),
  )
}

/// Set whether responses should be streamed.
///
/// ### Example
///
/// ```gleam
/// let client = client.new("api_key") |> client.set_stream(True)
/// ```
pub fn set_stream(client: Client, stream: Bool) -> Client {
  Client(..client, config: Config(..client.config, stream:))
}

/// Set the response format (JSON or text).
///
/// ### Example
///
/// ```gleam
/// let client = client.new("api_key") |> client.set_response_format(client.JsonObject)
/// ```
pub fn set_response_format(
  client: Client,
  response_format: ResponseFormat,
) -> Client {
  Client(..client, config: Config(..client.config, response_format:))
}

/// Set the tools available to the model.
///
/// ### Example
///
/// ```gleam
/// let tool = client.Function(name: "calculator", description: "Calculates stuff", strict: True, parameters: "{}")
/// let client = client.new("api_key") |> client.set_tools([tool])
/// ```
pub fn set_tools(client: Client, tools: List(Tool)) -> Client {
  Client(..client, config: Config(..client.config, tools:))
}

/// Set the tool choice for the model.
///
/// ### Example
///
/// ```gleam
/// let client = client.new("api_key") |> client.set_tool_choice(client.Auto)
/// ```
pub fn set_tool_choice(client: Client, tool_choice: ToolChoice) -> Client {
  Client(..client, config: Config(..client.config, tool_choice:))
}

/// Set the presence penalty to discourage repetition.
///
/// ### Example
///
/// ```gleam
/// let client = client.new("api_key") |> client.set_presence_penalty(0.5)
/// ```
pub fn set_presence_penalty(client: Client, presence_penalty: Float) -> Client {
  Client(
    ..client,
    config: Config(
      ..client.config,
      presence_penalty: float.clamp(presence_penalty, -2.0, 2.0),
    ),
  )
}

/// Set the frequency penalty to discourage repeated token usage.
///
/// ### Example
///
/// ```gleam
/// let client = client.new("api_key") |> client.set_frequency_penalty(0.5)
/// ```
pub fn set_frequency_penalty(client: Client, frequency_penalty: Float) -> Client {
  Client(
    ..client,
    config: Config(
      ..client.config,
      frequency_penalty: float.clamp(frequency_penalty, -2.0, 2.0),
    ),
  )
}

/// Set the number of completions to generate.
///
/// ### Example
///
/// ```gleam
/// let client = client.new("api_key") |> client.set_n(2)
/// ```
pub fn set_n(client: Client, n: Int) -> Client {
  Client(..client, config: Config(..client.config, n: int.max(n, 1)))
}

/// Set the prediction for the client.
pub fn set_prediction(client: Client, prediction: Prediction) -> Client {
  Client(..client, config: Config(..client.config, prediction:))
}

/// Set the safe prompt flag.
///
/// ### Example
///
/// ```gleam
/// let client = client.new("api_key") |> client.set_safe_prompt(True)
/// ```
pub fn set_safe_prompt(client: Client, safe_prompt: Bool) -> Client {
  Client(..client, config: Config(..client.config, safe_prompt: safe_prompt))
}

/// Send a chat completion request to the Mistral AI API.
/// This function validates the configuration before sending the request.
///
/// ### Example
///
/// ```gleam
/// let client = 
///   client.new("your_api_key")
///   |> client.set_temperature(0.7)
///
/// let messages = [
///   message.system("You are a helpful assistant"),
///   message.user("Hello!")
/// ]
///
/// case client.chat_completion(client, model.MistralLarge, messages) {
///   Ok(response) -> // handle response
///   Error(err) -> // handle error
/// }
/// ```
pub fn chat_completion(
  client: Client,
  model: model.Model,
  messages: List(Message),
) -> Result(Response, String) {
  let body = body_encoder(client, model, messages) |> json.to_string

  let request =
    request.new()
    |> request.set_method(http.Post)
    |> request.set_header("authorization", "Bearer " <> client.api_key)
    |> request.set_header("content-type", "application/json")
    |> request.set_host(api_endpoint)
    |> request.set_path("/v1/chat/completions")
    |> request.set_body(body)

  let assert Ok(http_result) = httpc.send(request)
  case http_result.status {
    200 -> {
      let assert Ok(response) =
        json.parse(from: http_result.body, using: response_decoder())
      Ok(response)
    }
    _ -> {
      io.debug(http_result.body)
      case json.parse(from: http_result.body, using: error_decoder()) {
        Ok(error) -> Error(error)
        Error(_) -> Error(http_result.body)
      }
    }
  }
}

fn error_decoder() -> decode.Decoder(String) {
  use error <- decode.field("message", decode.string)
  decode.success(error)
}

pub fn body_encoder(
  client: Client,
  model: model.Model,
  messages: List(Message),
) -> json.Json {
  let config = client.config

  json.object([
    #("model", json.string(model.to_string(model))),
    #("temperature", json.float(config.temperature)),
    #("top_p", json.float(config.top_p)),
    #("max_tokens", case config.max_tokens {
      0 -> json.null()
      max_tokens -> json.int(max_tokens)
    }),
    #("stream", json.bool(config.stream)),
    #("stop", json.array(config.stop, of: json.string)),
    #("random_seed", case config.random_seed {
      0 -> json.null()
      random_seed -> json.int(random_seed)
    }),
    #("messages", json.array(messages, of: message.message_encoder)),
    #(
      "response_format",
      json.object([
        #(
          "type",
          json.string(response_format_to_string(config.response_format)),
        ),
      ]),
    ),
    #(
      "tools",
      json.array(config.tools, of: fn(tool: Tool) { tool_to_json(tool) }),
    ),
    #("tool_choice", json.string(tool_choice_to_string(config.tool_choice))),
    #("presence_penalty", json.float(config.presence_penalty)),
    #("frequency_penalty", json.float(config.frequency_penalty)),
    #("n", json.int(config.n)),
    #("prediction", case config.prediction {
      Content(content) ->
        json.object([
          #("type", json.string("content")),
          #("content", json.string(content)),
        ])
    }),
    #("safe_prompt", json.bool(config.safe_prompt)),
  ])
}
