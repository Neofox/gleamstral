import gleam/json
import gleam/option
import gleeunit/should

import gleamstral/tool.{
  ArrayProperty, BooleanProperty, Function, FunctionCall, IntegerProperty,
  NumberProperty, ObjectProperty, StringProperty, ToolCall, ToolParameters,
}

pub fn tool_encoder_test() {
  let tool =
    Function(
      name: "get_weather",
      description: "Get the current weather",
      strict: True,
      parameters: ToolParameters(
        tool_type: "object",
        properties: [
          #("location", StringProperty(description: "The city and state")),
          #("unit", StringProperty(description: "The temperature unit")),
        ],
        required: ["location"],
        additional_properties: False,
      ),
    )

  let result = tool.tool_encoder(tool)
  let expected =
    json.object([
      #("type", json.string("function")),
      #(
        "function",
        json.object([
          #("name", json.string("get_weather")),
          #("description", json.string("Get the current weather")),
          #("strict", json.bool(True)),
          #(
            "parameters",
            json.object([
              #("type", json.string("object")),
              #(
                "properties",
                json.object([
                  #(
                    "location",
                    json.object([
                      #("type", json.string("string")),
                      #("description", json.string("The city and state")),
                    ]),
                  ),
                  #(
                    "unit",
                    json.object([
                      #("type", json.string("string")),
                      #("description", json.string("The temperature unit")),
                    ]),
                  ),
                ]),
              ),
              #("required", json.array(["location"], of: json.string)),
              #("additionalProperties", json.bool(False)),
            ]),
          ),
        ]),
      ),
    ])

  should.equal(result, expected)
}

pub fn new_basic_function_test() {
  let tool =
    tool.new_basic_function("get_weather", "Get the current weather", [
      #("location", StringProperty(description: "The city and state")),
      #("unit", StringProperty(description: "The temperature unit")),
    ])

  let expected =
    Function(
      name: "get_weather",
      description: "Get the current weather",
      strict: True,
      parameters: ToolParameters(
        tool_type: "object",
        properties: [
          #("location", StringProperty(description: "The city and state")),
          #("unit", StringProperty(description: "The temperature unit")),
        ],
        required: ["location", "unit"],
        additional_properties: False,
      ),
    )

  should.equal(tool.name, expected.name)
  should.equal(tool.description, expected.description)
  should.equal(tool.strict, expected.strict)
  should.equal(tool.parameters.tool_type, expected.parameters.tool_type)
  should.equal(tool.parameters.required, expected.parameters.required)
  should.equal(
    tool.parameters.additional_properties,
    expected.parameters.additional_properties,
  )
}

pub fn parameter_property_test() {
  // Test all property types
  let string_property = StringProperty(description: "A string")
  let integer_property = IntegerProperty(description: "An integer")
  let number_property = NumberProperty(description: "A number")
  let boolean_property = BooleanProperty(description: "A boolean")
  let array_property =
    ArrayProperty(
      description: "An array of strings",
      item_type: StringProperty(description: "a string"),
    )
  let object_property =
    ObjectProperty(description: "A nested object", properties: [
      #("nested", StringProperty(description: "A nested property")),
    ])

  // Create a tool with all property types
  let tool =
    Function(
      name: "test_properties",
      description: "Test all property types",
      strict: True,
      parameters: ToolParameters(
        tool_type: "object",
        properties: [
          #("string_prop", string_property),
          #("integer_prop", integer_property),
          #("number_prop", number_property),
          #("boolean_prop", boolean_property),
          #("array_prop", array_property),
          #("object_prop", object_property),
        ],
        required: ["string_prop"],
        additional_properties: False,
      ),
    )

  tool.tool_encoder(tool)

  should.equal(string_property.description, "A string")
  should.equal(integer_property.description, "An integer")
  should.equal(number_property.description, "A number")
  should.equal(boolean_property.description, "A boolean")
  should.equal(array_property.description, "An array of strings")
  should.equal(
    array_property.item_type,
    StringProperty(description: "a string"),
  )
  should.equal(object_property.description, "A nested object")
  should.equal(object_property.properties, [
    #("nested", StringProperty(description: "A nested property")),
  ])
}

pub fn tool_call_test() {
  let tool_call =
    ToolCall(
      id: "call_123",
      tool_type: "function",
      function: FunctionCall(
        name: "get_weather",
        arguments: "{\"location\":\"New York\",\"unit\":\"celsius\"}",
      ),
      index: 0,
    )

  let result = tool.tool_calls_encoder(option.Some([tool_call]))
  let expected =
    json.array(
      [
        json.object([
          #("id", json.string("call_123")),
          #("type", json.string("function")),
          #(
            "function",
            json.object([
              #("name", json.string("get_weather")),
              #(
                "arguments",
                json.string("{\"location\":\"New York\",\"unit\":\"celsius\"}"),
              ),
            ]),
          ),
          #("index", json.int(0)),
        ]),
      ],
      of: fn(x) { x },
    )

  should.equal(result, expected)
}

pub fn tool_choice_test() {
  // Test Auto choice
  let auto_result = tool.tool_choice_encoder(tool.Auto)
  should.equal(auto_result, json.string("auto"))

  // Test None choice
  let none_result = tool.tool_choice_encoder(tool.None)
  should.equal(none_result, json.string("none"))

  // Test Any choice
  let any_result = tool.tool_choice_encoder(tool.Any)
  should.equal(any_result, json.string("any"))

  // Test Required choice
  let required_result = tool.tool_choice_encoder(tool.Required)
  should.equal(required_result, json.string("required"))

  // Test specific tool choice
  let tool =
    Function(
      name: "get_weather",
      description: "Get the current weather",
      strict: True,
      parameters: ToolParameters(
        tool_type: "object",
        properties: [
          #("location", StringProperty(description: "The city and state")),
        ],
        required: ["location"],
        additional_properties: False,
      ),
    )

  let choice_result = tool.tool_choice_encoder(tool.Choice(tool))
  let expected_choice =
    json.object([
      #("type", json.string("function")),
      #("function", json.object([#("name", json.string("get_weather"))])),
    ])

  should.equal(choice_result, expected_choice)
}

pub fn tool_calls_encoder_none_test() {
  let result = tool.tool_calls_encoder(option.None)
  should.equal(result, json.null())
}
