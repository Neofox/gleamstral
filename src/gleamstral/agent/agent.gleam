import gleam/float
import gleam/http
import gleam/http/request
import gleam/httpc
import gleam/int
import gleam/json
import gleamstral/agent/response
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

/// Sends an agent completion request to the API and returns the response
///
/// ### Parameters
///
/// - `agent`: The configured Agent instance
/// - `agent_id`: The ID of the Mistral AI agent to interact with
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
/// let result = agent
///   |> agent.set_max_tokens(1000)
///   |> agent.complete("agent-123", messages)
/// ```
pub fn complete(
  agent: Agent,
  agent_id: String,
  messages: List(message.Message),
) -> Result(response.Response, client.Error) {
  let body = body_encoder(agent, agent_id, messages) |> json.to_string

  let request =
    request.new()
    |> request.set_method(http.Post)
    |> request.set_header("authorization", "Bearer " <> agent.client.api_key)
    |> request.set_header("content-type", "application/json")
    |> request.set_host(client.api_endpoint)
    |> request.set_path("/v1/agents/completions")
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
