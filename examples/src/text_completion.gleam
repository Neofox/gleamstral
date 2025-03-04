import gleam/httpc
import gleam/io
import gleam/list
import gleamstral/chat
import gleamstral/client
import gleamstral/message
import gleamstral/model
import glenvy/dotenv
import glenvy/env

// To run this example:
// cd examples && gleam run -m text_completion 

pub fn main() {
  let _ = dotenv.load()
  let assert Ok(api_key) = env.get_string("MISTRAL_API_KEY")

  let client = client.new(api_key)

  let messages = [
    message.UserMessage(message.TextContent("Explain brievly what is Gleam")),
  ]

  let assert Ok(response) =
    chat.new(client)
    |> chat.set_max_tokens(1000)
    |> chat.complete_request(model.MistralSmall, messages)
    |> httpc.send

  let assert Ok(response) =
    client.handle_response(response, chat.response_decoder())
  let assert Ok(choice) = list.first(response.choices)
  let assert message.AssistantMessage(content, _, _) = choice.message

  io.println("Response: " <> content)
}
