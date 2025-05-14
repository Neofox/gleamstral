import gleam/dynamic/decode
import gleam/httpc
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{Some}
import gleamstral/chat
import gleamstral/client
import gleamstral/message
import gleamstral/model
import gleamstral/tool.{ArrayProperty, NumberProperty, StringProperty}
import glenvy/dotenv
import glenvy/env

// To run this example:
// cd examples && gleam run -m basic_tool

// If you want to make your own tool with custom parameters, you can build the type by hand.
// if you are not gonna define any special behavior, you can use the `new_basic_function` function
// from the `tool` module.
// 
// new_basic_function(
//   "calculator",
//   "A tool that can perform basic arithmetic calculations",
//   [#("operator", StringProperty("should be either +,*,/,-")), #("operands", ArrayProperty("the numbers to operate on", "integer"))],
// )
//
// This is equivalent to:
// OR    
// Function(
//   name: "calculator_custom",
//   description: "A custom tool that can perform basic arithmetic calculations",
//   parameters: ToolParameters(
//     properties: [
//       #("operator", StringProperty(description: "should be either +,*,/,-")),
//       #("operands", ArrayProperty(description: "the numbers to operate on", "integer")),
//     ],
//     required: ["operator", "operands"],
//     tool_type: "function",
//     additional_properties: False,
//   ),
//   strict: False,
// )
// 

pub fn main() {
  let _ = dotenv.load()
  let assert Ok(api_key) = env.get_string("MISTRAL_API_KEY")

  let calculator_tool =
    tool.new_basic_function(
      "calculator",
      "A tool that can perform basic arithmetic calculations",
      [
        #("operator", StringProperty("should be either +,*,/,-")),
        #(
          "operands",
          ArrayProperty(
            "the numbers to operate on",
            NumberProperty(description: "a number"),
          ),
        ),
      ],
    )

  let client = client.new(api_key)
  let chat = chat.new(client) |> chat.set_tools([calculator_tool])

  let messages = [
    message.SystemMessage(message.TextContent(
      "You are a helpful assistant with access to a calculator tool.",
    )),
    message.UserMessage(message.TextContent(
      "What is 4 + 8 + 15 + 16 + 23 + 42? Please use the calculator tool.",
    )),
  ]

  io.println("Sending initial request...")
  let assert Ok(response) =
    chat.complete_request(chat, model.MistralSmall, messages)
    |> httpc.send
  let assert Ok(response) = chat.handle_response(response)
  let assert Ok(choice) = list.first(response.choices)

  io.println("Received response. Processing tool call...")
  let assert message.AssistantMessage(content, Some(tool_calls), _) =
    choice.message
  let assert Ok(tool_call) = list.first(tool_calls)

  io.println("Tool call received:")
  io.println("Content: " <> content)
  io.println("Function: " <> tool_call.function.name)
  io.println("Arguments: " <> tool_call.function.arguments)

  // Execute the tool
  let decoder = {
    use operator <- decode.field("operator", decode.string)
    use operands <- decode.field("operands", decode.list(decode.int))
    decode.success(#(operator, operands))
  }
  let assert Ok(#(operator, operands)) =
    json.parse(tool_call.function.arguments, decoder)
  let assert Ok(result) = calculate(operator, operands)
  let tool_response = int.to_string(result)
  io.println("Tool result: " <> tool_response)

  let tool_message =
    message.ToolMessage(
      message.TextContent(tool_response),
      tool_call.id,
      tool_call.function.name,
    )

  // Add the assistant message and tool response to conversation
  let updated_messages = list.append(messages, [choice.message, tool_message])

  io.println("Sending follow-up request with tool result...")
  let assert Ok(follow_up) =
    chat.complete_request(chat, model.MistralSmall, updated_messages)
    |> httpc.send
  let assert Ok(follow_up) = chat.handle_response(follow_up)
  let assert Ok(follow_up_choice) = list.first(follow_up.choices)

  let assert message.AssistantMessage(final_answer, _, _) =
    follow_up_choice.message

  io.println("Final answer: " <> final_answer)
  io.println(
    "Usage: completion_tokens: "
    <> int.to_string(follow_up.usage.completion_tokens)
    <> " prompt_tokens: "
    <> int.to_string(follow_up.usage.prompt_tokens)
    <> " total_tokens: "
    <> int.to_string(follow_up.usage.total_tokens),
  )
}

fn calculate(operator: String, operands: List(Int)) -> Result(Int, String) {
  case operator {
    "+" -> Ok(list.fold(operands, 0, fn(acc, operand) { acc + operand }))
    "-" -> Ok(list.fold(operands, 0, fn(acc, operand) { acc - operand }))
    "*" -> Ok(list.fold(operands, 1, fn(acc, operand) { acc * operand }))
    "/" -> Ok(list.fold(operands, 1, fn(acc, operand) { acc / operand }))
    _ -> Error("Invalid operator")
  }
}
