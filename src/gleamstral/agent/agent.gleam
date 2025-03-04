import gleam/dynamic/decode
import gleam/float
import gleam/http
import gleam/http/request
import gleam/httpc
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleamstral/agent/response
import gleamstral/client
import gleamstral/message

const api_endpoint = "api.mistral.ai"

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
    tools: List(Tool),
    tool_choice: ToolChoice,
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
    tool_choice: Auto,
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

pub type Tool {
  Function(
    name: String,
    description: String,
    strict: Bool,
    parameters: ToolParameters,
  )
}

pub type ToolParameters {
  ToolParameters(
    tool_type: String,
    properties: List(#(String, ParameterProperty)),
    required: List(String),
    additional_properties: Bool,
  )
}

pub type ParameterProperty {
  ParameterProperty(param_type: String)
}

pub fn tool_encoder(tool: Tool) -> json.Json {
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
            #("parameters", function_parameters_encoder(parameters)),
          ]),
        ),
      ])
  }
}

fn function_parameters_encoder(parameters: ToolParameters) -> json.Json {
  json.object([
    #("type", json.string(parameters.tool_type)),
    #(
      "properties",
      json.object(
        parameters.properties
        |> list.map(fn(prop: #(String, ParameterProperty)) {
          let #(name, property) = prop
          #(name, json.object([#("type", json.string(property.param_type))]))
        }),
      ),
    ),
    #("required", json.array(parameters.required, of: json.string)),
    #("additionalProperties", json.bool(parameters.additional_properties)),
  ])
}

pub type ToolChoice {
  Auto
  None
  Any
  Required
  Choice(Tool)
}

fn tool_choice_encoder(tool_choice: ToolChoice) -> json.Json {
  case tool_choice {
    Auto -> json.string("auto")
    None -> json.string("none")
    Any -> json.string("any")
    Required -> json.string("required")
    Choice(tool) ->
      json.object([
        #("type", json.string("function")),
        #("function", json.object([#("name", json.string(tool.name))])),
      ])
  }
}

pub type Prediction {
  Content(String)
}

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

pub fn set_tools(agent: Agent, tools: List(Tool)) -> Agent {
  Agent(..agent, config: Config(..agent.config, tools:))
}

pub fn set_tool_choice(agent: Agent, tool_choice: ToolChoice) -> Agent {
  Agent(..agent, config: Config(..agent.config, tool_choice:))
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

pub fn complete(
  agent: Agent,
  agent_id: String,
  messages: List(message.Message),
) -> Result(response.Response, String) {
  let body = body_encoder(agent, agent_id, messages) |> json.to_string

  let request =
    request.new()
    |> request.set_method(http.Post)
    |> request.set_header("authorization", "Bearer " <> agent.client.api_key)
    |> request.set_header("content-type", "application/json")
    |> request.set_host(api_endpoint)
    |> request.set_path("/v1/agents/completions")
    |> request.set_body(body)

  let assert Ok(http_result) = httpc.send(request)
  case http_result.status {
    200 -> {
      let assert Ok(response) =
        json.parse(from: http_result.body, using: response.response_decoder())
      Ok(response)
    }
    _ -> {
      io.debug(http_result)
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
    #("tools", json.array(agent.config.tools, of: tool_encoder)),
    #("tool_choice", tool_choice_encoder(agent.config.tool_choice)),
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
