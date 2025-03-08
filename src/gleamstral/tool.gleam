import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option.{type Option}

/// Represents a tool that can be used by the model
///
/// - `Function`: A function tool with name, description, and parameters
pub type Tool {
  Function(
    name: String,
    description: String,
    strict: Bool,
    parameters: ToolParameters,
  )
}

/// Decodes a tool from JSON
pub fn tool_decoder() -> decode.Decoder(Tool) {
  use name <- decode.field("name", decode.string)
  use description <- decode.field("description", decode.string)
  use strict <- decode.field("strict", decode.bool)
  use parameters <- decode.field("parameters", tool_parameters_decoder())
  decode.success(Function(name:, description:, strict:, parameters:))
}

/// Parameters for a tool function
///
/// Contains the structure of parameters expected by the tool
pub type ToolParameters {
  ToolParameters(
    tool_type: String,
    properties: List(#(String, ParameterProperty)),
    required: List(String),
    additional_properties: Bool,
  )
}

fn tool_parameters_decoder() -> decode.Decoder(ToolParameters) {
  use tool_type <- decode.field("tool_type", decode.string)
  use properties <- decode.field(
    "properties",
    decode.list({
      use a <- decode.field(0, decode.string)
      use b <- decode.field(1, parameter_property_decoder())

      decode.success(#(a, b))
    }),
  )
  use required <- decode.field("required", decode.list(decode.string))
  use additional_properties <- decode.field(
    "additional_properties",
    decode.bool,
  )
  decode.success(ToolParameters(
    tool_type:,
    properties:,
    required:,
    additional_properties:,
  ))
}

/// Property definition for a tool parameter
pub type ParameterProperty {
  /// A string property type
  StringProperty(description: String)
  /// An integer property type
  IntegerProperty(description: String)
  /// A number property type (float or integer)
  NumberProperty(description: String)
  /// A boolean property type
  BooleanProperty(description: String)
  /// An array property type with an item type (string, integer, number, boolean)
  ArrayProperty(description: String, item_type: String)
  /// An object property type
  ObjectProperty(
    description: String,
    properties: List(#(String, ParameterProperty)),
  )
}

fn parameter_property_decoder() -> decode.Decoder(ParameterProperty) {
  use param_type <- decode.field("type", decode.string)
  case param_type {
    "string" -> {
      use description <- decode.field("description", decode.string)
      decode.success(StringProperty(description:))
    }
    "integer" -> {
      use description <- decode.field("description", decode.string)
      decode.success(IntegerProperty(description:))
    }
    "number" -> {
      use description <- decode.field("description", decode.string)
      decode.success(NumberProperty(description:))
    }
    "boolean" -> {
      use description <- decode.field("description", decode.string)
      decode.success(BooleanProperty(description:))
    }
    "array" -> {
      use description <- decode.field("description", decode.string)
      use item_type <- decode.subfield(["items", "type"], decode.string)
      decode.success(ArrayProperty(description:, item_type:))
    }
    "object" -> {
      use description <- decode.field("description", decode.string)
      use properties <- decode.field(
        "properties",
        decode.list({
          use a <- decode.field(0, decode.string)
          use b <- decode.field(1, parameter_property_decoder())

          decode.success(#(a, b))
        }),
      )
      decode.success(ObjectProperty(description:, properties:))
    }
    _ ->
      decode.failure(StringProperty(description: ""), "Invalid parameter type")
  }
}

fn parameter_property_encoder(property: ParameterProperty) -> json.Json {
  case property {
    StringProperty(description) ->
      json.object([
        #("type", json.string("string")),
        #("description", json.string(description)),
      ])

    IntegerProperty(description) ->
      json.object([
        #("type", json.string("integer")),
        #("description", json.string(description)),
      ])

    NumberProperty(description) ->
      json.object([
        #("type", json.string("number")),
        #("description", json.string(description)),
      ])

    BooleanProperty(description) ->
      json.object([
        #("type", json.string("boolean")),
        #("description", json.string(description)),
      ])

    ArrayProperty(description, item_type) ->
      json.object([
        #("type", json.string("array")),
        #("description", json.string(description)),
        #("items", json.object([#("type", json.string(item_type))])),
      ])

    ObjectProperty(description, properties) ->
      json.object([
        #("type", json.string("object")),
        #("description", json.string(description)),
        #("additionalProperties", json.bool(False)),
        #(
          "properties",
          json.object(
            properties
            |> list.map(fn(prop: #(String, ParameterProperty)) {
              let #(name, property) = prop
              #(name, parameter_property_encoder(property))
            }),
          ),
        ),
      ])
  }
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
          #(name, parameter_property_encoder(property))
        }),
      ),
    ),
    #("required", json.array(parameters.required, of: json.string)),
    #("additionalProperties", json.bool(parameters.additional_properties)),
  ])
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

@deprecated("Please use the tool/new_basic_function or make your own Tool type.")
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
      case param_type {
        "string" -> #(name, StringProperty(""))
        "integer" -> #(name, IntegerProperty(""))
        "number" -> #(name, NumberProperty(""))
        "boolean" -> #(name, BooleanProperty(""))
        "array" -> #(name, ArrayProperty("", ""))
        "object" -> #(name, ObjectProperty("", []))
        _ -> #(name, StringProperty(""))
      }
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
///   [#("city", "string"), #("unit", "string")]
/// )
/// ```
pub fn new_basic_function(
  name: String,
  description: String,
  properties: List(#(String, ParameterProperty)),
) -> Tool {
  Function(
    name: name,
    description: description,
    strict: True,
    parameters: ToolParameters(
      tool_type: "object",
      properties: properties,
      required: list.map(properties, fn(prop) {
        let #(name, _) = prop
        name
      }),
      additional_properties: False,
    ),
  )
}
