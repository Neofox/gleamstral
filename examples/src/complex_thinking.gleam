import gleam/httpc
import gleam/io
import gleam/list
import gleam/option
import gleam/regexp
import gleamstral/chat
import gleamstral/client
import gleamstral/message
import gleamstral/model
import glenvy/dotenv
import glenvy/env

// To run this example:
// cd examples && gleam run -m complex_thinking

pub fn main() {
  let _ = dotenv.load()
  let assert Ok(api_key) = env.string("MISTRAL_API_KEY")

  let client = client.new(api_key)

  let messages = [
    message.UserMessage(message.TextContent(
      "Hello world",
      // "If we lay 5 shirts out in the sun and it takes 4 hours to dry, how long would 20 shirts take to dry?",
    )),
  ]

  let assert Ok(response) =
    chat.new(client)
    |> chat.set_max_tokens(8000)
    |> chat.complete_request(model.MagistralSmall, messages)
    |> httpc.send
    |> echo

  let assert Ok(response) = chat.handle_response(response)
  let assert Ok(choice) = list.first(response.choices)
  let assert message.AssistantMessage(content, _, _) = choice.message

  let #(thinking, answer) = extract_thinking(content)
  io.println("Thinking: " <> thinking)
  io.println("Answer: " <> answer)
}

fn extract_thinking(content: String) -> #(String, String) {
  let assert Ok(reg) =
    regexp.compile(
      "</think>",
      with: regexp.Options(case_insensitive: False, multi_line: True),
    )
    |> echo
  let matches = regexp.scan(reg, content) |> echo

  let assert [match] = matches
  let assert [thinking, answer] = match.submatches

  #(option.unwrap(thinking, "no thinking"), option.unwrap(answer, "no answer"))
}
