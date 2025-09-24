import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option.{type Option}
import oas/json_schema

/// Represents a tool that can be used by the model
///
/// - `Function`: A function tool with name, description, and parameters
pub type Tool {
  Function(
    name: String,
    description: String,
    strict: Bool,
    parameters: json_schema.Schema,
  )
}

/// Decodes a tool from JSON
pub fn tool_decoder() -> decode.Decoder(Tool) {
  use name <- decode.field("name", decode.string)
  use description <- decode.field("description", decode.string)
  use strict <- decode.field("strict", decode.bool)
  use parameters <- decode.field("parameters", json_schema.decoder())
  decode.success(Function(name:, description:, strict:, parameters:))
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
            #("parameters", json_schema.encode(parameters)),
          ]),
        ),
      ])
  }
}

/// Represents a tool call made by the model
///
/// Contains the ID, type, function call details, and index of the tool call
pub type ToolCall {
  ToolCall(id: String, tool_type: String, function: FunctionCall, index: Int)
}

/// Decodes a tool call from JSON
///
/// Used to parse tool calls in model responses
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

/// Represents a function call within a tool call
///
/// Contains the name of the function and its arguments as a JSON string
pub type FunctionCall {
  FunctionCall(name: String, arguments: String)
}

fn function_call_decoder() -> decode.Decoder(FunctionCall) {
  use name <- decode.field("name", decode.string)
  use arguments <- decode.field("arguments", decode.string)

  decode.success(FunctionCall(name, arguments))
}

/// Tool choice options for API requests
///
/// - `Auto`: Let the model decide when to use tools
/// - `None`: Do not use tools
/// - `Any`: Allow the model to use any available tool
/// - `Required`: Require the model to use tools
/// - `Choice(Tool)`: Require the model to use a specific tool
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

/// Creates a new basic function tool with the given name, description, and properties.
///
/// ### Parameters
/// - `name`: The name of the function tool.
/// - `description`: A brief description of the function tool.
/// - `properties`: A list of tuples where each tuple contains a property name and its type.
///
/// ### Returns
/// A `Tool` representing the function tool.
///
/// ### Examples
/// ```
/// let tool = new_basic_function(
///   "get_weather",
///   "Get the current weather for the provided city. Use the unit for the temperature.",
///   [
///     json_schema.field("city", json_schema.string()), 
///     json_schema.field("unit", json_schema.string())
///   ]
/// )
/// ```
pub fn new_basic_function(
  name: String,
  description: String,
  fields: List(#(String, json_schema.Ref(json_schema.Schema), Bool)),
) -> Tool {
  Function(
    name: name,
    description: description,
    strict: True,
    parameters: json_schema.object(fields),
  )
}
