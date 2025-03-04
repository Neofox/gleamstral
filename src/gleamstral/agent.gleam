import gleam/dynamic/decode
import gleam/float
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/int
import gleam/json
import gleamstral/client
import gleamstral/message
import gleamstral/tool

/// Represents an agent with configuration options for communication with Mistral AI agents
pub type Agent {
  Agent(client: client.Client, config: Config)
}

pub type Config {
  Config(
    max_tokens: Int,
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
  )
}

fn default_config() -> Config {
  Config(
    max_tokens: 0,
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

/// Creates a new Agent with default configuration using the provided client
///
/// ### Example
///
/// ```gleam
/// let client = client.new("your-api-key")
/// let agent = agent.new(client)
/// ```
pub fn new(client: client.Client) -> Agent {
  Agent(client: client, config: default_config())
}

pub fn set_max_tokens(agent: Agent, max_tokens: Int) -> Agent {
  Agent(
    ..agent,
    config: Config(..agent.config, max_tokens: int.max(max_tokens, 0)),
  )
}

pub fn set_stream(agent: Agent, stream: Bool) -> Agent {
  Agent(..agent, config: Config(..agent.config, stream:))
}

pub fn set_stop(agent: Agent, stop: List(String)) -> Agent {
  Agent(..agent, config: Config(..agent.config, stop:))
}

pub fn set_random_seed(agent: Agent, random_seed: Int) -> Agent {
  Agent(..agent, config: Config(..agent.config, random_seed:))
}

pub fn set_response_format(
  agent: Agent,
  response_format: ResponseFormat,
) -> Agent {
  Agent(..agent, config: Config(..agent.config, response_format:))
}

pub fn set_tools(agent: Agent, tools: List(tool.Tool)) -> Agent {
  Agent(..agent, config: Config(..agent.config, tools: tools))
}

pub fn set_tool_choice(agent: Agent, tool_choice: tool.ToolChoice) -> Agent {
  Agent(..agent, config: Config(..agent.config, tool_choice: tool_choice))
}

pub fn set_presence_penalty(agent: Agent, presence_penalty: Float) -> Agent {
  Agent(
    ..agent,
    config: Config(
      ..agent.config,
      presence_penalty: float.clamp(presence_penalty, -2.0, 2.0),
    ),
  )
}

pub fn set_frequency_penalty(agent: Agent, frequency_penalty: Float) -> Agent {
  Agent(
    ..agent,
    config: Config(
      ..agent.config,
      frequency_penalty: float.clamp(frequency_penalty, -2.0, 2.0),
    ),
  )
}

pub fn set_n(agent: Agent, n: Int) -> Agent {
  Agent(..agent, config: Config(..agent.config, n: int.max(n, 1)))
}

pub fn set_prediction(agent: Agent, prediction: Prediction) -> Agent {
  Agent(..agent, config: Config(..agent.config, prediction:))
}

/// Creates an HTTP request for the Agent API endpoint
///
/// This function prepares a request to be sent to the Mistral AI Agent API.
/// It needs to be paired with an HTTP client to actually send the request,
/// and the response should be handled with client.handle_response using 
/// the appropriate decoder.
///
/// ### Example
///
/// ```gleam
/// // Create the request
/// let req = agent
///   |> agent.complete_request("agent-123", messages)
///
/// // Send the request with your HTTP client
/// use response <- result.try(http_client.send(req))
/// 
/// // Handle the response with the appropriate decoder
/// client.handle_response(response, using: agent.response_decoder())
/// ```
pub fn complete_request(
  agent: Agent,
  agent_id: String,
  messages: List(message.Message),
) -> request.Request(String) {
  let body = body_encoder(agent, agent_id, messages) |> json.to_string

  request.new()
  |> request.set_method(http.Post)
  |> request.set_header("authorization", "Bearer " <> agent.client.api_key)
  |> request.set_header("content-type", "application/json")
  |> request.set_host(client.api_endpoint)
  |> request.set_path("/v1/agents/completions")
  |> request.set_body(body)
}

fn body_encoder(
  agent: Agent,
  agent_id: String,
  messages: List(message.Message),
) -> json.Json {
  json.object([
    #("agent_id", json.string(agent_id)),
    #("max_tokens", case agent.config.max_tokens {
      0 -> json.null()
      max_tokens -> json.int(max_tokens)
    }),
    #("stream", json.bool(agent.config.stream)),
    #("stop", json.array(agent.config.stop, of: json.string)),
    #("random_seed", case agent.config.random_seed {
      0 -> json.null()
      random_seed -> json.int(random_seed)
    }),
    #("messages", json.array(messages, of: message.message_encoder)),
    #(
      "response_format",
      json.object([
        #("type", response_format_encoder(agent.config.response_format)),
      ]),
    ),
    #("tools", json.array(agent.config.tools, of: tool.tool_encoder)),
    #("tool_choice", tool.tool_choice_encoder(agent.config.tool_choice)),
    #("presence_penalty", json.float(agent.config.presence_penalty)),
    #("frequency_penalty", json.float(agent.config.frequency_penalty)),
    #("n", json.int(agent.config.n)),
    #("prediction", case agent.config.prediction {
      Content(content) ->
        json.object([
          #("type", json.string("content")),
          #("content", json.string(content)),
        ])
    }),
  ])
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

/// Handle HTTP responses from an agent request
///
/// This is a convenience function that automatically uses the agent response decoder,
/// so you don't need to pass it manually.
///
/// ## Example
///
/// ```gleam
/// agent.handle_response(response)
/// ```
pub fn handle_response(
  response: response.Response(String),
) -> Result(Response, client.Error) {
  client.handle_response(response, using: response_decoder())
}
