import gleam/int
import gleam/io
import gleam/list
import gleam/option.{Some}
import gleamstral/client
import gleamstral/message
import gleamstral/model
import gleamstral/response
import glenvy/dotenv
import glenvy/env

// To run this example:
// gleam run -m basic_tool

pub fn main() {
  let _ = dotenv.load()
  let assert Ok(api_key) = env.get_string("MISTRAL_API_KEY")

  // Create a simple calculator tool
  let calculator_tool =
    client.create_function_tool(
      "calculator",
      "A tool that can perform basic arithmetic calculations",
      False,
      [#("expression", "string")],
      ["expression"],
      False,
    )

  let client = client.new(api_key) |> client.set_tools([calculator_tool])

  let messages = [
    message.SystemMessage(message.TextContent(
      "You are a helpful assistant with access to a calculator tool.",
    )),
    message.UserMessage(message.TextContent(
      "What is 1337 * 42? Please use the calculator tool.",
    )),
  ]

  io.println("Sending initial request...")
  let assert Ok(response) =
    client.chat_completion(client, model.MistralSmall, messages)
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
  // TODO: Parse the arguments
  let result = 1337 * 42
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
    client.chat_completion(client, model.MistralLarge, updated_messages)
  let assert Ok(follow_up_choice) = list.first(follow_up.choices)

  let assert message.AssistantMessage(final_answer, _, _) =
    follow_up_choice.message

  io.println("\nFinal answer: " <> final_answer)
  io.println("\nToken usage:")
  io.println(format_usage(follow_up.usage))
}

fn format_usage(usage: response.Usage) -> String {
  "Prompt tokens: "
  <> int.to_string(usage.prompt_tokens)
  <> "\nCompletion tokens: "
  <> int.to_string(usage.completion_tokens)
  <> "\nTotal tokens: "
  <> int.to_string(usage.total_tokens)
}
