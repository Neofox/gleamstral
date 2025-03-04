import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option.{type Option}

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

pub type ToolCall {
  ToolCall(id: String, tool_type: String, function: FunctionCall, index: Int)
}

pub fn tool_call_decoder() -> decode.Decoder(ToolCall) {
  use id <- decode.field("id", decode.string)
  use function <- decode.field("function", function_call_decoder())
  use index <- decode.field("index", decode.int)

  decode.success(ToolCall(id, function, index, tool_type: "function"))
}

pub fn tool_calls_encoder(tool_calls: Option(List(ToolCall))) -> json.Json {
  case tool_calls {
    option.Some(calls) ->
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
    option.None -> json.null()
  }
}

pub type FunctionCall {
  FunctionCall(name: String, arguments: String)
}

fn function_call_decoder() -> decode.Decoder(FunctionCall) {
  use name <- decode.field("name", decode.string)
  use arguments <- decode.field("arguments", decode.string)

  decode.success(FunctionCall(name, arguments))
}

/// Tool choice options for API requests
pub type ToolChoice {
  Auto
  None
  Any
  Required
  Choice(Tool)
}

pub fn tool_choice_encoder(tool_choice: ToolChoice) -> json.Json {
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

/// Create a function tool with parameters
///
/// ### Example
///
/// ```gleam
/// let weather_tool = tool.create_function_tool(
///   name: "get_weather",
///   description: "Get current temperature for provided coordinates in celsius.",
///   strict: True,
///   property_types: [
///     #("latitude", "number"),
///     #("longitude", "number"),
///   ],
///   required: ["latitude", "longitude"],
///   additional_properties: False,
/// )
/// ```
pub fn create_function_tool(
  name: String,
  description: String,
  strict: Bool,
  property_types: List(#(String, String)),
  required: List(String),
  additional_properties: Bool,
) -> Tool {
  let properties =
    property_types
    |> list.map(fn(prop) {
      let #(name, param_type) = prop
      #(name, ParameterProperty(param_type))
    })

  Function(
    name: name,
    description: description,
    strict: strict,
    parameters: ToolParameters(
      tool_type: "object",
      properties: properties,
      required: required,
      additional_properties: additional_properties,
    ),
  )
}
