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
    message.UserMessage(message.TextContent(
      "Explain the story of lucy the star",
    )),
  ]

  let request =
    chat.new(client)
    |> chat.set_max_tokens(1000)
    |> chat.set_stream(True)
    |> chat.complete_request(model.MistralSmall, messages)

  let assert Ok(response) = request |> httpc.send

  let assert Ok(response) = chat.handle_response(response)
  let assert Ok(choice) = list.first(response.choices)
  let assert message.AssistantMessage(content, _, _) = choice.message

  io.println("Response: " <> content)
}
