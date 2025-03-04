import gleam/httpc
import gleam/int
import gleam/io
import gleam/list
import gleamstral/chat
import gleamstral/client
import gleamstral/message
import gleamstral/model
import glenvy/dotenv
import glenvy/env

// To run this example:
// cd examples && gleam run -m json_object 

pub fn main() {
  let _ = dotenv.load()
  let assert Ok(api_key) = env.get_string("MISTRAL_API_KEY")

  // Create a new client
  let client = client.new(api_key)

  let messages = [
    message.SystemMessage(message.TextContent(
      "You should only respond in JSON format. with the following keys: 'country', 'capital'",
    )),
    message.UserMessage(message.TextContent("What is the capital of France?")),
  ]

  let assert Ok(response) =
    chat.new(client)
    |> chat.set_response_format(chat.JsonObject)
    |> chat.set_max_tokens(100)
    |> chat.complete_request(model.MistralSmall, messages)
    |> httpc.send

  case chat.handle_response(response) {
    Ok(res) -> {
      let assert Ok(choice) = list.first(res.choices)
      let assert message.AssistantMessage(content, _, _) = choice.message

      io.println("Response: " <> content)
      io.println(
        "Usage: completion_tokens: "
        <> int.to_string(res.usage.completion_tokens)
        <> " prompt_tokens: "
        <> int.to_string(res.usage.prompt_tokens)
        <> " total_tokens: "
        <> int.to_string(res.usage.total_tokens),
      )
    }
    Error(error) -> {
      case error {
        client.RateLimitExceeded -> io.println("Rate limit exceeded")
        client.Unauthorized -> io.println("Unauthorized")
        client.Unknown(error) -> io.println("Unknown error: " <> error)
      }
    }
  }
}
