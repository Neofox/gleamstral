import gleam/int
import gleam/io
import gleam/list
import gleamstral/client
import gleamstral/message
import gleamstral/model
import glenvy/dotenv
import glenvy/env

// To run this example:
// gleam run -m json_object 

pub fn main() {
  let _ = dotenv.load()
  let assert Ok(api_key) = env.get_string("MISTRAL_API_KEY")

  // Create a new client
  let client =
    client.new(api_key)
    |> client.set_temperature(0.7)
    |> client.set_max_tokens(150)
    |> client.set_response_format(client.JsonObject)

  let messages = [
    message.SystemMessage(message.TextContent(
      "You should only respond in JSON format. with the following keys: 'country', 'capital'",
    )),
    message.UserMessage(message.TextContent("What is the capital of France?")),
  ]

  let response = client.chat_completion(client, model.MistralSmall, messages)
  case response {
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
      io.println("Error: " <> error)
    }
  }
}
